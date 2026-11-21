import SwiftUI
import SwiftData
import CoreBluetooth

struct DevicePairingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DevicePairingViewModel()
    @State private var showManualEntry = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scanning status
                PairingStatusBar(viewModel: viewModel)

                // Device list
                if viewModel.discoveredDevices.isEmpty && !viewModel.isScanning {
                    ContentUnavailableView(
                        "No Devices Found",
                        systemImage: "antenna.radiowaves.left.and.right.slash",
                        description: Text("Tap 'Start Scan' to find nearby LED controllers")
                    )
                } else {
                    List {
                        Section {
                            ForEach(viewModel.discoveredDevices) { device in
                                PairingDeviceRow(device: device, viewModel: viewModel)
                            }
                        } header: {
                            HStack {
                                Text("Discovered Devices (\(viewModel.discoveredDevices.count))")
                                Spacer()
                                if viewModel.isScanning {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Pair New Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isScanning {
                        Button("Stop") {
                            viewModel.stopScanning()
                        }
                    } else {
                        Button("Start Scan") {
                            viewModel.startScanning()
                        }
                    }
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualDeviceEntryView()
            }
            .onAppear {
                viewModel.startScanning()
            }
            .onDisappear {
                viewModel.stopScanning()
            }
        }
    }
}

// MARK: - Status Bar
struct PairingStatusBar: View {
    @ObservedObject var viewModel: DevicePairingViewModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(viewModel.bleStateColor)
                    .frame(width: 10, height: 10)
                Text(viewModel.bleStateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning for LED controllers...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Quick actions
            HStack(spacing: 12) {
                Button(viewModel.isScanning ? "Stop Scan" : "Start Scan") {
                    if viewModel.isScanning {
                        viewModel.stopScanning()
                    } else {
                        viewModel.startScanning()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button("Manual Entry") {
                    showManualEntry = true
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Device Row for Pairing
struct PairingDeviceRow: View {
    let device: DiscoveredDevice
    @ObservedObject var viewModel: DevicePairingViewModel

    var body: some View {
        Button {
            viewModel.pairDevice(device)
        } label: {
            HStack(spacing: 12) {
                // Signal strength
                VStack {
                    Image(systemName: rssiIcon(for: device.rssi))
                        .font(.title2)
                        .foregroundStyle(rssiColor(for: device.rssi))
                    Text("\(device.rssi) dBm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Text(device.id.uuidString.prefix(8) + "...")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if device.name.lowercased().contains("lotus") ||
                           device.name.lowercased().contains("lantern") ||
                           device.name.lowercased().contains("led") {
                            Label("LED Controller", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()

                if device.isConnectable {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(!device.isConnectable)
    }

    private func rssiIcon(for rssi: Int) -> String {
        switch rssi {
        case -50...0: return "wifi"
        case -70..<(-50): return "wifi.exclamationmark"
        default: return "wifi.slash"
        }
    }

    private func rssiColor(for rssi: Int) -> Color {
        switch rssi {
        case -50...0: return .green
        case -70..<(-50): return .orange
        default: return .red
        }
    }
}

// MARK: - View Model
@MainActor
class DevicePairingViewModel: ObservableObject {
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isScanning = false
    @Published var bleState: CBManagerState = .unknown
    @Published var pairingStatus: String?
    @Published var errorMessage: String?

    private let bleManager = BLEManager.shared

    init() {
        observeBLEState()
    }

    private func observeBLEState() {
        Task {
            for await state in bleManager.stateStream {
                await MainActor.run {
                    self.bleState = state
                }
            }
        }
    }

    var bleStateColor: Color {
        switch bleState {
        case .poweredOn: return .green
        case .poweredOff: return .red
        case .unauthorized: return .orange
        case .unsupported: return .gray
        case .resetting: return .yellow
        default: return .gray
        }
    }

    var bleStateText: String {
        switch bleState {
        case .poweredOn: return "Bluetooth Ready"
        case .poweredOff: return "Bluetooth Off"
        case .unauthorized: return "Permission Denied"
        case .unsupported: return "Not Supported"
        case .resetting: return "Resetting..."
        default: return "Unknown"
        }
    }

    func startScanning() {
        guard bleState == .poweredOn else {
            errorMessage = "Bluetooth is not powered on. Enable it in Settings."
            return
        }
        isScanning = true
        discoveredDevices = []
        bleManager.scanForDevices()
    }

    func stopScanning() {
        isScanning = false
        bleManager.stopScanning()
    }

    func pairDevice(_ device: DiscoveredDevice) {
        // In a real implementation, this would:
        // 1. Connect to the peripheral
        // 2. Discover services
        // 3. Verify it's a Lotus Lantern controller
        // 4. Save to SwiftData

        pairingStatus = "Connecting to \(device.name)..."

        // For now, show an alert to manually enter details
        // In production, this would be automatic
        let alert = UIAlertController(
            title: "Pair \(device.name)",
            message: "Enter a name and room for this device",
            preferredStyle: .alert
        )

        alert.addTextField { $0.placeholder = "Name (e.g., Bedroom Lights)" }
        alert.addTextField { $0.placeholder = "Room (e.g., Bedroom)" }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Pair", style: .default) { _ in
            let name = alert.textFields?[0].text?.trimmingCharacters(in: .whitespaces) ?? ""
            let room = alert.textFields?[1].text?.trimmingCharacters(in: .whitespaces) ?? ""

            guard !name.isEmpty, !room.isEmpty else { return }

            // Create device with Lotus Lantern UUIDs
            let newDevice = LEDDevice(
                name: name,
                room: room,
                serviceUUID: LotusLanternUUIDs.service.uuidString,
                characteristicUUID: LotusLanternUUIDs.writeCharacteristic.uuidString,
                isConnected: false,
                lastKnownState: nil
            )

            // Save to SwiftData would happen here
            self.pairingStatus = "Paired: \(name)"

            // Dismiss and show success
        })

        // Present alert (would need UIViewController access in real app)
    }
}

// MARK: - Manual Entry
struct ManualDeviceEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var room = ""
    @State private var serviceUUID = LotusLanternUUIDs.service.uuidString
    @State private var writeUUID = LotusLanternUUIDs.writeCharacteristic.uuidString
    @State private var readUUID = LotusLanternUUIDs.readCharacteristic.uuidString

    var body: some View {
        NavigationStack {
            Form {
                Section("Device Info") {
                    TextField("Name (e.g., Bedroom Lights)", text: $name)
                    TextField("Room (e.g., Bedroom)", text: $room)
                }

                Section("Bluetooth UUIDs (Lotus Lantern defaults)") {
                    TextField("Service UUID", text: $serviceUUID)
                        .textInputAutocapitalization(.characters)
                    TextField("Write Characteristic UUID", text: $writeUUID)
                        .textInputAutocapitalization(.characters)
                    TextField("Read Characteristic UUID", text: $readUUID)
                        .textInputAutocapitalization(.characters)
                }

                Section {
                    Button("Save Device") {
                        saveDevice()
                    }
                    .disabled(name.isEmpty || room.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveDevice() {
        let device = LEDDevice(
            name: name,
            room: room,
            serviceUUID: serviceUUID,
            characteristicUUID: writeUUID,
            isConnected: false,
            lastKnownState: nil
        )
        modelContext.insert(device)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    DevicePairingView()
        .modelContainer(for: [LEDDevice.self, WeeklySchedule.self], inMemory: true)
}
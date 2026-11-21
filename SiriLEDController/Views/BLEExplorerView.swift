import SwiftUI
import CoreBluetooth

struct BLEExplorerView: View {
    @StateObject private var viewModel = BLEExplorerViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with scan controls
                ScanControlBar(viewModel: viewModel)

                // Main content
                if viewModel.isInspecting {
                    GATTInspectorView(viewModel: viewModel)
                } else {
                    DeviceListView(viewModel: viewModel)
                }
            }
            .navigationTitle("BLE Explorer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isInspecting {
                        Button("Done") {
                            viewModel.stopInspection()
                        }
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Scan Control Bar
struct ScanControlBar: View {
    @ObservedObject var viewModel: BLEExplorerViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Status indicator
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
                    Text("Scanning...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Action buttons
            HStack(spacing: 16) {
                if viewModel.isScanning {
                    Button("Stop Scan") {
                        viewModel.stopScanning()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("Scan LED Controllers") {
                        viewModel.scanForLEDControllers()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Scan All") {
                        viewModel.scanAllDevices()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button("Clear") {
                    viewModel.clearDevices()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Device List
struct DeviceListView: View {
    @ObservedObject var viewModel: BLEExplorerViewModel

    var body: some View {
        List {
            if viewModel.discoveredDevices.isEmpty {
                ContentUnavailableView(
                    "No Devices Found",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Tap 'Scan LED Controllers' to find Lotus Lantern devices, or 'Scan All' for all BLE devices")
                )
                .listRowBackground(Color.clear)
            } else {
                Section("Discovered Devices (\(viewModel.discoveredDevices.count))") {
                    ForEach(viewModel.discoveredDevices) { device in
                        DiscoveredDeviceRow(device: device) {
                            viewModel.connectAndInspect(device)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct DiscoveredDeviceRow: View {
    let device: DiscoveredDevice
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // RSSI indicator
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
                    Text(device.id.uuidString.prefix(8) + "...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let localName = device.advertisementData[CBAdvertisementDataLocalNameKey] as? String,
                       localName != device.name {
                        Text("Local: \(localName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if device.isConnectable {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                } else {
                    Image(systemName: "xmark.circle")
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

// MARK: - GATT Inspector
struct GATTInspectorView: View {
    @ObservedObject var viewModel: BLEExplorerViewModel

    var body: some View {
        List {
            if viewModel.discoveredServices.isEmpty {
                ContentUnavailableView(
                    "Discovering Services...",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Please wait while we discover GATT services and characteristics")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.discoveredServices) { service in
                    Section(service.name) {
                        ForEach(service.characteristics) { characteristic in
                            CharacteristicRow(characteristic: characteristic)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.isInspecting && viewModel.discoveredServices.isEmpty {
                ProgressView("Discovering GATT...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
            }
        }
    }
}

struct CharacteristicRow: View {
    let characteristic: GATTCharacteristicInfo
    @State private var showValue = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(characteristic.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(characteristic.properties)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundStyle(.accentColor)
                    .clipShape(Capsule())
            }

            Text("UUID: \(characteristic.uuid)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let value = characteristic.value, !value.isEmpty {
                HStack {
                    Text("Value:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button(showValue ? "Hide" : "Show") {
                        showValue.toggle()
                    }
                    .font(.caption)
                }

                if showValue {
                    // Show bytes in detail
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bytes: \(value)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, 4)
                }
            }

            if !characteristic.descriptors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Descriptors:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(characteristic.descriptors) { descriptor in
                        HStack {
                            Text(descriptor.uuid)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                            if let value = descriptor.value {
                                Text(value)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model
@MainActor
class BLEExplorerViewModel: ObservableObject {
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var discoveredServices: [GATTServiceInfo] = []
    @Published var isScanning = false
    @Published var isInspecting = false
    @Published var bleState: CBManagerState = .unknown
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
        case .poweredOn: return "Bluetooth ON"
        case .poweredOff: return "Bluetooth OFF"
        case .unauthorized: return "Not Authorized"
        case .unsupported: return "Unsupported"
        case .resetting: return "Resetting..."
        default: return "Unknown"
        }
    }

    func scanForLEDControllers() {
        guard bleState == .poweredOn else {
            errorMessage = "Bluetooth is not powered on"
            return
        }
        isScanning = true
        discoveredDevices = []
        bleManager.scanForDevices()
    }

    func scanAllDevices() {
        guard bleState == .poweredOn else {
            errorMessage = "Bluetooth is not powered on"
            return
        }
        isScanning = true
        discoveredDevices = []
        bleManager.scanForAllDevices()
    }

    func stopScanning() {
        isScanning = false
        bleManager.stopScanning()
    }

    func clearDevices() {
        discoveredDevices = []
    }

    func connectAndInspect(_ device: DiscoveredDevice) {
        stopScanning()
        isInspecting = true

        Task {
            // Find peripheral and connect
            // Note: In real implementation, we'd get the peripheral from BLEManager
            // For now, we simulate the connection flow
        }
    }

    func stopInspection() {
        isInspecting = false
        bleManager.stopGATTInspection()
        discoveredServices = []
    }
}

// MARK: - Preview
#Preview {
    BLEExplorerView()
}
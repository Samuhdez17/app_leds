import SwiftUI
import SwiftData

struct DevicesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LEDDevice.name) private var devices: [LEDDevice]
    @State private var showingAddDevice = false
    @State private var selectedDevice: LEDDevice?

    var body: some View {
        NavigationStack {
            Group {
                if devices.isEmpty {
                    ContentUnavailableView(
                        "No LED Devices",
                        systemImage: "lightbulb.slash",
                        description: Text("Add your first LED controller to get started")
                    )
                } else {
                    List {
                        ForEach(devices) { device in
                            DeviceRow(device: device)
                                .onTapGesture {
                                    selectedDevice = device
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteDevice(device)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        renameDevice(device)
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
            }
            .navigationTitle("Devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddDevice = true
                    } label: {
                        Label("Add Device", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        rescanDevices()
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingAddDevice) {
                AddDeviceView()
            }
            .sheet(item: $selectedDevice) { device in
                NavigationStack {
                    ControlView(device: device)
                }
            }
            .alert("Rename Device", isPresented: .constant(false)) { } // Placeholder for rename
        }
    }

    private func deleteDevice(_ device: LEDDevice) {
        modelContext.delete(device)
        try? modelContext.save()
    }

    private func renameDevice(_ device: LEDDevice) {
        // TODO: Implement rename alert
    }

    private func rescanDevices() {
        // TODO: Trigger BLE scan
    }
}

struct DeviceRow: View {
    let device: LEDDevice

    var body: some View {
        HStack(spacing: 12) {
            // Connection status indicator
            Circle()
                .fill(device.isConnected ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(device.isConnected ? Color.green : Color.gray, lineWidth: 2)
                        .scaleEffect(device.isConnected ? 1.5 : 1)
                        .animation(device.isConnected ? .easeInOut(duration: 1).repeatForever() : .default, value: device.isConnected)
                )

            // Color preview
            if let stateData = device.lastKnownState,
               let state = RGBCCT.from(data: stateData) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(state.swiftUIColor)
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.headline)
                Text(device.room)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Power toggle
            Toggle("", isOn: Binding(
                get: { device.lastKnownState != nil && RGBCCT.from(data: device.lastKnownState!)?.intensity ?? 0 > 0 },
                set: { _ in }
            ))
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        }
        .padding(.vertical, 8)
    }
}

struct AddDeviceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var room = ""
    @State private var serviceUUID = "FFF0"
    @State private var characteristicUUID = "FFF1"

    var body: some View {
        NavigationStack {
            Form {
                Section("Device Info") {
                    TextField("Name (e.g., Bedroom Lights)", text: $name)
                    TextField("Room (e.g., Bedroom)", text: $room)
                }

                Section("Bluetooth") {
                    TextField("Service UUID", text: $serviceUUID)
                    TextField("Characteristic UUID", text: $characteristicUUID)
                }
            }
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let device = LEDDevice(
                            name: name,
                            room: room,
                            serviceUUID: serviceUUID,
                            characteristicUUID: characteristicUUID
                        )
                        modelContext.insert(device)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty || room.isEmpty)
                }
            }
        }
    }
}
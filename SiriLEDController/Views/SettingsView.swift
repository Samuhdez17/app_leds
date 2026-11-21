import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LEDDevice.name) private var devices: [LEDDevice]
    @State private var showingResetAlert = false
    @State private var showingDebug = false
    @State private var showingBLEExplorer = false

    var body: some View {
        NavigationStack {
            List {
                Section("Devices") {
                    ForEach(devices) { device in
                        NavigationLink {
                            DeviceSettingsView(device: device)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(device.isConnected ? Color.green : Color.gray)
                                    .frame(width: 10, height: 10)
                                Text(device.name)
                                Spacer()
                                Text(device.room)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Bluetooth") {
                    NavigationLink {
                        BLEExplorerView()
                    } label: {
                        Label("BLE Explorer / GATT Inspector", systemImage: "antenna.radiowaves.left.and.right")
                    }

                    NavigationLink {
                        DevicePairingView()
                    } label: {
                        Label("Pair New Device", systemImage: "plus.circle")
                    }
                }

                Section("App") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Build", systemImage: "hammer")
                        Spacer()
                        Text("1")
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        DebugView()
                    } label: {
                        Label("Debug", systemImage: "ladybug")
                    }
                }

                Section("Data") {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Reset All Data", systemImage: "trash")
                    }
                }

                Section("Legal") {
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                    Link("Licenses", destination: URL(string: "https://example.com/licenses")!)
                }
            }
            .navigationTitle("Settings")
            .alert("Reset All Data", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will delete all devices, schedules, and settings. This action cannot be undone.")
            }
        }
    }

    private func resetAllData() {
        for device in devices {
            modelContext.delete(device)
        }
        try? modelContext.save()
    }
}

struct DeviceSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let device: LEDDevice

    @State private var name: String
    @State private var room: String
    @State private var serviceUUID: String
    @State private var characteristicUUID: String

    init(device: LEDDevice) {
        self.device = device
        _name = State(initialValue: device.name)
        _room = State(initialValue: device.room)
        _serviceUUID = State(initialValue: device.serviceUUID)
        _characteristicUUID = State(initialValue: device.characteristicUUID)
    }

    var body: some View {
        Form {
            Section("Device Info") {
                TextField("Name", text: $name)
                TextField("Room", text: $room)
            }

            Section("Bluetooth") {
                TextField("Service UUID", text: $serviceUUID)
                TextField("Characteristic UUID", text: $characteristicUUID)
            }

            Section {
                Button(role: .destructive) {
                    deleteDevice()
                } label: {
                    Label("Delete Device", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Device Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveChanges()
                    dismiss()
                }
            }
        }
    }

    private func saveChanges() {
        device.name = name
        device.room = room
        device.serviceUUID = serviceUUID
        device.characteristicUUID = characteristicUUID
        device.updatedAt = Date()
        try? modelContext.save()
    }

    private func deleteDevice() {
        modelContext.delete(device)
        try? modelContext.save()
        dismiss()
    }
}

struct DebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var devices: [LEDDevice]
    @Query private var schedules: [WeeklySchedule]

    var body: some View {
        List {
            Section("Devices (\(devices.count))") {
                ForEach(devices) { device in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name).font(.headline)
                        Text("ID: \(device.id.uuidString)").font(.caption).foregroundStyle(.secondary)
                        Text("Room: \(device.room)").font(.caption).foregroundStyle(.secondary)
                        Text("Service: \(device.serviceUUID)").font(.caption).foregroundStyle(.secondary)
                        Text("Characteristic: \(device.characteristicUUID)").font(.caption).foregroundStyle(.secondary)
                        Text("Connected: \(device.isConnected ? "Yes" : "No")").font(.caption).foregroundStyle(.secondary)
                        if let state = device.lastKnownState {
                            Text("Last State: \(state.map { String(format: "%02X", $0) }.joined(separator: " "))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Schedules (\(schedules.count))") {
                ForEach(schedules) { schedule in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(schedule.name).font(.headline)
                        Text("Device: \(schedule.device?.name ?? "None")").font(.caption).foregroundStyle(.secondary)
                        Text("Enabled: \(schedule.isEnabled ? "Yes" : "No")").font(.caption).foregroundStyle(.secondary)
                        Text("Weekdays: \(formatTime(schedule.weekdaysOn)) - \(formatTime(schedule.weekdaysOff))").font(.caption).foregroundStyle(.secondary)
                        Text("Weekends: \(formatTime(schedule.weekendOn)) - \(formatTime(schedule.weekendOff))").font(.caption).foregroundStyle(.secondary)
                        if let state = RGBCCT.from(data: schedule.targetColor) {
                            Text("Target: \(state.swiftUIColor.description) · \(Int(schedule.targetIntensity * 100))% · \(Int(schedule.targetColorTemp))K")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("SwiftData") {
                Button("Print Schema") {
                    print(SQLiteSchema.script)
                }
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Helper to access SQLite schema
private enum SQLiteSchema {
    static var script: String {
        var output = ""
        let context = PersistenceController(inMemory: true).modelContainer.mainContext
        // SwiftData doesn't expose raw SQLite schema easily
        output = "Use Xcode's Data Model inspector or `sqlite3` CLI on the .sqlite file"
        return output
    }
}
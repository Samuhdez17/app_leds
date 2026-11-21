import SwiftUI
import SwiftData

struct DeviceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LEDDevice.name) private var devices: [LEDDevice]
    @State private var selectedDevice: LEDDevice?

    var body: some View {
        NavigationStack {
            Group {
                if devices.isEmpty {
                    ContentUnavailableView(
                        "No Devices",
                        systemImage: "lightbulb.slash",
                        description: Text("Add devices from iPhone app")
                    )
                } else {
                    List {
                        ForEach(devices) { device in
                            WatchDeviceRow(device: device)
                                .onTapGesture {
                                    selectedDevice = device
                                }
                        }
                    }
                }
            }
            .navigationTitle("LED Control")
            .sheet(item: $selectedDevice) { device in
                NavigationStack {
                    DeviceControlView(device: device)
                }
            }
        }
    }
}

struct WatchDeviceRow: View {
    let device: LEDDevice

    var body: some View {
        HStack(spacing: 12) {
            // Connection status
            Circle()
                .fill(device.isConnected ? Color.green : Color.gray)
                .frame(width: 10, height: 10)

            // Color preview
            if let stateData = device.lastKnownState,
               let state = RGBCCT.from(data: stateData) {
                Circle()
                    .fill(state.swiftUIColor)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    )
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(device.room)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Power indicator
            if let stateData = device.lastKnownState,
               let state = RGBCCT.from(data: stateData),
               state.intensity > 0 {
                Text("\(Int(state.intensity * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
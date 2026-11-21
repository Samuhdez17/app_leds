import SwiftUI

struct ContentView: View {
    @State private var devices: [WatchDevice] = [
        WatchDevice(id: UUID(), name: "Living Room", isOn: true, brightness: 0.8, color: .blue),
        WatchDevice(id: UUID(), name: "Bedroom", isOn: false, brightness: 0.5, color: .orange),
        WatchDevice(id: UUID(), name: "Kitchen", isOn: true, brightness: 1.0, color: .white)
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(devices) { device in
                    WatchDeviceRow(device: device)
                }
            }
            .navigationTitle("LED Control")
        }
    }
}

struct WatchDevice: Identifiable {
    let id: UUID
    let name: String
    var isOn: Bool
    var brightness: Double
    let color: Color
}

struct WatchDeviceRow: View {
    let device: WatchDevice
    
    var body: some View {
        HStack {
            Circle()
                .fill(device.isOn ? device.color : .gray)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.headline)
                Text(device.isOn ? "On" : "Off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if device.isOn {
                Text("\(Int(device.brightness * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
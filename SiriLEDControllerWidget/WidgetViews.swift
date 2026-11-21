import SwiftUI
import WidgetKit

struct WidgetEntryView: View {
    var entry: WidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: WidgetEntry

    var device: WidgetDeviceEntry? {
        entry.devices.first
    }

    var body: some View {
        VStack(spacing: 8) {
            if let device = device {
                ZStack {
                    Circle()
                        .fill(device.state.swiftUIColor)
                        .frame(width: 50, height: 50)

                    if !device.isConnected {
                        Circle()
                            .stroke(Color.gray.opacity(0.5), lineWidth: 3)
                            .frame(width: 50, height: 50)
                    }
                }

                Text(device.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(device.isConnected ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(device.isConnected ? "\(Int(device.state.intensity * 100))%" : "Off")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let next = entry.nextSchedule {
                    VStack(spacing: 2) {
                        Text(next.action == "On" ? "Next: On" : "Next: Off")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(next.time, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Devices",
                    systemImage: "lightbulb.slash",
                    description: Text("Add devices in app")
                )
            }
        }
        .padding()
    }
}

struct MediumWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("LED Devices")
                    .font(.headline)
                Spacer()
                if let next = entry.nextSchedule {
                    Text("Next: \(next.action) at \(next.time, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if entry.devices.isEmpty {
                ContentUnavailableView(
                    "No Devices",
                    systemImage: "lightbulb.slash",
                    description: Text("Add devices in app")
                )
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(entry.devices.prefix(4)) { device in
                        MediumDeviceCard(device: device)
                    }
                }
            }
        }
        .padding()
    }
}

struct MediumDeviceCard: View {
    let device: WidgetDeviceEntry

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(device.state.swiftUIColor)
                    .frame(width: 44, height: 44)

                if !device.isConnected {
                    Circle()
                        .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
            }

            Text(device.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            HStack(spacing: 4) {
                Circle()
                    .fill(device.isConnected ? Color.green : Color.gray)
                    .frame(width: 5, height: 5)
                Text(device.isConnected ? "\(Int(device.state.intensity * 100))%" : "Off")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LargeWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("LED Devices")
                    .font(.headline)
                Spacer()
                if let next = entry.nextSchedule {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Next Schedule")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(next.action) \(next.deviceName) at \(next.time, style: .time)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }

            if entry.devices.isEmpty {
                ContentUnavailableView(
                    "No Devices",
                    systemImage: "lightbulb.slash",
                    description: Text("Add devices in app")
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(entry.devices) { device in
                        LargeDeviceRow(device: device)
                    }
                }
            }
        }
        .padding()
    }
}

struct LargeDeviceRow: View {
    let device: WidgetDeviceEntry

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(device.state.swiftUIColor)
                    .frame(width: 36, height: 36)

                if !device.isConnected {
                    Circle()
                        .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 36, height: 36)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(device.room)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(device.isConnected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(device.isConnected ? "\(Int(device.state.intensity * 100))%" : "Off")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
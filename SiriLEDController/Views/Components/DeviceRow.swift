import SwiftUI

struct DeviceRow: View {
    let device: LEDDevice
    let showPowerToggle: Bool
    let onTap: (() -> Void)?
    let onRename: (() -> Void)?
    let onDelete: (() -> Void)?

    init(
        device: LEDDevice,
        showPowerToggle: Bool = true,
        onTap: (() -> Void)? = nil,
        onRename: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.device = device
        self.showPowerToggle = showPowerToggle
        self.onTap = onTap
        self.onRename = onRename
        self.onDelete = onDelete
    }

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
                        .animation(
                            device.isConnected ? .easeInOut(duration: 1).repeatForever() : .default,
                            value: device.isConnected
                        )
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
            if showPowerToggle {
                Toggle("", isOn: Binding(
                    get: {
                        device.lastKnownState != nil &&
                        RGBCCT.from(data: device.lastKnownState!)?.intensity ?? 0 > 0
                    },
                    set: { _ in }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .contextMenu {
            if let onRename {
                Button {
                    onRename()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
            }
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var device = LEDDevice(
        name: "Bedroom Lights",
        room: "Bedroom",
        serviceUUID: "FFF0",
        characteristicUUID: "FFF1",
        isConnected: true,
        lastKnownState: RGBCCT.warmWhite.data
    )
    DeviceRow(device: device)
        .padding()
}
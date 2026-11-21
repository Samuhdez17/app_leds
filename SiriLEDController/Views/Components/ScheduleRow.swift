import SwiftUI

struct ScheduleRow: View {
    let schedule: WeeklySchedule
    let onToggle: ((Bool) -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    init(
        schedule: WeeklySchedule,
        onToggle: ((Bool) -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.schedule = schedule
        self.onToggle = onToggle
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(schedule.name)
                        .font(.subheadline)
                    HStack(spacing: 12) {
                        Label(
                            "\(timeFormatter.string(from: schedule.weekdaysOn)) – \(timeFormatter.string(from: schedule.weekdaysOff))",
                            systemImage: "calendar"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Label(
                            "\(timeFormatter.string(from: schedule.weekendOn)) – \(timeFormatter.string(from: schedule.weekendOff))",
                            systemImage: "calendar.badge.clock"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { schedule.isEnabled },
                    set: { newValue in
                        onToggle?(newValue)
                    }
                ))
                .labelsHidden()
            }

            // Target state preview
            if let state = RGBCCT.from(data: schedule.targetColor) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(state.swiftUIColor)
                        .frame(width: 24, height: 24)
                    Text("\(Int(schedule.targetIntensity * 100))% · \(Int(schedule.targetColorTemp))K")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit?()
        }
        .contextMenu {
            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
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
    let calendar = Calendar.current
    var components = DateComponents()
    components.hour = 7
    components.minute = 0
    let weekdaysOn = calendar.date(from: components)!
    components.hour = 23
    components.minute = 0
    let weekdaysOff = calendar.date(from: components)!
    components.hour = 8
    components.minute = 0
    let weekendOn = calendar.date(from: components)!
    components.hour = 22
    components.minute = 0
    let weekendOff = calendar.date(from: components)!

    @Previewable @State var schedule = WeeklySchedule(
        name: "Morning Wake Up",
        weekdaysOn: weekdaysOn,
        weekdaysOff: weekdaysOff,
        weekendOn: weekendOn,
        weekendOff: weekendOff,
        targetColor: RGBCCT.warmWhite.data,
        targetIntensity: 0.8,
        targetColorTemp: 3000,
        isEnabled: true
    )

    ScheduleRow(schedule: schedule)
        .padding()
}
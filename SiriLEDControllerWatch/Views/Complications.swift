import SwiftUI
import ClockKit
import SwiftData

struct CircularComplicationView: View {
    let device: LEDDevice?
    let state: RGBCCT

    var body: some View {
        ZStack {
            if let state = device?.lastKnownState.flatMap({ RGBCCT.from(data: $0) }) {
                // Animated ring
                Circle()
                    .trim(from: 0, to: state.intensity)
                    .stroke(
                        state.swiftUIColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 40, height: 40)

                // Center indicator
                Image(systemName: state.intensity > 0 ? "lightbulb.fill" : "lightbulb.slash")
                    .font(.title2)
                    .foregroundStyle(state.intensity > 0 ? Color.primary : Color.secondary)
            } else {
                Image(systemName: "lightbulb.slash")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RectangularComplicationView: View {
    let device: LEDDevice?
    let state: RGBCCT

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: state.intensity > 0 ? "lightbulb.fill" : "lightbulb.slash")
                    .foregroundStyle(state.intensity > 0 ? Color.accentColor : Color.secondary)
                Text(device?.name ?? "No Device")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }

            if let device = device {
                Text(device.room)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let stateData = device.lastKnownState,
                   let state = RGBCCT.from(data: stateData),
                   state.intensity > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(state.swiftUIColor)
                            .frame(width: 8, height: 8)
                        Text("\(Int(state.intensity * 100))%")
                            .font(.caption2)
                    }
                } else {
                    Text("Off")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ModularComplicationView: View {
    let device: LEDDevice?
    let state: RGBCCT
    let nextSchedule: WidgetScheduleEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(state.swiftUIColor)
                    .frame(width: 12, height: 12)
                Text(device?.name ?? "No Device")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }

            if let next = nextSchedule {
                HStack {
                    Image(systemName: next.action == "On" ? "arrow.up.circle" : "arrow.down.circle")
                        .foregroundStyle(.accentColor)
                    Text("\(next.action) at \(next.time, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if let device = device,
                      let stateData = device.lastKnownState,
                      let state = RGBCCT.from(data: stateData) {
                HStack {
                    Text("\(Int(state.intensity * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }
}

// Timeline Provider for complications
struct ComplicationTimelineProvider: TimelineProvider {
    typealias Entry = ComplicationEntry

    let modelContainer: ModelContainer

    init() {
        let schema = Schema([LEDDevice.self, WeeklySchedule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        self.modelContainer = try! ModelContainer(for: schema, configurations: [config])
    }

    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), device: nil, state: .off, nextSchedule: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let entry = ComplicationEntry(date: Date(), device: nil, state: .off, nextSchedule: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        Task {
            let context = ModelContext(modelContainer)
            let devices = (try? context.fetch(FetchDescriptor<LEDDevice>())) ?? []
            let schedules = (try? context.fetch(FetchDescriptor<WeeklySchedule>())) ?? []

            let device = devices.first
            let state = device?.lastKnownState.flatMap { RGBCCT.from(data: $0) } ?? .off
            let nextSchedule = findNextSchedule(schedules)

            let entry = ComplicationEntry(date: Date(), device: device, state: state, nextSchedule: nextSchedule)
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
            completion(timeline)
        }
    }

    private func findNextSchedule(_ schedules: [WeeklySchedule]) -> WidgetScheduleEntry? {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        return schedules
            .filter { $0.isEnabled }
            .compactMap { schedule -> (Date, WidgetScheduleEntry)? in
                let isWeekday = (2...6).contains(weekday)
                let onTime = isWeekday ? schedule.weekdaysOn : schedule.weekendOn
                let offTime = isWeekday ? schedule.weekdaysOff : schedule.weekendOff

                let nextOn = calendar.nextDate(after: now, matching: calendar.dateComponents([.hour, .minute], from: onTime), matchingPolicy: .nextTime)!
                let nextOff = calendar.nextDate(after: now, matching: calendar.dateComponents([.hour, .minute], from: offTime), matchingPolicy: .nextTime)!

                if nextOn < nextOff {
                    return (nextOn, WidgetScheduleEntry(deviceName: schedule.device?.name ?? "Unknown", time: nextOn, action: "On", targetColor: schedule.targetColor, targetIntensity: schedule.targetIntensity, targetColorTemp: schedule.targetColorTemp))
                } else {
                    return (nextOff, WidgetScheduleEntry(deviceName: schedule.device?.name ?? "Unknown", time: nextOff, action: "Off", targetColor: schedule.targetColor, targetIntensity: schedule.targetIntensity, targetColorTemp: schedule.targetColorTemp))
                }
            }
            .min { $0.0 < $1.0 }?.1
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let device: LEDDevice?
    let state: RGBCCT
    let nextSchedule: WidgetScheduleEntry?
}
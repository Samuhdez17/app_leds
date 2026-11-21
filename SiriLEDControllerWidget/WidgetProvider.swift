import Foundation
import SwiftData
import WidgetKit

struct WidgetProvider: TimelineProvider {
    typealias Entry = WidgetEntry

    let modelContainer: ModelContainer

    init() {
        let schema = Schema([LEDDevice.self, WeeklySchedule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        self.modelContainer = try! ModelContainer(for: schema, configurations: [config])
    }

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), devices: [], nextSchedule: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = WidgetEntry(date: Date(), devices: [], nextSchedule: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        Task {
            let context = ModelContext(modelContainer)
            let devices = (try? context.fetch(FetchDescriptor<LEDDevice>())) ?? []
            let schedules = (try? context.fetch(FetchDescriptor<WeeklySchedule>())) ?? []

            let deviceEntries = devices.map { device in
                WidgetDeviceEntry(
                    id: device.id.uuidString,
                    name: device.name,
                    room: device.room,
                    isConnected: device.isConnected,
                    state: device.lastKnownState.flatMap { RGBCCT.from(data: $0) } ?? .off
                )
            }

            let nextSchedule = findNextSchedule(schedules)

            let entry = WidgetEntry(date: Date(), devices: deviceEntries, nextSchedule: nextSchedule)
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
            completion(timeline)
        }
    }

    private func findNextSchedule(_ schedules: [WeeklySchedule]) -> WidgetScheduleEntry? {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)

        let upcoming = schedules
            .filter { $0.isEnabled }
            .compactMap { schedule -> (Date, WidgetScheduleEntry)? in
                let isWeekday = (2...6).contains(weekday) // Mon-Fri
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
            .min { $0.0 < $1.0 }

        return upcoming?.1
    }
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let devices: [WidgetDeviceEntry]
    let nextSchedule: WidgetScheduleEntry?
}

struct WidgetDeviceEntry: Identifiable {
    let id: String
    let name: String
    let room: String
    let isConnected: Bool
    let state: RGBCCT
}

struct WidgetScheduleEntry {
    let deviceName: String
    let time: Date
    let action: String
    let targetColor: Data
    let targetIntensity: Double
    let targetColorTemp: Double

    var targetRGBCCT: RGBCCT {
        RGBCCT.from(data: targetColor) ?? .off
    }
}
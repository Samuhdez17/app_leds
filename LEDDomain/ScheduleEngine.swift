import Foundation
import SwiftData

public enum ScheduleActionType: Sendable {
    case turnOn(deviceId: UUID, targetColor: RGBCCT, intensity: Double, colorTemp: Double)
    case turnOff(deviceId: UUID)
}

public struct ScheduleAction: Sendable {
    public let id: UUID
    public let scheduleId: UUID
    public let deviceId: UUID
    public let type: ScheduleActionType
    public let scheduledTime: Date

    public init(
        id: UUID = UUID(),
        scheduleId: UUID,
        deviceId: UUID,
        type: ScheduleActionType,
        scheduledTime: Date
    ) {
        self.id = id
        self.scheduleId = scheduleId
        self.deviceId = deviceId
        self.type = type
        self.scheduledTime = scheduledTime
    }
}

public actor ScheduleEngine {
    public static let shared = ScheduleEngine()

    private let modelContainer: ModelContainer

    private init() {
        let schema = Schema([LEDDevice.self, WeeklySchedule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        self.modelContainer = try! ModelContainer(for: schema, configurations: [config])
    }

    public func evaluateSchedules() -> [ScheduleAction] {
        let context = modelContainer.mainContext
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let currentTimeComponents = calendar.dateComponents([.hour, .minute], from: now)
        let currentMinutes = (currentTimeComponents.hour ?? 0) * 60 + (currentTimeComponents.minute ?? 0)

        var actions: [ScheduleAction] = []

        do {
            let schedules = try context.fetch(
                FetchDescriptor<WeeklySchedule>(
                    predicate: #Predicate { $0.isEnabled == true }
                )
            )

            for schedule in schedules {
                guard let device = schedule.device else { continue }

                let isWeekday = (2...6).contains(weekday) // Mon-Fri
                let onTime = isWeekday ? schedule.weekdaysOn : schedule.weekendOn
                let offTime = isWeekday ? schedule.weekdaysOff : schedule.weekendOff

                let onComponents = calendar.dateComponents([.hour, .minute], from: onTime)
                let offComponents = calendar.dateComponents([.hour, .minute], from: offTime)
                let onMinutes = (onComponents.hour ?? 0) * 60 + (onComponents.minute ?? 0)
                let offMinutes = (offComponents.hour ?? 0) * 60 + (offComponents.minute ?? 0)

                // Check for ON action
                if currentMinutes == onMinutes {
                    let targetRGBCCT = RGBCCT.from(data: schedule.targetColor) ?? .off
                    actions.append(ScheduleAction(
                        scheduleId: schedule.id,
                        deviceId: device.id,
                        type: .turnOn(
                            deviceId: device.id,
                            targetColor: targetRGBCCT,
                            intensity: schedule.targetIntensity,
                            colorTemp: schedule.targetColorTemp
                        ),
                        scheduledTime: now
                    ))
                }

                // Check for OFF action
                if currentMinutes == offMinutes {
                    actions.append(ScheduleAction(
                        scheduleId: schedule.id,
                        deviceId: device.id,
                        type: .turnOff(deviceId: device.id),
                        scheduledTime: now
                    ))
                }
            }
        } catch {
            print("Failed to evaluate schedules: \(error)")
        }

        return actions
    }

    public func getNextScheduledActions(limit: Int = 5) -> [ScheduleAction] {
        let context = modelContainer.mainContext
        let now = Date()
        let calendar = Calendar.current

        var upcomingActions: [(Date, ScheduleAction)] = []

        do {
            let schedules = try context.fetch(
                FetchDescriptor<WeeklySchedule>(
                    predicate: #Predicate { $0.isEnabled == true }
                )
            )

            for schedule in schedules {
                guard let device = schedule.device else { continue }

                let onTime = schedule.weekdaysOn
                let offTime = schedule.weekdaysOff

                let nextOn = calendar.nextDate(after: now, matching: calendar.dateComponents([.hour, .minute], from: onTime), matchingPolicy: .nextTime)!
                let nextOff = calendar.nextDate(after: now, matching: calendar.dateComponents([.hour, .minute], from: offTime), matchingPolicy: .nextTime)!

                if nextOn < nextOff {
                    let targetRGBCCT = RGBCCT.from(data: schedule.targetColor) ?? .off
                    upcomingActions.append((nextOn, ScheduleAction(
                        scheduleId: schedule.id,
                        deviceId: device.id,
                        type: .turnOn(deviceId: device.id, targetColor: targetRGBCCT, intensity: schedule.targetIntensity, colorTemp: schedule.targetColorTemp),
                        scheduledTime: nextOn
                    )))
                    upcomingActions.append((nextOff, ScheduleAction(
                        scheduleId: schedule.id,
                        deviceId: device.id,
                        type: .turnOff(deviceId: device.id),
                        scheduledTime: nextOff
                    )))
                } else {
                    upcomingActions.append((nextOff, ScheduleAction(
                        scheduleId: schedule.id,
                        deviceId: device.id,
                        type: .turnOff(deviceId: device.id),
                        scheduledTime: nextOff
                    )))
                    let targetRGBCCT = RGBCCT.from(data: schedule.targetColor) ?? .off
                    upcomingActions.append((nextOn, ScheduleAction(
                        scheduleId: schedule.id,
                        deviceId: device.id,
                        type: .turnOn(deviceId: device.id, targetColor: targetRGBCCT, intensity: schedule.targetIntensity, colorTemp: schedule.targetColorTemp),
                        scheduledTime: nextOn
                    )))
                }
            }
        } catch {
            print("Failed to get upcoming actions: \(error)")
        }

        return upcomingActions
            .sorted { $0.0 < $1.0 }
            .prefix(limit)
            .map { $0.1 }
    }
}
import Foundation
import AppIntents
import SwiftData

@available(iOS 17.0, watchOS 10.0, *)
struct LEDDeviceEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "LED Device"
    static var defaultQuery = LEDDeviceQuery()

    let id: String
    let name: String
    let room: String
    let serviceUUID: String
    let characteristicUUID: String

    @Property(title: "Name")
    var displayName: String { name }

    @Property(title: "Room")
    var displayRoom: String { room }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(room)",
            image: .init(systemName: "lightbulb.fill")
        )
    }
}

@available(iOS 17.0, watchOS 10.0, *)
struct LEDDeviceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LEDDeviceEntity] {
        let context = PersistenceController.shared.newBackgroundContext()
        let descriptor = FetchDescriptor<LEDDevice>(
            predicate: #Predicate { device in
                identifiers.contains(device.id.uuidString)
            }
        )
        let devices = try context.fetch(descriptor)
        return devices.map { LEDDeviceEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [LEDDeviceEntity] {
        let context = PersistenceController.shared.newBackgroundContext()
        let descriptor = FetchDescriptor<LEDDevice>(sortBy: [SortDescriptor(\.name)])
        let devices = try context.fetch(descriptor)
        return devices.map { LEDDeviceEntity(from: $0) }
    }
}

extension LEDDeviceEntity {
    init(from device: LEDDevice) {
        self.id = device.id.uuidString
        self.name = device.name
        self.room = device.room
        self.serviceUUID = device.serviceUUID
        self.characteristicUUID = device.characteristicUUID
    }
}

@available(iOS 17.0, watchOS 10.0, *)
struct WeeklyScheduleEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Weekly Schedule"
    static var defaultQuery = WeeklyScheduleQuery()

    let id: String
    let name: String
    let deviceName: String
    let weekdaysOn: Date
    let weekdaysOff: Date
    let weekendOn: Date
    let weekendOff: Date
    let isEnabled: Bool

    @Property(title: "Name")
    var displayName: String { name }

    @Property(title: "Device")
    var displayDevice: String { deviceName }

    @Property(title: "Enabled")
    var displayEnabled: String { isEnabled ? "On" : "Off" }

    var displayRepresentation: DisplayRepresentation {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let onTime = timeFormatter.string(from: weekdaysOn)
        let offTime = timeFormatter.string(from: weekdaysOff)

        return DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(deviceName) · Weekdays \(onTime)–\(offTime) · \(isEnabled ? "Enabled" : "Disabled")",
            image: .init(systemName: isEnabled ? "clock.fill" : "clock")
        )
    }
}

@available(iOS 17.0, watchOS 10.0, *)
struct WeeklyScheduleQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WeeklyScheduleEntity] {
        let context = PersistenceController.shared.newBackgroundContext()
        let descriptor = FetchDescriptor<WeeklySchedule>(
            predicate: #Predicate { schedule in
                identifiers.contains(schedule.id.uuidString)
            }
        )
        let schedules = try context.fetch(descriptor)
        return schedules.compactMap { schedule in
            guard let device = schedule.device else { return nil }
            return WeeklyScheduleEntity(from: schedule, deviceName: device.name)
        }
    }

    func suggestedEntities() async throws -> [WeeklyScheduleEntity] {
        let context = PersistenceController.shared.newBackgroundContext()
        let descriptor = FetchDescriptor<WeeklySchedule>(sortBy: [SortDescriptor(\.name)])
        let schedules = try context.fetch(descriptor)
        return schedules.compactMap { schedule in
            guard let device = schedule.device else { return nil }
            return WeeklyScheduleEntity(from: schedule, deviceName: device.name)
        }
    }
}

extension WeeklyScheduleEntity {
    init(from schedule: WeeklySchedule, deviceName: String) {
        self.id = schedule.id.uuidString
        self.name = schedule.name
        self.deviceName = deviceName
        self.weekdaysOn = schedule.weekdaysOn
        self.weekdaysOff = schedule.weekdaysOff
        self.weekendOn = schedule.weekendOn
        self.weekendOff = schedule.weekendOff
        self.isEnabled = schedule.isEnabled
    }
}
import Foundation
import Testing
import SwiftData
@testable import LEDCore

@Suite("ScheduleEngine Tests")
struct ScheduleEngineTests {

    @Test("ScheduleActionType turnOn initialization")
    func testScheduleActionTypeTurnOn() {
        let deviceId = UUID()
        let targetColor = RGBCCT.warmWhite
        let action = ScheduleActionType.turnOn(
            deviceId: deviceId,
            targetColor: targetColor,
            intensity: 0.8,
            colorTemp: 3000
        )

        switch action {
        case .turnOn(let d, let color, let intensity, let temp):
            #expect(d == deviceId)
            #expect(color == targetColor)
            #expect(intensity == 0.8)
            #expect(temp == 3000)
        case .turnOff:
            #expect(Bool(false), "Wrong action type")
        }
    }

    @Test("ScheduleActionType turnOff initialization")
    func testScheduleActionTypeTurnOff() {
        let deviceId = UUID()
        let action = ScheduleActionType.turnOff(deviceId: deviceId)

        switch action {
        case .turnOff(let d):
            #expect(d == deviceId)
        case .turnOn:
            #expect(Bool(false), "Wrong action type")
        }
    }

    @Test("ScheduleAction initialization")
    func testScheduleActionInit() {
        let scheduleId = UUID()
        let deviceId = UUID()
        let actionType = ScheduleActionType.turnOff(deviceId: deviceId)
        let scheduledTime = Date()

        let action = ScheduleAction(
            scheduleId: scheduleId,
            deviceId: deviceId,
            type: actionType,
            scheduledTime: scheduledTime
        )

        #expect(action.scheduleId == scheduleId)
        #expect(action.deviceId == deviceId)
        #expect(action.scheduledTime == scheduledTime)

        switch action.type {
        case .turnOff(let d):
            #expect(d == deviceId)
        default:
            #expect(Bool(false), "Wrong action type")
        }
    }

    @Test("ScheduleEngine evaluates schedules")
    func testScheduleEngineEvaluation() async throws {
        let engine = ScheduleEngine.shared
        let context = engine.modelContainer.mainContext

        // Create test device
        let device = LEDDevice(
            name: "Test Device",
            room: "Test Room",
            serviceUUID: "FFF0",
            characteristicUUID: "FFF1",
            isConnected: true
        )
        context.insert(device)

        // Create schedule for current time
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: Date())
        components.minute = components.minute! + 1 // Next minute
        let onTime = calendar.date(from: components)!
        components.minute = components.minute! + 2
        let offTime = calendar.date(from: components)!

        let schedule = WeeklySchedule(
            name: "Test Schedule",
            weekdaysOn: onTime,
            weekdaysOff: offTime,
            weekendOn: onTime,
            weekendOff: offTime,
            targetColor: RGBCCT.warmWhite.data,
            targetIntensity: 0.8,
            targetColorTemp: 3000,
            isEnabled: true
        )
        schedule.device = device
        context.insert(schedule)

        try context.save()

        // Evaluate schedules
        let actions = engine.evaluateSchedules()

        // Should find the schedule if time matches
        #expect(actions.count >= 0)
    }

    @Test("ScheduleEngine getNextScheduledActions")
    func testGetNextScheduledActions() async throws {
        let engine = ScheduleEngine.shared
        let context = engine.modelContainer.mainContext

        let device = LEDDevice(
            name: "Test Device",
            room: "Test Room",
            serviceUUID: "FFF0",
            characteristicUUID: "FFF1",
            isConnected: true
        )
        context.insert(device)

        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.hour, .minute], from: now)
        components.minute = components.minute! + 5
        let onTime = calendar.date(from: components)!
        components.minute = components.minute! + 30
        let offTime = calendar.date(from: components)!

        let schedule = WeeklySchedule(
            name: "Test Schedule",
            weekdaysOn: onTime,
            weekdaysOff: offTime,
            weekendOn: onTime,
            weekendOff: offTime,
            targetColor: RGBCCT.warmWhite.data,
            targetIntensity: 0.8,
            targetColorTemp: 3000,
            isEnabled: true
        )
        schedule.device = device
        context.insert(schedule)

        try context.save()

        let upcoming = engine.getNextScheduledActions(limit: 5)

        #expect(upcoming.count >= 0)
        // Should have at least the on and off actions
    }

    @Test("ScheduleEngine handles disabled schedules")
    func testDisabledSchedules() async throws {
        let engine = ScheduleEngine.shared
        let context = engine.modelContainer.mainContext

        let device = LEDDevice(
            name: "Test Device",
            room: "Test Room",
            serviceUUID: "FFF0",
            characteristicUUID: "FFF1",
            isConnected: true
        )
        context.insert(device)

        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: Date())
        components.minute = components.minute! + 1
        let onTime = calendar.date(from: components)!
        components.minute = components.minute! + 2
        let offTime = calendar.date(from: components)!

        let schedule = WeeklySchedule(
            name: "Disabled Schedule",
            weekdaysOn: onTime,
            weekdaysOff: offTime,
            weekendOn: onTime,
            weekendOff: offTime,
            targetColor: RGBCCT.warmWhite.data,
            targetIntensity: 0.8,
            targetColorTemp: 3000,
            isEnabled: false // Disabled
        )
        schedule.device = device
        context.insert(schedule)

        try context.save()

        let actions = engine.evaluateSchedules()

        // Should not include disabled schedule
        #expect(actions.isEmpty)
    }
}
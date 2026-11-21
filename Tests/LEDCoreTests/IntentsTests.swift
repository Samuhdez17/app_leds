import Foundation
import Testing
@testable import LEDCore

@Suite("App Intents Tests")
struct IntentsTests {

    @Test("LEDDeviceEntity initialization")
    func testLEDDeviceEntityInit() {
        let entity = LEDDeviceEntity(
            id: "test-id",
            name: "Test Light",
            room: "Living Room",
            serviceUUID: "FFF0",
            characteristicUUID: "FFF1"
        )

        #expect(entity.id == "test-id")
        #expect(entity.name == "Test Light")
        #expect(entity.room == "Living Room")
        #expect(entity.serviceUUID == "FFF0")
        #expect(entity.characteristicUUID == "FFF1")
        #expect(entity.displayName == "Test Light")
        #expect(entity.displayRoom == "Living Room")
    }

    @Test("WeeklyScheduleEntity initialization")
    func testWeeklyScheduleEntityInit() {
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

        let entity = WeeklyScheduleEntity(
            id: "sched-1",
            name: "Morning",
            deviceName: "Bedroom",
            weekdaysOn: weekdaysOn,
            weekdaysOff: weekdaysOff,
            weekendOn: weekendOn,
            weekendOff: weekendOff,
            isEnabled: true
        )

        #expect(entity.id == "sched-1")
        #expect(entity.name == "Morning")
        #expect(entity.deviceName == "Bedroom")
        #expect(entity.isEnabled == true)
        #expect(entity.displayName == "Morning")
        #expect(entity.displayDevice == "Bedroom")
        #expect(entity.displayEnabled == "On")
    }

    @Test("PowerIntent parameter summary")
    func testPowerIntentSummary() {
        let intent = PowerIntent()
        intent.device = LEDDeviceEntity(
            id: "1", name: "Test", room: "Room", serviceUUID: "FFF0", characteristicUUID: "FFF1"
        )
        intent.power = true

        let summary = intent.parameterSummary
        #expect(summary != nil)
    }

    @Test("SetColorIntent parameter validation")
    func testSetColorIntentValidation() {
        let intent = SetColorIntent()
        intent.device = LEDDeviceEntity(
            id: "1", name: "Test", room: "Room", serviceUUID: "FFF0", characteristicUUID: "FFF1"
        )
        intent.hue = 1.5 // Over 1.0
        intent.saturation = -0.5 // Under 0

        // The intent doesn't validate at creation, but perform() clamps values
        #expect(intent.hue == 1.5)
        #expect(intent.saturation == -0.5)
    }

    @Test("SetColorTemperatureIntent parameter validation")
    func testSetColorTempIntentValidation() {
        let intent = SetColorTemperatureIntent()
        intent.device = LEDDeviceEntity(
            id: "1", name: "Test", room: "Room", serviceUUID: "FFF0", characteristicUUID: "FFF1"
        )
        intent.kelvin = 10000 // Over 6500

        #expect(intent.kelvin == 10000)
    }

    @Test("SetIntensityIntent parameter validation")
    func testSetIntensityIntentValidation() {
        let intent = SetIntensityIntent()
        intent.device = LEDDeviceEntity(
            id: "1", name: "Test", room: "Room", serviceUUID: "FFF0", characteristicUUID: "FFF1"
        )
        intent.intensity = 1.5 // Over 1.0

        #expect(intent.intensity == 1.5)
    }

    @Test("EnableScheduleIntent parameter summary")
    func testEnableScheduleIntentSummary() {
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

        let intent = EnableScheduleIntent()
        intent.schedule = WeeklyScheduleEntity(
            id: "1", name: "Test", deviceName: "Device",
            weekdaysOn: weekdaysOn, weekdaysOff: weekdaysOff,
            weekendOn: weekendOn, weekendOff: weekendOff,
            isEnabled: false
        )

        let summary = intent.parameterSummary
        #expect(summary != nil)
    }

    @Test("DisableScheduleIntent parameter summary")
    func testDisableScheduleIntentSummary() {
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

        let intent = DisableScheduleIntent()
        intent.schedule = WeeklyScheduleEntity(
            id: "1", name: "Test", deviceName: "Device",
            weekdaysOn: weekdaysOn, weekdaysOff: weekdaysOff,
            weekendOn: weekendOn, weekendOff: weekendOff,
            isEnabled: true
        )

        let summary = intent.parameterSummary
        #expect(summary != nil)
    }

    @Test("DeviceStatusResult display representation")
    func testDeviceStatusResult() {
        let result = DeviceStatusResult(
            deviceName: "Test Light",
            isOn: true,
            intensity: 0.75,
            colorTemp: 4000,
            color: "warm white"
        )

        #expect(result.deviceName == "Test Light")
        #expect(result.isOn == true)
        #expect(result.intensity == 0.75)
        #expect(result.colorTemp == 4000)
        #expect(result.color == "warm white")
    }
}
import Foundation
import Testing
import SwiftData
@testable import LEDCore

@Suite("Models Tests")
struct ModelsTests {

    @Test("LEDDevice initializes with correct properties")
    func testLEDDeviceInitialization() {
        let device = LEDDevice(
            name: "Test Light",
            room: "Living Room",
            serviceUUID: "FFF0",
            characteristicUUID: "FFF1"
        )

        #expect(device.name == "Test Light")
        #expect(device.room == "Living Room")
        #expect(device.serviceUUID == "FFF0")
        #expect(device.characteristicUUID == "FFF1")
        #expect(device.isConnected == false)
        #expect(device.lastKnownState == nil)
        #expect(device.schedules.isEmpty)
        #expect(device.id != UUID())
    }

    @Test("LEDDevice initializes with custom values")
    func testLEDDeviceCustomInitialization() {
        let state = RGBCCT.warmWhite.data
        let device = LEDDevice(
            name: "Bedroom",
            room: "Bedroom",
            serviceUUID: "AAA0",
            characteristicUUID: "AAA1",
            isConnected: true,
            lastKnownState: state
        )

        #expect(device.isConnected == true)
        #expect(device.lastKnownState == state)
    }

    @Test("WeeklySchedule initializes with correct properties")
    func testWeeklyScheduleInitialization() {
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

        let targetColor = RGBCCT(red: 255, green: 100, blue: 50, warmWhite: 200, coolWhite: 50).data
        let schedule = WeeklySchedule(
            name: "Morning Wake Up",
            weekdaysOn: weekdaysOn,
            weekdaysOff: weekdaysOff,
            weekendOn: weekendOn,
            weekendOff: weekendOff,
            targetColor: targetColor,
            targetIntensity: 0.75,
            targetColorTemp: 3500,
            isEnabled: true
        )

        #expect(schedule.name == "Morning Wake Up")
        #expect(schedule.weekdaysOn == weekdaysOn)
        #expect(schedule.weekdaysOff == weekdaysOff)
        #expect(schedule.weekendOn == weekendOn)
        #expect(schedule.weekendOff == weekendOff)
        #expect(schedule.targetColor == targetColor)
        #expect(schedule.targetIntensity == 0.75)
        #expect(schedule.targetColorTemp == 3500)
        #expect(schedule.isEnabled == true)
        #expect(schedule.device == nil)
    }

    @Test("WeeklySchedule device relationship works")
    func testWeeklyScheduleDeviceRelationship() {
        let device = LEDDevice(
            name: "Test",
            room: "Room",
            serviceUUID: "FFF0",
            characteristicUUID: "FFF1"
        )

        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 7
        components.minute = 0
        let weekdaysOn = calendar.date(from: components)!
        components.hour = 23
        components.minute = 0
        let weekdaysOff = calendar.date(from: components)!

        let schedule = WeeklySchedule(
            name: "Test Schedule",
            weekdaysOn: weekdaysOn,
            weekdaysOff: weekdaysOff,
            weekendOn: weekdaysOn,
            weekendOff: weekdaysOff,
            targetColor: RGBCCT.off.data,
            targetIntensity: 0.5,
            targetColorTemp: 4000
        )
        schedule.device = device

        #expect(schedule.device?.id == device.id)
        #expect(device.schedules.contains { $0.id == schedule.id })
    }

    @Test("RGBCCT encodes and decodes correctly")
    func testRGBCCTEncoding() {
        let original = RGBCCT(red: 255, green: 128, blue: 64, warmWhite: 200, coolWhite: 100)
        let data = original.data
        let decoded = RGBCCT.from(data: data)

        #expect(decoded?.red == 255)
        #expect(decoded?.green == 128)
        #expect(decoded?.blue == 64)
        #expect(decoded?.warmWhite == 200)
        #expect(decoded?.coolWhite == 100)
    }

    @Test("RGBCCT static presets work")
    func testRGBCCTPresets() {
        #expect(RGBCCT.off.red == 0)
        #expect(RGBCCT.off.intensity == 0.0)

        #expect(RGBCCT.warmWhite.warmWhite == 255)
        #expect(RGBCCT.warmWhite.intensity == 1.0)

        #expect(RGBCCT.coolWhite.coolWhite == 255)

        #expect(RGBCCT.neutralWhite.warmWhite == 128)
        #expect(RGBCCT.neutralWhite.coolWhite == 128)
    }

    @Test("RGBCCT intensity calculation")
    func testRGBCCTIntensity() {
        let full = RGBCCT(red: 255, green: 255, blue: 255, warmWhite: 255, coolWhite: 255)
        #expect(full.intensity == 1.0)

        let half = RGBCCT(red: 128, green: 0, blue: 0, warmWhite: 0, coolWhite: 0)
        #expect(abs(half.intensity - 128.0/255.0) < 0.01)

        let off = RGBCCT.off
        #expect(off.intensity == 0.0)
    }

    @Test("RGBCCT color temperature calculation")
    func testRGBCCTColorTemp() {
        let warm = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 255, coolWhite: 0)
        #expect(warm.colorTemperatureKelvin == 2000)

        let cool = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 0, coolWhite: 255)
        #expect(cool.colorTemperatureKelvin == 6500)

        let neutral = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 128, coolWhite: 128)
        #expect(abs(neutral.colorTemperatureKelvin - 4250) < 50)
    }

    @Test("ModelContainer initializes in memory")
    func testModelContainerInMemory() async throws {
        let controller = PersistenceController(inMemory: true)
        #expect(controller.modelContainer != nil)
    }

    @Test("Preview controller has sample data")
    func testPreviewController() async throws {
        let controller = PersistenceController.preview
        let context = controller.modelContainer.mainContext

        let devices = try context.fetch(FetchDescriptor<LEDDevice>())
        #expect(devices.count >= 2)

        let schedules = try context.fetch(FetchDescriptor<WeeklySchedule>())
        #expect(schedules.count >= 1)
    }

    @Test("SwiftData CRUD operations work")
    func testSwiftDataCRUD() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.modelContainer.mainContext

        let device = LEDDevice(
            name: "CRUD Test",
            room: "Test Room",
            serviceUUID: "TEST",
            characteristicUUID: "TEST"
        )
        context.insert(device)

        try controller.save(context: context)

        let fetched = try controller.fetch(LEDDevice.self, in: context)
        #expect(fetched.contains { $0.name == "CRUD Test" })

        controller.delete(device, in: context)
        try controller.save(context: context)

        let afterDelete = try controller.fetch(LEDDevice.self, in: context)
        #expect(!afterDelete.contains { $0.name == "CRUD Test" })
    }
}
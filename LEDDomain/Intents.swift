import Foundation
import AppIntents
import SwiftData

@available(iOS 17.0, watchOS 10.0, *)
struct PowerIntent: AppIntent {
    static var title: LocalizedStringResource = "Power"
    static var description = IntentDescription("Turn LED device on or off")

    @Parameter(title: "Device")
    var device: LEDDeviceEntity

    @Parameter(title: "Power")
    var power: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("\(power ? "Turn on" : "Turn off") \(\.$device)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let manager = BLEManager.shared
        let peripheralId = UUID(uuidString: device.id) ?? UUID()

        let data = CommonLEDCommandEncoder.shared.encodePower(on: power)
        try await manager.writeCommand(data, to: peripheralId)

        return .result(value: power ? "Turned on \(device.name)" : "Turned off \(device.name)")
    }
}

@available(iOS 17.0, watchOS 10.0, *)
struct SetColorIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Color"
    static var description = IntentDescription("Set LED device color (hue/saturation)")

    @Parameter(title: "Device")
    var device: LEDDeviceEntity

    @Parameter(title: "Hue", default: 0.0)
    var hue: Double

    @Parameter(title: "Saturation", default: 1.0)
    var saturation: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Set color of \(\.$device) to hue \(\.$hue), saturation \(\.$saturation)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let manager = BLEManager.shared
        let peripheralId = UUID(uuidString: device.id) ?? UUID()

        let clampedHue = max(0, min(1, hue))
        let clampedSat = max(0, min(1, saturation))

        let (r, g, b) = hsvToRgb(hue: clampedHue, saturation: clampedSat, brightness: 1.0)
        let data = CommonLEDCommandEncoder.shared.encodeColor(
            red: r, green: g, blue: b, warmWhite: 0, coolWhite: 0
        )
        try await manager.writeCommand(data, to: peripheralId)

        return .result(value: "Set color of \(device.name)")
    }

    private func hsvToRgb(hue: Double, saturation: Double, brightness: Double) -> (UInt8, UInt8, UInt8) {
        let h = hue.truncatingRemainder(dividingBy: 1.0)
        let s = max(0, min(1, saturation))
        let v = max(0, min(1, brightness))

        let i = Int(h * 6)
        let f = h * 6 - Double(i)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)

        let (r, g, b): (Double, Double, Double)
        switch i % 6 {
        case 0: (r, g, b) = (v, t, p)
        case 1: (r, g, b) = (q, v, p)
        case 2: (r, g, b) = (p, v, t)
        case 3: (r, g, b) = (p, q, v)
        case 4: (r, g, b) = (t, p, v)
        case 5: (r, g, b) = (v, p, q)
        default: (r, g, b) = (0, 0, 0)
        }

        return (UInt8(r * 255), UInt8(g * 255), UInt8(b * 255))
    }
}

@available(iOS 17.0, watchOS 10.0, *)
struct SetColorTemperatureIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Color Temperature"
    static var description = IntentDescription("Set LED device color temperature in Kelvin")

    @Parameter(title: "Device")
    var device: LEDDeviceEntity

    @Parameter(title: "Kelvin", default: 4000)
    var kelvin: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Set color temperature of \(\.$device) to \(\.$kelvin)K")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let manager = BLEManager.shared
        let peripheralId = UUID(uuidString: device.id) ?? UUID()

        let clampedKelvin = max(2000, min(6500, kelvin))
        let data = CommonLEDCommandEncoder.shared.encodeColorTemp(kelvin: clampedKelvin)
        try await manager.writeCommand(data, to: peripheralId)

        return .result(value: "Set color temperature of \(device.name) to \(clampedKelvin)K")
    }
}

@available(iOS 17.0, watchOS 10.0, *)
struct SetIntensityIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Intensity"
    static var description = IntentDescription("Set LED device brightness intensity")

    @Parameter(title: "Device")
    var device: LEDDeviceEntity

    @Parameter(title: "Intensity", default: 1.0)
    var intensity: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Set intensity of \(\.$device) to \(\.$intensity)%")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let manager = BLEManager.shared
        let peripheralId = UUID(uuidString: device.id) ?? UUID()

        let clampedIntensity = max(0, min(1, intensity))
        let data = CommonLEDCommandEncoder.shared.encodeIntensity(clampedIntensity)
        try await manager.writeCommand(data, to: peripheralId)

        return .result(value: "Set intensity of \(device.name) to \(Int(clampedIntensity * 100))%")
    }
}

@available(iOS 17.0, watchOS 10.0, *)
struct QueryStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Query Status"
    static var description = IntentDescription("Get current LED device status")

    @Parameter(title: "Device")
    var device: LEDDeviceEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get status of \(\.$device)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<DeviceStatusResult> {
        let manager = BLEManager.shared
        let peripheralId = UUID(uuidString: device.id) ?? UUID()

        let stateData = try await manager.readState(from: peripheralId)

        let status = parseState(stateData)
        let result = DeviceStatusResult(
            deviceName: device.name,
            isOn: status.isOn,
            intensity: status.intensity,
            colorTemp: status.colorTemp,
            color: status.color
        )

        return .result(value: result)
    }

    private func parseState(_ data: Data) -> (isOn: Bool, intensity: Double, colorTemp: Int, color: String) {
        guard data.count >= 6 else {
            return (false, 0, 4000, "unknown")
        }
        let isOn = data[0] == 0x01
        let r = data[1], g = data[2], b = data[3], ww = data[4], cw = data[5]
        let intensity = Double(max(r, g, b, ww, cw)) / 255.0
        let totalWhite = Double(ww + cw)
        let colorTemp = totalWhite > 0 ? Int(2000 + 4500 * (1 - Double(ww) / totalWhite)) : 4000
        let color = r > g && r > b ? "red" : g > b ? "green" : "blue"
        return (isOn, intensity, colorTemp, color)
    }
}

@available(iOS 17.0, watchOS 10.0, *)
struct DeviceStatusResult: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Device Status"
    static var defaultQuery = DeviceStatusResultQuery()

    let id = UUID().uuidString
    let deviceName: String
    let isOn: Bool
    let intensity: Double
    let colorTemp: Int
    let color: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(deviceName)",
            subtitle: "\(isOn ? "On" : "Off") · \(Int(intensity * 100))% · \(colorTemp)K · \(color)"
        )
    }
}

@available(iOS 17.0, watchOS 10.0, *)
struct DeviceStatusResultQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DeviceStatusResult] { [] }
    func suggestedEntities() async throws -> [DeviceStatusResult] { [] }
}

@available(iOS 17.0, watchOS 10.0, *)
struct EnableScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable Schedule"
    static var description = IntentDescription("Enable a weekly schedule for an LED device")

    @Parameter(title: "Schedule")
    var schedule: WeeklyScheduleEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Enable schedule \(\.$schedule)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let context = PersistenceController.shared.newBackgroundContext()
        let descriptor = FetchDescriptor<WeeklySchedule>(
            predicate: #Predicate { $0.id.uuidString == schedule.id }
        )
        if let model = try context.fetch(descriptor).first {
            model.isEnabled = true
            model.updatedAt = Date()
            try PersistenceController.shared.save(context: context)
        }

        return .result(value: "Enabled schedule \(schedule.name)")
    }
}

@available(iOS 17.0, watchOS 10.0, *)
struct DisableScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Schedule"
    static var description = IntentDescription("Disable a weekly schedule for an LED device")

    @Parameter(title: "Schedule")
    var schedule: WeeklyScheduleEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Disable schedule \(\.$schedule)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let context = PersistenceController.shared.newBackgroundContext()
        let descriptor = FetchDescriptor<WeeklySchedule>(
            predicate: #Predicate { $0.id.uuidString == schedule.id }
        )
        if let model = try context.fetch(descriptor).first {
            model.isEnabled = false
            model.updatedAt = Date()
            try PersistenceController.shared.save(context: context)
        }

        return .result(value: "Disabled schedule \(schedule.name)")
    }
}

@available(iOS 17.0, watchOS 10.0, *)
struct LEDShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PowerIntent(),
            phrases: [
                "Turn on \(.applicationName)",
                "Turn off \(.applicationName)",
                "\(.applicationName) on",
                "\(.applicationName) off"
            ],
            shortTitle: "Power",
            systemImageName: "power"
        ),
        AppShortcut(
            intent: SetColorIntent(),
            phrases: [
                "Set \(.applicationName) color",
                "Change \(.applicationName) to red"
            ],
            shortTitle: "Color",
            systemImageName: "paintpalette"
        ),
        AppShortcut(
            intent: SetIntensityIntent(),
            phrases: [
                "Set \(.applicationName) brightness",
                "Dim \(.applicationName)"
            ],
            shortTitle: "Brightness",
            systemImageName: "sun.max"
        ),
        AppShortcut(
            intent: QueryStatusIntent(),
            phrases: [
                "What's the status of \(.applicationName)",
                "Is \(.applicationName) on"
            ],
            shortTitle: "Status",
            systemImageName: "info.circle"
        )
    }
}
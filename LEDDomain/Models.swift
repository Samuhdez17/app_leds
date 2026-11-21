import Foundation
import SwiftData
import SwiftUI

@Model
final class LEDDevice {
    @Attribute(.unique) var id: UUID
    var name: String
    var room: String
    var serviceUUID: String
    var characteristicUUID: String
    var isConnected: Bool
    var lastKnownState: Data?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WeeklySchedule.device)
    var schedules: [WeeklySchedule] = []

    init(
        id: UUID = UUID(),
        name: String,
        room: String,
        serviceUUID: String,
        characteristicUUID: String,
        isConnected: Bool = false,
        lastKnownState: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.room = room
        self.serviceUUID = serviceUUID
        self.characteristicUUID = characteristicUUID
        self.isConnected = isConnected
        self.lastKnownState = lastKnownState
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class WeeklySchedule {
    @Attribute(.unique) var id: UUID
    var name: String
    var weekdaysOn: Date
    var weekdaysOff: Date
    var weekendOn: Date
    var weekendOff: Date
    var targetColor: Data
    var targetIntensity: Double
    var targetColorTemp: Double
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    var device: LEDDevice?

    init(
        id: UUID = UUID(),
        name: String,
        weekdaysOn: Date,
        weekdaysOff: Date,
        weekendOn: Date,
        weekendOff: Date,
        targetColor: Data,
        targetIntensity: Double,
        targetColorTemp: Double,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.weekdaysOn = weekdaysOn
        self.weekdaysOff = weekdaysOff
        self.weekendOn = weekendOn
        self.weekendOff = weekendOff
        self.targetColor = targetColor
        self.targetIntensity = targetIntensity
        self.targetColorTemp = targetColorTemp
        self.isEnabled = isEnabled
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct RGBCCT: Codable, Sendable, Equatable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    var warmWhite: UInt8
    var coolWhite: UInt8

    init(red: UInt8 = 0, green: UInt8 = 0, blue: UInt8 = 0, warmWhite: UInt8 = 0, coolWhite: UInt8 = 0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.warmWhite = warmWhite
        self.coolWhite = coolWhite
    }

    static let off = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 0, coolWhite: 0)
    static let warmWhite = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 255, coolWhite: 0)
    static let coolWhite = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 0, coolWhite: 255)
    static let neutralWhite = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 128, coolWhite: 128)

    var data: Data {
        Data([red, green, blue, warmWhite, coolWhite])
    }

    static func from(data: Data) -> RGBCCT? {
        guard data.count >= 5 else { return nil }
        return RGBCCT(red: data[0], green: data[1], blue: data[2], warmWhite: data[3], coolWhite: data[4])
    }

    var intensity: Double {
        Double(max(red, green, blue, warmWhite, coolWhite)) / 255.0
    }

    var colorTemperatureKelvin: Double {
        let totalWhite = Double(warmWhite + coolWhite)
        guard totalWhite > 0 else { return 4000 }
        let warmRatio = Double(warmWhite) / totalWhite
        return 2000 + (4500 * (1 - warmRatio))
    }

    var swiftUIColor: Color {
        guard intensity > 0 else { return .black }

        let r = Double(red) / 255.0
        let g = Double(green) / 255.0
        let b = Double(blue) / 255.0
        let ww = Double(warmWhite) / 255.0
        let cw = Double(coolWhite) / 255.0

        if r > 0 || g > 0 || b > 0 {
            return Color(red: r, green: g, blue: b)
        } else {
            let whiteVal = (ww + cw) / 2.0
            return Color(white: whiteVal)
        }
    }
}
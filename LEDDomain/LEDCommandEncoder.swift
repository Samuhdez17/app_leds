import Foundation

public protocol LEDCommandEncoder: Sendable {
    func encodePower(on: Bool) -> Data
    func encodeColor(red: UInt8, green: UInt8, blue: UInt8) -> Data
    func encodeWhite(warmWhite: UInt8, coolWhite: UInt8) -> Data
    func encodeBrightness(_ brightness: UInt8) -> Data
    func encodeColorTemp(kelvin: Int) -> Data
    func encodeEffect(_ effect: Effect, speed: UInt8) -> Data
    func encodeFullState(power: Bool, red: UInt8, green: UInt8, blue: UInt8, warmWhite: UInt8, coolWhite: UInt8, brightness: UInt8) -> Data
}

public struct LotusLanternEncoder: LEDCommandEncoder {
    public static let shared = LotusLanternEncoder()

    private init() {}

    // MARK: - Frame Format
    // 7E LEN CMD D0 D1 D2 D3 00 EF (9 bytes)
    private let startByte: UInt8 = 0x7E
    private let endByte: UInt8 = 0xEF
    private let reservedByte: UInt8 = 0x00
    private let payloadLength: UInt8 = 0x07 // CMD + D0 + D1 + D2 + D3 + 00 = 6 bytes, but protocol says 7

    // MARK: - Command Bytes (from LotusLantern protocol)
    private enum Command: UInt8 {
        case power = 0x01
        case color = 0x02
        case brightness = 0x03
        case colorTemp = 0x04
        case effect = 0x05
        case speed = 0x06
        case white = 0x07
        case query = 0x0F
    }

    // MARK: - Effects
    public enum Effect: UInt8, Sendable, CaseIterable {
        case staticColor = 0x00
        case jump = 0x01
        case fade = 0x02
        case flash = 0x03
        case strobe = 0x04
        case smooth = 0x05
        case police = 0x06
        case fireworks = 0x07
        case breathing = 0x08
        case heartbeat = 0x09
    }

    // MARK: - Frame Builder
    private func buildFrame(cmd: Command, d0: UInt8, d1: UInt8 = 0x00, d2: UInt8 = 0x00, d3: UInt8 = 0x00) -> Data {
        var frame = Data()
        frame.append(startByte)           // 7E
        frame.append(payloadLength)       // 07
        frame.append(cmd.rawValue)        // CMD
        frame.append(d0)                  // D0
        frame.append(d1)                  // D1
        frame.append(d2)                  // D2
        frame.append(d3)                  // D3
        frame.append(reservedByte)        // 00
        frame.append(endByte)             // EF
        return frame
    }

    // MARK: - Public Encoders
    public func encodePower(on: Bool) -> Data {
        buildFrame(cmd: .power, d0: on ? 0x01 : 0x00)
    }

    public func encodeColor(red: UInt8, green: UInt8, blue: UInt8) -> Data {
        buildFrame(cmd: .color, d0: red, d1: green, d2: blue)
    }

    public func encodeWhite(warmWhite: UInt8, coolWhite: UInt8) -> Data {
        buildFrame(cmd: .white, d0: warmWhite, d1: coolWhite)
    }

    public func encodeBrightness(_ brightness: UInt8) -> Data {
        buildFrame(cmd: .brightness, d0: brightness)
    }

    public func encodeColorTemp(kelvin: Int) -> Data {
        let clamped = max(2000, min(6500, kelvin))
        // Convert Kelvin to warm/cool ratio
        let warmRatio = Double(6500 - clamped) / 4500.0
        let warm = UInt8(255 * warmRatio)
        let cool = UInt8(255 * (1.0 - warmRatio))
        return buildFrame(cmd: .colorTemp, d0: warm, d1: cool)
    }

    public func encodeEffect(_ effect: Effect, speed: UInt8 = 0x80) -> Data {
        buildFrame(cmd: .effect, d0: effect.rawValue, d1: speed)
    }

    public func encodeFullState(power: Bool, red: UInt8, green: UInt8, blue: UInt8, warmWhite: UInt8, coolWhite: UInt8, brightness: UInt8) -> Data {
        // For full state, we send multiple commands in sequence
        // This returns the power command; caller should send others separately
        buildFrame(cmd: .power, d0: power ? 0x01 : 0x00)
    }

    // MARK: - Command Sequences
    public func encodeFullStateSequence(power: Bool, red: UInt8, green: UInt8, blue: UInt8, warmWhite: UInt8, coolWhite: UInt8, brightness: UInt8) -> [Data] {
        var commands: [Data] = []

        // 1. Power
        commands.append(encodePower(on: power))

        // 2. Brightness
        commands.append(encodeBrightness(brightness))

        // 3. Color or White
        if red > 0 || green > 0 || blue > 0 {
            commands.append(encodeColor(red: red, green: green, blue: blue))
        } else if warmWhite > 0 || coolWhite > 0 {
            commands.append(encodeWhite(warmWhite: warmWhite, coolWhite: coolWhite))
        }

        return commands
    }
}

// MARK: - RGBCCT Model
public struct RGBCCT: Codable, Sendable, Equatable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var warmWhite: UInt8
    public var coolWhite: UInt8

    public init(red: UInt8 = 0, green: UInt8 = 0, blue: UInt8 = 0, warmWhite: UInt8 = 0, coolWhite: UInt8 = 0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.warmWhite = warmWhite
        self.coolWhite = coolWhite
    }

    public static let off = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 0, coolWhite: 0)
    public static let warmWhite = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 255, coolWhite: 0)
    public static let coolWhite = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 0, coolWhite: 255)
    public static let neutralWhite = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 128, coolWhite: 128)
    public static let red = RGBCCT(red: 255, green: 0, blue: 0, warmWhite: 0, coolWhite: 0)
    public static let green = RGBCCT(red: 0, green: 255, blue: 0, warmWhite: 0, coolWhite: 0)
    public static let blue = RGBCCT(red: 0, green: 0, blue: 255, warmWhite: 0, coolWhite: 0)

    public var data: Data {
        Data([red, green, blue, warmWhite, coolWhite])
    }

    public static func from(data: Data) -> RGBCCT? {
        guard data.count >= 5 else { return nil }
        return RGBCCT(red: data[0], green: data[1], blue: data[2], warmWhite: data[3], coolWhite: data[4])
    }

    public var intensity: Double {
        Double(max(red, green, blue, warmWhite, coolWhite)) / 255.0
    }

    public var colorTemperatureKelvin: Int {
        let totalWhite = Double(warmWhite + coolWhite)
        guard totalWhite > 0 else { return 4000 }
        let warmRatio = Double(warmWhite) / totalWhite
        return Int(2000 + (4500 * (1 - warmRatio)))
    }

    public func withIntensity(_ intensity: Double) -> RGBCCT {
        let factor = max(0, min(1, intensity))
        return RGBCCT(
            red: UInt8(Double(red) * factor),
            green: UInt8(Double(green) * factor),
            blue: UInt8(Double(blue) * factor),
            warmWhite: UInt8(Double(warmWhite) * factor),
            coolWhite: UInt8(Double(coolWhite) * factor)
        )
    }

    public func withColorTemp(_ kelvin: Int) -> RGBCCT {
        let clamped = max(2000, min(6500, kelvin))
        let warmRatio = Double(6500 - clamped) / 4500
        let totalWhite = max(1, Double(warmWhite + coolWhite))
        let newWarm = UInt8(totalWhite * warmRatio)
        let newCool = UInt8(totalWhite * (1 - warmRatio))
        return RGBCCT(
            red: red,
            green: green,
            blue: blue,
            warmWhite: newWarm,
            coolWhite: newCool
        )
    }
}

// MARK: - SwiftUI Color Extension
import SwiftUI

extension RGBCCT {
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

// MARK: - Mock for Testing
public struct MockBLEManager: Sendable {
    public var lastWrittenData: Data?
    public var lastWrittenSequence: [Data] = []
    public var lastConnectedPeripheral: UUID?
    public var connectionState: BLEConnectionState = .disconnected
    public var shouldFailConnection = false
    public var shouldFailWrite = false

    public init() {}

    public mutating func scanForDevices() {
        connectionState = .scanning
    }

    public mutating func connect(to peripheralId: UUID) async throws {
        if shouldFailConnection {
            connectionState = .failed(peripheralId, BLEError.connectionFailed)
            throw BLEError.connectionFailed
        }
        connectionState = .connecting(peripheralId)
        connectionState = .connected(peripheralId)
        lastConnectedPeripheral = peripheralId
    }

    public mutating func disconnect(from peripheralId: UUID) {
        connectionState = .disconnected
        if lastConnectedPeripheral == peripheralId {
            lastConnectedPeripheral = nil
        }
    }

    public mutating func writeCommand(_ data: Data, to peripheralId: UUID) async throws {
        if shouldFailWrite {
            throw BLEError.writeFailed(BLEError.connectionFailed)
        }
        lastWrittenData = data
    }

    public mutating func writeSequence(_ sequence: [Data], to peripheralId: UUID) async throws {
        if shouldFailWrite {
            throw BLEError.writeFailed(BLEError.connectionFailed)
        }
        lastWrittenSequence = sequence
        lastWrittenData = sequence.last
    }

    public mutating func readState(from peripheralId: UUID) async throws -> Data {
        // Simulate device response: Power ON, Brightness 255, Warm White
        return Data([0x7E, 0x07, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0xEF])
    }
}
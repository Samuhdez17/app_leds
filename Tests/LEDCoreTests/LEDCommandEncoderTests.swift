import Foundation
import Testing
@testable import LEDCore

@Suite("LEDCommandEncoder Tests")
struct LEDCommandEncoderTests {

    let encoder = CommonLEDCommandEncoder.shared

    @Test("encodePower on")
    func testEncodePowerOn() {
        let data = encoder.encodePower(on: true)
        #expect(data.count == 2)
        #expect(data[0] == 0x01) // Command.setPower.rawValue
        #expect(data[1] == 0x01)
    }

    @Test("encodePower off")
    func testEncodePowerOff() {
        let data = encoder.encodePower(on: false)
        #expect(data.count == 2)
        #expect(data[0] == 0x01)
        #expect(data[1] == 0x00)
    }

    @Test("encodeColor RGBCCT")
    func testEncodeColor() {
        let data = encoder.encodeColor(red: 255, green: 128, blue: 64, warmWhite: 200, coolWhite: 100)
        #expect(data.count == 6)
        #expect(data[0] == 0x02) // Command.setColor.rawValue
        #expect(data[1] == 255)
        #expect(data[2] == 128)
        #expect(data[3] == 64)
        #expect(data[4] == 200)
        #expect(data[5] == 100)
    }

    @Test("encodeIntensity")
    func testEncodeIntensity() {
        let data = encoder.encodeIntensity(0.5)
        #expect(data.count == 2)
        #expect(data[0] == 0x03) // Command.setIntensity.rawValue
        #expect(data[1] == UInt8(127.5)) // 0.5 * 255 = 127.5 -> 127 or 128
    }

    @Test("encodeIntensity clamps to valid range")
    func testEncodeIntensityClamping() {
        let over = encoder.encodeIntensity(1.5)
        #expect(over[1] == 255)

        let under = encoder.encodeIntensity(-0.5)
        #expect(under[1] == 0)
    }

    @Test("encodeColorTemp")
    func testEncodeColorTemp() {
        let data = encoder.encodeColorTemp(kelvin: 4000)
        #expect(data.count == 3)
        #expect(data[0] == 0x04) // Command.setColorTemp.rawValue
        // 4000 in big-endian = 0x0F, 0xA0
        #expect(data[1] == 0x0F)
        #expect(data[2] == 0xA0)
    }

    @Test("encodeColorTemp clamps to valid range")
    func testEncodeColorTempClamping() {
        let low = encoder.encodeColorTemp(kelvin: 1000)
        // Should clamp to 2000
        let lowValue = UInt16(bigEndian: low[1..<3].withUnsafeBytes { $0.load(as: UInt16.self) })
        #expect(lowValue == 2000)

        let high = encoder.encodeColorTemp(kelvin: 10000)
        // Should clamp to 6500
        let highValue = UInt16(bigEndian: high[1..<3].withUnsafeBytes { $0.load(as: UInt16.self) })
        #expect(highValue == 6500)
    }

    @Test("encodeFullState")
    func testEncodeFullState() {
        let data = encoder.encodeFullState(
            power: true,
            red: 255,
            green: 100,
            blue: 50,
            warmWhite: 200,
            coolWhite: 100,
            intensity: 0.8,
            colorTemp: 3500
        )
        #expect(data.count == 10)
        #expect(data[0] == 0x05) // Command.setFullState.rawValue
        #expect(data[1] == 0x01) // power on
        #expect(data[2] == 255)
        #expect(data[3] == 100)
        #expect(data[4] == 50)
        #expect(data[5] == 200)
        #expect(data[6] == 100)
        #expect(data[7] == UInt8(0.8 * 255))
        // colorTemp 3500 in big-endian
        let temp = UInt16(bigEndian: data[8..<10].withUnsafeBytes { $0.load(as: UInt16.self) })
        #expect(temp == 3500)
    }
}

@Suite("RGBCCT Tests")
struct RGBCCTTests {

    @Test("RGBCCT initialization")
    func testRGBCCTInit() {
        let color = RGBCCT(red: 255, green: 128, blue: 64, warmWhite: 200, coolWhite: 100)
        #expect(color.red == 255)
        #expect(color.green == 128)
        #expect(color.blue == 64)
        #expect(color.warmWhite == 200)
        #expect(color.coolWhite == 100)
    }

    @Test("RGBCCT static presets")
    func testRGBCCTPresets() {
        #expect(RGBCCT.off == RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 0, coolWhite: 0))
        #expect(RGBCCT.warmWhite == RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 255, coolWhite: 0))
        #expect(RGBCCT.coolWhite == RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 0, coolWhite: 255))
        #expect(RGBCCT.neutralWhite == RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 128, coolWhite: 128))
    }

    @Test("RGBCCT data encoding")
    func testRGBCCTData() {
        let color = RGBCCT(red: 10, green: 20, blue: 30, warmWhite: 40, coolWhite: 50)
        let data = color.data
        #expect(data.count == 5)
        #expect(data[0] == 10)
        #expect(data[1] == 20)
        #expect(data[2] == 30)
        #expect(data[3] == 40)
        #expect(data[4] == 50)

        let decoded = RGBCCT.from(data: data)
        #expect(decoded == color)
    }

    @Test("RGBCCT from data handles invalid input")
    func testRGBCCTFromDataInvalid() {
        #expect(RGBCCT.from(data: Data([1, 2, 3, 4])) == nil)
        #expect(RGBCCT.from(data: Data()) == nil)
    }

    @Test("RGBCCT intensity calculation")
    func testRGBCCTIntensity() {
        let off = RGBCCT.off
        #expect(off.intensity == 0.0)

        let full = RGBCCT(red: 255, green: 255, blue: 255, warmWhite: 255, coolWhite: 255)
        #expect(full.intensity == 1.0)

        let half = RGBCCT(red: 128, green: 0, blue: 0, warmWhite: 0, coolWhite: 0)
        #expect(abs(half.intensity - 128.0/255.0) < 0.01)
    }

    @Test("RGBCCT color temperature calculation")
    func testRGBCCTColorTemp() {
        let warm = RGBCCT.warmWhite
        #expect(warm.colorTemperatureKelvin == 2000)

        let cool = RGBCCT.coolWhite
        #expect(cool.colorTemperatureKelvin == 6500)

        let neutral = RGBCCT.neutralWhite
        #expect(abs(neutral.colorTemperatureKelvin - 4250) < 50)
    }

    @Test("RGBCCT withIntensity")
    func testRGBCCTWithIntensity() {
        let color = RGBCCT(red: 255, green: 100, blue: 50, warmWhite: 200, coolWhite: 100)
        let half = color.withIntensity(0.5)

        #expect(half.red == 127)
        #expect(half.green == 50)
        #expect(half.blue == 25)
        #expect(half.warmWhite == 100)
        #expect(half.coolWhite == 50)
    }

    @Test("RGBCCT withColorTemp")
    func testRGBCCTWithColorTemp() {
        let color = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: 200, coolWhite: 100)
        let warmer = color.withColorTemp(2700) // More warm
        let cooler = color.withColorTemp(6000) // More cool

        #expect(warmer.warmWhite > warmer.coolWhite)
        #expect(cooler.coolWhite > cooler.warmWhite)
    }
}
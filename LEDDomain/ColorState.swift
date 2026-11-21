import Foundation
import SwiftUI

public struct ColorState: Sendable, Equatable, Codable {
    public var hue: Double
    public var saturation: Double
    public var brightness: Double
    public var kelvin: Int?
    public var isOn: Bool
    
    public init(
        hue: Double = 0,
        saturation: Double = 0,
        brightness: Double = 1,
        kelvin: Int? = nil,
        isOn: Bool = true
    ) {
        self.hue = max(0, min(1, hue))
        self.saturation = max(0, min(1, saturation))
        self.brightness = max(0, min(1, brightness))
        self.kelvin = kelvin
        self.isOn = isOn
    }
    
    public static let `default` = ColorState(hue: 0, saturation: 0, brightness: 1, isOn: true)
    public static let off = ColorState(hue: 0, saturation: 0, brightness: 0, isOn: false)
    
    public var swiftUIColor: Color {
        guard isOn else { return .black }
        
        if let kelvin = kelvin {
            return Color(white: brightness)
        }
        
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    public var uiColor: UIColor {
        guard isOn else { return .black }
        
        if let kelvin = kelvin {
            return UIColor(white: CGFloat(brightness), alpha: 1)
        }
        
        return UIColor(hue: CGFloat(hue), saturation: CGFloat(saturation), brightness: CGFloat(brightness), alpha: 1)
    }
    
    public func withBrightness(_ brightness: Double) -> ColorState {
        var copy = self
        copy.brightness = max(0, min(1, brightness))
        return copy
    }
    
    public func withHue(_ hue: Double) -> ColorState {
        var copy = self
        copy.hue = max(0, min(1, hue))
        return copy
    }
    
    public func withSaturation(_ saturation: Double) -> ColorState {
        var copy = self
        copy.saturation = max(0, min(1, saturation))
        return copy
    }
    
    public func withKelvin(_ kelvin: Int?) -> ColorState {
        var copy = self
        copy.kelvin = kelvin
        return copy
    }
    
    public func toggled() -> ColorState {
        var copy = self
        copy.isOn.toggle()
        return copy
    }
    
    public var hexString: String {
        guard isOn else { return "#000000" }
        
        if let kelvin = kelvin {
            let gray = Int(brightness * 255)
            return String(format: "#%02X%02X%02X", gray, gray, gray)
        }
        
        let (r, g, b) = hsvToRgb(hue: hue, saturation: saturation, brightness: brightness)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    private func hsvToRgb(hue: Double, saturation: Double, brightness: Double) -> (Int, Int, Int) {
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
        
        return (Int(r * 255), Int(g * 255), Int(b * 255))
    }
    
    public static func fromHex(_ hex: String) -> ColorState? {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        
        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)
        let delta = maxVal - minVal
        
        var hue: Double = 0
        var saturation: Double = 0
        let brightness = maxVal
        
        if delta > 0 {
            saturation = delta / maxVal
            
            if maxVal == r {
                hue = (g - b) / delta
            } else if maxVal == g {
                hue = 2 + (b - r) / delta
            } else {
                hue = 4 + (r - g) / delta
            }
            
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        
        return ColorState(hue: hue, saturation: saturation, brightness: brightness, isOn: true)
    }
}

extension ColorState {
    public static let presets: [ColorState] = [
        ColorState(hue: 0, saturation: 1, brightness: 1, name: "Red"),
        ColorState(hue: 0.083, saturation: 1, brightness: 1, name: "Orange"),
        ColorState(hue: 0.167, saturation: 1, brightness: 1, name: "Yellow"),
        ColorState(hue: 0.333, saturation: 1, brightness: 1, name: "Green"),
        ColorState(hue: 0.5, saturation: 1, brightness: 1, name: "Cyan"),
        ColorState(hue: 0.667, saturation: 1, brightness: 1, name: "Blue"),
        ColorState(hue: 0.833, saturation: 1, brightness: 1, name: "Purple"),
        ColorState(hue: 0.917, saturation: 1, brightness: 1, name: "Pink"),
        ColorState(hue: 0, saturation: 0, brightness: 1, name: "White"),
        ColorState(hue: 0.1, saturation: 0.1, brightness: 1, name: "Warm White"),
        ColorState(hue: 0.6, saturation: 0.1, brightness: 1, name: "Cool White")
    ]
}

extension ColorState {
    private var name: String { "" }
}

public struct ColorTransition: Sendable, Equatable {
    public let from: ColorState
    public let to: ColorState
    public let duration: TimeInterval
    public let easing: EasingFunction
    
    public init(from: ColorState, to: ColorState, duration: TimeInterval = 1.0, easing: EasingFunction = .easeInOut) {
        self.from = from
        self.to = to
        self.duration = duration
        self.easing = easing
    }
    
    public func interpolated(at progress: Double) -> ColorState {
        let easedProgress = easing.apply(progress)
        
        guard from.isOn && to.isOn else {
            return easedProgress < 0.5 ? from : to
        }
        
        if let fromKelvin = from.kelvin, let toKelvin = to.kelvin {
            let kelvin = Int(Double(fromKelvin) + (Double(toKelvin) - Double(fromKelvin)) * easedProgress)
            let brightness = from.brightness + (to.brightness - from.brightness) * easedProgress
            return ColorState(kelvin: kelvin, brightness: brightness, isOn: true)
        }
        
        let hue = from.hue + shortestHueDistance(from: from.hue, to: to.hue) * easedProgress
        let saturation = from.saturation + (to.saturation - from.saturation) * easedProgress
        let brightness = from.brightness + (to.brightness - from.brightness) * easedProgress
        
        return ColorState(hue: hue, saturation: saturation, brightness: brightness, isOn: true)
    }
    
    private func shortestHueDistance(from: Double, to: Double) -> Double {
        let diff = to - from
        if diff > 0.5 { return diff - 1 }
        if diff < -0.5 { return diff + 1 }
        return diff
    }
}

public enum EasingFunction: String, Sendable, CaseIterable, Codable {
    case linear = "Linear"
    case easeIn = "Ease In"
    case easeOut = "Ease Out"
    case easeInOut = "Ease In Out"
    case spring = "Spring"
    
    public func apply(_ t: Double) -> Double {
        switch self {
        case .linear: return t
        case .easeIn: return t * t
        case .easeOut: return 1 - (1 - t) * (1 - t)
        case .easeInOut:
            return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        case .spring:
            let c = 1.70158
            return 1 + c * pow(t - 1, 3) + pow(t - 1, 2)
        }
    }
}
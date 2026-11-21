import SwiftUI

struct RGBCCTPicker: View {
    @Binding var rgbcct: RGBCCT
    @Binding var isColorMode: Bool
    let onColorChange: (RGBCCT) -> Void
    let onIntensityChange: (Double) -> Void
    let onColorTempChange: (Double) -> Void

    @State private var hue: Double = 0
    @State private var saturation: Double = 0
    @State private var intensity: Double = 0
    @State private var colorTemp: Double = 4000

    var body: some View {
        VStack(spacing: 20) {
            Picker("Mode", selection: $isColorMode) {
                Label("Color", systemImage: "paintpalette").tag(true)
                Label("White", systemImage: "lightbulb").tag(false)
            }
            .pickerStyle(.segmented)

            if isColorMode {
                ColorPickerPanel(
                    hue: $hue,
                    saturation: $saturation,
                    intensity: $intensity,
                    onHueChange: { h in hue = h; updateRGBCCT() },
                    onSaturationChange: { s in saturation = s; updateRGBCCT() },
                    onIntensityChange: { i in intensity = i; onIntensityChange(i); updateRGBCCT() }
                )
            } else {
                WhitePickerPanel(
                    colorTemp: $colorTemp,
                    intensity: $intensity,
                    onColorTempChange: { t in colorTemp = t; onColorTempChange(t); updateRGBCCT() },
                    onIntensityChange: { i in intensity = i; onIntensityChange(i); updateRGBCCT() }
                )
            }
        }
        .onAppear {
            loadFromRGBCCT()
        }
    }

    private func loadFromRGBCCT() {
        intensity = rgbcct.intensity
        colorTemp = Double(rgbcct.colorTemperatureKelvin)

        let r = Double(rgbcct.red) / 255.0
        let g = Double(rgbcct.green) / 255.0
        let b = Double(rgbcct.blue) / 255.0

        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)
        let delta = maxVal - minVal

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
        } else {
            hue = 0
            saturation = 0
        }
    }

    private func updateRGBCCT() {
        if isColorMode {
            let (r, g, b) = hsvToRgb(hue: hue, saturation: saturation, brightness: intensity)
            rgbcct = RGBCCT(red: r, green: g, blue: b, warmWhite: 0, coolWhite: 0)
        } else {
            let warmRatio = (6500 - colorTemp) / 4500.0
            let totalWhite = intensity * 255
            let warm = UInt8(totalWhite * warmRatio)
            let cool = UInt8(totalWhite * (1 - warmRatio))
            rgbcct = RGBCCT(red: 0, green: 0, blue: 0, warmWhite: warm, coolWhite: cool)
        }
        onColorChange(rgbcct)
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

struct ColorPickerPanel: View {
    @Binding var hue: Double
    @Binding var saturation: Double
    @Binding var intensity: Double
    let onHueChange: (Double) -> Void
    let onSaturationChange: (Double) -> Void
    let onIntensityChange: (Double) -> Void

    private let presets = [
        (name: "Red", hue: 0.0, sat: 1.0),
        (name: "Orange", hue: 0.083, sat: 1.0),
        (name: "Yellow", hue: 0.167, sat: 1.0),
        (name: "Green", hue: 0.333, sat: 1.0),
        (name: "Cyan", hue: 0.5, sat: 1.0),
        (name: "Blue", hue: 0.667, sat: 1.0),
        (name: "Purple", hue: 0.833, sat: 1.0),
        (name: "Pink", hue: 0.917, sat: 1.0),
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Hue slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Hue")
                    Spacer()
                    Text(String(format: "%.0f°", hue * 360))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $hue, in: 0...1) { _ in onHueChange(hue) }
                    .tint(.red)
            }

            // Saturation slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Saturation")
                    Spacer()
                    Text(String(format: "%.0f%%", saturation * 100))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $saturation, in: 0...1) { _ in onSaturationChange(saturation) }
                    .tint(.blue)
            }

            // Intensity slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Intensity")
                    Spacer()
                    Text(String(format: "%.0f%%", intensity * 100))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $intensity, in: 0...1) { _ in onIntensityChange(intensity) }
                    .tint(.accentColor)
            }

            // Quick color presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Presets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(presets, id: \.name) { preset in
                            Button {
                                hue = preset.hue
                                saturation = preset.sat
                                onHueChange(hue)
                                onSaturationChange(saturation)
                            } label: {
                                Circle()
                                    .fill(Color(hue: preset.hue, saturation: preset.sat, brightness: 1))
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct WhitePickerPanel: View {
    @Binding var colorTemp: Double
    @Binding var intensity: Double
    let onColorTempChange: (Double) -> Void
    let onIntensityChange: (Double) -> Void

    private let tempPresets = [2700, 3000, 3500, 4000, 5000, 6500]

    var body: some View {
        VStack(spacing: 16) {
            // Color temp slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Color Temperature")
                    Spacer()
                    Text("\(Int(colorTemp))K")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $colorTemp, in: 2000...6500, step: 100) { _ in onColorTempChange(colorTemp) }
                    .tint(.orange)
            }

            // Intensity slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Intensity")
                    Spacer()
                    Text("\(Int(intensity * 100))%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $intensity, in: 0...1) { _ in onIntensityChange(intensity) }
                    .tint(.accentColor)
            }

            // Quick temp presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Presets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    ForEach(tempPresets, id: \.self) { temp in
                        Button("\(temp)K") {
                            colorTemp = Double(temp)
                            onColorTempChange(Double(temp))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}
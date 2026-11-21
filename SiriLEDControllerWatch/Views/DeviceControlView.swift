import SwiftUI
import SwiftData

struct DeviceControlView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let device: LEDDevice

    @State private var rgbcct: RGBCCT = .off
    @State private var intensity: Double = 0
    @State private var colorTemp: Double = 4000
    @State private var isColorMode: Bool = false

    private let bleManager = BLEManager.shared
    private let encoder = CommonLEDCommandEncoder.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Color preview
                ZStack {
                    Circle()
                        .fill(rgbcct.swiftUIColor)
                        .frame(width: 100, height: 100)
                        .shadow(radius: 8)

                    if !device.isConnected {
                        Circle()
                            .stroke(Color.gray.opacity(0.5), lineWidth: 3)
                            .frame(width: 100, height: 100)
                    }
                }

                // Power toggle
                Toggle(isOn: Binding(
                    get: { intensity > 0 },
                    set: { newValue in
                        intensity = newValue ? 1.0 : 0
                        updateRGBCCT()
                    }
                )) {
                    Text("Power")
                        .font(.title3)
                }
                .toggleStyle(.switch)
                .tint(.green)

                // Main controls
                VStack(spacing: 16) {
                    if isColorMode {
                        ColorPickerPanel(
                            hue: $hue,
                            saturation: $saturation,
                            intensity: $intensity,
                            onHueChange: { h in hue = h; updateRGBCCT() },
                            onSaturationChange: { s in saturation = s; updateRGBCCT() },
                            onIntensityChange: { i in intensity = i; updateRGBCCT() }
                        )
                    } else {
                        WhitePickerPanel(
                            colorTemp: $colorTemp,
                            intensity: $intensity,
                            onColorTempChange: { t in colorTemp = t; updateRGBCCT() },
                            onIntensityChange: { i in intensity = i; updateRGBCCT() }
                        )
                    }
                }

                // Mode selector
                Picker("Mode", selection: $isColorMode) {
                    Label("Color", systemImage: "paintpalette").tag(true)
                    Label("White", systemImage: "lightbulb").tag(false)
                }
                .pickerStyle(.segmented)

                // Quick presets
                QuickPresetsView(onPresetSelect: { preset in
                    rgbcct = preset
                    updateFromRGBCCT()
                })

                // Send button
                Button(action: sendCommand) {
                    Text(device.isConnected ? "Send to Device" : "Device Disconnected")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!device.isConnected)
            }
            .padding()
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDeviceState()
        }
    }

    @State private var hue: Double = 0
    @State private var saturation: Double = 0

    private func loadDeviceState() {
        if let stateData = device.lastKnownState,
           let state = RGBCCT.from(data: stateData) {
            rgbcct = state
            updateFromRGBCCT()
        }
    }

    private func updateFromRGBCCT() {
        intensity = rgbcct.intensity
        colorTemp = Double(rgbcct.colorTemperatureKelvin)

        let r = Double(rgbcct.red) / 255.0
        let g = Double(rgbcct.green) / 255.0
        let b = Double(rgbcct.blue) / 255.0

        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)
        let delta = maxVal - minVal

        var h: Double = 0
        var s: Double = 0

        if delta > 0 {
            s = delta / maxVal
            if maxVal == r {
                h = (g - b) / delta
            } else if maxVal == g {
                h = 2 + (b - r) / delta
            } else {
                h = 4 + (r - g) / delta
            }
            h /= 6
            if h < 0 { h += 1 }
        }

        hue = h
        saturation = s
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

    private func sendCommand() {
        WKInterfaceDevice.current().play(.click)
        Task {
            let peripheralId = UUID(uuidString: device.serviceUUID) ?? UUID()
            let data = encoder.encodeFullState(
                power: intensity > 0,
                red: rgbcct.red,
                green: rgbcct.green,
                blue: rgbcct.blue,
                warmWhite: rgbcct.warmWhite,
                coolWhite: rgbcct.coolWhite,
                intensity: intensity,
                colorTemp: Int(colorTemp)
            )
            do {
                try await bleManager.writeCommand(data, to: peripheralId)
            } catch {
                print("Failed to send command: \(error)")
            }
        }
    }
}

// Reuse components from iPhone (simplified for Watch)
struct ColorPickerPanel: View {
    @Binding var hue: Double
    @Binding var saturation: Double
    @Binding var intensity: Double
    let onHueChange: (Double) -> Void
    let onSaturationChange: (Double) -> Void
    let onIntensityChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hue")
                Slider(value: $hue, in: 0...1) { _ in onHueChange(hue) }
                    .tint(.red)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Saturation")
                Slider(value: $saturation, in: 0...1) { _ in onSaturationChange(saturation) }
                    .tint(.blue)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Intensity")
                Slider(value: $intensity, in: 0...1) { _ in onIntensityChange(intensity) }
                    .tint(.accentColor)
            }

            // Quick color presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colorPresets, id: \.name) { preset in
                        Button {
                            hue = preset.hue
                            saturation = preset.sat
                            onHueChange(hue)
                            onSaturationChange(saturation)
                        } label: {
                            Circle()
                                .fill(Color(hue: preset.hue, saturation: preset.sat, brightness: 1))
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }

        private let colorPresets = [
            (name: "Red", hue: 0.0, sat: 1.0),
            (name: "Orange", hue: 0.083, sat: 1.0),
            (name: "Yellow", hue: 0.167, sat: 1.0),
            (name: "Green", hue: 0.333, sat: 1.0),
            (name: "Cyan", hue: 0.5, sat: 1.0),
            (name: "Blue", hue: 0.667, sat: 1.0),
            (name: "Purple", hue: 0.833, sat: 1.0),
            (name: "Pink", hue: 0.917, sat: 1.0),
        ]
    }
}

struct WhitePickerPanel: View {
    @Binding var colorTemp: Double
    @Binding var intensity: Double
    let onColorTempChange: (Double) -> Void
    let onIntensityChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Color Temperature")
                Slider(value: $colorTemp, in: 2000...6500, step: 100) { _ in onColorTempChange(colorTemp) }
                    .tint(.orange)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Intensity")
                Slider(value: $intensity, in: 0...1) { _ in onIntensityChange(intensity) }
                    .tint(.accentColor)
            }

            // Quick temp presets
            HStack(spacing: 12) {
                ForEach([2700, 3500, 4000, 5000, 6500], id: \.self) { temp in
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

struct QuickPresetsView: View {
    let onPresetSelect: (RGBCCT) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presets")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(presets, id: \.name) { preset in
                        Button {
                            onPresetSelect(preset.color)
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(preset.color.swiftUIColor)
                                    .frame(width: 40, height: 40)
                                Text(preset.name)
                                    .font(.caption2)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }

        private let presets = [
            (name: "Off", color: RGBCCT.off),
            (name: "Warm", color: RGBCCT.warmWhite),
            (name: "Neutral", color: RGBCCT.neutralWhite),
            (name: "Cool", color: RGBCCT.coolWhite),
            (name: "Red", color: RGBCCT.red),
            (name: "Green", color: RGBCCT.green),
            (name: "Blue", color: RGBCCT.blue),
        ]
    }
}
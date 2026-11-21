import SwiftUI
import SwiftData

struct ControlView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let device: LEDDevice

    @State private var rgbcct: RGBCCT = .off
    @State private var intensity: Double = 0
    @State private var colorTemp: Double = 4000
    @State private var hue: Double = 0
    @State private var saturation: Double = 0
    @State private var isColorMode: Bool = true

    private let bleManager = BLEManager.shared
    private let encoder = CommonLEDCommandEncoder.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Color preview
                    ColorPreviewView(rgbcct: rgbcct)

                    // Power toggle
                    PowerToggleView(isOn: Binding(
                        get: { intensity > 0 },
                        set: { newValue in
                            intensity = newValue ? 1.0 : 0
                            updateRGBCCT()
                        }
                    ))

                    // Main controls
                    VStack(spacing: 20) {
                        if isColorMode {
                            ColorPickerSection(
                                hue: $hue,
                                saturation: $saturation,
                                onColorChange: { h, s in
                                    hue = h
                                    saturation = s
                                    updateRGBCCT()
                                }
                            )
                        } else {
                            ColorTempSection(
                                colorTemp: $colorTemp,
                                onTempChange: { temp in
                                    colorTemp = temp
                                    updateRGBCCT()
                                }
                            )
                        }

                        IntensitySection(
                            intensity: $intensity,
                            onIntensityChange: { newIntensity in
                                intensity = newIntensity
                                updateRGBCCT()
                            }
                        )
                    }

                    // Mode selector
                    Picker("Mode", selection: $isColorMode) {
                        Label("Color", systemImage: "paintpalette").tag(true)
                        Label("White", systemImage: "lightbulb").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Quick presets
                    QuickPresetsView(onPresetSelect: { preset in
                        rgbcct = preset
                        updateFromRGBCCT()
                    })

                    // Send button
                    Button(action: sendCommand) {
                        Label("Send to Device", systemImage: "arrow.up.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal)
                    .disabled(!device.isConnected)
                }
                .padding()
            }
            .navigationTitle(device.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadDeviceState()
            }
        }
    }

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

        // Convert RGB to HSV
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
                // Handle error
                print("Failed to send command: \(error)")
            }
        }
    }
}

struct ColorPreviewView: View {
    let rgbcct: RGBCCT

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(rgbcct.swiftUIColor)
            .frame(height: 160)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .shadow(radius: 12)
    }
}

struct PowerToggleView: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text("Power")
                .font(.title2)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .scaleEffect(1.2)
        }
        .padding(.horizontal)
    }
}

struct ColorPickerSection: View {
    @Binding var hue: Double
    @Binding var saturation: Double
    let onColorChange: (Double, Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Color")
                .font(.headline)

            // Hue/Saturation wheel (simplified as sliders for now)
            VStack(spacing: 12) {
                HStack {
                    Text("Hue")
                    Slider(value: $hue, in: 0...1) { _ in
                        onColorChange(hue, saturation)
                    }
                    .tint(.red)
                }

                HStack {
                    Text("Saturation")
                    Slider(value: $saturation, in: 0...1) { _ in
                        onColorChange(hue, saturation)
                    }
                    .tint(.blue)
                }
            }

            // Quick color presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colorPresets, id: \.name) { preset in
                        Circle()
                            .fill(preset.color)
                            .frame(width: 50, height: 50)
                            .onTapGesture {
                                // Convert preset to HSV
                                // Simplified for now
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: 2)
                                    .opacity(0)
                            )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private let colorPresets = [
        (name: "Red", color: Color.red),
        (name: "Orange", color: Color.orange),
        (name: "Yellow", color: Color.yellow),
        (name: "Green", color: Color.green),
        (name: "Cyan", color: Color.cyan),
        (name: "Blue", color: Color.blue),
        (name: "Purple", color: Color.purple),
        (name: "Pink", color: Color.pink),
    ]
}

struct ColorTempSection: View {
    @Binding var colorTemp: Double
    let onTempChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Color Temperature")
                .font(.headline)

            VStack(spacing: 12) {
                HStack {
                    Text("\(Int(colorTemp))K")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 60)
                    Slider(value: $colorTemp, in: 2000...6500, step: 100) { _ in
                        onTempChange(colorTemp)
                    }
                    .tint(.orange)
                }

                // Warm/Cool labels
                HStack {
                    Text("Warm").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Cool").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)

                // Quick presets
                HStack(spacing: 16) {
                    ForEach([2700, 3500, 4000, 5000, 6500], id: \.self) { temp in
                        Button("\(temp)K") {
                            colorTemp = Double(temp)
                            onTempChange(Double(temp))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

struct IntensitySection: View {
    @Binding var intensity: Double
    let onIntensityChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Intensity")
                .font(.headline)

            HStack {
                Text("\(Int(intensity * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 50)
                Slider(value: $intensity, in: 0...1) { _ in
                    onIntensityChange(intensity)
                }
                .tint(.accentColor)
            }

            // Quick presets
            HStack(spacing: 16) {
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { value in
                    Button("\(Int(value * 100))%") {
                        intensity = value
                        onIntensityChange(value)
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
            Text("Quick Presets")
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
                                    .frame(width: 50, height: 50)
                                Text(preset.name)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
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
import SwiftUI

struct WatchIntensitySlider: View {
    @Binding var intensity: Double
    let onIntensityChange: (Double) -> Void
    let label: String

    init(
        intensity: Binding<Double>,
        label: String = "Intensity",
        onIntensityChange: @escaping (Double) -> Void
    ) {
        self._intensity = intensity
        self.label = label
        self.onIntensityChange = onIntensityChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(intensity * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $intensity, in: 0...1) { _ in
                onIntensityChange(intensity)
            }
            .tint(.accentColor)

            HStack(spacing: 8) {
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { value in
                    Button("\(Int(value * 100))%") {
                        intensity = value
                        onIntensityChange(value)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var intensity = 0.5
    WatchIntensitySlider(intensity: $intensity) { _ in }
        .padding()
}
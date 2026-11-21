import SwiftUI

struct IntensitySlider: View {
    @Binding var intensity: Double
    let onIntensityChange: (Double) -> Void
    let label: String
    let showPercentage: Bool

    init(
        intensity: Binding<Double>,
        label: String = "Intensity",
        showPercentage: Bool = true,
        onIntensityChange: @escaping (Double) -> Void
    ) {
        self._intensity = intensity
        self.label = label
        self.showPercentage = showPercentage
        self.onIntensityChange = onIntensityChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                if showPercentage {
                    Spacer()
                    Text("\(Int(intensity * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }

            Slider(value: $intensity, in: 0...1) { _ in
                onIntensityChange(intensity)
            }
            .tint(.accentColor)

            // Quick preset buttons
            HStack(spacing: 12) {
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

#Preview {
    @Previewable @State var intensity = 0.5
    IntensitySlider(intensity: $intensity) { _ in }
        .padding()
}
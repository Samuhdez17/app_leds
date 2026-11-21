import SwiftUI

struct ColorTempSlider: View {
    @Binding var colorTemp: Double
    let onColorTempChange: (Double) -> Void
    let label: String
    let showValue: Bool

    init(
        colorTemp: Binding<Double>,
        label: String = "Color Temperature",
        showValue: Bool = true,
        onColorTempChange: @escaping (Double) -> Void
    ) {
        self._colorTemp = colorTemp
        self.label = label
        self.showValue = showValue
        self.onColorTempChange = onColorTempChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                if showValue {
                    Spacer()
                    Text("\(Int(colorTemp))K")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
            }

            Slider(value: $colorTemp, in: 2000...6500, step: 100) { _ in
                onColorTempChange(colorTemp)
            }
            .tint(.orange)

            // Warm/Cool labels
            HStack {
                Text("Warm").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Cool").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            // Quick preset buttons
            HStack(spacing: 12) {
                ForEach([2700, 3000, 3500, 4000, 5000, 6500], id: \.self) { temp in
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

#Preview {
    @Previewable @State var colorTemp = 4000.0
    ColorTempSlider(colorTemp: $colorTemp) { _ in }
        .padding()
}
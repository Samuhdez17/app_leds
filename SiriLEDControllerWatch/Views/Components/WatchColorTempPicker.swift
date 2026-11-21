import SwiftUI

struct WatchColorTempPicker: View {
    @Binding var colorTemp: Double
    let onColorTempChange: (Double) -> Void
    let label: String

    init(
        colorTemp: Binding<Double>,
        label: String = "Color Temp",
        onColorTempChange: @escaping (Double) -> Void
    ) {
        self._colorTemp = colorTemp
        self.label = label
        self.onColorTempChange = onColorTempChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(colorTemp))K")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $colorTemp, in: 2000...6500, step: 100) { _ in
                onColorTempChange(colorTemp)
            }
            .tint(.orange)

            HStack {
                Text("Warm").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("Cool").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                ForEach([2700, 3500, 4000, 5000, 6500], id: \.self) { temp in
                    Button("\(temp)K") {
                        colorTemp = Double(temp)
                        onColorTempChange(Double(temp))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var colorTemp = 4000.0
    WatchColorTempPicker(colorTemp: $colorTemp) { _ in }
        .padding()
}
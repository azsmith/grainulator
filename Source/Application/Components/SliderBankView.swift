//
//  SliderBankView.swift
//  Grainulator
//
//  Reusable vertical slider bank with LED activity indicators
//  Inspired by Juno 106 style parameter sections
//

import SwiftUI

// MARK: - Slider Parameter

struct SliderParameter: Identifiable {
    let id: String
    let label: String
    var value: Binding<Float>
    var modulationAmount: Float
    var accentColor: Color

    init(
        id: String? = nil,
        label: String,
        value: Binding<Float>,
        modulationAmount: Float = 0,
        accentColor: Color = ColorPalette.ledBlue
    ) {
        self.id = id ?? label
        self.label = label
        self.value = value
        self.modulationAmount = modulationAmount
        self.accentColor = accentColor
    }
}

// MARK: - Slider Bank View

struct SliderBankView: View {
    let parameters: [SliderParameter]
    let sliderHeight: CGFloat
    let showLEDs: Bool
    let sliderWidth: CGFloat

    init(
        parameters: [SliderParameter],
        sliderHeight: CGFloat = 100,
        showLEDs: Bool = true,
        sliderWidth: CGFloat = 16
    ) {
        self.parameters = parameters
        self.sliderHeight = sliderHeight
        self.showLEDs = showLEDs
        self.sliderWidth = sliderWidth
    }

    var body: some View {
        VStack(spacing: 4) {
            // LED activity row
            if showLEDs {
                HStack(spacing: calculateSpacing()) {
                    ForEach(parameters) { param in
                        SliderLED(
                            value: param.value.wrappedValue,
                            modulationAmount: param.modulationAmount,
                            accentColor: param.accentColor
                        )
                    }
                }
            }

            // Slider row
            HStack(spacing: calculateSpacing()) {
                ForEach(parameters) { param in
                    BankVerticalSlider(
                        value: param.value,
                        accentColor: param.accentColor,
                        width: sliderWidth,
                        height: sliderHeight
                    )
                }
            }

            // Label row
            HStack(spacing: calculateSpacing()) {
                ForEach(parameters) { param in
                    Text(param.label)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textMuted)
                        .frame(width: sliderWidth + 8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    private func calculateSpacing() -> CGFloat {
        // Dynamic spacing based on number of parameters
        let count = CGFloat(parameters.count)
        return max(4, 12 - count)
    }
}

// MARK: - Slider LED Indicator

struct SliderLED: View {
    let value: Float
    let modulationAmount: Float
    let accentColor: Color

    // LED brightness based on value and modulation
    private var brightness: Double {
        let base = Double(value)
        let mod = abs(Double(modulationAmount))
        return min(1.0, base + mod * 0.5)
    }

    private var isActive: Bool {
        brightness > 0.05
    }

    var body: some View {
        ZStack {
            // LED housing
            Circle()
                .fill(ColorPalette.ledOff)
                .frame(width: 8, height: 8)

            // LED glow
            Circle()
                .fill(isActive ? accentColor.opacity(brightness) : Color.clear)
                .frame(width: 6, height: 6)
                .shadow(
                    color: isActive ? accentColor.opacity(brightness * 0.6) : .clear,
                    radius: 4
                )
        }
    }
}

// MARK: - Bank Vertical Slider

struct BankVerticalSlider: View {
    @Binding var value: Float
    let accentColor: Color
    let width: CGFloat
    let height: CGFloat

    @State private var isDragging = false
    @State private var dragStartValue: Float = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Track background
                RoundedRectangle(cornerRadius: width / 4)
                    .fill(ColorPalette.backgroundPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: width / 4)
                            .stroke(ColorPalette.divider, lineWidth: 1)
                    )

                // Center line (50% marker)
                Rectangle()
                    .fill(ColorPalette.dividerSubtle)
                    .frame(width: width - 4, height: 1)
                    .offset(y: -geometry.size.height / 2)

                // Value fill
                RoundedRectangle(cornerRadius: width / 4)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.6), accentColor.opacity(0.3)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: geometry.size.height * CGFloat(value))

                // Thumb
                sliderThumb
                    .offset(y: -geometry.size.height * CGFloat(value) + 6)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            dragStartValue = value
                        }
                        // Vertical drag with sensitivity
                        let isFineControl = NSEvent.modifierFlags.contains(.shift)
                        let sensitivity: Float = isFineControl ? 300.0 : 100.0
                        let delta = -Float(gesture.translation.height) / sensitivity
                        value = max(0, min(1, dragStartValue + delta))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(width: width, height: height)
    }

    private var sliderThumb: some View {
        ZStack {
            // Thumb shadow
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.black.opacity(0.4))
                .frame(width: width + 4, height: 12)
                .offset(y: 1)

            // Thumb body
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [
                            ColorPalette.metalAluminum,
                            ColorPalette.metalSteel
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width + 4, height: 12)

            // Thumb grip line
            Rectangle()
                .fill(ColorPalette.divider)
                .frame(width: width - 2, height: 1)
        }
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isDragging)
    }
}

// MARK: - Preview

#if DEBUG
struct SliderBankView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var values: [Float] = [0.5, 0.7, 0.3, 0.8, 0.6]

        var body: some View {
            VStack(spacing: 30) {
                Text("Slider Bank Component")
                    .font(.headline)
                    .foregroundColor(.white)

                // 5-slider bank (like Rings)
                SliderBankView(
                    parameters: [
                        SliderParameter(label: "STR", value: $values[0], accentColor: ColorPalette.accentRings),
                        SliderParameter(label: "BRT", value: $values[1], modulationAmount: 0.3, accentColor: ColorPalette.accentRings),
                        SliderParameter(label: "DMP", value: $values[2], accentColor: ColorPalette.accentRings),
                        SliderParameter(label: "POS", value: $values[3], modulationAmount: 0.5, accentColor: ColorPalette.accentRings),
                        SliderParameter(label: "LVL", value: $values[4], accentColor: ColorPalette.accentRings)
                    ],
                    sliderHeight: 100
                )

                Divider()
                    .background(ColorPalette.divider)

                // 4-slider bank (like Plaits OSC)
                SliderBankView(
                    parameters: [
                        SliderParameter(label: "HARM", value: $values[0], accentColor: ColorPalette.accentPlaits),
                        SliderParameter(label: "TMBR", value: $values[1], accentColor: ColorPalette.accentPlaits),
                        SliderParameter(label: "MRPH", value: $values[2], accentColor: ColorPalette.accentPlaits),
                        SliderParameter(label: "LVL", value: $values[3], accentColor: ColorPalette.accentPlaits)
                    ],
                    sliderHeight: 80
                )

                // Values display
                HStack {
                    ForEach(0..<5) { i in
                        Text(String(format: "%.0f%%", values[i] * 100))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
            }
            .padding(30)
            .background(ColorPalette.backgroundPrimary)
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
#endif

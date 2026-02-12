//
//  ProKnobView.swift
//  Grainulator
//
//  Professional vintage-style knob component with realistic 3D appearance
//  Inspired by classic Bakelite chicken-head knobs and metal pointer caps
//

import SwiftUI

// MARK: - Knob Size Configuration

enum KnobSize {
    case small      // 28px - for dense parameter areas
    case medium     // 40px - standard mixer/effects
    case large      // 56px - featured parameters
    case xlarge     // 72px - master controls

    var diameter: CGFloat {
        switch self {
        case .small: return 28
        case .medium: return 40
        case .large: return 56
        case .xlarge: return 72
        }
    }

    var pointerLength: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 12
        case .large: return 16
        case .xlarge: return 22
        }
    }

    var pointerWidth: CGFloat {
        switch self {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        case .xlarge: return 5
        }
    }

    var labelFont: Font {
        switch self {
        case .small: return Typography.parameterLabelSmall
        case .medium: return Typography.parameterLabel
        case .large: return Typography.parameterLabel
        case .xlarge: return Typography.channelLabel
        }
    }

    var valueFont: Font {
        switch self {
        case .small: return Typography.valueTiny
        case .medium: return Typography.valueSmall
        case .large: return Typography.valueStandard
        case .xlarge: return Typography.valueMedium
        }
    }

    var indicatorWidth: CGFloat {
        switch self {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        case .xlarge: return 5
        }
    }
}

// MARK: - Knob Style Configuration

enum KnobStyle {
    case bakelite       // Classic brown chicken-head style
    case metalPointer   // Black with metal pointer cap
    case aluminum       // Brushed aluminum look
    case minimoog       // Minimoog-style: black body with silver cap

    var bodyColor: Color {
        switch self {
        case .bakelite: return ColorPalette.knobBrown
        case .metalPointer: return ColorPalette.knobBlack
        case .aluminum: return ColorPalette.metalAluminum
        case .minimoog: return ColorPalette.minimoogKnobBody
        }
    }

    var pointerColor: Color {
        switch self {
        case .bakelite: return ColorPalette.knobCream
        case .metalPointer: return ColorPalette.metalChrome
        case .aluminum: return ColorPalette.knobPointerRed
        case .minimoog: return ColorPalette.minimoogPointer
        }
    }

    /// Whether the knob has a raised silver cap (Minimoog style)
    var hasCap: Bool {
        self == .minimoog
    }

    var capColor: Color {
        ColorPalette.minimoogCapSilver
    }

    var capHighlight: Color {
        ColorPalette.minimoogCapHighlight
    }

    var capShadow: Color {
        ColorPalette.minimoogCapShadow
    }
}

// MARK: - Pro Knob View

struct ProKnobView: View {
    @Binding var value: Float
    let label: String
    let accentColor: Color
    let size: KnobSize
    let style: KnobStyle
    let minValue: Float
    let maxValue: Float
    let defaultValue: Float
    let isBipolar: Bool
    let showValue: Bool
    let valueFormatter: (Float) -> String

    // Modulation overlay (optional)
    var modulationValue: Float?

    // State
    @State private var dragStartValue: Float = 0
    @State private var isDragging: Bool = false
    @State private var isHovering: Bool = false

    // Constants
    private let rotationRange: Double = 270  // Total rotation in degrees
    // Start angle: 225° puts 0% at ~7:30 (lower-left) and 100% at ~4:30 (lower-right)
    // This ensures 50% is always at 12 o'clock (straight up)
    private let startAngle: Double = 225

    init(
        value: Binding<Float>,
        label: String,
        accentColor: Color = ColorPalette.ledBlue,
        size: KnobSize = .medium,
        style: KnobStyle = .bakelite,
        range: ClosedRange<Float> = 0...1,
        defaultValue: Float? = nil,
        isBipolar: Bool = false,
        showValue: Bool = true,
        modulationValue: Float? = nil,
        valueFormatter: @escaping (Float) -> String = { String(format: "%.2f", $0) }
    ) {
        self._value = value
        self.label = label
        self.accentColor = accentColor
        self.size = size
        self.style = style
        self.minValue = range.lowerBound
        self.maxValue = range.upperBound
        self.defaultValue = defaultValue ?? (isBipolar ? (range.lowerBound + range.upperBound) / 2 : range.lowerBound)
        self.isBipolar = isBipolar
        self.showValue = showValue
        self.modulationValue = modulationValue
        self.valueFormatter = valueFormatter
    }

    // Normalized value (0-1)
    private var normalizedValue: Float {
        (value - minValue) / (maxValue - minValue)
    }

    // Rotation angle for the knob pointer
    private var rotationAngle: Double {
        startAngle + Double(normalizedValue) * rotationRange
    }

    // Normalized modulation value (if present)
    private var normalizedModulationValue: Float? {
        guard let mod = modulationValue else { return nil }
        return (mod - minValue) / (maxValue - minValue)
    }

    var body: some View {
        VStack(spacing: size == .small ? 2 : 4) {
            // Knob assembly
            ZStack {
                // Position markers around the knob
                positionMarkers

                // Indicator arc (shows value range)
                indicatorArc

                // Modulation arc (ghost value)
                if let modNorm = normalizedModulationValue {
                    modulationArc(modNorm)
                }

                // Knob body with 3D effect
                knobBody

                // Pointer/indicator line
                knobPointer
            }
            .frame(width: size.diameter + 12, height: size.diameter + 12)
            .gesture(dragGesture)
            .onTapGesture(count: 2) {
                // Double-tap to reset to default
                withAnimation(.easeInOut(duration: 0.15)) {
                    value = defaultValue
                }
            }
            .onHover { hovering in
                isHovering = hovering
            }

            // Label below knob
            Text(label)
                .font(size.labelFont)
                .foregroundColor(style == .minimoog ? ColorPalette.synthPanelLabel : ColorPalette.textMuted)
                .tracking(style == .minimoog ? 1.5 : 0)
                .textCase(.uppercase)
                .lineLimit(1)

            // Value display (optional)
            if showValue {
                Text(valueFormatter(value))
                    .font(size.valueFont)
                    .foregroundColor(isDragging ? accentColor : ColorPalette.textSecondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Position Markers

    private var positionMarkers: some View {
        let markerCount = 11
        let markerAngles = (0..<markerCount).map { i in
            startAngle + Double(i) / Double(markerCount - 1) * rotationRange
        }

        return ForEach(Array(markerAngles.enumerated()), id: \.offset) { index, angle in
            let isEndpoint = index == 0 || index == markerCount - 1
            let isMidpoint = index == markerCount / 2

            Rectangle()
                .fill(isEndpoint || isMidpoint ? ColorPalette.textMuted : ColorPalette.textDimmed)
                .frame(width: isEndpoint ? 2 : 1, height: isEndpoint || isMidpoint ? 6 : 4)
                .offset(y: -(size.diameter / 2 + 6))
                .rotationEffect(.degrees(angle))
        }
    }

    // MARK: - Indicator Arc

    // Arc rotation offset: rotates the Circle trim so that fraction 0.0 aligns
    // with the knob's start position (225° = ~7:30). This keeps all trim fractions
    // in the [0, 0.75] range, avoiding wrap-around issues at the 1.0 boundary.
    private var arcRotationOffset: Double {
        startAngle - 90  // -90 converts from trim coords (0°=3 o'clock) to screen
    }

    private var indicatorArc: some View {
        let arcEnd = Double(normalizedValue) * rotationRange / 360.0

        return Circle()
            .trim(from: 0, to: arcEnd)
            .stroke(
                accentColor,
                style: StrokeStyle(lineWidth: size.indicatorWidth, lineCap: .round)
            )
            .frame(width: size.diameter + 4, height: size.diameter + 4)
            .rotationEffect(.degrees(arcRotationOffset))
    }

    // MARK: - Modulation Arc

    private func modulationArc(_ modNorm: Float) -> some View {
        let baseEnd = Double(normalizedValue) * rotationRange / 360.0
        let modEnd = Double(modNorm) * rotationRange / 360.0

        return Circle()
            .trim(from: min(baseEnd, modEnd), to: max(baseEnd, modEnd))
            .stroke(
                accentColor.opacity(0.4),
                style: StrokeStyle(lineWidth: size.indicatorWidth, lineCap: .round)
            )
            .frame(width: size.diameter + 4, height: size.diameter + 4)
            .rotationEffect(.degrees(arcRotationOffset))
    }

    // MARK: - Knob Body

    private var knobBody: some View {
        ZStack {
            // Shadow underneath
            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: size.diameter, height: size.diameter)
                .offset(x: 2, y: 3)
                .blur(radius: 4)

            // Main knob body with gradient for 3D effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            style.bodyColor.lighter(by: 0.15),
                            style.bodyColor,
                            style.bodyColor.darker(by: 0.2)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: size.diameter * 0.6
                    )
                )
                .frame(width: size.diameter, height: size.diameter)

            if style.hasCap {
                // Minimoog-style raised silver cap
                let capSize = size.diameter * 0.55

                // Cap shadow ring
                Circle()
                    .fill(Color.black.opacity(0.25))
                    .frame(width: capSize + 2, height: capSize + 2)
                    .offset(y: 1)

                // Silver cap body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                style.capHighlight,
                                style.capColor,
                                style.capShadow
                            ],
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: 0,
                            endRadius: capSize * 0.6
                        )
                    )
                    .frame(width: capSize, height: capSize)

                // Cap edge highlight
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.clear,
                                Color.black.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: capSize, height: capSize)
            } else {
                // Standard highlight ring (top edge catch light)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear,
                                Color.black.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: size.diameter - 1, height: size.diameter - 1)

                // Knurled edge indication (subtle texture)
                Circle()
                    .strokeBorder(
                        style.bodyColor.darker(by: 0.1),
                        lineWidth: 2
                    )
                    .frame(width: size.diameter - 4, height: size.diameter - 4)
            }
        }
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isDragging)
    }

    // MARK: - Knob Pointer

    private var knobPointer: some View {
        ZStack {
            // Pointer line/cap
            RoundedRectangle(cornerRadius: size.pointerWidth / 2)
                .fill(
                    LinearGradient(
                        colors: [
                            style.pointerColor,
                            style.pointerColor.darker(by: 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size.pointerWidth, height: size.pointerLength)
                .offset(y: -(size.diameter / 2 - size.pointerLength / 2 - 4))

            // Center dot
            Circle()
                .fill(style.pointerColor)
                .frame(width: size.pointerWidth + 2, height: size.pointerWidth + 2)
        }
        .rotationEffect(.degrees(rotationAngle))
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { gesture in
                if !isDragging {
                    isDragging = true
                    dragStartValue = value
                }

                // Vertical drag with shift key for fine control
                let isFineControl = NSEvent.modifierFlags.contains(.shift)
                let sensitivity: Float = isFineControl ? 400.0 : 100.0
                let delta = -Float(gesture.translation.height) / sensitivity
                let range = maxValue - minValue

                value = max(minValue, min(maxValue, dragStartValue + delta * range))
            }
            .onEnded { _ in
                isDragging = false
            }
    }
}

// MARK: - Color Extensions for Lighting Effects

extension Color {
    func lighter(by percentage: CGFloat = 0.2) -> Color {
        self.opacity(1.0 + percentage)
    }

    func darker(by percentage: CGFloat = 0.2) -> Color {
        // Adjust the color by blending with black
        let uiColor = NSColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        return Color(
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(max(0, brightness - percentage)),
            opacity: Double(alpha)
        )
    }
}

// MARK: - Convenience Initializers

extension ProKnobView {
    /// Standard 0-1 normalized knob
    static func normalized(
        value: Binding<Float>,
        label: String,
        accentColor: Color = ColorPalette.ledBlue,
        size: KnobSize = .medium,
        style: KnobStyle = .bakelite
    ) -> ProKnobView {
        ProKnobView(
            value: value,
            label: label,
            accentColor: accentColor,
            size: size,
            style: style,
            range: 0...1,
            valueFormatter: { String(format: "%.0f%%", $0 * 100) }
        )
    }

    /// Bipolar knob (-1 to +1)
    static func bipolar(
        value: Binding<Float>,
        label: String,
        accentColor: Color = ColorPalette.ledBlue,
        size: KnobSize = .medium,
        style: KnobStyle = .bakelite
    ) -> ProKnobView {
        ProKnobView(
            value: value,
            label: label,
            accentColor: accentColor,
            size: size,
            style: style,
            range: -1...1,
            defaultValue: 0,
            isBipolar: true,
            valueFormatter: { val in
                if abs(val) < 0.01 { return "C" }
                return String(format: "%+.0f", val * 100)
            }
        )
    }

    /// Pan knob (L-C-R display)
    static func pan(
        value: Binding<Float>,
        label: String = "PAN",
        accentColor: Color = ColorPalette.ledBlue,
        size: KnobSize = .medium,
        style: KnobStyle = .bakelite
    ) -> ProKnobView {
        ProKnobView(
            value: value,
            label: label,
            accentColor: accentColor,
            size: size,
            style: style,
            range: 0...1,
            defaultValue: 0.5,
            isBipolar: true,
            valueFormatter: { val in
                let pan = (val - 0.5) * 2
                if abs(pan) < 0.05 { return "C" }
                if pan < 0 { return String(format: "L%d", Int(abs(pan) * 100)) }
                return String(format: "R%d", Int(pan * 100))
            }
        )
    }

    /// Frequency knob (20Hz - 20kHz logarithmic display)
    static func frequency(
        value: Binding<Float>,
        label: String = "FREQ",
        accentColor: Color = ColorPalette.ledBlue,
        size: KnobSize = .medium,
        style: KnobStyle = .bakelite
    ) -> ProKnobView {
        ProKnobView(
            value: value,
            label: label,
            accentColor: accentColor,
            size: size,
            style: style,
            range: 0...1,
            valueFormatter: { val in
                let hz = 20.0 * pow(1000.0, Double(val))
                if hz >= 1000 {
                    return String(format: "%.1fk", hz / 1000)
                }
                return String(format: "%.0f", hz)
            }
        )
    }

    /// Decibel knob (-inf to +10dB)
    static func decibel(
        value: Binding<Float>,
        label: String = "GAIN",
        accentColor: Color = ColorPalette.ledBlue,
        size: KnobSize = .medium,
        style: KnobStyle = .bakelite
    ) -> ProKnobView {
        ProKnobView(
            value: value,
            label: label,
            accentColor: accentColor,
            size: size,
            style: style,
            range: 0...1,
            defaultValue: 0.5,
            valueFormatter: { val in
                if val < 0.001 { return "-inf" }
                let db = 20 * log10(Double(val) * 2)  // 0.5 = unity (0dB)
                if db > 0 {
                    return String(format: "+%.1f", db)
                }
                return String(format: "%.1f", db)
            }
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ProKnobView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var value1: Float = 0.5
        @State private var value2: Float = 0.75
        @State private var value3: Float = 0.3
        @State private var value4: Float = 0.5

        var body: some View {
            VStack(spacing: 30) {
                Text("ProKnobView Sizes")
                    .font(Typography.sectionHeader)
                    .foregroundColor(.white)

                HStack(spacing: 20) {
                    ProKnobView(
                        value: $value1,
                        label: "SMALL",
                        accentColor: ColorPalette.accentPlaits,
                        size: .small
                    )

                    ProKnobView(
                        value: $value1,
                        label: "MEDIUM",
                        accentColor: ColorPalette.accentRings,
                        size: .medium
                    )

                    ProKnobView(
                        value: $value1,
                        label: "LARGE",
                        accentColor: ColorPalette.accentGranular1,
                        size: .large
                    )

                    ProKnobView(
                        value: $value1,
                        label: "XLARGE",
                        accentColor: ColorPalette.accentMaster,
                        size: .xlarge
                    )
                }

                Divider()

                Text("Knob Styles")
                    .font(Typography.sectionHeader)
                    .foregroundColor(.white)

                HStack(spacing: 30) {
                    ProKnobView(
                        value: $value2,
                        label: "BAKELITE",
                        accentColor: ColorPalette.ledAmber,
                        size: .large,
                        style: .bakelite
                    )

                    ProKnobView(
                        value: $value2,
                        label: "METAL",
                        accentColor: ColorPalette.ledBlue,
                        size: .large,
                        style: .metalPointer
                    )

                    ProKnobView(
                        value: $value2,
                        label: "ALUMINUM",
                        accentColor: ColorPalette.ledRed,
                        size: .large,
                        style: .aluminum
                    )

                    ProKnobView(
                        value: $value2,
                        label: "MINIMOOG",
                        accentColor: ColorPalette.accentPlaits,
                        size: .large,
                        style: .minimoog
                    )
                }

                Divider()

                Text("Specialized Knobs")
                    .font(Typography.sectionHeader)
                    .foregroundColor(.white)

                HStack(spacing: 30) {
                    ProKnobView.pan(
                        value: $value4,
                        accentColor: ColorPalette.accentLooper1,
                        size: .medium
                    )

                    ProKnobView.frequency(
                        value: $value3,
                        accentColor: ColorPalette.accentRings,
                        size: .medium
                    )

                    ProKnobView.decibel(
                        value: $value2,
                        accentColor: ColorPalette.accentPlaits,
                        size: .medium
                    )

                    ProKnobView.normalized(
                        value: $value1,
                        label: "MIX",
                        accentColor: ColorPalette.ledGreen,
                        size: .medium
                    )
                }
            }
            .padding(40)
            .background(ColorPalette.backgroundPrimary)
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
#endif

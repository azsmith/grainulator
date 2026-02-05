//
//  ProFaderView.swift
//  Grainulator
//
//  Professional console-style fader with realistic 3D appearance
//  Includes dB scale markings, unity gain indicator, and backlit scribble strip
//

import SwiftUI

// MARK: - Fader Size Configuration

enum FaderSize {
    case small      // 60px height - compact strips
    case medium     // 80px height - standard
    case large      // 100px height - master/featured
    case xlarge     // 120px height - master only

    var height: CGFloat {
        switch self {
        case .small: return 60
        case .medium: return 80
        case .large: return 100
        case .xlarge: return 120
        }
    }

    var width: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 24
        case .large: return 28
        case .xlarge: return 32
        }
    }

    var capHeight: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 18
        case .large: return 22
        case .xlarge: return 26
        }
    }

    var capWidth: CGFloat {
        switch self {
        case .small: return 18
        case .medium: return 22
        case .large: return 26
        case .xlarge: return 30
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
}

// MARK: - Pro Fader View

struct ProFaderView: View {
    @Binding var value: Float       // 0-1 linear, 0.5 = unity (0dB)
    let accentColor: Color
    let size: FaderSize
    let showScale: Bool
    let unityValue: Float           // Value that represents 0dB (default 0.5)
    let isMuted: Bool

    @State private var dragStartValue: Float = 0
    @State private var isDragging: Bool = false

    // dB scale markings (position, label)
    private let scaleMarks: [(position: Float, label: String)] = [
        (1.0, "+10"),
        (0.9, "+6"),
        (0.8, "+3"),
        (0.7, "0"),    // Unity position (will be adjusted based on unityValue)
        (0.5, "-6"),
        (0.3, "-12"),
        (0.15, "-20"),
        (0.05, "-40"),
        (0.0, "-∞")
    ]

    init(
        value: Binding<Float>,
        accentColor: Color = ColorPalette.ledBlue,
        size: FaderSize = .medium,
        showScale: Bool = true,
        unityValue: Float = 0.5,
        isMuted: Bool = false
    ) {
        self._value = value
        self.accentColor = accentColor
        self.size = size
        self.showScale = showScale
        self.unityValue = unityValue
        self.isMuted = isMuted
    }

    // Convert linear value to dB for display
    private var dbValue: String {
        if value < 0.001 { return "-∞" }
        let gain = value * 2  // 0.5 = unity (1.0 gain)
        let db = 20 * log10(Double(gain))
        if db > 0 {
            return String(format: "+%.1f", db)
        }
        return String(format: "%.1f", db)
    }

    var body: some View {
        HStack(spacing: 4) {
            // Scale markings (optional, left side)
            if showScale {
                scaleMarkingsView
            }

            // Main fader assembly
            faderAssembly

            // Scale markings (optional, right side for stereo)
            if showScale {
                Spacer()
                    .frame(width: 20)
            }
        }
    }

    // MARK: - Scale Markings

    private var scaleMarkingsView: some View {
        GeometryReader { geometry in
            ForEach(scaleMarks, id: \.label) { mark in
                let y = geometry.size.height * CGFloat(1 - mark.position)

                HStack(spacing: 2) {
                    // Tick mark
                    Rectangle()
                        .fill(mark.position == unityValue + 0.2 ? accentColor : ColorPalette.textDimmed)
                        .frame(width: mark.position == unityValue + 0.2 ? 6 : 4, height: 1)

                    // Label (only show some to avoid crowding)
                    if mark.label == "0" || mark.label == "-∞" || mark.label == "+10" || mark.label == "-12" {
                        Text(mark.label)
                            .font(Typography.vuScale)
                            .foregroundColor(ColorPalette.textDimmed)
                    }
                }
                .position(x: 14, y: y)
            }

            // Unity indicator arrow
            let unityY = geometry.size.height * CGFloat(1 - (unityValue + 0.2))
            Path { path in
                path.move(to: CGPoint(x: 20, y: unityY - 3))
                path.addLine(to: CGPoint(x: 24, y: unityY))
                path.addLine(to: CGPoint(x: 20, y: unityY + 3))
            }
            .fill(accentColor)
        }
        .frame(width: 30)
    }

    // MARK: - Fader Assembly

    private var faderAssembly: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Track shadow (inset)
                faderTrack(geometry: geometry)

                // Level fill indicator
                levelFill(geometry: geometry)

                // Unity mark on track
                unityMark(geometry: geometry)

                // Fader cap
                faderCap(geometry: geometry)
            }
            .gesture(faderGesture(geometry: geometry))
            .onTapGesture(count: 2) {
                // Double-tap to reset to unity
                withAnimation(.easeInOut(duration: 0.15)) {
                    value = unityValue
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Track

    private func faderTrack(geometry: GeometryProxy) -> some View {
        ZStack {
            // Outer track frame
            RoundedRectangle(cornerRadius: 3)
                .fill(ColorPalette.metalSteel)
                .frame(width: size.width, height: geometry.size.height)

            // Inner track groove
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [
                            ColorPalette.faderGroove,
                            ColorPalette.faderTrack,
                            ColorPalette.faderGroove
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size.width - 4, height: geometry.size.height - 4)

            // Side rails
            HStack {
                Rectangle()
                    .fill(ColorPalette.metalSteel.opacity(0.5))
                    .frame(width: 2, height: geometry.size.height - 8)
                Spacer()
                Rectangle()
                    .fill(ColorPalette.metalSteel.opacity(0.5))
                    .frame(width: 2, height: geometry.size.height - 8)
            }
            .frame(width: size.width - 2)
        }
    }

    // MARK: - Level Fill

    private func levelFill(geometry: GeometryProxy) -> some View {
        let fillHeight = geometry.size.height * CGFloat(value)

        return RoundedRectangle(cornerRadius: 1)
            .fill(
                LinearGradient(
                    colors: isMuted
                        ? [ColorPalette.textDimmed.opacity(0.3), ColorPalette.textDimmed.opacity(0.5)]
                        : [accentColor.opacity(0.2), accentColor.opacity(0.4)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: size.width - 8, height: fillHeight)
            .offset(y: 2)
    }

    // MARK: - Unity Mark

    private func unityMark(geometry: GeometryProxy) -> some View {
        let unityY = geometry.size.height * CGFloat(1 - unityValue)

        return Rectangle()
            .fill(accentColor)
            .frame(width: size.width - 6, height: 2)
            .position(x: size.width / 2, y: unityY)
    }

    // MARK: - Fader Cap

    private func faderCap(geometry: GeometryProxy) -> some View {
        let capY = geometry.size.height * CGFloat(1 - value)

        return ZStack {
            // Cap shadow
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.5))
                .frame(width: size.capWidth, height: size.capHeight)
                .offset(x: 2, y: 2)
                .blur(radius: 2)

            // Cap body
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            ColorPalette.faderCapHighlight,
                            ColorPalette.faderCapBlack,
                            ColorPalette.faderCapBlack.darker(by: 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size.capWidth, height: size.capHeight)

            // Cap texture (grip lines)
            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(ColorPalette.metalSteel.opacity(0.3))
                        .frame(width: size.capWidth - 8, height: 1)
                }
            }

            // Cap highlight (top edge)
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isDragging ? 0.4 : 0.2),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .frame(width: size.capWidth, height: size.capHeight)

            // Accent color indicator line
            if isDragging || value != unityValue {
                Rectangle()
                    .fill(isMuted ? ColorPalette.textDimmed : accentColor)
                    .frame(width: size.capWidth - 4, height: 2)
                    .offset(y: -size.capHeight / 2 + 4)
            }
        }
        .position(x: size.width / 2, y: capY)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isDragging)
    }

    // MARK: - Gesture

    private func faderGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !isDragging {
                    isDragging = true
                    dragStartValue = value
                }

                // Vertical drag with shift for fine control
                let isFineControl = NSEvent.modifierFlags.contains(.shift)
                let sensitivity: Float = isFineControl ? 4.0 : 1.0
                let delta = -Float(gesture.translation.height / geometry.size.height) / sensitivity

                value = max(0, min(1, dragStartValue + delta))
            }
            .onEnded { _ in
                isDragging = false
            }
    }
}

// MARK: - Fader with Label and Value Display

struct LabeledFaderView: View {
    @Binding var value: Float
    let label: String
    let accentColor: Color
    let size: FaderSize
    let isMuted: Bool

    init(
        value: Binding<Float>,
        label: String,
        accentColor: Color = ColorPalette.ledBlue,
        size: FaderSize = .medium,
        isMuted: Bool = false
    ) {
        self._value = value
        self.label = label
        self.accentColor = accentColor
        self.size = size
        self.isMuted = isMuted
    }

    // Convert linear value to dB for display
    private var dbValue: String {
        if value < 0.001 { return "-∞" }
        let gain = value * 2  // 0.5 = unity (1.0 gain)
        let db = 20 * log10(Double(gain))
        if db > 0 {
            return String(format: "+%.1f", db)
        }
        return String(format: "%.1f", db)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Channel label (scribble strip style)
            ScribbleStripView(label, color: accentColor, isActive: !isMuted)

            // Fader
            ProFaderView(
                value: $value,
                accentColor: accentColor,
                size: size,
                showScale: false,
                isMuted: isMuted
            )

            // dB value display
            Text(dbValue)
                .font(size.labelFont)
                .foregroundColor(isMuted ? ColorPalette.textDimmed : accentColor)
                .monospacedDigit()
                .frame(width: 40)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ColorPalette.backgroundPrimary)
                )
        }
    }
}

// MARK: - Channel Strip Fader (Complete Assembly)

struct ChannelStripFaderView: View {
    @Binding var gain: Float
    @Binding var pan: Float
    @Binding var sendA: Float
    @Binding var sendB: Float
    @Binding var isMuted: Bool
    @Binding var isSolo: Bool

    let channelName: String
    let channelIndex: Int
    let accentColor: Color
    let level: Float           // Current meter level

    var body: some View {
        VStack(spacing: 6) {
            // VU Meter
            VUMeterBarView(
                level: .constant(isMuted ? 0 : level),
                segments: 10,
                width: 8,
                height: 60
            )

            // Pan knob
            ProKnobView.pan(
                value: $pan,
                accentColor: accentColor,
                size: .small
            )

            // Send knobs
            HStack(spacing: 4) {
                VStack(spacing: 2) {
                    ProKnobView(
                        value: $sendA,
                        label: "A",
                        accentColor: ColorPalette.ledAmber,
                        size: .small,
                        showValue: false
                    )
                }

                VStack(spacing: 2) {
                    ProKnobView(
                        value: $sendB,
                        label: "B",
                        accentColor: ColorPalette.ledGreen,
                        size: .small,
                        showValue: false
                    )
                }
            }

            // Main fader
            LabeledFaderView(
                value: $gain,
                label: channelName,
                accentColor: accentColor,
                size: .medium,
                isMuted: isMuted
            )

            // Mute/Solo buttons
            HStack(spacing: 4) {
                MuteButtonView(isMuted: $isMuted)
                SoloButtonView(isSolo: $isSolo)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(ColorPalette.backgroundSecondary)
        )
    }
}

// MARK: - Placeholder Button Views (will be implemented separately)

struct MuteButtonView: View {
    @Binding var isMuted: Bool

    var body: some View {
        Button(action: { isMuted.toggle() }) {
            Text("M")
                .font(Typography.buttonSmall)
                .foregroundColor(isMuted ? .white : ColorPalette.textMuted)
                .frame(width: 20, height: 20)
                .background(isMuted ? ColorPalette.ledRed : ColorPalette.ledOff)
                .cornerRadius(3)
        }
        .buttonStyle(.plain)
    }
}

struct SoloButtonView: View {
    @Binding var isSolo: Bool

    var body: some View {
        Button(action: { isSolo.toggle() }) {
            Text("S")
                .font(Typography.buttonSmall)
                .foregroundColor(isSolo ? .black : ColorPalette.textMuted)
                .frame(width: 20, height: 20)
                .background(isSolo ? ColorPalette.ledAmber : ColorPalette.ledOff)
                .cornerRadius(3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct ProFaderView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var value1: Float = 0.5
        @State private var value2: Float = 0.7
        @State private var value3: Float = 0.3
        @State private var pan: Float = 0.5
        @State private var sendA: Float = 0.3
        @State private var sendB: Float = 0.2
        @State private var isMuted: Bool = false
        @State private var isSolo: Bool = false

        var body: some View {
            VStack(spacing: 30) {
                Text("ProFaderView Sizes")
                    .font(Typography.sectionHeader)
                    .foregroundColor(.white)

                HStack(spacing: 40) {
                    VStack {
                        ProFaderView(
                            value: $value1,
                            accentColor: ColorPalette.accentPlaits,
                            size: .small,
                            showScale: false
                        )
                        Text("Small")
                            .font(Typography.parameterLabel)
                            .foregroundColor(ColorPalette.textMuted)
                    }

                    VStack {
                        ProFaderView(
                            value: $value1,
                            accentColor: ColorPalette.accentRings,
                            size: .medium
                        )
                        Text("Medium")
                            .font(Typography.parameterLabel)
                            .foregroundColor(ColorPalette.textMuted)
                    }

                    VStack {
                        ProFaderView(
                            value: $value1,
                            accentColor: ColorPalette.accentGranular1,
                            size: .large
                        )
                        Text("Large")
                            .font(Typography.parameterLabel)
                            .foregroundColor(ColorPalette.textMuted)
                    }

                    VStack {
                        ProFaderView(
                            value: $value1,
                            accentColor: ColorPalette.accentMaster,
                            size: .xlarge
                        )
                        Text("XLarge")
                            .font(Typography.parameterLabel)
                            .foregroundColor(ColorPalette.textMuted)
                    }
                }

                Divider()

                Text("Complete Channel Strip")
                    .font(Typography.sectionHeader)
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    ChannelStripFaderView(
                        gain: $value1,
                        pan: $pan,
                        sendA: $sendA,
                        sendB: $sendB,
                        isMuted: $isMuted,
                        isSolo: $isSolo,
                        channelName: "PLAITS",
                        channelIndex: 0,
                        accentColor: ColorPalette.accentPlaits,
                        level: 0.6
                    )

                    ChannelStripFaderView(
                        gain: $value2,
                        pan: .constant(0.3),
                        sendA: .constant(0.5),
                        sendB: .constant(0.4),
                        isMuted: .constant(false),
                        isSolo: .constant(true),
                        channelName: "RINGS",
                        channelIndex: 1,
                        accentColor: ColorPalette.accentRings,
                        level: 0.4
                    )

                    ChannelStripFaderView(
                        gain: $value3,
                        pan: .constant(0.7),
                        sendA: .constant(0.2),
                        sendB: .constant(0.6),
                        isMuted: .constant(true),
                        isSolo: .constant(false),
                        channelName: "GRAN 1",
                        channelIndex: 2,
                        accentColor: ColorPalette.accentGranular1,
                        level: 0.8
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

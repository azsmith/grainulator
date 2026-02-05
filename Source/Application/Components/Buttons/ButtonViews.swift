//
//  ButtonViews.swift
//  Grainulator
//
//  Professional vintage-style button components
//  Includes illuminated jewel lens buttons and chrome toggle switches
//

import SwiftUI

// MARK: - Jewel Lens Button Base

/// Base component for illuminated jewel lens style buttons (Mute/Solo)
struct JewelLensButton: View {
    @Binding var isActive: Bool
    let label: String
    let activeColor: Color
    let glowColor: Color
    let size: CGSize

    var body: some View {
        Button(action: { isActive.toggle() }) {
            ZStack {
                // Bezel (outer ring)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ColorPalette.metalChrome,
                                ColorPalette.metalSteel,
                                ColorPalette.metalSteel.darker(by: 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size.width, height: size.height)

                // Inner bezel shadow
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: size.width - 4, height: size.height - 4)

                // Jewel lens
                Circle()
                    .fill(
                        RadialGradient(
                            colors: isActive
                                ? [activeColor.lighter(by: 0.3), activeColor, activeColor.darker(by: 0.2)]
                                : [ColorPalette.ledOff.lighter(by: 0.1), ColorPalette.ledOff, ColorPalette.ledOff.darker(by: 0.1)],
                            center: UnitPoint(x: 0.3, y: 0.3),
                            startRadius: 0,
                            endRadius: size.width * 0.4
                        )
                    )
                    .frame(width: size.width - 6, height: size.height - 6)

                // Highlight reflection
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isActive ? 0.5 : 0.2),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .frame(width: size.width - 8, height: size.height - 8)
                    .offset(x: -2, y: -2)

                // Label text
                Text(label)
                    .font(Typography.buttonSmall)
                    .fontWeight(.bold)
                    .foregroundColor(isActive ? .white : ColorPalette.textDimmed)
                    .shadow(color: isActive ? .black.opacity(0.5) : .clear, radius: 1, x: 0, y: 1)
            }
            .shadow(
                color: isActive ? glowColor.opacity(0.6) : .clear,
                radius: isActive ? 8 : 0
            )
        }
        .buttonStyle(PressedScaleButtonStyle())
    }
}

// MARK: - Pressable Button Style

struct PressedScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
    }
}

// MARK: - Mute Button

struct MuteButton: View {
    @Binding var isMuted: Bool
    let size: ButtonSize

    enum ButtonSize {
        case small  // 20x20
        case medium // 24x24
        case large  // 30x30

        var dimensions: CGSize {
            switch self {
            case .small: return CGSize(width: 20, height: 20)
            case .medium: return CGSize(width: 24, height: 24)
            case .large: return CGSize(width: 30, height: 30)
            }
        }
    }

    init(isMuted: Binding<Bool>, size: ButtonSize = .medium) {
        self._isMuted = isMuted
        self.size = size
    }

    var body: some View {
        JewelLensButton(
            isActive: $isMuted,
            label: "M",
            activeColor: ColorPalette.ledRed,
            glowColor: ColorPalette.ledRedGlow,
            size: size.dimensions
        )
    }
}

// MARK: - Solo Button

struct SoloButton: View {
    @Binding var isSolo: Bool
    let size: MuteButton.ButtonSize

    init(isSolo: Binding<Bool>, size: MuteButton.ButtonSize = .medium) {
        self._isSolo = isSolo
        self.size = size
    }

    var body: some View {
        JewelLensButton(
            isActive: $isSolo,
            label: "S",
            activeColor: ColorPalette.ledAmber,
            glowColor: ColorPalette.ledAmberGlow,
            size: size.dimensions
        )
    }
}

// MARK: - Record Button

struct RecordButton: View {
    @Binding var isRecording: Bool
    let size: MuteButton.ButtonSize

    init(isRecording: Binding<Bool>, size: MuteButton.ButtonSize = .large) {
        self._isRecording = isRecording
        self.size = size
    }

    var body: some View {
        JewelLensButton(
            isActive: $isRecording,
            label: "●",
            activeColor: ColorPalette.ledRed,
            glowColor: ColorPalette.ledRedGlow,
            size: size.dimensions
        )
    }
}

// MARK: - Chrome Toggle Switch

struct ChromeToggleSwitch: View {
    @Binding var isOn: Bool
    let label: String
    let onLabel: String
    let offLabel: String

    @State private var isDragging: Bool = false

    init(
        isOn: Binding<Bool>,
        label: String = "",
        onLabel: String = "ON",
        offLabel: String = "OFF"
    ) {
        self._isOn = isOn
        self.label = label
        self.onLabel = onLabel
        self.offLabel = offLabel
    }

    var body: some View {
        VStack(spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(Typography.parameterLabel)
                    .foregroundColor(ColorPalette.textMuted)
                    .textCase(.uppercase)
            }

            // Switch assembly
            ZStack {
                // Plate background
                RoundedRectangle(cornerRadius: 4)
                    .fill(ColorPalette.panelBackground)
                    .frame(width: 32, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(ColorPalette.metalSteel, lineWidth: 1)
                    )

                // Position labels
                VStack(spacing: 20) {
                    Text(onLabel)
                        .font(Typography.parameterLabelSmall)
                        .foregroundColor(isOn ? ColorPalette.ledGreen : ColorPalette.textDimmed)

                    Text(offLabel)
                        .font(Typography.parameterLabelSmall)
                        .foregroundColor(!isOn ? ColorPalette.textSecondary : ColorPalette.textDimmed)
                }

                // Toggle bat
                toggleBat
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isOn.toggle()
                }
            }
        }
    }

    private var toggleBat: some View {
        ZStack {
            // Bat shadow
            Capsule()
                .fill(Color.black.opacity(0.4))
                .frame(width: 10, height: 20)
                .offset(x: 1, y: isOn ? -8 : 10)
                .blur(radius: 2)

            // Bat body
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            ColorPalette.metalChrome,
                            ColorPalette.metalAluminum,
                            ColorPalette.metalSteel
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 8, height: 18)
                .offset(y: isOn ? -9 : 9)

            // Bat highlight
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .frame(width: 8, height: 18)
                .offset(y: isOn ? -9 : 9)
        }
    }
}

// MARK: - Illuminated Push Button

struct IlluminatedPushButton: View {
    let label: String
    let color: Color
    let isLit: Bool
    let action: () -> Void

    init(
        label: String,
        color: Color = ColorPalette.ledBlue,
        isLit: Bool = false,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.color = color
        self.isLit = isLit
        self.action = action
    }

    var body: some View {
        Button(action: {
            // Defer execution out of SwiftUI's gesture dispatch path to avoid
            // sporadic MainActor/gesture isolation crashes under heavy view churn.
            DispatchQueue.main.async {
                action()
            }
        }) {
            ZStack {
                // Button body
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                ColorPalette.backgroundTertiary,
                                ColorPalette.backgroundSecondary
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 28)

                // LED indicator strip
                Rectangle()
                    .fill(isLit ? color : ColorPalette.ledOff)
                    .frame(height: 3)
                    .frame(maxWidth: .infinity)
                    .offset(y: -12)

                // Label
                Text(label)
                    .font(Typography.buttonStandard)
                    .foregroundColor(isLit ? color : ColorPalette.textSecondary)

                // Border
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        isLit ? color.opacity(0.5) : ColorPalette.divider,
                        lineWidth: 1
                    )
            }
            .shadow(color: isLit ? color.opacity(0.3) : .clear, radius: 4)
        }
        .buttonStyle(PressedScaleButtonStyle(pressedScale: 0.98))
    }
}

// MARK: - Transport Buttons

struct TransportButton: View {
    enum TransportType {
        case play
        case stop
        case record
        case pause
        case rewind
        case forward

        var symbol: String {
            switch self {
            case .play: return "▶"
            case .stop: return "■"
            case .record: return "●"
            case .pause: return "❚❚"
            case .rewind: return "◀◀"
            case .forward: return "▶▶"
            }
        }

        var activeColor: Color {
            switch self {
            case .play: return ColorPalette.ledGreen
            case .stop: return ColorPalette.textSecondary
            case .record: return ColorPalette.ledRed
            case .pause: return ColorPalette.ledAmber
            case .rewind, .forward: return ColorPalette.ledBlue
            }
        }
    }

    let type: TransportType
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            // Button body
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            ColorPalette.metalSteel,
                            ColorPalette.metalSteel.darker(by: 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 32)

            // Symbol
            Text(type.symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isActive ? type.activeColor : ColorPalette.textMuted)

            // Border
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    isActive ? type.activeColor.opacity(0.5) : ColorPalette.divider,
                    lineWidth: 1
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            DispatchQueue.main.async {
                action()
            }
        }
        .shadow(color: isActive ? type.activeColor.opacity(0.4) : .clear, radius: 4)
    }
}

// MARK: - Segmented Button Group

struct SegmentedButtonGroup<T: Hashable>: View {
    @Binding var selection: T
    let options: [(value: T, label: String)]
    let accentColor: Color

    init(
        selection: Binding<T>,
        options: [(value: T, label: String)],
        accentColor: Color = ColorPalette.ledBlue
    ) {
        self._selection = selection
        self.options = options
        self.accentColor = accentColor
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button(action: { selection = option.value }) {
                    Text(option.label)
                        .font(Typography.buttonSmall)
                        .foregroundColor(selection == option.value ? .white : ColorPalette.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selection == option.value
                                ? accentColor
                                : ColorPalette.backgroundTertiary
                        )
                }
                .buttonStyle(.plain)

                if index < options.count - 1 {
                    Rectangle()
                        .fill(ColorPalette.divider)
                        .frame(width: 1)
                }
            }
        }
        .background(ColorPalette.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(ColorPalette.divider, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ButtonViews_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var isMuted = false
        @State private var isSolo = true
        @State private var isRecording = false
        @State private var isPlaying = true
        @State private var toggleState = true
        @State private var selectedOption = 0

        var body: some View {
            VStack(spacing: 30) {
                Text("Button Components")
                    .font(Typography.sectionHeader)
                    .foregroundColor(.white)

                // Mute/Solo buttons
                HStack(spacing: 20) {
                    VStack {
                        MuteButton(isMuted: $isMuted, size: .small)
                        Text("Small")
                            .font(Typography.parameterLabelSmall)
                            .foregroundColor(ColorPalette.textDimmed)
                    }

                    VStack {
                        MuteButton(isMuted: $isMuted, size: .medium)
                        Text("Medium")
                            .font(Typography.parameterLabelSmall)
                            .foregroundColor(ColorPalette.textDimmed)
                    }

                    VStack {
                        MuteButton(isMuted: $isMuted, size: .large)
                        Text("Large")
                            .font(Typography.parameterLabelSmall)
                            .foregroundColor(ColorPalette.textDimmed)
                    }

                    VStack {
                        SoloButton(isSolo: $isSolo, size: .medium)
                        Text("Solo")
                            .font(Typography.parameterLabelSmall)
                            .foregroundColor(ColorPalette.textDimmed)
                    }

                    VStack {
                        RecordButton(isRecording: $isRecording, size: .large)
                        Text("Rec")
                            .font(Typography.parameterLabelSmall)
                            .foregroundColor(ColorPalette.textDimmed)
                    }
                }

                Divider()

                // Toggle switch
                HStack(spacing: 30) {
                    ChromeToggleSwitch(isOn: $toggleState, label: "SYNC")
                    ChromeToggleSwitch(isOn: .constant(false), label: "PRE/POST", onLabel: "PRE", offLabel: "POST")
                }

                Divider()

                // Transport buttons
                HStack(spacing: 8) {
                    TransportButton(type: .rewind, isActive: false) {}
                    TransportButton(type: .stop, isActive: !isPlaying) { isPlaying = false }
                    TransportButton(type: .play, isActive: isPlaying) { isPlaying = true }
                    TransportButton(type: .record, isActive: isRecording) { isRecording.toggle() }
                    TransportButton(type: .forward, isActive: false) {}
                }

                Divider()

                // Illuminated push buttons
                HStack(spacing: 8) {
                    IlluminatedPushButton(label: "TRIGGER", color: ColorPalette.accentPlaits, isLit: false) {}
                    IlluminatedPushButton(label: "RANDOM", color: ColorPalette.ledAmber, isLit: true) {}
                    IlluminatedPushButton(label: "RESET", color: ColorPalette.ledBlue, isLit: false) {}
                }
                .frame(width: 300)

                Divider()

                // Segmented buttons
                SegmentedButtonGroup(
                    selection: $selectedOption,
                    options: [
                        (0, "SINE"),
                        (1, "TRI"),
                        (2, "SAW"),
                        (3, "SQR")
                    ],
                    accentColor: ColorPalette.accentRings
                )
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

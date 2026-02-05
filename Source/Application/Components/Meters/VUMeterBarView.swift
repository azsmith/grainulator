//
//  VUMeterBarView.swift
//  Grainulator
//
//  Professional VU meter components with proper ballistics
//  Includes LED bar style and classic needle style meters
//

import SwiftUI
import Combine

// MARK: - Meter Ballistics Engine

/// Handles VU meter smoothing with attack/release characteristics
class MeterBallistics: ObservableObject {
    @Published private(set) var displayLevel: Float = 0
    @Published private(set) var peakLevel: Float = 0
    @Published private(set) var peakHoldLevel: Float = 0

    // Ballistics parameters
    private let attackTime: Float = 0.01       // 10ms attack (near instant for peaks)
    private let releaseTime: Float = 0.3       // 300ms release (VU standard)
    private let peakHoldTime: Float = 2.0      // 2 second peak hold
    private let peakDecayTime: Float = 1.5     // Peak decay rate

    private var lastUpdateTime: Date = Date()
    private var peakHoldTimer: Float = 0
    private var updateTimer: Timer?

    init() {
        // Start internal update timer at 60fps for smooth animation
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateBallistics()
        }
    }

    deinit {
        updateTimer?.invalidate()
    }

    /// Update with new input level (call from audio callback or timer)
    func updateLevel(_ newLevel: Float) {
        let now = Date()
        let deltaTime = Float(now.timeIntervalSince(lastUpdateTime))
        lastUpdateTime = now

        // Update display level with attack/release
        if newLevel > displayLevel {
            // Attack - fast rise
            let attackCoeff = 1.0 - exp(-deltaTime / attackTime)
            displayLevel += (newLevel - displayLevel) * attackCoeff
        } else {
            // Release - slow fall
            let releaseCoeff = 1.0 - exp(-deltaTime / releaseTime)
            displayLevel += (newLevel - displayLevel) * releaseCoeff
        }

        // Update peak level
        if newLevel > peakLevel {
            peakLevel = newLevel
        }

        // Update peak hold
        if newLevel > peakHoldLevel {
            peakHoldLevel = newLevel
            peakHoldTimer = 0
        }
    }

    private func updateBallistics() {
        let deltaTime: Float = 1.0 / 60.0

        // Decay peak level
        if peakLevel > displayLevel {
            let decayCoeff = 1.0 - exp(-deltaTime / peakDecayTime)
            peakLevel -= peakLevel * decayCoeff
            if peakLevel < displayLevel {
                peakLevel = displayLevel
            }
        }

        // Peak hold timer
        peakHoldTimer += deltaTime
        if peakHoldTimer > peakHoldTime {
            // Start decaying peak hold
            let holdDecayCoeff = 1.0 - exp(-deltaTime / (peakDecayTime * 2))
            peakHoldLevel -= peakHoldLevel * holdDecayCoeff
            if peakHoldLevel < displayLevel {
                peakHoldLevel = displayLevel
            }
        }
    }

    /// Reset all levels
    func reset() {
        displayLevel = 0
        peakLevel = 0
        peakHoldLevel = 0
        peakHoldTimer = 0
    }
}

// MARK: - LED Bar VU Meter

struct VUMeterBarView: View {
    @Binding var level: Float           // 0-1 linear level
    let segments: Int                   // Number of LED segments
    let orientation: Orientation
    let showPeakHold: Bool
    let width: CGFloat
    let height: CGFloat

    @StateObject private var ballistics = MeterBallistics()

    enum Orientation {
        case vertical
        case horizontal
    }

    init(
        level: Binding<Float>,
        segments: Int = 12,
        orientation: Orientation = .vertical,
        showPeakHold: Bool = true,
        width: CGFloat = 8,
        height: CGFloat = 80
    ) {
        self._level = level
        self.segments = segments
        self.orientation = orientation
        self.showPeakHold = showPeakHold
        self.width = width
        self.height = height
    }

    // Calculate which segments should be lit
    private func segmentState(at index: Int) -> SegmentState {
        let normalizedPosition = Float(index) / Float(segments - 1)
        let displayLevel = ballistics.displayLevel

        if normalizedPosition <= displayLevel {
            return .lit
        } else if showPeakHold && abs(normalizedPosition - ballistics.peakHoldLevel) < (1.0 / Float(segments)) {
            return .peak
        } else {
            return .off
        }
    }

    private func segmentColor(at index: Int) -> Color {
        let position = Float(index) / Float(segments - 1)

        if position < 0.6 {
            return ColorPalette.vuGreen
        } else if position < 0.8 {
            return ColorPalette.vuYellow
        } else {
            return ColorPalette.vuRed
        }
    }

    enum SegmentState {
        case off
        case lit
        case peak
    }

    var body: some View {
        let segmentSize = orientation == .vertical
            ? CGSize(width: width, height: (height - CGFloat(segments - 1) * 2) / CGFloat(segments))
            : CGSize(width: (width - CGFloat(segments - 1) * 2) / CGFloat(segments), height: height)

        Group {
            if orientation == .vertical {
                VStack(spacing: 2) {
                    ForEach((0..<segments).reversed(), id: \.self) { index in
                        ledSegment(at: index, size: segmentSize)
                    }
                }
            } else {
                HStack(spacing: 2) {
                    ForEach(0..<segments, id: \.self) { index in
                        ledSegment(at: index, size: segmentSize)
                    }
                }
            }
        }
        .frame(width: orientation == .vertical ? width : nil,
               height: orientation == .vertical ? nil : height)
        .onChange(of: level) { newLevel in
            ballistics.updateLevel(newLevel)
        }
    }

    @ViewBuilder
    private func ledSegment(at index: Int, size: CGSize) -> some View {
        let state = segmentState(at: index)
        let baseColor = segmentColor(at: index)

        RoundedRectangle(cornerRadius: 1)
            .fill(segmentFill(state: state, color: baseColor))
            .frame(width: size.width, height: size.height)
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .stroke(baseColor.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(
                color: state == .lit ? baseColor.opacity(0.6) : .clear,
                radius: state == .lit ? 4 : 0
            )
    }

    private func segmentFill(state: SegmentState, color: Color) -> some ShapeStyle {
        switch state {
        case .lit:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .peak:
            return AnyShapeStyle(color.opacity(0.8))
        case .off:
            return AnyShapeStyle(ColorPalette.ledOff)
        }
    }
}

// MARK: - Stereo VU Meter Bar

struct StereoVUMeterBarView: View {
    @Binding var levelL: Float
    @Binding var levelR: Float
    let segments: Int
    let width: CGFloat
    let height: CGFloat
    let showLabels: Bool

    init(
        levelL: Binding<Float>,
        levelR: Binding<Float>,
        segments: Int = 12,
        width: CGFloat = 20,
        height: CGFloat = 80,
        showLabels: Bool = true
    ) {
        self._levelL = levelL
        self._levelR = levelR
        self.segments = segments
        self.width = width
        self.height = height
        self.showLabels = showLabels
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                VUMeterBarView(
                    level: $levelL,
                    segments: segments,
                    width: (width - 2) / 2,
                    height: height
                )

                VUMeterBarView(
                    level: $levelR,
                    segments: segments,
                    width: (width - 2) / 2,
                    height: height
                )
            }

            if showLabels {
                HStack(spacing: 2) {
                    Text("L")
                        .font(Typography.parameterLabelSmall)
                        .foregroundColor(ColorPalette.textDimmed)
                        .frame(width: (width - 2) / 2)

                    Text("R")
                        .font(Typography.parameterLabelSmall)
                        .foregroundColor(ColorPalette.textDimmed)
                        .frame(width: (width - 2) / 2)
                }
            }
        }
    }
}

// MARK: - Classic Needle VU Meter

struct VUMeterNeedleView: View {
    @Binding var level: Float       // 0-1 linear level
    let width: CGFloat
    let height: CGFloat

    @StateObject private var ballistics = MeterBallistics()

    // VU meter scale (in VU, where 0 VU = reference level)
    private let scaleMarks: [(value: Float, label: String)] = [
        (0.0, "-20"),
        (0.2, "-10"),
        (0.4, "-7"),
        (0.5, "-5"),
        (0.6, "-3"),
        (0.7, "0"),
        (0.8, "+1"),
        (0.9, "+2"),
        (1.0, "+3")
    ]

    // Needle angle range (-45 to +45 degrees from center)
    private let needleMinAngle: Double = -50
    private let needleMaxAngle: Double = 50

    private var needleAngle: Double {
        let normalized = Double(ballistics.displayLevel)
        return needleMinAngle + normalized * (needleMaxAngle - needleMinAngle)
    }

    var body: some View {
        ZStack {
            // Meter face background
            meterFace

            // Scale markings
            scaleMarkings

            // Red zone indicator
            redZone

            // Needle
            needle

            // Needle pivot cover
            pivotCover
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorPalette.metalSteel, lineWidth: 2)
        )
        .shadow(color: ColorPalette.shadowDrop, radius: 4, x: 0, y: 2)
        .onChange(of: level) { newLevel in
            ballistics.updateLevel(newLevel)
        }
    }

    private var meterFace: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                LinearGradient(
                    colors: [
                        ColorPalette.vuFace,
                        ColorPalette.vuFaceShadow
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var scaleMarkings: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height * 0.85
            let arcRadius = geometry.size.height * 0.6

            ForEach(scaleMarks, id: \.label) { mark in
                let angle = needleMinAngle + Double(mark.value) * (needleMaxAngle - needleMinAngle)
                let radians = angle * .pi / 180

                // Tick mark
                Path { path in
                    let innerRadius = arcRadius - 8
                    let outerRadius = arcRadius
                    let x1 = centerX + CGFloat(sin(radians)) * innerRadius
                    let y1 = centerY - CGFloat(cos(radians)) * innerRadius
                    let x2 = centerX + CGFloat(sin(radians)) * outerRadius
                    let y2 = centerY - CGFloat(cos(radians)) * outerRadius
                    path.move(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))
                }
                .stroke(ColorPalette.vuNeedle, lineWidth: mark.value == 0.7 ? 2 : 1)

                // Label
                let labelRadius = arcRadius - 18
                let labelX = centerX + CGFloat(sin(radians)) * labelRadius
                let labelY = centerY - CGFloat(cos(radians)) * labelRadius

                Text(mark.label)
                    .font(Typography.vuScale)
                    .foregroundColor(mark.value >= 0.7 ? ColorPalette.vuRed : ColorPalette.vuNeedle)
                    .position(x: labelX, y: labelY)
            }

            // VU label
            Text("VU")
                .font(Typography.embossedLabel)
                .foregroundColor(ColorPalette.vuNeedle)
                .position(x: centerX, y: geometry.size.height * 0.35)
        }
    }

    private var redZone: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height * 0.85
            let arcRadius = geometry.size.height * 0.55

            // Red arc for +1 to +3 zone
            Path { path in
                let startAngle = Angle(degrees: needleMinAngle + 0.8 * (needleMaxAngle - needleMinAngle) - 90)
                let endAngle = Angle(degrees: needleMaxAngle - 90)
                path.addArc(
                    center: CGPoint(x: centerX, y: centerY),
                    radius: arcRadius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
            }
            .stroke(ColorPalette.vuRed, lineWidth: 4)
        }
    }

    private var needle: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height * 0.85
            let needleLength = geometry.size.height * 0.55

            // Needle shadow
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .frame(width: 2, height: needleLength)
                .offset(x: 1, y: -needleLength / 2 + 1)
                .rotationEffect(.degrees(needleAngle), anchor: .bottom)
                .position(x: centerX, y: centerY)

            // Needle
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [ColorPalette.vuNeedle, ColorPalette.vuNeedle.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2, height: needleLength)
                .offset(y: -needleLength / 2)
                .rotationEffect(.degrees(needleAngle), anchor: .bottom)
                .position(x: centerX, y: centerY)
                .animation(.interpolatingSpring(stiffness: 100, damping: 12), value: needleAngle)
        }
    }

    private var pivotCover: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height * 0.85

            Circle()
                .fill(
                    RadialGradient(
                        colors: [ColorPalette.metalChrome, ColorPalette.metalSteel],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 10
                    )
                )
                .frame(width: 12, height: 12)
                .position(x: centerX, y: centerY)
        }
    }
}

// MARK: - Stereo Needle VU Meter

struct StereoVUMeterNeedleView: View {
    @Binding var levelL: Float
    @Binding var levelR: Float
    let width: CGFloat
    let height: CGFloat

    init(
        levelL: Binding<Float>,
        levelR: Binding<Float>,
        width: CGFloat = 200,
        height: CGFloat = 80
    ) {
        self._levelL = levelL
        self._levelR = levelR
        self.width = width
        self.height = height
    }

    var body: some View {
        HStack(spacing: 4) {
            VStack(spacing: 2) {
                VUMeterNeedleView(level: $levelL, width: (width - 4) / 2, height: height)
                Text("L")
                    .font(Typography.parameterLabel)
                    .foregroundColor(ColorPalette.textMuted)
            }

            VStack(spacing: 2) {
                VUMeterNeedleView(level: $levelR, width: (width - 4) / 2, height: height)
                Text("R")
                    .font(Typography.parameterLabel)
                    .foregroundColor(ColorPalette.textMuted)
            }
        }
    }
}

// MARK: - Peak LED Indicator

struct PeakLEDView: View {
    @Binding var level: Float
    let threshold: Float
    let holdTime: TimeInterval

    @State private var isPeaking: Bool = false
    @State private var peakTimer: Timer?

    init(level: Binding<Float>, threshold: Float = 0.9, holdTime: TimeInterval = 2.0) {
        self._level = level
        self.threshold = threshold
        self.holdTime = holdTime
    }

    var body: some View {
        Circle()
            .fill(isPeaking ? ColorPalette.ledRed : ColorPalette.ledOff)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(ColorPalette.divider, lineWidth: 1)
            )
            .shadow(color: isPeaking ? ColorPalette.ledRedGlow : .clear, radius: 4)
            .onChange(of: level) { newLevel in
                if newLevel >= threshold {
                    isPeaking = true
                    peakTimer?.invalidate()
                    peakTimer = Timer.scheduledTimer(withTimeInterval: holdTime, repeats: false) { _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            isPeaking = false
                        }
                    }
                }
            }
    }
}

// MARK: - Preview

#if DEBUG
struct VUMeterViews_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var level: Float = 0.6
        @State private var levelL: Float = 0.5
        @State private var levelR: Float = 0.7

        var body: some View {
            VStack(spacing: 30) {
                Text("VU Meter Components")
                    .font(Typography.sectionHeader)
                    .foregroundColor(.white)

                HStack(spacing: 40) {
                    VStack {
                        Text("LED Bar")
                            .font(Typography.parameterLabel)
                            .foregroundColor(ColorPalette.textMuted)

                        VUMeterBarView(level: $level, segments: 12, width: 10, height: 100)
                    }

                    VStack {
                        Text("Stereo Bar")
                            .font(Typography.parameterLabel)
                            .foregroundColor(ColorPalette.textMuted)

                        StereoVUMeterBarView(levelL: $levelL, levelR: $levelR, width: 24, height: 100)
                    }

                    VStack {
                        Text("Needle")
                            .font(Typography.parameterLabel)
                            .foregroundColor(ColorPalette.textMuted)

                        VUMeterNeedleView(level: $level, width: 120, height: 70)
                    }
                }

                HStack {
                    Text("Peak LED:")
                        .foregroundColor(ColorPalette.textMuted)
                    PeakLEDView(level: $level)
                }

                // Level control slider
                VStack {
                    Text("Test Level: \(String(format: "%.2f", level))")
                        .foregroundColor(ColorPalette.textSecondary)

                    Slider(value: $level, in: 0...1)
                        .frame(width: 200)
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

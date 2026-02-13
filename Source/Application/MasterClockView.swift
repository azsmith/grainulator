//
//  MasterClockView.swift
//  Grainulator
//
//  Pam's Pro Workout-inspired master clock interface.
//  Compact display with 8 configurable clock/LFO outputs in 4x2 grid.
//

import SwiftUI

// MARK: - Draggable BPM View

struct DraggableBPMView: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let accentColor: Color

    @State private var isEditing = false
    @State private var editText = ""
    @State private var dragStartValue: Double = 0
    @State private var isDragging = false

    var body: some View {
        ZStack {
            if isEditing {
                // Text input mode
                TextField("", text: $editText)
                    .font(Typography.lcdSmall)
                    .foregroundColor(accentColor)
                    .multilineTextAlignment(.center)
                    .frame(width: 70, height: 36)
                    .background(ColorPalette.lcdAmberBg)
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(accentColor, lineWidth: 2)
                    )
                    .onSubmit {
                        if let newValue = Double(editText) {
                            value = min(max(newValue, range.lowerBound), range.upperBound)
                        }
                        isEditing = false
                    }
                    .onAppear {
                        editText = String(format: "%.0f", value)
                    }
            } else {
                // Display mode - draggable (LCD-inspired)
                Text(String(format: "%.0f", value))
                    .font(Typography.lcdSmall)
                    .foregroundColor(isDragging ? .white : accentColor)
                    .frame(width: 70, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isDragging ? accentColor.opacity(0.3) : ColorPalette.lcdAmberBg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(accentColor.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: accentColor.opacity(0.15), radius: 4, x: 0, y: 0)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { gesture in
                                if !isDragging {
                                    isDragging = true
                                    dragStartValue = value
                                }
                                // Vertical drag: up = increase, down = decrease
                                let sensitivity: Double = NSEvent.modifierFlags.contains(.shift) ? 0.1 : 0.5
                                let delta = -gesture.translation.height * sensitivity
                                value = min(max(dragStartValue + delta, range.lowerBound), range.upperBound)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                    .onTapGesture(count: 2) {
                        isEditing = true
                    }
            }
        }
        .help("Drag up/down to adjust BPM, double-click to type")
    }
}

// MARK: - Master Clock View

struct MasterClockView: View {
    @EnvironmentObject var masterClock: MasterClock
    @EnvironmentObject var sequencer: StepSequencer

    var body: some View {
        ConsoleModuleView(
            title: "M CLOCK",
            accentColor: ColorPalette.accentLooper1
        ) {
            VStack(spacing: 10) {
                header
                outputGrid
            }
            .padding(12)
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Header (Compact)

    private var header: some View {
        HStack(spacing: 10) {
            // Play/Stop button
            Text(sequencer.isPlaying ? "STOP" : "RUN")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(sequencer.isPlaying ? ColorPalette.backgroundSecondary : .white)
                .frame(width: 48, height: 28)
                .background(sequencer.isPlaying ? ColorPalette.ledGreen : ColorPalette.panelBackground)
                .cornerRadius(4)
                .contentShape(RoundedRectangle(cornerRadius: 4))
                .onTapGesture {
                    if sequencer.isPlaying {
                        sequencer.stop()
                    } else {
                        sequencer.start()
                    }
                }

            // Draggable BPM
            DraggableBPMView(
                value: $masterClock.bpm,
                range: 10...330,
                accentColor: ColorPalette.accentLooper1
            )

            // Time signature selector (compact)
            Menu {
                Button("4/4") { masterClock.setTimeSignature(numerator: 4, denominator: 4) }
                Button("3/4") { masterClock.setTimeSignature(numerator: 3, denominator: 4) }
                Button("6/8") { masterClock.setTimeSignature(numerator: 6, denominator: 8) }
                Button("5/4") { masterClock.setTimeSignature(numerator: 5, denominator: 4) }
                Button("7/8") { masterClock.setTimeSignature(numerator: 7, denominator: 8) }
            } label: {
                Text(masterClock.timeSignatureDisplay)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.accentLooper1)
                    .frame(width: 38, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ColorPalette.lcdAmberBg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(ColorPalette.accentLooper1.opacity(0.3), lineWidth: 1)
                    )
            }
            .menuStyle(.borderlessButton)
            .frame(width: 38)
            .help("Time signature")

            // Swing control (compact)
            HStack(spacing: 4) {
                Text("SWG")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textDimmed)

                Slider(
                    value: $masterClock.swing,
                    in: 0...1
                )
                .tint(ColorPalette.accentLooper1)
                .frame(width: 50)

                Text(String(format: "%.0f%%", masterClock.swing * 100))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textMuted)
                    .frame(width: 28, alignment: .trailing)
            }

            Spacer()
        }
    }

    // MARK: - Output Grid (8x1 row, matching drum step layout)

    private var outputGrid: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { groupIndex in
                HStack(spacing: 3) {
                    ForEach(0..<2, id: \.self) { inGroupIndex in
                        let outputIndex = groupIndex * 2 + inGroupIndex
                        ClockOutputPad(output: masterClock.outputs[outputIndex], index: outputIndex)
                            .frame(height: 80)
                    }
                }

                // Divider between groups (except after last)
                if groupIndex < 3 {
                    Rectangle()
                        .fill(ColorPalette.divider)
                        .frame(width: 1)
                        .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Clock Output Group Colors (matching drum sequencer step palette)

struct ClockOutputColors {
    /// Group colors for outputs 1-2, 3-4, 5-6, 7-8
    static let groupColors: [Color] = [
        Color(red: 0.85, green: 0.20, blue: 0.20),  // Red
        Color(red: 0.90, green: 0.55, blue: 0.15),  // Orange
        Color(red: 0.90, green: 0.80, blue: 0.20),  // Yellow
        Color(red: 0.90, green: 0.87, blue: 0.80),  // Off-white/cream
    ]

    /// Dim version of group colors (inactive/muted state)
    static let groupColorsDim: [Color] = [
        Color(red: 0.25, green: 0.08, blue: 0.08),  // Dim red
        Color(red: 0.28, green: 0.16, blue: 0.06),  // Dim orange
        Color(red: 0.28, green: 0.24, blue: 0.06),  // Dim yellow
        Color(red: 0.25, green: 0.24, blue: 0.22),  // Dim off-white
    ]

    /// Dark text color for light group pads (cream/yellow)
    static let darkText = Color(red: 0.15, green: 0.14, blue: 0.13)

    static func color(for index: Int, active: Bool) -> Color {
        let groupIndex = index / 2
        let clamped = min(groupIndex, 3)
        return active ? groupColors[clamped] : groupColorsDim[clamped]
    }

    static func brightColor(for index: Int) -> Color {
        let groupIndex = index / 2
        return groupColors[min(groupIndex, 3)]
    }

    /// Whether this output's group color needs dark text for contrast
    static func needsDarkText(for index: Int) -> Bool {
        let groupIndex = index / 2
        return groupIndex >= 2  // Yellow and cream groups need dark text
    }
}

// MARK: - Clock Output Pad (Drum Step Style)

struct ClockOutputPad: View {
    @ObservedObject var output: ClockOutput
    let index: Int

    @State private var showingConfig = false
    @State private var isHovering = false

    /// Whether the output is currently pulsing (activity above threshold)
    private var isActive: Bool {
        !output.muted && abs(output.currentValue) > 0.3
    }

    /// The pad's fill color based on state
    private var padColor: Color {
        if output.muted {
            return ClockOutputColors.groupColorsDim[min(index / 2, 3)].opacity(0.4)
        }
        return ClockOutputColors.color(for: index, active: isActive)
    }

    /// Text color — dark on bright yellow/cream pads, light on dim/dark pads
    private var textColor: Color {
        if output.muted { return ColorPalette.textDimmed }
        if isActive && ClockOutputColors.needsDarkText(for: index) {
            return ClockOutputColors.darkText
        }
        return isActive ? .white : ColorPalette.textMuted
    }

    /// Secondary text color for mode label
    private var secondaryTextColor: Color {
        if output.muted { return ColorPalette.textDimmed.opacity(0.5) }
        if isActive && ClockOutputColors.needsDarkText(for: index) {
            return ClockOutputColors.darkText.opacity(0.6)
        }
        return isActive ? .white.opacity(0.6) : ColorPalette.textDimmed
    }

    var body: some View {
        Button(action: { showingConfig = true }) {
            VStack(spacing: 2) {
                // Output index
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(secondaryTextColor)

                // Division or waveform (primary label)
                Text(output.mode == .clock ? output.division.rawValue : output.waveform.rawValue)
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Mode label
                Text(output.mode == .clock ? "CLK" : "LFO")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(secondaryTextColor)

                // Mute indicator
                if output.muted {
                    Text("MUTE")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.ledRed)
                } else {
                    Color.clear.frame(height: 9)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(padColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        isActive ? ClockOutputColors.brightColor(for: index).opacity(0.6) : Color.clear,
                        lineWidth: isActive ? 1.5 : 0
                    )
            )
            .shadow(
                color: isActive ? ClockOutputColors.brightColor(for: index).opacity(0.4) : .clear,
                radius: isActive ? 4 : 0
            )
            .scaleEffect(isHovering ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button(output.muted ? "Unmute" : "Mute") {
                output.muted.toggle()
            }
        }
        .popover(isPresented: $showingConfig) {
            ClockOutputConfigView(output: output, index: index)
        }
    }
}

// MARK: - Clock Output Configuration Popover

struct ClockOutputConfigView: View {
    @ObservedObject var output: ClockOutput
    @EnvironmentObject var masterClock: MasterClock
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("OUTPUT \(index + 1)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.accentLooper1)

                Spacer()

                Button(action: { masterClock.resetOutput(index: index) }) {
                    Text("RST")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ColorPalette.backgroundTertiary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(ColorPalette.divider, lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
                .help("Reset this output to beat 1")
            }

            // Mode selector
            HStack {
                Text("Mode")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textMuted)
                    .frame(width: 70, alignment: .leading)

                Picker("Mode", selection: $output.mode) {
                    ForEach(ClockOutputMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            // Division/Rate (for both clock and LFO modes)
            HStack {
                Text(output.mode == .clock ? "Division" : "Rate")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textMuted)
                    .frame(width: 70, alignment: .leading)

                Picker("Division", selection: $output.division) {
                    ForEach(SequencerClockDivision.allCases) { div in
                        Text(div.rawValue).tag(div)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
            }

            // Waveform (for LFO mode)
            if output.mode == .lfo {
                HStack {
                    Text("Waveform")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textMuted)
                        .frame(width: 70, alignment: .leading)

                    Picker("Waveform", selection: $output.waveform) {
                        ForEach(ClockWaveform.allCases) { wf in
                            Text(wf.rawValue).tag(wf)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }

                // Slow/Fast toggle
                HStack {
                    Text("Speed")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textMuted)
                        .frame(width: 70, alignment: .leading)

                    Picker("Speed", selection: $output.slowMode) {
                        Text("FAST").tag(false)
                        Text("SLOW").tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }

                if output.slowMode {
                    Text("÷4 rate multiplier")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            Divider()
                .background(ColorPalette.divider)

            // Level
            parameterSlider(label: "Level", value: $output.level, range: 0...1)

            // Offset
            parameterSlider(label: "Offset", value: $output.offset, range: -1...1)

            // Phase
            parameterSlider(label: "Phase", value: $output.phase, range: 0...1, format: "%.0f\u{00B0}") { $0 * 360 }

            // Width/Skew
            parameterSlider(label: "Width", value: $output.width, range: 0...1, format: "%.0f%%") { $0 * 100 }

            Divider()
                .background(ColorPalette.divider)

            // Destination
            HStack {
                Text("Dest")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textMuted)
                    .frame(width: 70, alignment: .leading)

                Picker("Destination", selection: $output.destination) {
                    ForEach(ModulationDestination.allCases) { dest in
                        Text(dest.displayName).tag(dest)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }

            // Mod Amount (only for CV modulation destinations)
            if output.destination != .none && !output.destination.isTriggerDestination {
                parameterSlider(label: "Mod Amt", value: $output.modulationAmount, range: 0...1, format: "%.0f%%") { $0 * 100 }
            }

            // Euclidean section (visible when mode == .clock and destination is a trigger)
            if output.mode == .clock && output.destination.isTriggerDestination {
                Divider()
                    .background(ColorPalette.divider)

                // Euclidean enable toggle
                HStack {
                    Text("Euclidean")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textMuted)
                        .frame(width: 70, alignment: .leading)

                    Toggle("", isOn: $output.euclideanEnabled)
                        .toggleStyle(.switch)
                        .tint(ClockOutputColors.brightColor(for: index))
                        .labelsHidden()
                }

                if output.euclideanEnabled {
                    // Steps stepper
                    HStack {
                        Text("Steps")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorPalette.textMuted)
                            .frame(width: 70, alignment: .leading)

                        Stepper(value: $output.euclideanSteps, in: 1...32) {
                            Text("\(output.euclideanSteps)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 30)
                        }
                    }

                    // Fills stepper
                    HStack {
                        Text("Fills")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorPalette.textMuted)
                            .frame(width: 70, alignment: .leading)

                        Stepper(value: $output.euclideanFills, in: 0...output.euclideanSteps) {
                            Text("\(output.euclideanFills)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 30)
                        }
                    }

                    // Rotation stepper
                    HStack {
                        Text("Rotate")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorPalette.textMuted)
                            .frame(width: 70, alignment: .leading)

                        Stepper(value: $output.euclideanRotation, in: 0...max(0, output.euclideanSteps - 1)) {
                            Text("\(output.euclideanRotation)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 30)
                        }
                    }

                    // Horizontal bar pattern visualization
                    EuclideanPatternView(
                        pattern: output.euclideanPattern,
                        steps: output.euclideanSteps,
                        fills: output.euclideanFills,
                        currentStep: output.euclideanCurrentStep,
                        accentColor: ClockOutputColors.brightColor(for: index)
                    )
                    .frame(height: 28)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(ColorPalette.backgroundSecondary)
        .environment(\.colorScheme, .dark)
    }

    private func parameterSlider(
        label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        format: String = "%.2f",
        displayTransform: ((Float) -> Float)? = nil
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textMuted)
                .frame(width: 70, alignment: .leading)

            Slider(value: value, in: range)
                .tint(ColorPalette.accentLooper1)
                .frame(width: 120)

            let displayValue = displayTransform?(value.wrappedValue) ?? value.wrappedValue
            Text(String(format: format, displayValue))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textPanelLabel)
                .frame(width: 45, alignment: .trailing)
        }
    }
}

// MARK: - Euclidean Pattern Visualization

/// Horizontal bar visualization of a euclidean rhythm pattern.
/// Each step is a discrete segment: active steps are filled, inactive are dim outlines.
/// The current playback step is highlighted with a bright border.
struct EuclideanPatternView: View {
    let pattern: [Bool]
    let steps: Int
    let fills: Int
    let currentStep: Int
    let accentColor: Color

    var body: some View {
        GeometryReader { geo in
            let totalSteps = max(1, steps)
            let gap: CGFloat = 1.5
            let totalGaps = gap * CGFloat(totalSteps - 1)
            let segWidth = max(2, (geo.size.width - totalGaps) / CGFloat(totalSteps))
            let height = geo.size.height

            HStack(spacing: gap) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    let isActive = step < pattern.count && pattern[step]
                    let isCurrent = step == currentStep

                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActive ? accentColor : accentColor.opacity(0.12))
                        .frame(width: segWidth, height: height)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(
                                    isCurrent ? Color.white : Color.clear,
                                    lineWidth: isCurrent ? 1.5 : 0
                                )
                        )
                        .brightness(isCurrent && isActive ? 0.2 : 0)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MasterClockView()
        .environmentObject(MasterClock())
        .frame(width: 400)
        .padding()
        .background(ColorPalette.backgroundPrimary)
}

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
    @EnvironmentObject var sequencer: MetropolixSequencer

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

    // MARK: - Output Grid (4x2)

    private var outputGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(0..<8) { index in
                CompactClockOutputCell(output: masterClock.outputs[index], index: index)
            }
        }
    }
}

// MARK: - Compact Clock Output Cell (Square)

struct CompactClockOutputCell: View {
    @ObservedObject var output: ClockOutput
    let index: Int

    @State private var showingConfig = false

    private var levelColor: Color {
        if output.muted {
            return ColorPalette.borderHighlight
        }
        let value = abs(output.currentValue)
        if value > 0.8 {
            return ColorPalette.ledRed
        } else if value > 0.5 {
            return ColorPalette.ledAmber
        } else if value > 0.1 {
            return ColorPalette.ledGreen
        }
        return ColorPalette.ledGreen
    }

    var body: some View {
        VStack(spacing: 3) {
            // Top row: Index + Activity indicator
            HStack(spacing: 4) {
                // Index badge
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.textMuted)
                    .frame(width: 14, height: 14)
                    .background(ColorPalette.backgroundTertiary)
                    .cornerRadius(3)

                // Activity indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorPalette.backgroundSecondary)
                        .frame(width: 32, height: 32)

                    GeometryReader { geo in
                        let normalizedValue = (output.currentValue + 1) / 2
                        Rectangle()
                            .fill(levelColor)
                            .frame(height: geo.size.height * CGFloat(normalizedValue))
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 2))

                    // Mode overlay
                    Text(output.mode == .clock ? "CLK" : "LFO")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(width: 32, height: 32)
            }

            // Bottom row: Division + Mute
            HStack(spacing: 3) {
                // Division/Waveform
                Text(output.mode == .clock ? output.division.rawValue : output.waveform.rawValue)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textPanelLabel)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Mute button
                Button(action: { output.muted.toggle() }) {
                    Text("M")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(output.muted ? ColorPalette.ledRed : ColorPalette.textDimmed)
                        .frame(width: 16, height: 14)
                        .background(output.muted ? ColorPalette.ledRed.opacity(0.2) : Color.clear)
                        .cornerRadius(2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .frame(minWidth: 60, minHeight: 60)
        .background(ColorPalette.backgroundSecondary)
        .cornerRadius(6)
        .onTapGesture {
            showingConfig = true
        }
        .popover(isPresented: $showingConfig) {
            ClockOutputConfigView(output: output, index: index)
        }
    }
}

// MARK: - Clock Output Configuration Popover

struct ClockOutputConfigView: View {
    @ObservedObject var output: ClockOutput
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OUTPUT \(index + 1)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(ColorPalette.accentLooper1)

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
                .frame(width: 160)
            }

            // Mod Amount
            if output.destination != .none {
                parameterSlider(label: "Mod Amt", value: $output.modulationAmount, range: 0...1, format: "%.0f%%") { $0 * 100 }
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

// MARK: - Preview

#Preview {
    MasterClockView()
        .environmentObject(MasterClock())
        .frame(width: 400)
        .padding()
        .background(ColorPalette.backgroundPrimary)
}

//
//  MasterClockView.swift
//  Grainulator
//
//  Pam's Pro Workout-inspired master clock interface.
//  Compact display with 8 configurable clock/LFO outputs.
//

import SwiftUI

struct MasterClockView: View {
    @EnvironmentObject var masterClock: MasterClock

    var body: some View {
        VStack(spacing: 12) {
            header
            outputGrid
        }
        .padding(16)
        .background(Color(hex: "#0F0F11"))
        .cornerRadius(8)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Text("MASTER CLOCK")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#9B59B6"))

            // Play/Stop button
            Button(action: {
                masterClock.toggle()
            }) {
                Text(masterClock.isRunning ? "STOP" : "RUN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(masterClock.isRunning ? Color(hex: "#1A1A1D") : .white)
                    .frame(width: 54, height: 28)
                    .background(masterClock.isRunning ? Color(hex: "#2ECC71") : Color(hex: "#2A2A2D"))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)

            // BPM control
            HStack(spacing: 6) {
                Text("BPM")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#888888"))

                Slider(
                    value: Binding(
                        get: { masterClock.bpm },
                        set: { masterClock.bpm = $0 }
                    ),
                    in: 10...330,
                    step: 1
                )
                .tint(Color(hex: "#9B59B6"))
                .frame(width: 140)

                Text(String(format: "%.0f", masterClock.bpm))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#9B59B6"))
                    .frame(width: 40, alignment: .trailing)
            }

            // Swing control
            HStack(spacing: 6) {
                Text("SWG")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#888888"))

                Slider(
                    value: $masterClock.swing,
                    in: 0...1
                )
                .tint(Color(hex: "#9B59B6"))
                .frame(width: 60)

                Text(String(format: "%.0f%%", masterClock.swing * 100))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#AAAAAA"))
                    .frame(width: 32, alignment: .trailing)
            }

            Spacer()
        }
    }

    // MARK: - Output Grid

    private var outputGrid: some View {
        HStack(spacing: 8) {
            ForEach(0..<8) { index in
                ClockOutputCell(output: masterClock.outputs[index], index: index)
            }
        }
    }
}

// MARK: - Clock Output Cell

struct ClockOutputCell: View {
    @ObservedObject var output: ClockOutput
    let index: Int

    @State private var showingConfig = false

    private var levelColor: Color {
        if output.muted {
            return Color(hex: "#444444")
        }
        // Color based on current output value
        let value = abs(output.currentValue)
        if value > 0.8 {
            return Color(hex: "#E74C3C")
        } else if value > 0.5 {
            return Color(hex: "#F39C12")
        } else if value > 0.1 {
            return Color(hex: "#2ECC71")
        }
        return Color(hex: "#27AE60")
    }

    var body: some View {
        VStack(spacing: 4) {
            // Output number
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#888888"))

            // Activity indicator (shows current output value)
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "#1A1A1D"))
                    .frame(width: 40, height: 40)

                // Level meter
                GeometryReader { geo in
                    let normalizedValue = (output.currentValue + 1) / 2 // Convert -1..1 to 0..1
                    Rectangle()
                        .fill(levelColor)
                        .frame(height: geo.size.height * CGFloat(normalizedValue))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 2))

                // Mode indicator overlay
                Text(output.mode == .clock ? "CLK" : "LFO")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 40, height: 40)
            .onTapGesture {
                showingConfig = true
            }

            // Division/Waveform label with slow indicator
            HStack(spacing: 2) {
                Text(output.mode == .clock ? output.division.rawValue : output.waveform.rawValue)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#AAAAAA"))

                if output.mode == .lfo && output.slowMode {
                    Text("S")
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#9B59B6"))
                }
            }
            .frame(width: 40)
            .lineLimit(1)

            // Destination label
            Text(output.destination.rawValue)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(output.destination == .none ? Color(hex: "#555555") : Color(hex: "#9B59B6"))
                .frame(width: 40)
                .lineLimit(1)

            // Mute button
            Button(action: {
                output.muted.toggle()
            }) {
                Text("M")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(output.muted ? Color(hex: "#E74C3C") : Color(hex: "#555555"))
                    .frame(width: 20, height: 16)
                    .background(output.muted ? Color(hex: "#E74C3C").opacity(0.2) : Color.clear)
                    .cornerRadius(2)
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(Color(hex: "#1A1A1D"))
        .cornerRadius(6)
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
                .foregroundColor(Color(hex: "#9B59B6"))

            // Mode selector
            HStack {
                Text("Mode")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#888888"))
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
                    .foregroundColor(Color(hex: "#888888"))
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
                        .foregroundColor(Color(hex: "#888888"))
                        .frame(width: 70, alignment: .leading)

                    Picker("Waveform", selection: $output.waveform) {
                        ForEach(ClockWaveform.allCases) { wf in
                            Text(wf.rawValue).tag(wf)
                        }
                    }
                    .frame(width: 100)
                }

                // Slow/Fast toggle (applies /4 multiplier in slow mode)
                HStack {
                    Text("Speed")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#888888"))
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
                        .foregroundColor(Color(hex: "#666666"))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            Divider()
                .background(Color(hex: "#333333"))

            // Level
            parameterSlider(label: "Level", value: $output.level, range: 0...1)

            // Offset
            parameterSlider(label: "Offset", value: $output.offset, range: -1...1)

            // Phase
            parameterSlider(label: "Phase", value: $output.phase, range: 0...1, format: "%.0f\u{00B0}") { $0 * 360 }

            // Width/Skew
            parameterSlider(label: "Width", value: $output.width, range: 0...1, format: "%.0f%%") { $0 * 100 }

            Divider()
                .background(Color(hex: "#333333"))

            // Destination
            HStack {
                Text("Dest")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#888888"))
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
        .background(Color(hex: "#1A1A1D"))
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
                .foregroundColor(Color(hex: "#888888"))
                .frame(width: 70, alignment: .leading)

            Slider(value: value, in: range)
                .tint(Color(hex: "#9B59B6"))
                .frame(width: 120)

            let displayValue = displayTransform?(value.wrappedValue) ?? value.wrappedValue
            Text(String(format: format, displayValue))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#AAAAAA"))
                .frame(width: 45, alignment: .trailing)
        }
    }
}

// MARK: - Preview

#Preview {
    MasterClockView()
        .environmentObject(MasterClock())
        .frame(width: 600)
        .padding()
        .background(Color(hex: "#0A0A0B"))
}

//
//  DrumSequencerView.swift
//  Grainulator
//
//  Cherry Audio DTS-inspired 4-lane x 16-step drum trigger sequencer.
//  Steps are grouped in 4 sets of 4, each colored: red, orange, yellow, off-white.
//  Each button has dim (unlit) and bright (lit) states.
//

import SwiftUI

// MARK: - Step Group Colors

private struct StepColors {
    /// Group colors for steps 1-4, 5-8, 9-12, 13-16
    static let groupColors: [Color] = [
        Color(red: 0.85, green: 0.20, blue: 0.20),  // Red
        Color(red: 0.90, green: 0.55, blue: 0.15),  // Orange
        Color(red: 0.90, green: 0.80, blue: 0.20),  // Yellow
        Color(red: 0.90, green: 0.87, blue: 0.80),  // Off-white/cream
    ]

    /// Dim version of group colors (unlit state)
    static let groupColorsDim: [Color] = [
        Color(red: 0.25, green: 0.08, blue: 0.08),  // Dim red
        Color(red: 0.28, green: 0.16, blue: 0.06),  // Dim orange
        Color(red: 0.28, green: 0.24, blue: 0.06),  // Dim yellow
        Color(red: 0.25, green: 0.24, blue: 0.22),  // Dim off-white
    ]

    static func color(for stepIndex: Int, active: Bool) -> Color {
        let groupIndex = stepIndex / 4
        let clamped = min(groupIndex, 3)
        return active ? groupColors[clamped] : groupColorsDim[clamped]
    }
}

// MARK: - Per-Lane Parameter Labels

/// Parameter labels per drum lane: [harmonics, timbre, morph]
/// Matches DaisyDrumView engine labeling.
private struct DrumLaneLabels {
    static let labels: [[String]] = [
        ["TONE", "PNCH", "DCAY"],  // Analog Kick (engine 0)
        ["TONE", "FM",   "DCAY"],  // Synth Kick  (engine 1)
        ["TONE", "SNAP", "DCAY"],  // Analog Snare (engine 2)
        ["TONE", "NOIS", "DCAY"],  // Hi-Hat       (engine 4)
    ]

    static func harmonicsLabel(for lane: Int) -> String { labels[min(lane, 3)][0] }
    static func timbreLabel(for lane: Int) -> String { labels[min(lane, 3)][1] }
    static func morphLabel(for lane: Int) -> String { labels[min(lane, 3)][2] }
}

// MARK: - Drum Sequencer View

struct DrumSequencerView: View {
    @EnvironmentObject var drumSequencer: DrumSequencer
    @EnvironmentObject var masterClock: MasterClock

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            // Lane rows
            VStack(spacing: 4) {
                ForEach(drumSequencer.lanes.indices, id: \.self) { laneIndex in
                    DrumLaneRow(
                        lane: drumSequencer.lanes[laneIndex],
                        laneIndex: laneIndex,
                        currentStep: drumSequencer.currentStep,
                        isPlaying: drumSequencer.isPlaying,
                        loopStart: drumSequencer.loopStart,
                        loopEnd: drumSequencer.loopEnd,
                        quarterNotesPerBar: masterClock.quarterNotesPerBar,
                        onToggleStep: { stepIndex in
                            drumSequencer.toggleStep(lane: laneIndex, step: stepIndex)
                        },
                        onToggleMute: {
                            drumSequencer.toggleLaneMute(laneIndex)
                        },
                        onHarmonicsChanged: { value in
                            drumSequencer.setLaneHarmonics(laneIndex, value: value)
                        },
                        onTimbreChanged: { value in
                            drumSequencer.setLaneTimbre(laneIndex, value: value)
                        },
                        onMorphChanged: { value in
                            drumSequencer.setLaneMorph(laneIndex, value: value)
                        },
                        onLevelChanged: { value in
                            drumSequencer.setLaneLevel(laneIndex, value: value)
                        },
                        onNoteChanged: { note in
                            drumSequencer.setLaneNote(laneIndex, note: note)
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Spacer()
        }
        .background(ColorPalette.backgroundPrimary)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 16) {
            Text("DRUM SEQUENCER")
                .font(Typography.panelTitle)
                .foregroundColor(ColorPalette.accentDaisyDrum)

            Spacer()

            // Step counter
            HStack(spacing: 4) {
                Text("STEP")
                    .font(Typography.parameterLabel)
                    .foregroundColor(ColorPalette.textDimmed)
                Text("\(drumSequencer.currentStep + 1)")
                    .font(Typography.valueStandard)
                    .foregroundColor(ColorPalette.textPrimary)
                    .monospacedDigit()
                    .frame(minWidth: 20)
            }

            // BPM display
            HStack(spacing: 4) {
                Text("BPM")
                    .font(Typography.parameterLabel)
                    .foregroundColor(ColorPalette.textDimmed)
                Text(String(format: "%.0f", masterClock.bpm))
                    .font(Typography.valueStandard)
                    .foregroundColor(ColorPalette.accentDaisyDrum)
                    .monospacedDigit()
                    .frame(minWidth: 30)
            }

            // Sync toggle button
            Button(action: { drumSequencer.syncToTransport.toggle() }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(drumSequencer.syncToTransport ? ColorPalette.ledAmber : ColorPalette.ledOff)
                        .frame(width: 8, height: 8)
                        .shadow(color: drumSequencer.syncToTransport ? ColorPalette.ledAmberGlow.opacity(0.6) : .clear, radius: 3)
                    Text("SYNC")
                        .font(Typography.buttonSmall)
                        .foregroundColor(drumSequencer.syncToTransport ? ColorPalette.ledAmber : ColorPalette.textMuted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(drumSequencer.syncToTransport ? ColorPalette.ledAmber.opacity(0.1) : ColorPalette.backgroundTertiary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(drumSequencer.syncToTransport ? ColorPalette.ledAmber.opacity(0.3) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(drumSequencer.syncToTransport ? "Synced to master transport" : "Independent playback")

            // Play/Stop button
            Button(action: { drumSequencer.togglePlayback() }) {
                Image(systemName: drumSequencer.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundColor(drumSequencer.isPlaying ? ColorPalette.ledRed : ColorPalette.ledGreen)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.backgroundTertiary)
                    )
            }
            .buttonStyle(.plain)

            // Clear button
            Button(action: { drumSequencer.clearAll() }) {
                Text("CLR")
                    .font(Typography.buttonSmall)
                    .foregroundColor(ColorPalette.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.backgroundTertiary)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ColorPalette.backgroundSecondary)
        .overlay(
            Rectangle()
                .fill(ColorPalette.divider)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Drum Lane Row

struct DrumLaneRow: View {
    let lane: DrumLaneState
    let laneIndex: Int
    let currentStep: Int
    let isPlaying: Bool
    let loopStart: Int
    let loopEnd: Int
    let quarterNotesPerBar: Double
    let onToggleStep: (Int) -> Void
    let onToggleMute: () -> Void
    let onHarmonicsChanged: (Float) -> Void
    let onTimbreChanged: (Float) -> Void
    let onMorphChanged: (Float) -> Void
    let onLevelChanged: (Float) -> Void
    let onNoteChanged: (UInt8) -> Void

    @State private var harmonics: Float = 0.5
    @State private var timbre: Float = 0.5
    @State private var morph: Float = 0.5
    @State private var level: Float = 0.8
    @State private var noteValue: Float = 0.5  // 0-1 mapped to MIDI 24-96

    /// Map 0-1 slider value to MIDI note range 24-96
    private static func sliderToNote(_ v: Float) -> UInt8 {
        UInt8(max(24, min(96, 24 + Int(v * 72))))
    }
    /// Map MIDI note to 0-1 slider value
    private static func noteToSlider(_ n: UInt8) -> Float {
        Float(max(0, Int(n) - 24)) / 72.0
    }

    var body: some View {
        HStack(spacing: 8) {
            // Lane label + mute
            VStack(spacing: 4) {
                Text(lane.lane.shortName)
                    .font(Typography.channelLabel)
                    .foregroundColor(lane.isMuted ? ColorPalette.textDimmed : ColorPalette.accentDaisyDrum)

                Button(action: onToggleMute) {
                    Circle()
                        .fill(lane.isMuted ? ColorPalette.ledRed : ColorPalette.ledOff)
                        .frame(width: 12, height: 12)
                        .shadow(color: lane.isMuted ? ColorPalette.ledRedGlow.opacity(0.6) : .clear, radius: 3)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 44)

            // 16 step buttons in 4 groups of 4
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { groupIndex in
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { inGroupIndex in
                            let stepIndex = groupIndex * 4 + inGroupIndex
                            let outsideLoop = stepIndex > loopEnd || stepIndex < loopStart
                            StepButton(
                                isActive: lane.steps[stepIndex].isActive,
                                isPlayhead: isPlaying && currentStep == stepIndex,
                                isMuted: lane.isMuted,
                                color: StepColors.color(for: stepIndex, active: lane.steps[stepIndex].isActive),
                                action: { onToggleStep(stepIndex) },
                                dimmed: outsideLoop
                            )
                        }
                    }

                    // Divider between groups (except after last)
                    if groupIndex < 3 {
                        let nextStep = (groupIndex + 1) * 4
                        let isBarLine = isDrumBarBoundary(step: nextStep)
                        Rectangle()
                            .fill(isBarLine ? ColorPalette.lcdAmber.opacity(0.5) : ColorPalette.divider)
                            .frame(width: isBarLine ? 2 : 1)
                            .padding(.vertical, 4)
                    }
                }
            }

            // Divider between steps and params
            Rectangle()
                .fill(ColorPalette.divider)
                .frame(width: 1)
                .padding(.vertical, 6)

            // Per-lane parameter sliders with labels
            HStack(spacing: 4) {
                LaneMiniSlider(
                    value: $harmonics,
                    label: DrumLaneLabels.harmonicsLabel(for: laneIndex),
                    accentColor: ColorPalette.accentDaisyDrum
                )
                .onChange(of: harmonics) { onHarmonicsChanged($0) }

                LaneMiniSlider(
                    value: $timbre,
                    label: DrumLaneLabels.timbreLabel(for: laneIndex),
                    accentColor: ColorPalette.accentDaisyDrum
                )
                .onChange(of: timbre) { onTimbreChanged($0) }

                LaneMiniSlider(
                    value: $morph,
                    label: DrumLaneLabels.morphLabel(for: laneIndex),
                    accentColor: ColorPalette.accentDaisyDrum
                )
                .onChange(of: morph) { onMorphChanged($0) }

                LaneMiniSlider(
                    value: $level,
                    label: "LVL",
                    accentColor: ColorPalette.ledGreen
                )
                .onChange(of: level) { onLevelChanged($0) }

                LaneMiniSlider(
                    value: $noteValue,
                    label: "NOTE",
                    accentColor: ColorPalette.ledAmber,
                    displayFormat: .note
                )
                .onChange(of: noteValue) { onNoteChanged(Self.sliderToNote($0)) }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorPalette.backgroundSecondary)
        )
        .onAppear {
            harmonics = lane.harmonics
            timbre = lane.timbre
            morph = lane.morph
            level = lane.level
            noteValue = Self.noteToSlider(lane.note)
        }
    }

    /// Returns true if the given step falls on a bar boundary in the drum grid.
    /// Drum grid runs at x4 (16th notes), so bar boundary = quarterNotesPerBar * 4 steps.
    private func isDrumBarBoundary(step: Int) -> Bool {
        guard step > 0 else { return false }
        let stepsPerBar = quarterNotesPerBar * 4.0  // x4 = 16th notes
        guard stepsPerBar > 0 else { return false }
        let remainder = Double(step).truncatingRemainder(dividingBy: stepsPerBar)
        return remainder < 0.01
    }
}

// MARK: - Lane Mini Slider Display Format

enum MiniSliderDisplayFormat {
    case percentage  // 0-100
    case note        // MIDI note name (C3, D#4, etc.)
}

// MARK: - Lane Mini Slider

/// Compact vertical slider designed to fit inline within a drum lane row.
/// Juno-106 inspired, with a thin track and mini thumb.
struct LaneMiniSlider: View {
    @Binding var value: Float
    let label: String
    let accentColor: Color
    var displayFormat: MiniSliderDisplayFormat = .percentage

    private let sliderWidth: CGFloat = 10
    private let sliderHeight: CGFloat = 48

    @State private var isDragging = false
    @State private var dragStartValue: Float = 0

    /// Map 0-1 value to MIDI note name
    private var noteDisplayText: String {
        let midiNote = Int(max(24, min(96, 24 + value * 72)))
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteName = noteNames[midiNote % 12]
        let octave = (midiNote / 12) - 1
        return "\(noteName)\(octave)"
    }

    private var displayText: String {
        switch displayFormat {
        case .percentage:
            return String(format: "%d", Int(value * 100))
        case .note:
            return noteDisplayText
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            // Parameter label
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)
                .frame(height: 10)

            // Value readout
            Text(displayText)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(isDragging ? accentColor : ColorPalette.textMuted)
                .frame(width: 34, height: 12)

            // Vertical slider
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Track background
                    RoundedRectangle(cornerRadius: sliderWidth / 4)
                        .fill(ColorPalette.backgroundPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: sliderWidth / 4)
                                .stroke(ColorPalette.dividerSubtle, lineWidth: 0.5)
                        )

                    // Value fill
                    RoundedRectangle(cornerRadius: sliderWidth / 4)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.7), accentColor.opacity(0.3)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: geometry.size.height * CGFloat(value))

                    // Mini thumb
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
                        .frame(width: sliderWidth + 6, height: 8)
                        .shadow(color: Color.black.opacity(0.3), radius: 1, y: 1)
                        .offset(y: -geometry.size.height * CGFloat(value) + 4)
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
                            let isFineControl = NSEvent.modifierFlags.contains(.shift)
                            let sensitivity: Float = isFineControl ? 400.0 : 120.0
                            let delta = -Float(gesture.translation.height) / sensitivity
                            value = max(0, min(1, dragStartValue + delta))
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(width: sliderWidth, height: sliderHeight)
        }
        .frame(width: 34)
    }
}

// MARK: - Step Button

struct StepButton: View {
    let isActive: Bool
    let isPlayhead: Bool
    let isMuted: Bool
    let color: Color
    let action: () -> Void
    var dimmed: Bool = false

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 4)
                .fill(displayColor)
                .frame(width: 36, height: 52)
                .opacity(dimmed ? 0.4 : 1.0)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(borderColor, lineWidth: isPlayhead ? 2 : 0.5)
                )
                .shadow(
                    color: isActive ? color.opacity(0.4) : .clear,
                    radius: isActive ? 4 : 0
                )
                .scaleEffect(isHovering ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }

    private var displayColor: Color {
        if isMuted {
            return isActive ? color.opacity(0.3) : color.opacity(0.15)
        }
        return isHovering ? color.opacity(isActive ? 1.0 : 0.5) : color
    }

    private var borderColor: Color {
        if isPlayhead {
            return .white
        }
        return isActive ? color.opacity(0.6) : ColorPalette.dividerSubtle
    }
}

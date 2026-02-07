//
//  ChordSequencerView.swift
//  Grainulator
//
//  Chord progression track UI — clock-output-pad styled step grid
//  with popover editor for each step (matching ClockOutputPad pattern).
//

import SwiftUI

struct ChordSequencerView: View {
    @ObservedObject var chordSequencer: ChordSequencer
    @EnvironmentObject var sequencer: StepSequencer

    private let trackColor = ColorPalette.ledBlue

    var body: some View {
        VStack(spacing: 8) {
            chordTrackHeader
            presetRow
            chordStepGrid
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorPalette.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(ColorPalette.consoleBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Track Header

    private var chordTrackHeader: some View {
        HStack(spacing: 8) {
            Text("CHORDS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(trackColor)

            Button(action: { chordSequencer.isEnabled.toggle() }) {
                Text("M")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(!chordSequencer.isEnabled ? .white : ColorPalette.metalSteel)
                    .frame(width: 20, height: 18)
                    .background(!chordSequencer.isEnabled ? ColorPalette.ledRed : ColorPalette.backgroundTertiary)
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(SequencerClockDivision.allCases) { division in
                    Button(division.rawValue) { chordSequencer.division = division }
                }
            } label: {
                HStack(spacing: 2) {
                    Text(chordSequencer.division.rawValue)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(ColorPalette.textMuted)
                }
                .frame(width: 40, height: 18)
                .background(ColorPalette.backgroundTertiary)
                .cornerRadius(3)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { chordSequencer.clearAll() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10))
                    .foregroundColor(ColorPalette.textMuted)
                    .frame(width: 24, height: 18)
                    .background(ColorPalette.backgroundTertiary)
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)
            .help("Clear all chords")
        }
    }

    // MARK: - Preset Row

    private var presetRow: some View {
        HStack(spacing: 4) {
            Text("PRESETS")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)

            ForEach(ChordSequencer.presets) { preset in
                Button(action: { chordSequencer.loadPreset(preset) }) {
                    Text(preset.name)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(ColorPalette.backgroundTertiary)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Step Grid

    private var chordStepGrid: some View {
        HStack(spacing: 5) {
            ForEach(0..<8, id: \.self) { stepIndex in
                ChordStepPad(
                    chordSequencer: chordSequencer,
                    stepIndex: stepIndex,
                    isPlaying: sequencer.isPlaying,
                    rootNote: sequencer.rootNote,
                    trackColor: trackColor
                )
            }
        }
    }
}

// MARK: - Chord Step Pad (with Popover)

struct ChordStepPad: View {
    @ObservedObject var chordSequencer: ChordSequencer
    let stepIndex: Int
    let isPlaying: Bool
    let rootNote: Int
    let trackColor: Color

    @State private var showingConfig = false

    private var step: ChordStep { chordSequencer.steps[stepIndex] }
    private var isPlayhead: Bool { chordSequencer.playheadStep == stepIndex && isPlaying }
    private var isEmpty: Bool { step.isEmpty }
    private var isActive: Bool { !isEmpty && step.active && chordSequencer.isEnabled }

    var body: some View {
        Button(action: { showingConfig = true }) {
            VStack(spacing: 2) {
                // Step number
                Text("\(stepIndex + 1)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(secondaryTextColor)

                // Chord name
                Text(chordSequencer.chordDisplayName(for: step))
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // Resolved notes
                if let notes = chordSequencer.resolvedNoteNames(for: step, rootNote: rootNote) {
                    Text(notes.joined(separator: " "))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else {
                    Color.clear.frame(height: 10)
                }

                // Mute indicator
                if !step.active {
                    Text("MUTE")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.ledRed)
                } else {
                    Color.clear.frame(height: 9)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        isPlayhead && isActive ? trackColor.opacity(0.6) : Color.clear,
                        lineWidth: isPlayhead ? 1.5 : 0
                    )
            )
            .shadow(
                color: isPlayhead && isActive ? trackColor.opacity(0.4) : .clear,
                radius: isPlayhead && isActive ? 4 : 0
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingConfig) {
            ChordStepConfigView(
                chordSequencer: chordSequencer,
                stepIndex: stepIndex,
                rootNote: rootNote,
                trackColor: trackColor
            )
        }
    }

    // MARK: - Colors

    private var fillColor: Color {
        if isPlayhead && step.active && !isEmpty {
            return trackColor.opacity(0.3)
        }
        if !step.active { return Color(hex: "#1F1F22") }
        if isEmpty { return ColorPalette.backgroundTertiary.opacity(0.5) }
        return ColorPalette.backgroundTertiary
    }

    private var primaryTextColor: Color {
        if !step.active || isEmpty { return ColorPalette.textDimmed }
        return .white
    }

    private var secondaryTextColor: Color {
        if !step.active { return ColorPalette.textDimmed.opacity(0.5) }
        if isEmpty { return ColorPalette.textDimmed }
        if isPlayhead { return .white.opacity(0.7) }
        return ColorPalette.textMuted
    }
}

// MARK: - Chord Step Config Popover

struct ChordStepConfigView: View {
    @ObservedObject var chordSequencer: ChordSequencer
    let stepIndex: Int
    let rootNote: Int
    let trackColor: Color

    private var step: ChordStep { chordSequencer.steps[stepIndex] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("STEP \(stepIndex + 1)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(trackColor)
                Text(chordSequencer.chordDisplayName(for: step))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textPanelLabel)
                Spacer()
            }

            Divider()
                .background(ColorPalette.divider)

            // Scale degree selector
            VStack(alignment: .leading, spacing: 4) {
                Text("DEGREE")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textDimmed)

                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        ForEach(Array(ChordSequencer.allDegrees.prefix(6)), id: \.id) { deg in
                            degreeButton(deg)
                        }
                    }
                    HStack(spacing: 3) {
                        ForEach(Array(ChordSequencer.allDegrees.dropFirst(6)), id: \.id) { deg in
                            degreeButton(deg)
                        }
                    }
                }
            }

            // Chord quality selector
            VStack(alignment: .leading, spacing: 4) {
                Text("QUALITY")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textDimmed)

                VStack(spacing: 3) {
                    // Triads
                    HStack(spacing: 3) {
                        ForEach(Array(ChordSequencer.allQualities.prefix(7)), id: \.id) { qual in
                            qualityButton(qual)
                        }
                    }
                    // 7ths
                    HStack(spacing: 3) {
                        ForEach(Array(ChordSequencer.allQualities.dropFirst(7).prefix(5)), id: \.id) { qual in
                            qualityButton(qual)
                        }
                    }
                    // Extensions
                    HStack(spacing: 3) {
                        ForEach(Array(ChordSequencer.allQualities.dropFirst(12)), id: \.id) { qual in
                            qualityButton(qual)
                        }
                    }
                }
            }

            // Active/Clear
            HStack(spacing: 6) {
                Button(action: { chordSequencer.setStepActive(stepIndex, !step.active) }) {
                    Text(step.active ? "ACTIVE" : "MUTED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(step.active ? ColorPalette.ledGreen : ColorPalette.ledRed)
                        .frame(width: 56, height: 22)
                        .background(ColorPalette.backgroundTertiary)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Button(action: { chordSequencer.clearStep(stepIndex) }) {
                    Text("CLEAR")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.textMuted)
                        .frame(width: 50, height: 22)
                        .background(ColorPalette.backgroundTertiary)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            // Note preview
            if let notes = chordSequencer.resolvedNoteNames(for: step, rootNote: rootNote) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOTES")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                    HStack(spacing: 4) {
                        ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                            Text(note)
                                .font(.system(size: 12, weight: index == 0 ? .bold : .medium, design: .monospaced))
                                .foregroundColor(index == 0 ? trackColor : ColorPalette.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(index == 0 ? trackColor.opacity(0.15) : ColorPalette.backgroundTertiary)
                                )
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(ColorPalette.backgroundPrimary)
    }

    // MARK: - Buttons

    @ViewBuilder
    private func degreeButton(_ deg: ChordDegree) -> some View {
        let isActive = step.degreeId == deg.id
        Button(action: { chordSequencer.setDegree(stepIndex, deg.id) }) {
            Text(deg.label)
                .font(.system(size: 10, weight: isActive ? .bold : .medium, design: .monospaced))
                .foregroundColor(isActive ? .white : ColorPalette.textMuted)
                .frame(minWidth: 24, minHeight: 22)
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isActive ? trackColor : ColorPalette.backgroundTertiary)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func qualityButton(_ qual: ChordQuality) -> some View {
        let isActive = step.qualityId == qual.id
        Button(action: { chordSequencer.setQuality(stepIndex, qual.id) }) {
            Text(qual.suffix.isEmpty ? "Maj" : qual.suffix)
                .font(.system(size: 9, weight: isActive ? .bold : .medium, design: .monospaced))
                .foregroundColor(isActive ? .white : ColorPalette.textMuted)
                .frame(minWidth: 22, minHeight: 20)
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isActive ? trackColor : ColorPalette.backgroundTertiary)
                )
        }
        .buttonStyle(.plain)
    }
}

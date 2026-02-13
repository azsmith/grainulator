//
//  SequencerView.swift
//  Grainulator
//
//  Step sequencer interface.
//  Step pads with popover editors (matching ClockOutputPad pattern).
//

import SwiftUI

struct SequencerView: View {
    @EnvironmentObject var sequencer: StepSequencer
    @EnvironmentObject var chordSequencer: ChordSequencer
    @EnvironmentObject var gridManager: MonomeGridManager
    @EnvironmentObject var masterClock: MasterClock

    @EnvironmentObject var scrambleManager: ScrambleManager

    var body: some View {
        ConsoleModuleView(
            title: "SEQ",
            accentColor: ColorPalette.ledAmber
        ) {
            VStack(spacing: 10) {
                header

                // Chord sequencer track
                ChordSequencerView(chordSequencer: chordSequencer)

                ForEach(Array(sequencer.tracks.indices), id: \.self) { trackIndex in
                    trackSection(trackIndex: trackIndex)
                }

                // Scramble probabilistic sequencer
                ScrambleView()
            }
            .padding(12)
        }
        .environment(\.colorScheme, .dark)
        .onChange(of: gridManager.activeTrack) { _ in
            // Grid switched tracks — UI can respond (e.g. scroll to track)
        }
    }

    // MARK: - Compact Header (Single Line)

    private var header: some View {
        HStack(spacing: 10) {
            // Play/Stop button
            HStack(spacing: 4) {
                Image(systemName: sequencer.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 10))
                Text(sequencer.isPlaying ? "STOP" : "PLAY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundColor(sequencer.isPlaying ? ColorPalette.backgroundSecondary : .white)
            .frame(width: 60, height: 26)
            .background(sequencer.isPlaying ? ColorPalette.accentPlaits : ColorPalette.panelBackground)
            .cornerRadius(4)
            .contentShape(RoundedRectangle(cornerRadius: 4))
            .onTapGesture { [sequencer] in
                DispatchQueue.main.async {
                    sequencer.togglePlayback()
                }
            }

            // Reset button (icon only)
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ColorPalette.textSecondary)
                .frame(width: 26, height: 26)
                .background(ColorPalette.panelBackground)
                .cornerRadius(4)
                .contentShape(RoundedRectangle(cornerRadius: 4))
                .onTapGesture { [sequencer] in
                    DispatchQueue.main.async {
                        sequencer.reset()
                    }
                }
            .help("Reset")

            // Root note dropdown (compact)
            Menu {
                ForEach(Array(sequencer.rootNames.enumerated()), id: \.offset) { index, name in
                    Button(name) { sequencer.setRootNote(index) }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(sequencer.rootNames[min(max(sequencer.rootNote, 0), sequencer.rootNames.count - 1)])
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(ColorPalette.textMuted)
                }
                .frame(width: 44, height: 26)
                .background(ColorPalette.panelBackground)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            // Scale dropdown (compact) — greyed out when chord sequencer drives the scale
            Menu {
                ForEach(Array(sequencer.scaleOptions.enumerated()), id: \.offset) { index, scale in
                    Button(scale.name) { sequencer.setScaleIndex(index) }
                }
            } label: {
                HStack(spacing: 3) {
                    if isChordScaleActive {
                        Image(systemName: "link")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(ColorPalette.ledBlue)
                    }
                    Text(currentScaleName)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(isChordScaleActive ? ColorPalette.ledBlue : .white)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(ColorPalette.textMuted)
                }
                .frame(height: 26)
                .frame(minWidth: 80)
                .padding(.horizontal, 4)
                .background(ColorPalette.panelBackground)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            // Toggle chord-driven scale mode
            Button(action: {
                if isChordScaleActive {
                    sequencer.setScaleIndex(0)
                } else {
                    sequencer.setScaleIndex(StepSequencer.chordSequencerScaleIndex)
                }
            }) {
                Text("USE CHORDS")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(isChordScaleActive ? .white : ColorPalette.metalSteel)
                    .padding(.horizontal, 6)
                    .frame(height: 26)
                    .background(isChordScaleActive ? ColorPalette.ledBlue : ColorPalette.panelBackground)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help(isChordScaleActive ? "Using chord progression as scale — click to revert" : "Use chord progression to drive sequencer scale")

            Spacer()
        }
    }

    private var isChordScaleActive: Bool {
        sequencer.scaleIndex == StepSequencer.chordSequencerScaleIndex
    }

    private var currentScaleName: String {
        guard !sequencer.scaleOptions.isEmpty else { return "Major" }
        let index = min(max(sequencer.scaleIndex, 0), sequencer.scaleOptions.count - 1)
        return sequencer.scaleOptions[index].name
    }

    // MARK: - Track Section

    @ViewBuilder
    private func trackSection(trackIndex: Int) -> some View {
        let track = sequencer.tracks[trackIndex]
        let trackColor = trackIndex == 0 ? ColorPalette.accentGranular1 : ColorPalette.accentLooper1

        VStack(spacing: 8) {
            // Track header (compact single line)
            trackHeaderRow(trackIndex: trackIndex, track: track, trackColor: trackColor)

            // Step grid (click any step to open popover editor)
            HStack(spacing: 5) {
                ForEach(track.stages.indices, id: \.self) { stageIndex in
                    // Bar boundary marker (subtle vertical line at bar boundaries)
                    if stageIndex > 0 && isBarBoundary(stageIndex: stageIndex, division: track.division) {
                        Rectangle()
                            .fill(ColorPalette.lcdAmber.opacity(0.3))
                            .frame(width: 1)
                            .padding(.vertical, 4)
                    }
                    SequencerStepColumn(
                        sequencer: sequencer,
                        trackIndex: trackIndex,
                        stageIndex: stageIndex,
                        trackColor: trackColor
                    )
                }
            }
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

    // MARK: - Bar Boundary Helper

    /// Returns true if the given stage index falls on a bar boundary (for visual markers).
    /// Bar boundaries occur at every `quarterNotesPerBar / division.multiplier` steps.
    private func isBarBoundary(stageIndex: Int, division: SequencerClockDivision) -> Bool {
        let qnPerBar = masterClock.quarterNotesPerBar
        let stepsPerBar = qnPerBar * division.multiplier
        guard stepsPerBar > 0 else { return false }
        let remainder = Double(stageIndex).truncatingRemainder(dividingBy: stepsPerBar)
        return remainder < 0.01 // Floating point tolerance
    }

    // MARK: - Track Header Row

    @ViewBuilder
    private func trackHeaderRow(trackIndex: Int, track: SequencerTrack, trackColor: Color) -> some View {
        HStack(spacing: 8) {
            // Track name
            Text(track.name)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(trackColor)

            // Run toggle
            Button(action: { sequencer.setTrackRunning(trackIndex, !track.running) }) {
                Text("RUN")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(track.running ? ColorPalette.ledGreen : ColorPalette.textDimmed)
                    .frame(width: 30, height: 18)
                    .background(track.running ? ColorPalette.ledGreen.opacity(0.2) : ColorPalette.backgroundTertiary)
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)

            // Reset track
            Button(action: { sequencer.resetTrack(trackIndex) }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(ColorPalette.textMuted)
                    .frame(width: 20, height: 18)
                    .background(ColorPalette.backgroundTertiary)
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)
            .help("Reset track to start")

            // Output dropdown
            compactDropdown(
                label: track.output.rawValue,
                width: 60,
                accentColor: trackColor
            ) {
                ForEach(SequencerTrackOutput.allCases) { output in
                    Button(output.rawValue) { sequencer.setTrackOutput(trackIndex, output) }
                }
            }

            // Direction dropdown
            compactDropdown(label: track.direction.rawValue, width: 58) {
                ForEach(SequencerDirection.allCases) { direction in
                    Button(direction.rawValue) { sequencer.setTrackDirection(trackIndex, direction) }
                }
            }

            // Division dropdown
            compactDropdown(label: track.division.rawValue, width: 40) {
                ForEach(SequencerClockDivision.allCases) { division in
                    Button(division.rawValue) { sequencer.setTrackDivision(trackIndex, division) }
                }
            }

            // Octave
            compactStepper(
                label: "OCT",
                value: sequencer.trackOctaveOffset(trackIndex),
                range: -4...4,
                signed: true
            ) { sequencer.setTrackOctaveOffset(trackIndex, $0) }

            // Transpose
            compactStepper(
                label: "TR",
                value: track.transpose,
                range: -24...24,
                signed: true
            ) { sequencer.setTrackTranspose(trackIndex, $0) }

            // Velocity
            compactStepper(
                label: "VEL",
                value: track.velocity,
                range: 1...127
            ) { sequencer.setTrackVelocity(trackIndex, $0) }

            // Loop start
            compactStepper(
                label: "S",
                value: track.loopStart + 1,
                range: 1...8
            ) { sequencer.setTrackLoopStart(trackIndex, $0 - 1) }

            // Loop end
            compactStepper(
                label: "E",
                value: track.loopEnd + 1,
                range: 1...8
            ) { sequencer.setTrackLoopEnd(trackIndex, $0 - 1) }

            Spacer()

            // Reset track to defaults
            Button(action: { sequencer.resetTrackToDefaults(trackIndex) }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(ColorPalette.textMuted)
                    .frame(width: 24, height: 18)
                    .background(ColorPalette.backgroundTertiary)
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)
            .help("Reset track to defaults")

            // Random button
            Button(action: { sequencer.randomizeTrack(trackIndex) }) {
                Image(systemName: "dice")
                    .font(.system(size: 10))
                    .foregroundColor(ColorPalette.textMuted)
                    .frame(width: 24, height: 18)
                    .background(ColorPalette.backgroundTertiary)
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)
            .help("Randomize track")
        }
    }

    // (Step column and context panel moved to SequencerStepColumn / SequencerStepConfigView structs below)

    // MARK: - Helper Views

    @ViewBuilder
    private func compactDropdown<Content: View>(
        label: String,
        width: CGFloat,
        accentColor: Color = ColorPalette.textMuted,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Menu(content: content) {
            HStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(accentColor)
            }
            .frame(width: width, height: 18)
            .background(ColorPalette.backgroundTertiary)
            .cornerRadius(3)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func compactStepper(
        label: String,
        value: Int,
        range: ClosedRange<Int>,
        signed: Bool = false,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.metalSteel)

            Button(action: { if value > range.lowerBound { onChange(value - 1) } }) {
                Image(systemName: "minus")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(value > range.lowerBound ? ColorPalette.textMuted : ColorPalette.borderHighlight)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(value <= range.lowerBound)

            Text(signed ? "\(value >= 0 ? "+" : "")\(value)" : "\(value)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(ColorPalette.textPanelLabel)
                .frame(width: signed ? 26 : 20)

            Button(action: { if value < range.upperBound { onChange(value + 1) } }) {
                Image(systemName: "plus")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(value < range.upperBound ? ColorPalette.textMuted : ColorPalette.borderHighlight)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(value >= range.upperBound)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(ColorPalette.backgroundSecondary)
        .cornerRadius(3)
    }

    // (contextStepper and contextDropdown moved to SequencerStepConfigView)

}

// MARK: - Sequencer Step Column (with Popover)

struct SequencerStepColumn: View {
    @ObservedObject var sequencer: StepSequencer
    let trackIndex: Int
    let stageIndex: Int
    let trackColor: Color

    @State private var showingConfig = false

    private var track: SequencerTrack { sequencer.tracks[trackIndex] }
    private var stageData: SequencerStage { track.stages[stageIndex] }
    private var isPlayhead: Bool { sequencer.playheadStagePerTrack[trackIndex] == stageIndex && sequencer.isPlaying }

    var body: some View {
        VStack(spacing: 3) {
            // Vertical note slider
            StepVerticalSlider(
                value: Binding(
                    get: { Double(sequencer.tracks[trackIndex].stages[stageIndex].noteSlot) },
                    set: { sequencer.setStageNoteSlot(track: trackIndex, stage: stageIndex, value: Int($0.rounded())) }
                ),
                range: 0...8,
                color: trackColor
            )
            .frame(width: 14, height: 100)

            // Step button — opens config popover
            Button(action: { showingConfig = true }) {
                VStack(spacing: 2) {
                    Text("\(stageIndex + 1)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                    Text(sequencer.stageNoteText(track: trackIndex, stage: stageIndex))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                    Text(stageData.stepType.shortLabel)
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                }
                .foregroundColor(stageTextColor)
                .frame(width: 42, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isPlayhead ? ColorPalette.ledAmber : fillColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(showingConfig ? trackColor : Color.clear, lineWidth: 2)
                        )
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingConfig) {
                SequencerStepConfigView(
                    sequencer: sequencer,
                    trackIndex: trackIndex,
                    stageIndex: stageIndex,
                    trackColor: trackColor
                )
            }
        }
    }

    // MARK: - Colors

    private var fillColor: Color {
        switch stageData.stepType {
        case .play:
            return ColorPalette.backgroundTertiary
        case .tie:
            return Color(hex: "#2D2640")
        case .rest:
            return Color(hex: "#1F1F22")
        case .skip:
            return Color(hex: "#202326")
        case .elide:
            return Color(hex: "#1E2A2A")
        }
    }

    private var stageTextColor: Color {
        switch stageData.stepType {
        case .rest, .skip:
            return ColorPalette.textPanelLabel
        case .elide:
            return Color(hex: "#8EE0D2")
        case .tie:
            return Color(hex: "#D0B8FF")
        case .play:
            return .white
        }
    }
}

// MARK: - Step Config Popover

struct SequencerStepConfigView: View {
    @ObservedObject var sequencer: StepSequencer
    let trackIndex: Int
    let stageIndex: Int
    let trackColor: Color

    private var stage: SequencerStage { sequencer.tracks[trackIndex].stages[stageIndex] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("STEP \(stageIndex + 1)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(trackColor)
                Text(sequencer.stageNoteText(track: trackIndex, stage: stageIndex))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textPanelLabel)
                Spacer()
                Button(action: { sequencer.resetStageToDefaults(track: trackIndex, stage: stageIndex) }) {
                    Text("RESET")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(ColorPalette.backgroundTertiary)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .help("Reset step to defaults")
            }

            Divider()
                .background(ColorPalette.divider)

            // Step parameters
            VStack(spacing: 8) {
                // Row 1: Pulses + Ratchets
                HStack(spacing: 12) {
                    configStepper(label: "PULSES", value: stage.pulses, range: 1...8) {
                        sequencer.setStagePulses(track: trackIndex, stage: stageIndex, value: $0)
                    }
                    configStepper(label: "RATCHETS", value: stage.ratchets, range: 1...8) {
                        sequencer.setStageRatchets(track: trackIndex, stage: stageIndex, value: $0)
                    }
                }

                // Row 2: Gate + Step Type
                HStack(spacing: 12) {
                    configDropdown(label: "GATE", value: stage.gateMode.rawValue, width: 60) {
                        ForEach(SequencerGateMode.allCases) { mode in
                            Button(mode.rawValue) {
                                sequencer.setStageGateMode(track: trackIndex, stage: stageIndex, value: mode)
                            }
                        }
                    }
                    configDropdown(label: "TYPE", value: stage.stepType.rawValue, width: 60) {
                        ForEach(SequencerStepType.allCases) { stepType in
                            Button(stepType.rawValue) {
                                sequencer.setStageStepType(track: trackIndex, stage: stageIndex, value: stepType)
                            }
                        }
                    }
                }

                // Row 3: Octave + Probability
                HStack(spacing: 12) {
                    configStepper(
                        label: "OCTAVE",
                        value: stage.octave,
                        range: -4...4,
                        signed: true
                    ) {
                        sequencer.setStageOctave(track: trackIndex, stage: stageIndex, value: $0)
                    }

                    // Probability slider
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PROBABILITY")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorPalette.textDimmed)
                        HStack(spacing: 4) {
                            Slider(
                                value: Binding(
                                    get: { stage.probability },
                                    set: { sequencer.setStageProbability(track: trackIndex, stage: stageIndex, value: $0) }
                                ),
                                in: 0...1
                            )
                            .tint(ColorPalette.ledAmber)
                            .frame(width: 60)
                            Text("\(Int(stage.probability * 100))%")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(ColorPalette.textMuted)
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }

                // Row 4: Gate Length slider
                VStack(alignment: .leading, spacing: 2) {
                    Text("GATE LENGTH")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                    HStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { stage.gateLength },
                                set: { sequencer.setStageGateLength(track: trackIndex, stage: stageIndex, value: $0) }
                            ),
                            in: 0.01...1.0
                        )
                        .tint(ColorPalette.ledAmber)
                        Text("\(Int(stage.gateLength * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorPalette.textMuted)
                            .frame(width: 32, alignment: .trailing)
                    }
                }

                // Row 5: Slide toggle
                HStack {
                    Text("SLIDE")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { stage.slide },
                        set: { sequencer.setStageSlide(track: trackIndex, stage: stageIndex, value: $0) }
                    ))
                    .toggleStyle(.switch)
                    .scaleEffect(0.65)
                    .frame(width: 44)
                }

                Divider()
                    .background(ColorPalette.textDimmed.opacity(0.3))

                // Row 6: Accumulator section
                Text("ACCUMULATOR")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.textDimmed)

                HStack(spacing: 12) {
                    configStepper(label: "TRANSPOSE", value: stage.accumTranspose, range: -7...7, signed: true) {
                        sequencer.setStageAccumTranspose(track: trackIndex, stage: stageIndex, value: $0)
                    }
                    configStepper(label: "RANGE", value: stage.accumRange, range: 1...7) {
                        sequencer.setStageAccumRange(track: trackIndex, stage: stageIndex, value: $0)
                    }
                }

                HStack(spacing: 12) {
                    configDropdown(label: "TRIGGER", value: stage.accumTrigger.rawValue, width: 52) {
                        ForEach(AccumulatorTrigger.allCases) { trigger in
                            Button(trigger.rawValue) {
                                sequencer.setStageAccumTrigger(track: trackIndex, stage: stageIndex, value: trigger)
                            }
                        }
                    }
                    configDropdown(label: "MODE", value: stage.accumMode.rawValue, width: 52) {
                        ForEach(AccumulatorMode.allCases) { mode in
                            Button(mode.rawValue) {
                                sequencer.setStageAccumMode(track: trackIndex, stage: stageIndex, value: mode)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(ColorPalette.backgroundPrimary)
    }

    // MARK: - Config Stepper

    @ViewBuilder
    private func configStepper(
        label: String,
        value: Int,
        range: ClosedRange<Int>,
        signed: Bool = false,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)
            HStack(spacing: 4) {
                Button(action: { if value > range.lowerBound { onChange(value - 1) } }) {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(ColorPalette.textMuted)
                        .frame(width: 20, height: 20)
                        .background(ColorPalette.backgroundTertiary)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)

                Text(signed ? "\(value >= 0 ? "+" : "")\(value)" : "\(value)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.textSecondary)
                    .frame(width: 28)

                Button(action: { if value < range.upperBound { onChange(value + 1) } }) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(ColorPalette.textMuted)
                        .frame(width: 20, height: 20)
                        .background(ColorPalette.backgroundTertiary)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Config Dropdown

    @ViewBuilder
    private func configDropdown<Content: View>(
        label: String,
        value: String,
        width: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)
            Menu(content: content) {
                HStack(spacing: 3) {
                    Text(value)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7))
                        .foregroundColor(ColorPalette.textDimmed)
                }
                .frame(width: width, height: 22)
                .background(ColorPalette.backgroundTertiary)
                .cornerRadius(3)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Step Vertical Slider

struct StepVerticalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color

    private var normalizedValue: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return (value - range.lowerBound) / span
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: width / 2)
                    .fill(ColorPalette.backgroundTertiary)

                RoundedRectangle(cornerRadius: width / 2)
                    .fill(color.opacity(0.85))
                    .frame(height: max(4, height * normalizedValue))

                Circle()
                    .fill(color)
                    .frame(width: width + 2, height: width + 2)
                    .offset(y: -height * normalizedValue + (width / 2))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard height > 1 else { return }
                        let y = min(max(gesture.location.y, 0), height)
                        let normalized = 1.0 - (y / height)
                        let rawValue = range.lowerBound + Double(normalized) * (range.upperBound - range.lowerBound)
                        value = rawValue.rounded()
                    }
            )
        }
    }
}

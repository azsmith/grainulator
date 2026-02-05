//
//  SequencerView.swift
//  Grainulator
//
//  Metropolix-inspired sequencer interface.
//  Compact layout with context panel for step editing.
//

import SwiftUI

struct SequencerView: View {
    @EnvironmentObject var sequencer: MetropolixSequencer

    var body: some View {
        ConsoleModuleView(
            title: "SEQ",
            accentColor: ColorPalette.ledAmber
        ) {
            VStack(spacing: 10) {
                header

                ForEach(Array(sequencer.tracks.indices), id: \.self) { trackIndex in
                    trackSection(trackIndex: trackIndex)
                }
            }
            .padding(12)
        }
        .environment(\.colorScheme, .dark)
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

            // Scale dropdown (compact)
            Menu {
                ForEach(Array(sequencer.scaleOptions.enumerated()), id: \.offset) { index, scale in
                    Button(scale.name) { sequencer.setScaleIndex(index) }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(currentScaleName)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(ColorPalette.textMuted)
                }
                .frame(width: 80, height: 26)
                .background(ColorPalette.panelBackground)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            // Sequence octave (compact stepper-like)
            HStack(spacing: 2) {
                Text("OCT")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textDimmed)
                Button(action: { sequencer.setSequenceOctave(sequencer.sequenceOctave - 1) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(ColorPalette.textMuted)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(sequencer.sequenceOctave <= -2)

                Text("\(sequencer.sequenceOctave >= 0 ? "+" : "")\(sequencer.sequenceOctave)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.ledAmber)
                    .frame(width: 24)

                Button(action: { sequencer.setSequenceOctave(sequencer.sequenceOctave + 1) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(ColorPalette.textMuted)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(sequencer.sequenceOctave >= 2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(ColorPalette.backgroundSecondary)
            .cornerRadius(4)

            // BPM (draggable)
            DraggableBPMView(
                value: Binding(
                    get: { sequencer.tempoBPM },
                    set: { sequencer.setTempoBPM($0) }
                ),
                range: 40...240,
                accentColor: ColorPalette.ledAmber
            )

            Spacer()
        }
    }

    private var currentScaleName: String {
        guard !sequencer.scaleOptions.isEmpty else { return "Major" }
        let index = min(max(sequencer.scaleIndex, 0), sequencer.scaleOptions.count - 1)
        return sequencer.scaleOptions[index].name
    }

    private var controlLabelColor: Color {
        ColorPalette.metalChrome
    }

    // MARK: - Track Section

    @ViewBuilder
    private func trackSection(trackIndex: Int) -> some View {
        let track = sequencer.tracks[trackIndex]
        let selectedStage = min(
            max(sequencer.selectedStagePerTrack[trackIndex], 0),
            track.stages.count - 1
        )
        let stage = track.stages[selectedStage]
        let trackColor = trackIndex == 0 ? ColorPalette.accentGranular1 : ColorPalette.accentLooper1

        VStack(spacing: 8) {
            // Track header (compact single line)
            trackHeaderRow(trackIndex: trackIndex, track: track, trackColor: trackColor)

            // Main content: Steps + Context Panel
            HStack(spacing: 8) {
                // Step sliders and buttons (scrollable)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(track.stages.indices, id: \.self) { stageIndex in
                            stepColumn(
                                trackIndex: trackIndex,
                                stageIndex: stageIndex,
                                track: track,
                                selectedStage: selectedStage,
                                trackColor: trackColor
                            )
                        }
                    }
                }

                // Context panel for selected step
                stepContextPanel(
                    trackIndex: trackIndex,
                    selectedStage: selectedStage,
                    stage: stage,
                    trackColor: trackColor
                )
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

    // MARK: - Track Header Row

    @ViewBuilder
    private func trackHeaderRow(trackIndex: Int, track: SequencerTrack, trackColor: Color) -> some View {
        HStack(spacing: 8) {
            // Track name
            Text(track.name)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(trackColor)

            // Mute toggle
            Button(action: { sequencer.setTrackMuted(trackIndex, !track.muted) }) {
                Text("M")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(track.muted ? .white : ColorPalette.metalSteel)
                    .frame(width: 20, height: 18)
                    .background(track.muted ? ColorPalette.ledRed : ColorPalette.backgroundTertiary)
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)

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
            compactDropdown(label: track.direction.rawValue, width: 50) {
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
                range: -2...2,
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

            Spacer()

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

    // MARK: - Step Column (Slider + Button)

    @ViewBuilder
    private func stepColumn(
        trackIndex: Int,
        stageIndex: Int,
        track: SequencerTrack,
        selectedStage: Int,
        trackColor: Color
    ) -> some View {
        let stageData = track.stages[stageIndex]
        let isSelected = selectedStage == stageIndex
        let isPlayhead = sequencer.playheadStagePerTrack[trackIndex] == stageIndex && sequencer.isPlaying

        VStack(spacing: 3) {
            // Taller step slider
            StepVerticalSlider(
                value: Binding(
                    get: { Double(sequencer.tracks[trackIndex].stages[stageIndex].noteSlot) },
                    set: { sequencer.setStageNoteSlot(track: trackIndex, stage: stageIndex, value: Int($0.rounded())) }
                ),
                range: 0...8,
                color: trackColor
            )
            .frame(width: 14, height: 100)  // Taller slider

            // Step button
            Button(action: { sequencer.selectStage(trackIndex, stageIndex) }) {
                VStack(spacing: 2) {
                    Text("\(stageIndex + 1)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                    Text(sequencer.stageNoteText(track: trackIndex, stage: stageIndex))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                    Text(stageData.stepType.shortLabel)
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                }
                .foregroundColor(stageTextColor(for: stageData))
                .frame(width: 42, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isPlayhead ? ColorPalette.ledAmber : stageFillColor(for: stageData, isSelected: isSelected))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? trackColor : Color.clear, lineWidth: 2)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Step Context Panel

    @ViewBuilder
    private func stepContextPanel(
        trackIndex: Int,
        selectedStage: Int,
        stage: SequencerStage,
        trackColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("STEP \(selectedStage + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(trackColor)
                Text(sequencer.stageNoteText(track: trackIndex, stage: selectedStage))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textPanelLabel)
            }

            Divider()
                .background(ColorPalette.divider)

            // Step parameters in a compact grid
            VStack(spacing: 4) {
                // Row 1: Pulses + Ratchets
                HStack(spacing: 8) {
                    contextStepper(label: "PLS", value: stage.pulses, range: 1...8) {
                        sequencer.setStagePulses(track: trackIndex, stage: selectedStage, value: $0)
                    }
                    contextStepper(label: "RCH", value: stage.ratchets, range: 1...8) {
                        sequencer.setStageRatchets(track: trackIndex, stage: selectedStage, value: $0)
                    }
                }

                // Row 2: Gate + Step Type
                HStack(spacing: 8) {
                    contextDropdown(label: "GATE", value: stage.gateMode.rawValue, width: 50) {
                        ForEach(SequencerGateMode.allCases) { mode in
                            Button(mode.rawValue) {
                                sequencer.setStageGateMode(track: trackIndex, stage: selectedStage, value: mode)
                            }
                        }
                    }
                    contextDropdown(label: "TYPE", value: stage.stepType.rawValue, width: 50) {
                        ForEach(SequencerStepType.allCases) { stepType in
                            Button(stepType.rawValue) {
                                sequencer.setStageStepType(track: trackIndex, stage: selectedStage, value: stepType)
                            }
                        }
                    }
                }

                // Row 3: Octave + Probability
                HStack(spacing: 8) {
                    contextStepper(
                        label: "OCT",
                        value: stage.octave,
                        range: -2...2,
                        signed: true
                    ) {
                        sequencer.setStageOctave(track: trackIndex, stage: selectedStage, value: $0)
                    }

                    // Probability mini-slider
                    VStack(alignment: .leading, spacing: 1) {
                        Text("PROB")
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorPalette.textDimmed)
                        HStack(spacing: 2) {
                            Slider(
                                value: Binding(
                                    get: { stage.probability },
                                    set: { sequencer.setStageProbability(track: trackIndex, stage: selectedStage, value: $0) }
                                ),
                                in: 0...1
                            )
                            .tint(ColorPalette.ledAmber)
                            .frame(width: 40)
                            Text("\(Int(stage.probability * 100))%")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundColor(ColorPalette.textMuted)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }

                // Row 4: Slide toggle
                HStack {
                    Text("SLIDE")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { stage.slide },
                        set: { sequencer.setStageSlide(track: trackIndex, stage: selectedStage, value: $0) }
                    ))
                    .toggleStyle(.switch)
                    .scaleEffect(0.6)
                    .frame(width: 40)
                }
            }
        }
        .padding(8)
        .frame(width: 140)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(ColorPalette.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(trackColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

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

    @ViewBuilder
    private func contextStepper(
        label: String,
        value: Int,
        range: ClosedRange<Int>,
        signed: Bool = false,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)
            HStack(spacing: 2) {
                Button(action: { if value > range.lowerBound { onChange(value - 1) } }) {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(ColorPalette.textMuted)
                        .frame(width: 16, height: 16)
                        .background(ColorPalette.backgroundTertiary)
                        .cornerRadius(2)
                }
                .buttonStyle(.plain)

                Text(signed ? "\(value >= 0 ? "+" : "")\(value)" : "\(value)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.textSecondary)
                    .frame(width: 24)

                Button(action: { if value < range.upperBound { onChange(value + 1) } }) {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(ColorPalette.textMuted)
                        .frame(width: 16, height: 16)
                        .background(ColorPalette.backgroundTertiary)
                        .cornerRadius(2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func contextDropdown<Content: View>(
        label: String,
        value: String,
        width: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)
            Menu(content: content) {
                HStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 6))
                        .foregroundColor(ColorPalette.textDimmed)
                }
                .frame(width: width, height: 18)
                .background(ColorPalette.backgroundTertiary)
                .cornerRadius(3)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Style Helpers

    private func stageFillColor(for stage: SequencerStage, isSelected: Bool) -> Color {
        if isSelected {
            return ColorPalette.backgroundTertiary
        }

        switch stage.stepType {
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

    private func stageTextColor(for stage: SequencerStage) -> Color {
        switch stage.stepType {
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

//
//  SequencerView.swift
//  Grainulator
//
//  Metropolix-inspired sequencer interface.
//

import SwiftUI

struct SequencerView: View {
    @EnvironmentObject var sequencer: MetropolixSequencer

    var body: some View {
        VStack(spacing: 14) {
            header

            ForEach(Array(sequencer.tracks.indices), id: \.self) { trackIndex in
                trackSection(trackIndex: trackIndex)
            }
        }
        .padding(16)
        .background(Color(hex: "#0F0F11"))
        .cornerRadius(8)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 14) {
                    Text("SEQUENCER")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#F39C12"))

                    Button(action: {
                        sequencer.togglePlayback()
                    }) {
                        Text(sequencer.isPlaying ? "STOP" : "PLAY")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(sequencer.isPlaying ? Color(hex: "#1A1A1D") : .white)
                            .frame(width: 64, height: 28)
                            .background(sequencer.isPlaying ? Color(hex: "#FF6B6B") : Color(hex: "#2A2A2D"))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        sequencer.reset()
                    }) {
                        Text("RESET")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                            .frame(width: 64, height: 28)
                            .background(Color(hex: "#2A2A2D"))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        Text("BPM")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#888888"))
                        Slider(
                            value: Binding(
                                get: { sequencer.tempoBPM },
                                set: { sequencer.setTempoBPM($0) }
                            ),
                            in: 40...240,
                            step: 1
                        )
                            .tint(Color(hex: "#F39C12"))
                            .frame(width: 180)
                        Text(String(format: "%.0f", sequencer.tempoBPM))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#F39C12"))
                            .frame(width: 34, alignment: .trailing)
                    }

                    HStack(spacing: 6) {
                        Text("ALIGN")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#888888"))
                        Slider(
                            value: Binding(
                                get: { sequencer.interEngineCompensationMs },
                                set: { sequencer.setInterEngineCompensationMs($0) }
                            ),
                            in: -5.0...5.0,
                            step: 0.05
                        )
                            .tint(Color(hex: "#4A9EFF"))
                            .frame(width: 150)
                        Text(String(format: "%+.2fms", sequencer.interEngineCompensationMs))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#4A9EFF"))
                            .frame(width: 62, alignment: .trailing)
                    }

                    Spacer(minLength: 8)
                }
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROOT")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#777777"))
                    Menu {
                        ForEach(Array(sequencer.rootNames.enumerated()), id: \.offset) { index, name in
                            Button(name) { sequencer.setRootNote(index) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(sequencer.rootNames[min(max(sequencer.rootNote, 0), sequencer.rootNames.count - 1)])
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color(hex: "#888888"))
                        }
                        .frame(width: 74, height: 24)
                        .background(Color(hex: "#2A2A2D"))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("SCALE")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#777777"))
                    Menu {
                        ForEach(Array(sequencer.scaleOptions.enumerated()), id: \.offset) { index, scale in
                            Button(scale.name) { sequencer.setScaleIndex(index) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(currentScaleName)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color(hex: "#888888"))
                        }
                        .frame(width: 210, height: 24, alignment: .leading)
                        .padding(.horizontal, 8)
                        .background(Color(hex: "#2A2A2D"))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                Stepper(
                    "SEQ OCT \(sequencer.sequenceOctave >= 0 ? "+" : "")\(sequencer.sequenceOctave)",
                    value: Binding(
                        get: { sequencer.sequenceOctave },
                        set: { sequencer.setSequenceOctave($0) }
                    ),
                    in: -2...2
                )
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(controlLabelColor)
                .tint(controlLabelColor)
                .frame(width: 150, alignment: .leading)

                Spacer(minLength: 8)
            }
        }
    }

    private var currentScaleName: String {
        guard !sequencer.scaleOptions.isEmpty else { return "Major" }
        let index = min(max(sequencer.scaleIndex, 0), sequencer.scaleOptions.count - 1)
        return sequencer.scaleOptions[index].name
    }

    private var controlLabelColor: Color {
        Color(hex: "#C8C8D0")
    }

    @ViewBuilder
    private func trackSection(trackIndex: Int) -> some View {
        let track = sequencer.tracks[trackIndex]
        let selectedStage = min(
            max(sequencer.selectedStagePerTrack[trackIndex], 0),
            track.stages.count - 1
        )
        let stage = track.stages[selectedStage]

        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 10) {
                    Text(track.name)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(trackIndex == 0 ? Color(hex: "#4A9EFF") : Color(hex: "#9B59B6"))

                    Toggle(
                        isOn: Binding(
                            get: { track.muted },
                            set: { sequencer.setTrackMuted(trackIndex, $0) }
                        )
                    ) {
                        Text("MUTE")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#888888"))
                    }
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("OUTPUT")
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#777777"))

                        Menu {
                            ForEach(SequencerTrackOutput.allCases) { output in
                                Button(output.rawValue) {
                                    sequencer.setTrackOutput(trackIndex, output)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(track.output.rawValue)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(trackIndex == 0 ? Color(hex: "#4A9EFF") : Color(hex: "#9B59B6"))
                            }
                            .frame(width: 82, height: 20)
                            .background(Color(hex: "#2A2A2D"))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke((trackIndex == 0 ? Color(hex: "#4A9EFF") : Color(hex: "#9B59B6")).opacity(0.45), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 90)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ORDER")
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#777777"))

                        Menu {
                            ForEach(SequencerDirection.allCases) { direction in
                                Button(direction.rawValue) {
                                    sequencer.setTrackDirection(trackIndex, direction)
                                }
                            }
                        } label: {
                            menuButtonLabel(text: track.direction.rawValue, width: 68)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 74)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("DIV")
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#777777"))

                        Menu {
                            ForEach(SequencerClockDivision.allCases) { division in
                                Button(division.rawValue) {
                                    sequencer.setTrackDivision(trackIndex, division)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(track.division.rawValue)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(Color(hex: "#888888"))
                            }
                            .frame(width: 56, height: 20)
                            .background(Color(hex: "#2A2A2D"))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 64)

                    Stepper(
                        "TRNS \(track.transpose >= 0 ? "+" : "")\(track.transpose)",
                        value: Binding(
                            get: { track.transpose },
                            set: { sequencer.setTrackTranspose(trackIndex, $0) }
                        ),
                        in: -24...24
                    )
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(controlLabelColor)
                    .tint(controlLabelColor)
                    .frame(width: 140, alignment: .leading)

                    Stepper(
                        "TRK OCT \(sequencer.trackOctaveOffset(trackIndex) >= 0 ? "+" : "")\(sequencer.trackOctaveOffset(trackIndex))",
                        value: Binding(
                            get: { sequencer.trackOctaveOffset(trackIndex) },
                            set: { sequencer.setTrackOctaveOffset(trackIndex, $0) }
                        ),
                        in: -2...2
                    )
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(controlLabelColor)
                    .tint(controlLabelColor)
                    .frame(width: 130, alignment: .leading)

                    Stepper(
                        "VEL \(track.velocity)",
                        value: Binding(
                            get: { track.velocity },
                            set: { sequencer.setTrackVelocity(trackIndex, $0) }
                        ),
                        in: 1...127
                    )
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(controlLabelColor)
                    .tint(controlLabelColor)
                    .frame(width: 110, alignment: .leading)

                    Stepper(
                        "L START \(track.loopStart + 1)",
                        value: Binding(
                            get: { track.loopStart },
                            set: { sequencer.setTrackLoopStart(trackIndex, $0) }
                        ),
                        in: 0...(track.stages.count - 1)
                    )
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(controlLabelColor)
                    .tint(controlLabelColor)
                    .frame(width: 128, alignment: .leading)

                    Stepper(
                        "L END \(track.loopEnd + 1)",
                        value: Binding(
                            get: { track.loopEnd },
                            set: { sequencer.setTrackLoopEnd(trackIndex, $0) }
                        ),
                        in: 0...(track.stages.count - 1)
                    )
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(controlLabelColor)
                    .tint(controlLabelColor)
                    .frame(width: 118, alignment: .leading)

                    Spacer(minLength: 8)

                    Button(action: {
                        sequencer.randomizeTrack(trackIndex)
                    }) {
                        Text("RANDOM")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#DDDDDD"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#2A2A2D"))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 6) {
                    ForEach(track.stages.indices, id: \.self) { stageIndex in
                        let stageData = track.stages[stageIndex]
                        let isSelected = selectedStage == stageIndex
                        let isPlayhead = sequencer.playheadStagePerTrack[trackIndex] == stageIndex && sequencer.isPlaying

                        VStack(spacing: 4) {
                            StepVerticalSlider(
                                value: Binding(
                                    get: { Double(sequencer.tracks[trackIndex].stages[stageIndex].noteSlot) },
                                    set: { sequencer.setStageNoteSlot(track: trackIndex, stage: stageIndex, value: Int($0.rounded())) }
                                ),
                                range: 0...8,
                                color: Color(hex: "#4A9EFF")
                            )
                            .frame(width: 16, height: 62)

                            Button(action: {
                                sequencer.selectStage(trackIndex, stageIndex)
                            }) {
                                VStack(spacing: 3) {
                                    Text("\(stageIndex + 1)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    Text(sequencer.stageNoteText(track: trackIndex, stage: stageIndex))
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    Text(stageData.stepType.shortLabel)
                                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                                }
                                .foregroundColor(stageTextColor(for: stageData))
                                .frame(width: 54, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isPlayhead ? Color(hex: "#F39C12") : stageFillColor(for: stageData, isSelected: isSelected))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(isSelected ? Color(hex: "#4A9EFF") : Color.clear, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 14) {
                    Stepper(
                        "PULSES \(stage.pulses)",
                        value: Binding(
                            get: { stage.pulses },
                            set: { sequencer.setStagePulses(track: trackIndex, stage: selectedStage, value: $0) }
                        ),
                        in: 1...8
                    )
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(controlLabelColor)
                    .tint(controlLabelColor)
                    .frame(width: 110, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("GATE")
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#777777"))

                        Menu {
                            ForEach(SequencerGateMode.allCases) { mode in
                                Button(mode.rawValue) {
                                    sequencer.setStageGateMode(track: trackIndex, stage: selectedStage, value: mode)
                                }
                            }
                        } label: {
                            menuButtonLabel(text: stage.gateMode.rawValue, width: 76)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 82)

                    Stepper(
                        "RATCH \(stage.ratchets)",
                        value: Binding(
                            get: { stage.ratchets },
                            set: { sequencer.setStageRatchets(track: trackIndex, stage: selectedStage, value: $0) }
                        ),
                        in: 1...8
                    )
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(controlLabelColor)
                    .tint(controlLabelColor)
                    .frame(width: 108, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("STEP")
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#777777"))

                        Menu {
                            ForEach(SequencerStepType.allCases) { stepType in
                                Button(stepType.rawValue) {
                                    sequencer.setStageStepType(track: trackIndex, stage: selectedStage, value: stepType)
                                }
                            }
                        } label: {
                            menuButtonLabel(text: stage.stepType.rawValue, width: 80)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 86)

                    Stepper(
                        "OCT \(stage.octave >= 0 ? "+" : "")\(stage.octave)",
                        value: Binding(
                            get: { stage.octave },
                            set: { sequencer.setStageOctave(track: trackIndex, stage: selectedStage, value: $0) }
                        ),
                        in: -2...2
                    )
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(controlLabelColor)
                    .tint(controlLabelColor)
                    .frame(width: 104, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("PROB \(Int(stage.probability * 100))%")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#888888"))
                        Slider(value: Binding(
                            get: { stage.probability },
                            set: { sequencer.setStageProbability(track: trackIndex, stage: selectedStage, value: $0) }
                        ), in: 0...1)
                        .tint(Color(hex: "#F39C12"))
                        .frame(width: 110)
                    }

                    Toggle(
                        isOn: Binding(
                            get: { stage.slide },
                            set: { sequencer.setStageSlide(track: trackIndex, stage: selectedStage, value: $0) }
                        )
                    ) {
                        Text("SLIDE")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#888888"))
                    }
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)
                    .frame(width: 74)

                    Spacer(minLength: 8)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "#18181B"))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "#2C2C31"), lineWidth: 1)
                )
        )
    }

    private func stageFillColor(for stage: SequencerStage, isSelected: Bool) -> Color {
        if isSelected {
            return Color(hex: "#35353A")
        }

        switch stage.stepType {
        case .play:
            return Color(hex: "#252528")
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
            return Color(hex: "#AAAAAA")
        case .elide:
            return Color(hex: "#8EE0D2")
        case .tie:
            return Color(hex: "#D0B8FF")
        case .play:
            return .white
        }
    }

    private func menuButtonLabel(text: String, width: CGFloat) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Color(hex: "#888888"))
        }
        .frame(width: width, height: 20)
        .background(Color(hex: "#2A2A2D"))
        .cornerRadius(4)
    }
}

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
                    .fill(Color(hex: "#252528"))

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

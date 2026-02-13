//
//  ScrambleView.swift
//  Grainulator
//
//  Scramble probabilistic sequencer UI — horizontal 3-column layout (Gate | Note | Mod)
//  inspired by Mutable Instruments Marbles.
//

import SwiftUI

// MARK: - Scramble View

struct ScrambleView: View {
    @EnvironmentObject var scrambleManager: ScrambleManager
    @EnvironmentObject var masterClock: MasterClock

    private let accent = ColorPalette.accentScramble

    var body: some View {
        ConsoleModuleView(
            title: "SCRAMBLE",
            accentColor: accent
        ) {
            VStack(spacing: 0) {
                headerBar
                Rectangle().fill(ColorPalette.textMuted).frame(height: 1).padding(.vertical, 4)
                columnsSection
            }
            .padding(12)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 10) {
            // ON/OFF toggle
            Button {
                scrambleManager.enabled.toggle()
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(scrambleManager.enabled ? accent : ColorPalette.textMuted)
                        .frame(width: 8, height: 8)
                    Text(scrambleManager.enabled ? "RUN" : "STOP")
                        .font(Typography.buttonSmall)
                }
                .foregroundColor(scrambleManager.enabled ? .white : ColorPalette.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(scrambleManager.enabled ? accent.opacity(0.3) : ColorPalette.panelBackground)
                )
            }
            .buttonStyle(.plain)

            // Clock division picker
            Menu {
                ForEach(SequencerClockDivision.allCases) { div in
                    Button(div.rawValue) {
                        scrambleManager.division = div
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "metronome")
                        .font(.system(size: 10))
                    Text(scrambleManager.division.rawValue)
                        .font(Typography.buttonSmall)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
                .foregroundColor(accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(accent.opacity(0.4), lineWidth: 1)
                )
            }
            .menuIndicator(.hidden)

            Spacer()

            // Reset button
            Button {
                scrambleManager.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(ColorPalette.panelBackground)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help("Reset Scramble")
        }
        .padding(.bottom, 8)
    }

    // MARK: - Columns Section

    private var columnsSection: some View {
        HStack(alignment: .top, spacing: 16) {
            gateColumn
            verticalDivider
            noteColumn
            verticalDivider
            modColumn
        }
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(ColorPalette.textMuted)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .padding(.vertical, 8)
    }

    // MARK: - Gate Column

    private var gateColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("GATE GENERATOR")

            parameterRow("MODE") {
                menuPicker(scrambleManager.engine.gateSection.mode.displayName) {
                    ForEach(ScrambleEngine.GateMode.allCases) { mode in
                        Button(mode.displayName) {
                            scrambleManager.engine.gateSection.mode = mode
                        }
                    }
                }
            }

            sliderRow("BIAS", value: $scrambleManager.engine.gateSection.bias, range: 0...1)
            sliderRow("LENGTH", value: $scrambleManager.engine.gateSection.gateLength, range: 0...1)
            sliderRow("JITTER", value: $scrambleManager.engine.gateSection.jitter, range: 0...1)

            dejaVuControls(
                state: $scrambleManager.engine.gateSection.dejaVu,
                amount: $scrambleManager.engine.gateSection.dejaVuAmount,
                loopLength: $scrambleManager.engine.gateSection.dejaVuLoopLength
            )

            dividerRow("DIVIDER", value: $scrambleManager.engine.gateSection.dividerRatio)

            sectionDivider

            sectionLabel("GATE OUTPUTS")

            triggerDestinationRow("GATE 1", destination: $scrambleManager.gate1Destination, active: scrambleManager.lastGateOutput.gate1)
            triggerDestinationRow("GATE 2", destination: $scrambleManager.gate2Destination, active: scrambleManager.lastGateOutput.gate2)
            triggerDestinationRow("GATE 3", destination: $scrambleManager.gate3Destination, active: scrambleManager.lastGateOutput.gate3)

            sectionDivider

            gatePatternViz
        }
        .frame(minWidth: 200)
    }

    // MARK: - Note Column

    private var noteColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("NOTE GENERATOR")

            parameterRow("CTRL") {
                menuPicker(scrambleManager.engine.noteSection.controlMode.rawValue) {
                    ForEach(ScrambleEngine.NoteControlMode.allCases) { mode in
                        Button(mode.rawValue) {
                            scrambleManager.engine.noteSection.controlMode = mode
                        }
                    }
                }
            }

            sliderRow("SPREAD", value: $scrambleManager.engine.noteSection.spread, range: 0...1)
            sliderRow("BIAS", value: $scrambleManager.engine.noteSection.bias, range: 0...1)
            smoothQuantizeRow(value: $scrambleManager.engine.noteSection.steps)

            parameterRow("RANGE") {
                menuPicker(scrambleManager.engine.noteSection.range.rawValue) {
                    ForEach(ScrambleEngine.NoteRange.allCases) { range in
                        Button(range.rawValue) {
                            scrambleManager.engine.noteSection.range = range
                        }
                    }
                }
            }

            dejaVuControls(
                state: $scrambleManager.engine.noteSection.dejaVu,
                amount: $scrambleManager.engine.noteSection.dejaVuAmount,
                loopLength: $scrambleManager.engine.noteSection.dejaVuLoopLength
            )

            dividerRow("DIVIDER", value: $scrambleManager.engine.noteSection.dividerRatio)

            sectionDivider

            sectionLabel("NOTE OUTPUTS")

            noteTargetRow("NOTE 1", destination: $scrambleManager.note1Destination, note: scrambleManager.lastNoteOutput.note1)
            noteTargetRow("NOTE 2", destination: $scrambleManager.note2Destination, note: scrambleManager.lastNoteOutput.note2)
            noteTargetRow("NOTE 3", destination: $scrambleManager.note3Destination, note: scrambleManager.lastNoteOutput.note3)

            sectionDivider

            noteValuesViz
        }
        .frame(minWidth: 200)
    }

    // MARK: - Mod Column

    private var modColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("MOD GENERATOR")

            sliderRow("SPREAD", value: $scrambleManager.engine.modSection.spread, range: 0...1)
            sliderRow("BIAS", value: $scrambleManager.engine.modSection.bias, range: 0...1)
            smoothQuantizeRow(value: $scrambleManager.engine.modSection.steps)

            dividerRow("DIVIDER", value: $scrambleManager.engine.modSection.dividerRatio)

            sectionDivider

            sectionLabel("MOD OUTPUT")

            cvDestinationRow("MOD", destination: $scrambleManager.modDestination)
            sliderRow("AMOUNT", value: $scrambleManager.modAmount, range: 0...1)

            sectionDivider

            modCVViz
        }
        .frame(minWidth: 200)
    }

    // MARK: - Reusable UI Components

    private var sectionDivider: some View {
        Rectangle().fill(ColorPalette.textMuted).frame(height: 1).padding(.vertical, 4)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.embossedLabel)
            .foregroundColor(accent)
            .tracking(1)
    }

    private func parameterRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Typography.parameterLabel)
                .foregroundColor(ColorPalette.textMuted)
                .frame(width: 54, alignment: .trailing)
            content()
        }
    }

    /// Menu picker with visible chevron and accent-colored label — hides system indicator
    private func menuPicker<Items: View>(_ currentValue: String, @ViewBuilder items: () -> Items) -> some View {
        Menu {
            items()
        } label: {
            HStack(spacing: 4) {
                Text(currentValue)
                    .font(Typography.valueSmall)
                    .foregroundColor(accent)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(accent)
            }
            .frame(minWidth: 80, alignment: .leading)
        }
        .menuIndicator(.hidden)
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Typography.parameterLabel)
                .foregroundColor(ColorPalette.textMuted)
                .frame(width: 54, alignment: .trailing)
            Slider(value: value, in: range)
                .tint(accent)
                .frame(maxWidth: 120)
            Text(String(format: "%.0f%%", value.wrappedValue * 100))
                .font(Typography.valueTiny)
                .foregroundColor(ColorPalette.textSecondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    /// Dual-mode slider: left = smooth (slew), center = bypass, right = quantize (snap to steps)
    private func smoothQuantizeRow(value: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            Text("S / Q")
                .font(Typography.parameterLabel)
                .foregroundColor(ColorPalette.textMuted)
                .frame(width: 54, alignment: .trailing)
            Slider(value: value, in: 0...1)
                .tint(accent)
                .frame(maxWidth: 120)
            Text(stepsDisplayLabel(value.wrappedValue))
                .font(Typography.valueTiny)
                .foregroundColor(ColorPalette.textSecondary)
                .frame(width: 42, alignment: .trailing)
        }
        .help("Left = Smooth (slew), Center = Off, Right = Quantize (snap)")
    }

    /// Display label for the smooth/quantize slider
    private func stepsDisplayLabel(_ value: Double) -> String {
        if value < 0.01 {
            return "OFF"
        } else if value < 0.45 {
            return "S \(Int(value / 0.45 * 100))%"
        } else if value > 0.55 {
            let t = (value - 0.55) / 0.45
            let levels = max(2, Int((t * 14.0 + 2.0).rounded()))
            return "Q \(levels)"
        } else {
            return "OFF"
        }
    }

    private func dividerRow(_ label: String, value: Binding<Int>) -> some View {
        parameterRow(label) {
            HStack(spacing: 6) {
                Text("\(value.wrappedValue)")
                    .font(Typography.valueSmall)
                    .foregroundColor(accent)
                    .frame(width: 20, alignment: .center)

                Button {
                    if value.wrappedValue > 1 {
                        value.wrappedValue -= 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ColorPalette.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(ColorPalette.panelBackground)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)

                Button {
                    if value.wrappedValue < 16 {
                        value.wrappedValue += 1
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ColorPalette.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(ColorPalette.panelBackground)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dejaVuControls(state: Binding<ScrambleEngine.DejaVuState>, amount: Binding<Double>, loopLength: Binding<Int>) -> some View {
        VStack(spacing: 4) {
            parameterRow("DEJA VU") {
                HStack(spacing: 4) {
                    ForEach(ScrambleEngine.DejaVuState.allCases) { dvState in
                        Button {
                            state.wrappedValue = dvState
                        } label: {
                            Text(dvState.rawValue.uppercased())
                                .font(Typography.buttonTiny)
                                .foregroundColor(state.wrappedValue == dvState ? .white : ColorPalette.textMuted)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(state.wrappedValue == dvState ? accent.opacity(0.5) : ColorPalette.panelBackground)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if state.wrappedValue != .off {
                sliderRow("DV AMT", value: amount, range: 0...1)
                dividerRow("LOOP", value: loopLength)
            }
        }
    }

    // MARK: - Routing Rows

    private func triggerDestinationRow(_ label: String, destination: Binding<ModulationDestination>, active: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? accent : ColorPalette.textMuted.opacity(0.4))
                .frame(width: 8, height: 8)

            Text(label)
                .font(Typography.channelLabel)
                .foregroundColor(active ? .white : ColorPalette.textMuted)
                .frame(width: 44, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundColor(ColorPalette.textMuted)

            triggerDestinationMenu(destination)
        }
    }

    private func triggerDestinationMenu(_ destination: Binding<ModulationDestination>) -> some View {
        Menu {
            ForEach(ModulationDestination.allCases.filter { $0.isTriggerDestination || $0 == .none }) { dest in
                Button(dest.displayName) {
                    destination.wrappedValue = dest
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(destination.wrappedValue.displayName)
                    .font(Typography.valueTiny)
                    .foregroundColor(accent)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(accent)
            }
            .frame(minWidth: 80, alignment: .leading)
        }
        .menuIndicator(.hidden)
    }

    private func noteTargetRow(_ label: String, destination: Binding<ScrambleNoteTarget>, note: UInt8) -> some View {
        HStack(spacing: 6) {
            Text(midiNoteName(Int(note)))
                .font(Typography.valueTiny)
                .foregroundColor(accent)
                .frame(width: 28, alignment: .center)

            Text(label)
                .font(Typography.channelLabel)
                .foregroundColor(ColorPalette.textMuted)
                .frame(width: 44, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundColor(ColorPalette.textMuted)

            Menu {
                ForEach(ScrambleNoteTarget.allCases) { target in
                    Button(target.rawValue) {
                        destination.wrappedValue = target
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(destination.wrappedValue.rawValue)
                        .font(Typography.valueTiny)
                        .foregroundColor(accent)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(accent)
                }
                .frame(minWidth: 80, alignment: .leading)
            }
            .menuIndicator(.hidden)
        }
    }

    private func cvDestinationRow(_ label: String, destination: Binding<ModulationDestination>) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(Typography.channelLabel)
                .foregroundColor(ColorPalette.textMuted)
                .frame(width: 32, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundColor(ColorPalette.textMuted)

            Menu {
                ForEach(ModulationDestination.allCases.filter { !$0.isTriggerDestination }) { dest in
                    Button(dest.displayName) {
                        destination.wrappedValue = dest
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(destination.wrappedValue.displayName)
                        .font(Typography.valueTiny)
                        .foregroundColor(accent)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(accent)
                }
                .frame(minWidth: 80, alignment: .leading)
            }
            .menuIndicator(.hidden)
        }
    }

    // MARK: - Visualization

    private var gatePatternViz: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PATTERN")
                .font(Typography.parameterLabelSmall)
                .foregroundColor(ColorPalette.textMuted)

            gatePatternRow("G1", keyPath: \.gate1)
            gatePatternRow("G2", keyPath: \.gate2)
            gatePatternRow("G3", keyPath: \.gate3)
        }
    }

    private func gatePatternRow(_ label: String, keyPath: KeyPath<ScrambleEngine.GateOutput, Bool>) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textMuted)
                .frame(width: 18, alignment: .leading)

            ForEach(0..<16, id: \.self) { i in
                let active = i < scrambleManager.gateHistory.count && scrambleManager.gateHistory[i][keyPath: keyPath]
                Circle()
                    .fill(active ? accent : ColorPalette.textMuted.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var noteValuesViz: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NOTES")
                .font(Typography.parameterLabelSmall)
                .foregroundColor(ColorPalette.textMuted)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<16, id: \.self) { i in
                    let note: UInt8 = i < scrambleManager.noteHistory.count ? scrambleManager.noteHistory[i] : 60
                    let height = max(4, CGFloat(note - 36) * 0.8)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < scrambleManager.noteHistory.count ? accent : ColorPalette.textMuted.opacity(0.3))
                        .frame(width: 8, height: height)
                }
            }
            .frame(height: 50, alignment: .bottom)
        }
    }

    private var modCVViz: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CV")
                .font(Typography.parameterLabelSmall)
                .foregroundColor(ColorPalette.textMuted)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<16, id: \.self) { i in
                    let value: Double = i < scrambleManager.modHistory.count ? scrambleManager.modHistory[i] : 0.5
                    let height = max(4, CGFloat(value) * 50)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < scrambleManager.modHistory.count ? accent : ColorPalette.textMuted.opacity(0.3))
                        .frame(width: 8, height: height)
                }
            }
            .frame(height: 50, alignment: .bottom)
        }
    }

    // MARK: - Helpers

    private func midiNoteName(_ note: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (note / 12) - 1
        let nameIndex = note % 12
        guard nameIndex >= 0, nameIndex < 12 else { return "--" }
        return "\(names[nameIndex])\(octave)"
    }
}

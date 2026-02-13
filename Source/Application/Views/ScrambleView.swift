//
//  ScrambleView.swift
//  Grainulator
//
//  Scramble probabilistic sequencer UI — horizontal 3-column layout (T | X | Y)
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
                Divider().background(ColorPalette.divider)
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
                        .fill(scrambleManager.enabled ? accent : ColorPalette.textDimmed)
                        .frame(width: 8, height: 8)
                    Text(scrambleManager.enabled ? "ON" : "OFF")
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
                        .font(.system(size: 9))
                    Text(scrambleManager.division.rawValue)
                        .font(Typography.buttonSmall)
                }
                .foregroundColor(accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(accent.opacity(0.4), lineWidth: 1)
                )
            }

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
            tColumn
            verticalDivider
            xColumn
            verticalDivider
            yColumn
        }
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(ColorPalette.divider)
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    // MARK: - T Column

    private var tColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("T GENERATOR")

            parameterRow("MODE") {
                Menu {
                    ForEach(ScrambleEngine.TMode.allCases) { mode in
                        Button(mode.rawValue) {
                            scrambleManager.engine.tSection.mode = mode
                        }
                    }
                } label: {
                    Text(scrambleManager.engine.tSection.mode.rawValue)
                        .font(Typography.valueSmall)
                        .foregroundColor(accent)
                        .frame(minWidth: 80, alignment: .leading)
                }
            }

            sliderRow("BIAS", value: $scrambleManager.engine.tSection.bias, range: 0...1)
            sliderRow("JITTER", value: $scrambleManager.engine.tSection.jitter, range: 0...1)

            dejaVuControls(
                state: $scrambleManager.engine.tSection.dejaVu,
                amount: $scrambleManager.engine.tSection.dejaVuAmount
            )

            Divider().background(ColorPalette.divider)

            sectionLabel("T OUTPUTS")

            triggerDestinationRow("T1", destination: $scrambleManager.t1Destination, active: scrambleManager.lastTOutput.t1)
            triggerDestinationRow("T2", destination: $scrambleManager.t2Destination, active: scrambleManager.lastTOutput.t2)
            triggerDestinationRow("T3", destination: $scrambleManager.t3Destination, active: scrambleManager.lastTOutput.t3)

            Divider().background(ColorPalette.divider)

            tPatternViz
        }
        .frame(minWidth: 200)
    }

    // MARK: - X Column

    private var xColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("X GENERATOR")

            parameterRow("CTRL") {
                Menu {
                    ForEach(ScrambleEngine.XControlMode.allCases) { mode in
                        Button(mode.rawValue) {
                            scrambleManager.engine.xSection.controlMode = mode
                        }
                    }
                } label: {
                    Text(scrambleManager.engine.xSection.controlMode.rawValue)
                        .font(Typography.valueSmall)
                        .foregroundColor(accent)
                        .frame(minWidth: 80, alignment: .leading)
                }
            }

            sliderRow("SPREAD", value: $scrambleManager.engine.xSection.spread, range: 0...1)
            sliderRow("BIAS", value: $scrambleManager.engine.xSection.bias, range: 0...1)
            sliderRow("STEPS", value: $scrambleManager.engine.xSection.steps, range: 0...1)

            parameterRow("RANGE") {
                Menu {
                    ForEach(ScrambleEngine.XRange.allCases) { range in
                        Button(range.rawValue) {
                            scrambleManager.engine.xSection.range = range
                        }
                    }
                } label: {
                    Text(scrambleManager.engine.xSection.range.rawValue)
                        .font(Typography.valueSmall)
                        .foregroundColor(accent)
                        .frame(minWidth: 80, alignment: .leading)
                }
            }

            parameterRow("CLK SRC") {
                Menu {
                    ForEach(ScrambleEngine.XClockSource.allCases) { src in
                        Button(src.rawValue) {
                            scrambleManager.engine.xSection.clockSource = src
                        }
                    }
                } label: {
                    Text(scrambleManager.engine.xSection.clockSource.rawValue)
                        .font(Typography.valueSmall)
                        .foregroundColor(accent)
                        .frame(minWidth: 80, alignment: .leading)
                }
            }

            dejaVuControls(
                state: $scrambleManager.engine.xSection.dejaVu,
                amount: $scrambleManager.engine.xSection.dejaVuAmount
            )

            Divider().background(ColorPalette.divider)

            sectionLabel("X OUTPUTS")

            noteTargetRow("X1", destination: $scrambleManager.x1Destination, note: scrambleManager.lastXOutput.x1)
            noteTargetRow("X2", destination: $scrambleManager.x2Destination, note: scrambleManager.lastXOutput.x2)
            noteTargetRow("X3", destination: $scrambleManager.x3Destination, note: scrambleManager.lastXOutput.x3)

            Divider().background(ColorPalette.divider)

            xNotesViz
        }
        .frame(minWidth: 200)
    }

    // MARK: - Y Column

    private var yColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Y GENERATOR")

            sliderRow("SPREAD", value: $scrambleManager.engine.ySection.spread, range: 0...1)
            sliderRow("BIAS", value: $scrambleManager.engine.ySection.bias, range: 0...1)
            sliderRow("STEPS", value: $scrambleManager.engine.ySection.steps, range: 0...1)

            parameterRow("DIVIDER") {
                Stepper(
                    value: $scrambleManager.engine.ySection.dividerRatio,
                    in: 1...16
                ) {
                    Text("\(scrambleManager.engine.ySection.dividerRatio)")
                        .font(Typography.valueSmall)
                        .foregroundColor(accent)
                }
            }

            Divider().background(ColorPalette.divider)

            sectionLabel("Y OUTPUT")

            cvDestinationRow("Y", destination: $scrambleManager.yDestination)
            sliderRow("AMOUNT", value: $scrambleManager.yAmount, range: 0...1)

            Divider().background(ColorPalette.divider)

            yCVViz
        }
        .frame(minWidth: 200)
    }

    // MARK: - Reusable UI Components

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
                .foregroundColor(ColorPalette.textDimmed)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func dejaVuControls(state: Binding<ScrambleEngine.DejaVuState>, amount: Binding<Double>) -> some View {
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
            }
        }
    }

    // MARK: - Routing Rows

    private func triggerDestinationRow(_ label: String, destination: Binding<ModulationDestination>, active: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? accent : ColorPalette.textDimmed.opacity(0.3))
                .frame(width: 8, height: 8)

            Text(label)
                .font(Typography.channelLabel)
                .foregroundColor(active ? .white : ColorPalette.textMuted)
                .frame(width: 20, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundColor(ColorPalette.textDimmed)

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
            Text(destination.wrappedValue.displayName)
                .font(Typography.valueTiny)
                .foregroundColor(accent)
                .lineLimit(1)
                .frame(minWidth: 80, alignment: .leading)
        }
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
                .frame(width: 20, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundColor(ColorPalette.textDimmed)

            Menu {
                ForEach(ScrambleNoteTarget.allCases) { target in
                    Button(target.rawValue) {
                        destination.wrappedValue = target
                    }
                }
            } label: {
                Text(destination.wrappedValue.rawValue)
                    .font(Typography.valueTiny)
                    .foregroundColor(accent)
                    .lineLimit(1)
                    .frame(minWidth: 80, alignment: .leading)
            }
        }
    }

    private func cvDestinationRow(_ label: String, destination: Binding<ModulationDestination>) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(Typography.channelLabel)
                .foregroundColor(ColorPalette.textMuted)
                .frame(width: 20, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundColor(ColorPalette.textDimmed)

            Menu {
                ForEach(ModulationDestination.allCases.filter { !$0.isTriggerDestination }) { dest in
                    Button(dest.displayName) {
                        destination.wrappedValue = dest
                    }
                }
            } label: {
                Text(destination.wrappedValue.displayName)
                    .font(Typography.valueTiny)
                    .foregroundColor(accent)
                    .lineLimit(1)
                    .frame(minWidth: 80, alignment: .leading)
            }
        }
    }

    // MARK: - Visualization

    private var tPatternViz: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PATTERN")
                .font(Typography.parameterLabelSmall)
                .foregroundColor(ColorPalette.textDimmed)

            HStack(spacing: 3) {
                ForEach(0..<16, id: \.self) { i in
                    let active = i < scrambleManager.tHistory.count && scrambleManager.tHistory[i].t1
                    Circle()
                        .fill(active ? accent : ColorPalette.textDimmed.opacity(0.2))
                        .frame(width: 10, height: 10)
                }
            }
        }
    }

    private var xNotesViz: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NOTES")
                .font(Typography.parameterLabelSmall)
                .foregroundColor(ColorPalette.textDimmed)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<16, id: \.self) { i in
                    let note: UInt8 = i < scrambleManager.xHistory.count ? scrambleManager.xHistory[i] : 60
                    let height = max(4, CGFloat(note - 36) * 0.8)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < scrambleManager.xHistory.count ? accent : ColorPalette.textDimmed.opacity(0.2))
                        .frame(width: 8, height: height)
                }
            }
            .frame(height: 50, alignment: .bottom)
        }
    }

    private var yCVViz: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CV")
                .font(Typography.parameterLabelSmall)
                .foregroundColor(ColorPalette.textDimmed)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<16, id: \.self) { i in
                    let value: Double = i < scrambleManager.yHistory.count ? scrambleManager.yHistory[i] : 0.5
                    let height = max(4, CGFloat(value) * 50)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < scrambleManager.yHistory.count ? accent : ColorPalette.textDimmed.opacity(0.2))
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

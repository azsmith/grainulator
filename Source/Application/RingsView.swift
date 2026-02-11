//
//  RingsView.swift
//  Grainulator
//
//  Mutable Rings-inspired resonator controls.
//  Minimoog-inspired knob-focused panel layout.
//

import SwiftUI

struct RingsView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    @State private var modelIndex: Int = 0
    @State private var structure: Float = 0.30
    @State private var brightness: Float = 0.40
    @State private var damping: Float = 0.39
    @State private var position: Float = 0.97
    @State private var level: Float = 0.8

    // Extended parameters
    @State private var polyphony: Int = 1        // 0=1voice, 1=2voice, 2=4voice
    @State private var chord: Int = 0            // 0-10
    @State private var fm: Float = 0.5           // 0-1 (0.5 = center = 0 semitones)
    @State private var exciterSource: Int = 0    // 0=internal, 1-7=channels

    // Modulation amounts (polled from audio engine)
    @State private var structureMod: Float = 0.0
    @State private var brightnessMod: Float = 0.0
    @State private var dampingMod: Float = 0.0
    @State private var positionMod: Float = 0.0

    let modulationTimer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()

    private let modelNames = [
        "Modal",
        "Sympathetic",
        "String",
        "FM Voice",
        "Symp Quant",
        "String+Rev"
    ]

    private let chordNames = [
        "Oct", "5th", "sus4", "min", "m7",
        "m9", "m11", "69", "M9", "M7", "Maj"
    ]

    private let exciterSourceNames = [
        "Internal", "Plaits", "Granular 1", "Looper 1",
        "Looper 2", "Granular 4", "Drums", "Sampler"
    ]

    // Maps UI exciter source index to engine channel index (-1=internal, then mixer ch indices)
    private let exciterSourceChannels = [-1, 0, 2, 3, 4, 5, 6, 11]

    private let polyphonyLabels = ["1", "2", "4"]

    var body: some View {
        SynthPanelView(
            title: "RINGS",
            accentColor: ColorPalette.accentRings,
            width: 280
        ) {
            VStack(spacing: 6) {
                // Model selector
                modelSelector

                // Polyphony selector
                polyphonySelector
                    .padding(.horizontal, 16)

                // Chord + Exciter source selectors
                HStack(spacing: 8) {
                    chordSelector
                    exciterSourceSelector
                }
                .padding(.horizontal, 16)

                SynthPanelSectionLabel("RESONATOR", accentColor: ColorPalette.accentRings)

                // Main parameter knobs: top row (Structure + Brightness)
                HStack(spacing: 16) {
                    ProKnobView(
                        value: $structure,
                        label: "STRUCT",
                        accentColor: ColorPalette.accentRings,
                        size: .large,
                        style: .minimoog,
                        modulationValue: structureMod > 0.001 ? structure + structureMod : nil
                    )
                    ProKnobView(
                        value: $brightness,
                        label: "BRIGHT",
                        accentColor: ColorPalette.accentRings,
                        size: .large,
                        style: .minimoog,
                        modulationValue: brightnessMod > 0.001 ? brightness + brightnessMod : nil
                    )
                }
                .padding(.horizontal, 12)

                // Bottom row (Damping + Position)
                HStack(spacing: 12) {
                    ProKnobView(
                        value: $damping,
                        label: "DAMPING",
                        accentColor: ColorPalette.accentRings,
                        size: .medium,
                        style: .minimoog,
                        modulationValue: dampingMod > 0.001 ? damping + dampingMod : nil
                    )
                    ProKnobView(
                        value: $position,
                        label: "POSITN",
                        accentColor: ColorPalette.accentRings,
                        size: .medium,
                        style: .minimoog,
                        modulationValue: positionMod > 0.001 ? position + positionMod : nil
                    )
                }
                .padding(.horizontal, 12)

                // Output row (FM + Level)
                HStack(spacing: 12) {
                    ProKnobView.bipolar(
                        value: $fm,
                        label: "FM",
                        accentColor: ColorPalette.accentRings,
                        size: .medium,
                        style: .minimoog
                    )
                    ProKnobView(
                        value: $level,
                        label: "LEVEL",
                        accentColor: ColorPalette.accentRings,
                        size: .medium,
                        style: .minimoog,
                        valueFormatter: { String(format: "%.0f%%", $0 * 100) }
                    )
                }
                .padding(.horizontal, 12)

                // Strike trigger button
                strikeButton
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
        }
        .onChange(of: structure) { audioEngine.setParameter(id: .ringsStructure, value: $0) }
        .onChange(of: brightness) { audioEngine.setParameter(id: .ringsBrightness, value: $0) }
        .onChange(of: damping) { audioEngine.setParameter(id: .ringsDamping, value: $0) }
        .onChange(of: position) { audioEngine.setParameter(id: .ringsPosition, value: $0) }
        .onChange(of: level) { audioEngine.setParameter(id: .ringsLevel, value: $0) }
        .onChange(of: polyphony) {
            let normalized: Float = [0.0, 0.5, 1.0][$0]
            audioEngine.setParameter(id: .ringsPolyphony, value: normalized)
        }
        .onChange(of: chord) {
            audioEngine.setParameter(id: .ringsChord, value: Float($0) / 10.0)
        }
        .onChange(of: fm) {
            // Bipolar -1..+1 → normalized 0..1
            audioEngine.setParameter(id: .ringsFM, value: ($0 + 1.0) / 2.0)
        }
        .onChange(of: exciterSource) {
            let channel = exciterSourceChannels[$0]
            let normalized: Float = channel < 0 ? 0.0 : (Float(channel) + 0.5) / 12.0
            audioEngine.setParameter(id: .ringsExciterSource, value: normalized)
        }
        .onReceive(modulationTimer) { _ in
            structureMod = audioEngine.getModulationValue(destination: .ringsStructure)
            brightnessMod = audioEngine.getModulationValue(destination: .ringsBrightness)
            dampingMod = audioEngine.getModulationValue(destination: .ringsDamping)
            positionMod = audioEngine.getModulationValue(destination: .ringsPosition)

            let rawModel = audioEngine.getParameter(id: .ringsModel)
            let engineIndex = Int(round(rawModel * Float(max(modelNames.count - 1, 1))))
            if engineIndex != modelIndex && engineIndex >= 0 && engineIndex < modelNames.count {
                modelIndex = engineIndex
            }
        }
        .onAppear {
            syncToEngine()
        }
    }

    // MARK: - Model Selector

    private var modelSelector: some View {
        Menu {
            ForEach(modelNames.indices, id: \.self) { index in
                Button(modelNames[index]) {
                    modelIndex = index
                    let normalized = Float(index) / Float(max(modelNames.count - 1, 1))
                    audioEngine.setParameter(id: .ringsModel, value: normalized)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(modelNames[modelIndex])
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.synthPanelLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(ColorPalette.accentRings)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(ColorPalette.synthPanelDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Polyphony Selector

    private var polyphonySelector: some View {
        HStack(spacing: 0) {
            ForEach(polyphonyLabels.indices, id: \.self) { index in
                Button {
                    polyphony = index
                } label: {
                    Text(polyphonyLabels[index])
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(polyphony == index ? ColorPalette.accentRings : ColorPalette.synthPanelLabel.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(polyphony == index ? ColorPalette.accentRings.opacity(0.2) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(ColorPalette.synthPanelDivider, lineWidth: 1)
        )
    }

    // MARK: - Chord Selector

    private var chordSelector: some View {
        Menu {
            ForEach(chordNames.indices, id: \.self) { index in
                Button(chordNames[index]) {
                    chord = index
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(chordNames[chord])
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.synthPanelLabel)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(ColorPalette.accentRings)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(ColorPalette.synthPanelDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exciter Source Selector

    private var exciterSourceSelector: some View {
        Menu {
            ForEach(exciterSourceNames.indices, id: \.self) { index in
                Button(exciterSourceNames[index]) {
                    exciterSource = index
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(exciterSourceNames[exciterSource])
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.synthPanelLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.down")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(ColorPalette.accentRings)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(ColorPalette.synthPanelDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Strike Button

    private var strikeButton: some View {
        Button(action: {
            DispatchQueue.main.async {
                audioEngine.noteOn(note: 48, velocity: 120)
            }
        }) {
            Text("STRIKE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(ColorPalette.synthPanelLabel)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(ColorPalette.synthPanelDivider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func syncToEngine() {
        audioEngine.setParameter(id: .ringsModel, value: Float(modelIndex) / Float(max(modelNames.count - 1, 1)))
        audioEngine.setParameter(id: .ringsStructure, value: structure)
        audioEngine.setParameter(id: .ringsBrightness, value: brightness)
        audioEngine.setParameter(id: .ringsDamping, value: damping)
        audioEngine.setParameter(id: .ringsPosition, value: position)
        audioEngine.setParameter(id: .ringsLevel, value: level)

        let polyNorm: Float = [0.0, 0.5, 1.0][polyphony]
        audioEngine.setParameter(id: .ringsPolyphony, value: polyNorm)
        audioEngine.setParameter(id: .ringsChord, value: Float(chord) / 10.0)
        audioEngine.setParameter(id: .ringsFM, value: (fm + 1.0) / 2.0)
        let channel = exciterSourceChannels[exciterSource]
        let exciterNorm: Float = channel < 0 ? 0.0 : (Float(channel) + 0.5) / 12.0
        audioEngine.setParameter(id: .ringsExciterSource, value: exciterNorm)
    }
}

// MARK: - Preview

#if DEBUG
struct RingsView_Previews: PreviewProvider {
    static var previews: some View {
        RingsView()
            .environmentObject(AudioEngineWrapper())
            .padding(20)
            .background(ColorPalette.backgroundPrimary)
    }
}
#endif

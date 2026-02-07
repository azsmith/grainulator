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
    @State private var structure: Float = 0.4
    @State private var brightness: Float = 0.7
    @State private var damping: Float = 0.8
    @State private var position: Float = 0.3
    @State private var level: Float = 0.8

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

    var body: some View {
        SynthPanelView(
            title: "RINGS",
            accentColor: ColorPalette.accentRings,
            width: 280
        ) {
            VStack(spacing: 6) {
                // Model selector
                modelSelector

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

                // Bottom row (Damping + Position + Level)
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

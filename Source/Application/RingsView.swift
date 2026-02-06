//
//  RingsView.swift
//  Grainulator
//
//  Mutable Rings-inspired resonator controls.
//  Vertical eurorack-style module (arranged horizontally with other modules).
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
        EurorackModuleView(
            title: "RINGS",
            accentColor: ColorPalette.accentRings,
            width: 180
        ) {
            VStack(spacing: 12) {
                // Model selector
                modelSelector

                ModuleSectionDivider("TIMBRE", accentColor: ColorPalette.accentRings)

                // Parameter sliders with LEDs
                parameterSliders

                ModuleSectionDivider(accentColor: ColorPalette.divider)

                // Strike trigger button
                ModuleTriggerButton(
                    label: "STRIKE",
                    isActive: false,
                    accentColor: ColorPalette.accentRings
                ) { [audioEngine] in
                    audioEngine.noteOn(note: 48, velocity: 120)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .onReceive(modulationTimer) { _ in
            // Poll modulation values from audio engine
            structureMod = audioEngine.getModulationValue(destination: .ringsStructure)
            brightnessMod = audioEngine.getModulationValue(destination: .ringsBrightness)
            dampingMod = audioEngine.getModulationValue(destination: .ringsDamping)
            positionMod = audioEngine.getModulationValue(destination: .ringsPosition)

            // Sync engine mode (may be changed externally via API)
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
                    .foregroundColor(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(ColorPalette.accentRings)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(ColorPalette.backgroundTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(ColorPalette.accentRings.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Parameter Sliders

    private var parameterSliders: some View {
        SliderBankView(
            parameters: [
                SliderParameter(
                    label: "STR",
                    value: $structure,
                    modulationAmount: structureMod,
                    accentColor: ColorPalette.accentRings
                ),
                SliderParameter(
                    label: "BRT",
                    value: $brightness,
                    modulationAmount: brightnessMod,
                    accentColor: ColorPalette.accentRings
                ),
                SliderParameter(
                    label: "DMP",
                    value: $damping,
                    modulationAmount: dampingMod,
                    accentColor: ColorPalette.accentRings
                ),
                SliderParameter(
                    label: "POS",
                    value: $position,
                    modulationAmount: positionMod,
                    accentColor: ColorPalette.accentRings
                ),
                SliderParameter(
                    label: "LVL",
                    value: $level,
                    accentColor: ColorPalette.accentRings
                )
            ],
            sliderHeight: 100,
            sliderWidth: 18
        )
        .onChange(of: structure) { audioEngine.setParameter(id: .ringsStructure, value: $0) }
        .onChange(of: brightness) { audioEngine.setParameter(id: .ringsBrightness, value: $0) }
        .onChange(of: damping) { audioEngine.setParameter(id: .ringsDamping, value: $0) }
        .onChange(of: position) { audioEngine.setParameter(id: .ringsPosition, value: $0) }
        .onChange(of: level) { audioEngine.setParameter(id: .ringsLevel, value: $0) }
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

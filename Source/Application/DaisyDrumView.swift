//
//  DaisyDrumView.swift
//  Grainulator
//
//  DaisyDrum percussion synthesizer UI component
//  Vertical eurorack-style module (arranged horizontally with other modules).
//

import SwiftUI

struct DaisyDrumView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    @State private var selectedEngine: Int = 0
    @State private var harmonics: Float = 0.5
    @State private var timbre: Float = 0.5
    @State private var morph: Float = 0.5
    @State private var level: Float = 0.8
    @State private var isTriggered: Bool = false

    // Modulation amounts (updated via timer)
    @State private var harmonicsMod: Float = 0.0
    @State private var timbreMod: Float = 0.0
    @State private var morphMod: Float = 0.0

    // Timer for polling modulation values
    let modulationTimer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()

    // Engine names (5 drum models)
    let engineNames = [
        "Analog Kick",       // 0
        "Synth Kick",        // 1
        "Analog Snare",      // 2
        "Synth Snare",       // 3
        "Hi-Hat"             // 4
    ]

    // Dynamic parameter labels per engine
    let parameterLabels: [[String]] = [
        ["TONE", "PNCH", "DCAY"],    // 0: Analog Kick
        ["TONE", "FM",   "DCAY"],    // 1: Synth Kick
        ["TONE", "SNAP", "DCAY"],    // 2: Analog Snare
        ["FM",   "SNAP", "DCAY"],    // 3: Synth Snare
        ["TONE", "NOIS", "DCAY"],    // 4: Hi-Hat
    ]

    var body: some View {
        EurorackModuleView(
            title: "DRUMS",
            accentColor: ColorPalette.accentDaisyDrum,
            width: 200
        ) {
            VStack(spacing: 10) {
                // Header: Engine selector
                headerSection

                ModuleSectionDivider("PERCUSSION", accentColor: ColorPalette.accentDaisyDrum)

                // Main parameter sliders (HARM, TIMBRE, MORPH, LEVEL)
                percussionSliders

                ModuleSectionDivider(accentColor: ColorPalette.divider)

                // Trigger button
                ModuleTriggerButton(
                    label: isTriggered ? "GATE ON" : "TRIGGER",
                    isActive: isTriggered,
                    accentColor: ColorPalette.accentDaisyDrum
                ) {
                    isTriggered.toggle()
                    audioEngine.triggerDaisyDrum(isTriggered)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .onReceive(modulationTimer) { _ in
            // Poll modulation values from audio engine
            harmonicsMod = audioEngine.getModulationValue(destination: .daisyDrumHarmonics)
            timbreMod = audioEngine.getModulationValue(destination: .daisyDrumTimbre)
            morphMod = audioEngine.getModulationValue(destination: .daisyDrumMorph)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 6) {
            // Engine selector
            Menu {
                ForEach(0..<engineNames.count, id: \.self) { index in
                    Button(action: {
                        selectedEngine = index
                        audioEngine.setParameter(id: .daisyDrumEngine, value: Float(index) / Float(engineNames.count - 1))
                    }) {
                        HStack {
                            Text(engineNames[index])
                            if selectedEngine == index {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(engineNames[selectedEngine])
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7))
                        .foregroundColor(ColorPalette.accentDaisyDrum)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorPalette.backgroundTertiary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(ColorPalette.accentDaisyDrum.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Percussion Sliders

    private var percussionSliders: some View {
        SliderBankView(
            parameters: [
                SliderParameter(
                    label: parameterLabels[selectedEngine][0],
                    value: $harmonics,
                    modulationAmount: harmonicsMod,
                    accentColor: ColorPalette.accentDaisyDrum
                ),
                SliderParameter(
                    label: parameterLabels[selectedEngine][1],
                    value: $timbre,
                    modulationAmount: timbreMod,
                    accentColor: ColorPalette.accentDaisyDrum
                ),
                SliderParameter(
                    label: parameterLabels[selectedEngine][2],
                    value: $morph,
                    modulationAmount: morphMod,
                    accentColor: ColorPalette.accentDaisyDrum
                ),
                SliderParameter(
                    label: "LVL",
                    value: $level,
                    accentColor: ColorPalette.accentDaisyDrum
                )
            ],
            sliderHeight: 80,
            sliderWidth: 20
        )
        .onChange(of: harmonics) { audioEngine.setParameter(id: .daisyDrumHarmonics, value: $0) }
        .onChange(of: timbre) { audioEngine.setParameter(id: .daisyDrumTimbre, value: $0) }
        .onChange(of: morph) { audioEngine.setParameter(id: .daisyDrumMorph, value: $0) }
        .onChange(of: level) { audioEngine.setParameter(id: .daisyDrumLevel, value: $0) }
    }
}

// MARK: - Preview

#if DEBUG
struct DaisyDrumView_Previews: PreviewProvider {
    static var previews: some View {
        DaisyDrumView()
            .environmentObject(AudioEngineWrapper())
            .padding(20)
            .background(ColorPalette.backgroundPrimary)
    }
}
#endif

//
//  DaisyDrumView.swift
//  Grainulator
//
//  DaisyDrum percussion synthesizer UI component
//  Minimoog-inspired knob-focused panel layout.
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

    // Dynamic parameter labels per engine (full names for knob labels)
    let parameterLabels: [[String]] = [
        ["TONE", "PUNCH", "DECAY"],    // 0: Analog Kick
        ["TONE", "FM",    "DECAY"],    // 1: Synth Kick
        ["TONE", "SNAP",  "DECAY"],    // 2: Analog Snare
        ["FM",   "SNAP",  "DECAY"],    // 3: Synth Snare
        ["TONE", "NOISE", "DECAY"],    // 4: Hi-Hat
    ]

    var body: some View {
        SynthPanelView(
            title: "DRUMS",
            accentColor: ColorPalette.accentDaisyDrum,
            width: 280
        ) {
            VStack(spacing: 6) {
                // Engine selector
                headerSection

                SynthPanelSectionLabel("PERCUSSION", accentColor: ColorPalette.accentDaisyDrum)

                // Main parameter knobs: 2x2 grid
                VStack(spacing: 4) {
                    HStack(spacing: 16) {
                        ProKnobView(
                            value: $harmonics,
                            label: parameterLabels[selectedEngine][0],
                            accentColor: ColorPalette.accentDaisyDrum,
                            size: .large,
                            style: .minimoog,
                            modulationValue: harmonicsMod > 0.001 ? harmonics + harmonicsMod : nil
                        )
                        ProKnobView(
                            value: $timbre,
                            label: parameterLabels[selectedEngine][1],
                            accentColor: ColorPalette.accentDaisyDrum,
                            size: .large,
                            style: .minimoog,
                            modulationValue: timbreMod > 0.001 ? timbre + timbreMod : nil
                        )
                    }

                    HStack(spacing: 16) {
                        ProKnobView(
                            value: $morph,
                            label: parameterLabels[selectedEngine][2],
                            accentColor: ColorPalette.accentDaisyDrum,
                            size: .large,
                            style: .minimoog,
                            modulationValue: morphMod > 0.001 ? morph + morphMod : nil
                        )
                        ProKnobView(
                            value: $level,
                            label: "LEVEL",
                            accentColor: ColorPalette.accentDaisyDrum,
                            size: .large,
                            style: .minimoog,
                            valueFormatter: { String(format: "%.0f%%", $0 * 100) }
                        )
                    }
                }
                .padding(.horizontal, 12)

                // Trigger button
                triggerButton
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
        }
        .onChange(of: harmonics) { audioEngine.setParameter(id: .daisyDrumHarmonics, value: $0) }
        .onChange(of: timbre) { audioEngine.setParameter(id: .daisyDrumTimbre, value: $0) }
        .onChange(of: morph) { audioEngine.setParameter(id: .daisyDrumMorph, value: $0) }
        .onChange(of: level) { audioEngine.setParameter(id: .daisyDrumLevel, value: $0) }
        .onReceive(modulationTimer) { _ in
            harmonicsMod = audioEngine.getModulationValue(destination: .daisyDrumHarmonics)
            timbreMod = audioEngine.getModulationValue(destination: .daisyDrumTimbre)
            morphMod = audioEngine.getModulationValue(destination: .daisyDrumMorph)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
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
            HStack(spacing: 6) {
                Text(engineNames[selectedEngine])
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.synthPanelLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(ColorPalette.accentDaisyDrum)
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

    // MARK: - Trigger Button

    private var triggerButton: some View {
        Button(action: {
            DispatchQueue.main.async {
                isTriggered.toggle()
                audioEngine.triggerDaisyDrum(isTriggered)
            }
        }) {
            Text(isTriggered ? "GATE ON" : "TRIGGER")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(isTriggered ? ColorPalette.synthPanelSurface : ColorPalette.synthPanelLabel)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isTriggered ? ColorPalette.accentDaisyDrum : Color.black.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isTriggered ? ColorPalette.accentDaisyDrum : ColorPalette.synthPanelDivider,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .shadow(color: isTriggered ? ColorPalette.accentDaisyDrum.opacity(0.4) : .clear, radius: 6)
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

//
//  PlaitsView.swift
//  Grainulator
//
//  Plaits synthesizer UI component
//  Vertical eurorack-style module (arranged horizontally with other modules).
//

import SwiftUI

struct PlaitsView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var midiManager: MIDIManager

    @State private var selectedEngine: Int = 0
    @State private var harmonics: Float = 0.5
    @State private var timbre: Float = 0.5
    @State private var morph: Float = 0.5
    @State private var level: Float = 0.8
    @State private var isTriggered: Bool = false

    // LPG parameters
    @State private var lpgColor: Float = 0.5
    @State private var lpgAttack: Float = 0.0
    @State private var lpgDecay: Float = 0.5
    @State private var lpgBypass: Bool = false

    // Modulation amounts (updated via timer)
    @State private var harmonicsMod: Float = 0.0
    @State private var timbreMod: Float = 0.0
    @State private var morphMod: Float = 0.0

    // Timer for polling modulation values
    let modulationTimer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()

    // Real Plaits engine names (16 models)
    let engineNames = [
        "Virtual Analog",    // 0: Two detuned oscillators
        "Waveshaper",        // 1: Triangle through waveshaper/folder
        "Two-Op FM",         // 2: Phase modulation + feedback
        "Granular Formant",  // 3: VOSIM/Pulsar synthesis
        "Harmonic",          // 4: Additive with 24 harmonics
        "Wavetable",         // 5: 4 banks of 8x8 wavetables
        "Chords",            // 6: Four-note chord generator
        "Speech",            // 7: Formant/SAM/LPC speech
        "Granular Cloud",    // 8: Swarm of enveloped grains
        "Filtered Noise",    // 9: Clocked noise + resonant filter
        "Particle Noise",    // 10: Dust through filters
        "String",            // 11: Karplus-Strong (TRIGGERED)
        "Modal",             // 12: Modal resonator (TRIGGERED)
        "Bass Drum",         // 13: Analog kick (TRIGGERED)
        "Snare Drum",        // 14: Analog snare (TRIGGERED)
        "Hi-Hat"             // 15: Analog hihat (TRIGGERED)
    ]

    // Dynamic parameter labels per engine
    let parameterLabels: [[String]] = [
        ["DETUNE", "PULSE", "SAW"],        // 0: Virtual Analog
        ["SHAPE", "FOLD", "ASYM"],         // 1: Waveshaper
        ["RATIO", "MOD", "FDBK"],          // 2: Two-Op FM
        ["FRMNT", "FREQ", "WDTH"],         // 3: Granular Formant
        ["BUMPS", "BRIT", "WDTH"],         // 4: Harmonic
        ["BANK", "ROW", "COL"],            // 5: Wavetable
        ["CHRD", "INV", "WAVE"],           // 6: Chords
        ["TYPE", "SPEC", "PHNM"],          // 7: Speech
        ["PTCH", "DENS", "DUR"],           // 8: Granular Cloud
        ["FILT", "CLK", "RES"],            // 9: Filtered Noise
        ["FREQ", "DENS", "FILT"],          // 10: Particle Noise
        ["IHRM", "BRIT", "DEC"],           // 11: String
        ["IHRM", "BRIT", "DEC"],           // 12: Modal
        ["PNCH", "DEC", "TONE"],           // 13: Bass Drum
        ["SNR", "TONE", "DEC"],            // 14: Snare Drum
        ["METL", "DEC", "DEC+"],           // 15: Hi-Hat
    ]

    // Whether engine uses LPG (engines 0-10) or has internal envelope (11-15)
    var usesLPG: Bool {
        selectedEngine < 11
    }

    var body: some View {
        EurorackModuleView(
            title: "PLAITS",
            accentColor: ColorPalette.accentPlaits,
            width: 220
        ) {
            VStack(spacing: 10) {
                // Header: Engine selector + MIDI indicator
                headerSection

                ModuleSectionDivider("OSCILLATOR", accentColor: ColorPalette.accentPlaits)

                // Main parameter sliders (HARM, TIMBRE, MORPH, LEVEL)
                oscillatorSliders

                ModuleSectionDivider("LPG", accentColor: usesLPG ? ColorPalette.accentPlaits : ColorPalette.textDimmed)

                // LPG section (dimmed for triggered engines)
                lpgSection
                    .opacity(usesLPG ? 1.0 : 0.4)

                ModuleSectionDivider(accentColor: ColorPalette.divider)

                // Trigger button
                ModuleTriggerButton(
                    label: isTriggered ? "GATE ON" : "TRIGGER",
                    isActive: isTriggered,
                    accentColor: ColorPalette.accentPlaits
                ) {
                    isTriggered.toggle()
                    audioEngine.triggerPlaits(isTriggered)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .onReceive(modulationTimer) { _ in
            // Poll modulation values from audio engine
            harmonicsMod = audioEngine.getModulationValue(destination: .plaitsHarmonics)
            timbreMod = audioEngine.getModulationValue(destination: .plaitsTimbre)
            morphMod = audioEngine.getModulationValue(destination: .plaitsMorph)
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
                        audioEngine.setParameter(id: .plaitsModel, value: Float(index) / Float(engineNames.count - 1))
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
                        .foregroundColor(ColorPalette.accentPlaits)
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
                        .stroke(ColorPalette.accentPlaits.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // MIDI indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(midiManager.isEnabled ? ColorPalette.ledGreen : ColorPalette.ledOff)
                    .frame(width: 6, height: 6)
                    .shadow(color: midiManager.isEnabled ? ColorPalette.ledGreenGlow.opacity(0.5) : .clear, radius: 3)

                if midiManager.lastNote > 0 {
                    Text(noteToName(Int(midiManager.lastNote)))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.accentPlaits)
                } else {
                    Text("MIDI")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                }
            }
        }
    }

    // MARK: - Oscillator Sliders

    private var oscillatorSliders: some View {
        SliderBankView(
            parameters: [
                SliderParameter(
                    label: parameterLabels[selectedEngine][0],
                    value: $harmonics,
                    modulationAmount: harmonicsMod,
                    accentColor: ColorPalette.accentPlaits
                ),
                SliderParameter(
                    label: parameterLabels[selectedEngine][1],
                    value: $timbre,
                    modulationAmount: timbreMod,
                    accentColor: ColorPalette.accentPlaits
                ),
                SliderParameter(
                    label: parameterLabels[selectedEngine][2],
                    value: $morph,
                    modulationAmount: morphMod,
                    accentColor: ColorPalette.accentPlaits
                ),
                SliderParameter(
                    label: "LVL",
                    value: $level,
                    accentColor: ColorPalette.accentPlaits
                )
            ],
            sliderHeight: 80,
            sliderWidth: 20
        )
        .onChange(of: harmonics) { audioEngine.setParameter(id: .plaitsHarmonics, value: $0) }
        .onChange(of: timbre) { audioEngine.setParameter(id: .plaitsTimbre, value: $0) }
        .onChange(of: morph) { audioEngine.setParameter(id: .plaitsMorph, value: $0) }
        .onChange(of: level) { audioEngine.setParameter(id: .plaitsLevel, value: $0) }
    }

    // MARK: - LPG Section

    private var lpgSection: some View {
        HStack(spacing: 8) {
            // LPG sliders
            SliderBankView(
                parameters: [
                    SliderParameter(
                        label: "ATK",
                        value: $lpgAttack,
                        accentColor: ColorPalette.accentLooper1
                    ),
                    SliderParameter(
                        label: "DEC",
                        value: $lpgDecay,
                        accentColor: ColorPalette.accentLooper1
                    ),
                    SliderParameter(
                        label: "LPG",
                        value: $lpgColor,
                        accentColor: ColorPalette.ledAmber
                    )
                ],
                sliderHeight: 60,
                sliderWidth: 18
            )
            .onChange(of: lpgAttack) { audioEngine.setParameter(id: .plaitsLPGAttack, value: $0) }
            .onChange(of: lpgDecay) { audioEngine.setParameter(id: .plaitsLPGDecay, value: $0) }
            .onChange(of: lpgColor) { audioEngine.setParameter(id: .plaitsLPGColor, value: $0) }

            Spacer()

            // Bypass toggle
            VStack(spacing: 4) {
                Button(action: {
                    lpgBypass.toggle()
                    audioEngine.setParameter(id: .plaitsLPGBypass, value: lpgBypass ? 1.0 : 0.0)
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(lpgBypass ? ColorPalette.ledAmber : ColorPalette.ledOff)
                            .frame(width: 24, height: 24)

                        if lpgBypass {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(ColorPalette.backgroundPrimary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .shadow(color: lpgBypass ? ColorPalette.ledAmberGlow.opacity(0.4) : .clear, radius: 4)

                Text("BYP")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundColor(lpgBypass ? ColorPalette.ledAmber : ColorPalette.textDimmed)
            }
        }
    }

    // MARK: - Helpers

    private func noteToName(_ midiNote: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midiNote / 12) - 1
        let noteName = noteNames[midiNote % 12]
        return "\(noteName)\(octave)"
    }
}

// MARK: - Preview

#if DEBUG
struct PlaitsView_Previews: PreviewProvider {
    static var previews: some View {
        PlaitsView()
            .environmentObject(AudioEngineWrapper())
            .environmentObject(MIDIManager())
            .padding(20)
            .background(ColorPalette.backgroundPrimary)
    }
}
#endif

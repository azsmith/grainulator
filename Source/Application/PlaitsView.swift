//
//  PlaitsView.swift
//  Grainulator
//
//  Plaits synthesizer UI component
//  Minimoog-inspired knob-focused panel layout.
//

import SwiftUI
import UniformTypeIdentifiers

struct PlaitsView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var midiManager: MIDIManager

    @State private var selectedEngine: Int = 3  // Granular Formant
    @State private var harmonics: Float = 0.35
    @State private var timbre: Float = 0.31
    @State private var morph: Float = 0.51
    @State private var level: Float = 0.8
    @State private var isTriggered: Bool = false

    // LPG parameters
    @State private var lpgColor: Float = 0.52
    @State private var lpgAttack: Float = 0.0
    @State private var lpgDecay: Float = 0.18
    @State private var lpgBypass: Bool = false

    // Modulation amounts (updated via timer)
    @State private var harmonicsMod: Float = 0.0
    @State private var timbreMod: Float = 0.0
    @State private var morphMod: Float = 0.0

    // Timer for polling modulation values
    let modulationTimer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()

    // Plaits engine names (17 models)
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
        "Hi-Hat",            // 15: Analog hihat (TRIGGERED)
        "Six-Op FM"          // 16: DX7-style 6-operator FM
    ]

    // Dynamic parameter labels per engine (full names for knob labels)
    let parameterLabels: [[String]] = [
        ["DETUNE", "PULSE", "SAW"],        // 0: Virtual Analog
        ["SHAPE", "FOLD", "ASYM"],         // 1: Waveshaper
        ["RATIO", "MOD", "FDBK"],          // 2: Two-Op FM
        ["FORMANT", "FREQ", "WIDTH"],      // 3: Granular Formant
        ["BUMPS", "BRIGHT", "WIDTH"],      // 4: Harmonic
        ["BANK", "ROW", "COLUMN"],         // 5: Wavetable
        ["CHORD", "INVERT", "WAVE"],       // 6: Chords
        ["TYPE", "SPECTR", "PHONEM"],      // 7: Speech
        ["PITCH", "DENSITY", "DURATN"],    // 8: Granular Cloud
        ["FILTER", "CLOCK", "RESON"],      // 9: Filtered Noise
        ["FREQ", "DENSITY", "FILTER"],     // 10: Particle Noise
        ["INHARM", "BRIGHT", "DECAY"],     // 11: String
        ["INHARM", "BRIGHT", "DECAY"],     // 12: Modal
        ["PUNCH", "DECAY", "TONE"],        // 13: Bass Drum
        ["SNARE", "TONE", "DECAY"],        // 14: Snare Drum
        ["METAL", "DECAY", "DECAY+"],      // 15: Hi-Hat
        ["ALGO", "DEPTH", "BALANCE"],      // 16: Six-Op FM
    ]

    // Whether engine uses LPG (engines 0-10 and 16) or has internal envelope (11-15)
    var usesLPG: Bool {
        selectedEngine < 11 || selectedEngine == 16
    }

    var body: some View {
        SynthPanelView(
            title: "PLAITS",
            accentColor: ColorPalette.accentPlaits,
            width: 300
        ) {
            VStack(spacing: 6) {
                // Engine selector + MIDI indicator
                headerSection

                SynthPanelSectionLabel("OSCILLATOR", accentColor: ColorPalette.accentPlaits)

                // Main parameter knobs: 2x2 grid
                oscillatorKnobs

                SynthPanelSectionLabel(
                    "LPG",
                    accentColor: usesLPG ? ColorPalette.synthPanelLabelDim : ColorPalette.textDimmed
                )

                // LPG knobs + bypass
                lpgSection
                    .opacity(usesLPG ? 1.0 : 0.35)

                // Load wavetable button (only shown for Wavetable engine)
                if selectedEngine == 5 {
                    loadWavetableButton
                        .padding(.horizontal, 16)
                }

                // Trigger button
                triggerButton
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            syncToEngine()
        }
        .onReceive(modulationTimer) { _ in
            // Poll modulation values from audio engine
            harmonicsMod = audioEngine.getModulationValue(destination: .plaitsHarmonics)
            timbreMod = audioEngine.getModulationValue(destination: .plaitsTimbre)
            morphMod = audioEngine.getModulationValue(destination: .plaitsMorph)

            // Sync engine mode (may be changed externally via API)
            let rawModel = audioEngine.getParameter(id: .plaitsModel)
            let engineIndex = Int(round(rawModel * Float(engineNames.count - 1)))
            if engineIndex != selectedEngine && engineIndex >= 0 && engineIndex < engineNames.count {
                selectedEngine = engineIndex
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 8) {
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
                HStack(spacing: 6) {
                    Text(engineNames[selectedEngine])
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.synthPanelLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(ColorPalette.accentPlaits)
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

            // MIDI indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(midiManager.isEnabled ? ColorPalette.ledGreen : ColorPalette.ledOff)
                    .frame(width: 6, height: 6)
                    .shadow(color: midiManager.isEnabled ? ColorPalette.ledGreenGlow.opacity(0.5) : .clear, radius: 3)

                if midiManager.lastNote > 0 {
                    Text(noteToName(Int(midiManager.lastNote)))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.accentPlaits)
                } else {
                    Text("MIDI")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Oscillator Knobs (2x2 grid)

    private var oscillatorKnobs: some View {
        VStack(spacing: 4) {
            // Top row: param1 + param2
            HStack(spacing: 16) {
                ProKnobView(
                    value: $harmonics,
                    label: parameterLabels[selectedEngine][0],
                    accentColor: ColorPalette.accentPlaits,
                    size: .large,
                    style: .minimoog,
                    modulationValue: harmonicsMod > 0.001 ? harmonics + harmonicsMod : nil
                )
                ProKnobView(
                    value: $timbre,
                    label: parameterLabels[selectedEngine][1],
                    accentColor: ColorPalette.accentPlaits,
                    size: .large,
                    style: .minimoog,
                    modulationValue: timbreMod > 0.001 ? timbre + timbreMod : nil
                )
            }

            // Bottom row: param3 + level
            HStack(spacing: 16) {
                ProKnobView(
                    value: $morph,
                    label: parameterLabels[selectedEngine][2],
                    accentColor: ColorPalette.accentPlaits,
                    size: .large,
                    style: .minimoog,
                    modulationValue: morphMod > 0.001 ? morph + morphMod : nil
                )
                ProKnobView(
                    value: $level,
                    label: "LEVEL",
                    accentColor: ColorPalette.accentPlaits,
                    size: .large,
                    style: .minimoog,
                    valueFormatter: { String(format: "%.0f%%", $0 * 100) }
                )
            }
        }
        .padding(.horizontal, 12)
        .onChange(of: harmonics) { audioEngine.setParameter(id: .plaitsHarmonics, value: $0) }
        .onChange(of: timbre) { audioEngine.setParameter(id: .plaitsTimbre, value: $0) }
        .onChange(of: morph) { audioEngine.setParameter(id: .plaitsMorph, value: $0) }
        .onChange(of: level) { audioEngine.setParameter(id: .plaitsLevel, value: $0) }
    }

    // MARK: - LPG Section

    private var lpgSection: some View {
        HStack(spacing: 12) {
            ProKnobView(
                value: $lpgAttack,
                label: "ATTACK",
                accentColor: ColorPalette.accentLooper1,
                size: .medium,
                style: .minimoog
            )
            ProKnobView(
                value: $lpgDecay,
                label: "DECAY",
                accentColor: ColorPalette.accentLooper1,
                size: .medium,
                style: .minimoog
            )
            ProKnobView(
                value: $lpgColor,
                label: "COLOR",
                accentColor: ColorPalette.ledAmber,
                size: .medium,
                style: .minimoog
            )

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
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(lpgBypass ? ColorPalette.ledAmber : ColorPalette.textDimmed)
                    .tracking(1)
            }
        }
        .padding(.horizontal, 14)
        .onChange(of: lpgAttack) { audioEngine.setParameter(id: .plaitsLPGAttack, value: $0) }
        .onChange(of: lpgDecay) { audioEngine.setParameter(id: .plaitsLPGDecay, value: $0) }
        .onChange(of: lpgColor) { audioEngine.setParameter(id: .plaitsLPGColor, value: $0) }
    }

    // MARK: - Load Wavetable Button

    @State private var showWavetableFilePicker = false

    private var loadWavetableButton: some View {
        Button(action: {
            showWavetableFilePicker = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 10, weight: .bold))
                Text("LOAD WAVETABLE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundColor(ColorPalette.synthPanelLabel)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
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
        .fileImporter(
            isPresented: $showWavetableFilePicker,
            allowedContentTypes: [.wav, .aiff, .audio],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                audioEngine.loadUserWavetable(url: url)
                // Switch to user bank (harmonics ~0.9)
                harmonics = 0.9
                audioEngine.setParameter(id: .plaitsHarmonics, value: 0.9)
            }
        }
    }

    // MARK: - Trigger Button

    private var triggerButton: some View {
        Button(action: {
            DispatchQueue.main.async {
                isTriggered.toggle()
                audioEngine.triggerPlaits(isTriggered)
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
                        .fill(isTriggered ? ColorPalette.accentPlaits : Color.black.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isTriggered ? ColorPalette.accentPlaits : ColorPalette.synthPanelDivider,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .shadow(color: isTriggered ? ColorPalette.accentPlaits.opacity(0.4) : .clear, radius: 6)
    }

    // MARK: - Helpers

    private func noteToName(_ midiNote: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midiNote / 12) - 1
        let noteName = noteNames[midiNote % 12]
        return "\(noteName)\(octave)"
    }

    private func syncToEngine() {
        audioEngine.setParameter(id: .plaitsModel, value: Float(selectedEngine) / Float(engineNames.count - 1))
        audioEngine.setParameter(id: .plaitsHarmonics, value: harmonics)
        audioEngine.setParameter(id: .plaitsTimbre, value: timbre)
        audioEngine.setParameter(id: .plaitsMorph, value: morph)
        audioEngine.setParameter(id: .plaitsLevel, value: level)
        audioEngine.setParameter(id: .plaitsLPGAttack, value: lpgAttack)
        audioEngine.setParameter(id: .plaitsLPGDecay, value: lpgDecay)
        audioEngine.setParameter(id: .plaitsLPGColor, value: lpgColor)
        audioEngine.setParameter(id: .plaitsLPGBypass, value: lpgBypass ? 1.0 : 0.0)
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

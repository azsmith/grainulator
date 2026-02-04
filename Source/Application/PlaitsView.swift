//
//  PlaitsView.swift
//  Grainulator
//
//  Plaits synthesizer UI component
//

import SwiftUI

struct PlaitsView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var midiManager: MIDIManager
    @State private var selectedEngine: Int = 0
    @State private var note: Float = 60.0 // Middle C
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

    // Real Plaits engine names (16 models)
    // Bank 1 (0-7): Pitched/sustained synth voices
    // Bank 2 (8-15): Noise and percussion models
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
    // Format: [HARMONICS, TIMBRE, MORPH]
    // Based on actual parameter usage in each engine
    let parameterLabels: [[String]] = [
        ["DETUNE", "PULSE W", "SAW"],        // 0: Virtual Analog
        ["SHAPE", "FOLD", "ASYM"],           // 1: Waveshaper
        ["RATIO", "MOD IDX", "FEEDBK"],      // 2: Two-Op FM
        ["FORMANT", "FREQ", "WIDTH"],        // 3: Granular Formant
        ["BUMPS", "BRIGHT", "WIDTH"],        // 4: Harmonic
        ["BANK", "ROW", "COLUMN"],           // 5: Wavetable
        ["CHORD", "INVERT", "WAVE"],         // 6: Chords
        ["TYPE", "SPECIES", "PHONEME"],      // 7: Speech
        ["PITCH R", "DENSITY", "DURATN"],    // 8: Granular Cloud
        ["FILTER", "CLOCK", "RESON"],        // 9: Filtered Noise
        ["FREQ R", "DENSITY", "FILTER"],     // 10: Particle Noise
        ["INHARM", "BRIGHT", "DECAY"],       // 11: String - morph=decay
        ["INHARM", "BRIGHT", "DECAY"],       // 12: Modal - morph=decay
        ["PUNCH", "DECAY", "TONE"],          // 13: Bass Drum - timbre=decay, morph=tone
        ["SNARES", "TONE", "DECAY"],         // 14: Snare Drum - morph=decay
        ["METAL", "DECAY", "DECAY+"],        // 15: Hi-Hat - timbre=main decay (open/closed), morph=fine tune
    ]

    // Whether engine uses LPG (engines 0-10) or has internal envelope (11-15)
    var usesLPG: Bool {
        selectedEngine < 11
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("PLAITS")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#4A9EFF"))

                Spacer()

                // MIDI status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(midiManager.isEnabled ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text("MIDI")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#888888"))
                    if midiManager.lastNote > 0 {
                        Text(noteToName(Int(midiManager.lastNote)))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#4A9EFF"))
                    }
                }
                .padding(.horizontal, 10)

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
                    HStack(spacing: 8) {
                        Text(engineNames[selectedEngine])
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#888888"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#333333"))
                    .cornerRadius(6)
                }
            }
            .padding(.bottom, 10)

            // Parameter controls
            HStack(spacing: 24) {
                // Note control
                VStack(spacing: 8) {
                    Text("NOTE")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#888888"))

                    Slider(value: $note, in: 24...96, step: 1)
                        .tint(Color(hex: "#4A9EFF"))
                        .onChange(of: note) { newValue in
                            audioEngine.setParameter(id: .plaitsFrequency, value: (newValue - 24.0) / 72.0)
                        }

                    Text(noteToName(Int(note)))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#4A9EFF"))
                }
                .frame(width: 140)

                // Harmonics (dynamic label)
                ParameterSlider(
                    label: parameterLabels[selectedEngine][0],
                    value: $harmonics,
                    color: Color(hex: "#4A9EFF")
                )
                .onChange(of: harmonics) { newValue in
                    audioEngine.setParameter(id: .plaitsHarmonics, value: newValue)
                }

                // Timbre (dynamic label)
                ParameterSlider(
                    label: parameterLabels[selectedEngine][1],
                    value: $timbre,
                    color: Color(hex: "#FF6B6B")
                )
                .onChange(of: timbre) { newValue in
                    audioEngine.setParameter(id: .plaitsTimbre, value: newValue)
                }

                // Morph (dynamic label)
                ParameterSlider(
                    label: parameterLabels[selectedEngine][2],
                    value: $morph,
                    color: Color(hex: "#4ECDC4")
                )
                .onChange(of: morph) { newValue in
                    audioEngine.setParameter(id: .plaitsMorph, value: newValue)
                }

                // Level
                ParameterSlider(
                    label: "LEVEL",
                    value: $level,
                    color: Color(hex: "#FFD93D")
                )
                .onChange(of: level) { newValue in
                    audioEngine.setParameter(id: .plaitsLevel, value: newValue)
                }

                // Divider
                Rectangle()
                    .fill(Color(hex: "#333333"))
                    .frame(width: 1, height: 100)

                // LPG section (dimmed for triggered engines 11-15)
                Group {
                    // LPG Attack
                    ParameterSlider(
                        label: "ATTACK",
                        value: $lpgAttack,
                        color: usesLPG ? Color(hex: "#9B59B6") : Color(hex: "#444444")
                    )
                    .onChange(of: lpgAttack) { newValue in
                        audioEngine.setParameter(id: .plaitsLPGAttack, value: newValue)
                    }

                    // LPG Decay
                    ParameterSlider(
                        label: usesLPG ? "DECAY" : "(n/a)",
                        value: $lpgDecay,
                        color: usesLPG ? Color(hex: "#9B59B6") : Color(hex: "#444444")
                    )
                    .onChange(of: lpgDecay) { newValue in
                        audioEngine.setParameter(id: .plaitsLPGDecay, value: newValue)
                    }

                    // LPG Color
                    ParameterSlider(
                        label: "LPG",
                        value: $lpgColor,
                        color: usesLPG ? Color(hex: "#E67E22") : Color(hex: "#444444")
                    )
                    .onChange(of: lpgColor) { newValue in
                        audioEngine.setParameter(id: .plaitsLPGColor, value: newValue)
                    }
                }
                .opacity(usesLPG ? 1.0 : 0.5)
            }

            // Bottom controls row
            HStack(spacing: 20) {
                // Trigger button
                Button(action: {
                    isTriggered.toggle()
                    audioEngine.triggerPlaits(isTriggered)
                }) {
                    Text(isTriggered ? "GATE ON" : "TRIGGER")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isTriggered ? Color(hex: "#1A1A1D") : .white)
                        .frame(width: 120, height: 40)
                        .background(isTriggered ? Color(hex: "#4A9EFF") : Color(hex: "#333333"))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Spacer()

                // LPG Bypass toggle (for testing)
                Toggle(isOn: $lpgBypass) {
                    Text("LPG BYPASS")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(lpgBypass ? Color(hex: "#FF6B6B") : Color(hex: "#888888"))
                }
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#FF6B6B")))
                .onChange(of: lpgBypass) { newValue in
                    audioEngine.setParameter(id: .plaitsLPGBypass, value: newValue ? 1.0 : 0.0)
                }
            }
        }
        .padding(20)
        .background(Color(hex: "#0F0F11"))
        .cornerRadius(8)
    }

    private func noteToName(_ midiNote: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midiNote / 12) - 1
        let note = noteNames[midiNote % 12]
        return "\(note)\(octave)"
    }
}

// Vertical slider parameter control - more trackpad friendly
struct ParameterSlider: View {
    let label: String
    @Binding var value: Float
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#888888"))

            // Custom vertical slider
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Track background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#252528"))
                        .frame(width: 8)

                    // Center marker (50% / 12 o'clock position)
                    Rectangle()
                        .fill(Color(hex: "#555555"))
                        .frame(width: 16, height: 2)
                        .offset(y: -geometry.size.height * 0.5)
                        .frame(maxHeight: .infinity, alignment: .bottom)

                    // Value fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 8, height: geometry.size.height * CGFloat(value))

                    // Thumb
                    Circle()
                        .fill(color)
                        .frame(width: 16, height: 16)
                        .shadow(color: color.opacity(0.5), radius: 4)
                        .offset(y: -geometry.size.height * CGFloat(value) + 8)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let newValue = 1.0 - Float(gesture.location.y / geometry.size.height)
                            value = max(0, min(1, newValue))
                        }
                )
            }
            .frame(width: 50, height: 80)

            Text(String(format: "%.0f%%", value * 100))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

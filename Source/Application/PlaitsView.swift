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

    let engineNames = [
        "Virtual Analog",
        "VA Bright",
        "VA Warm",
        "VA PWM",
        "FM Classic",
        "FM Bells",
        "Waveshaper",
        "WS Fold",
        "Granular",
        "Grain Cloud",
        "Grain Sparse",
        "Grain Dense"
    ]

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
                Picker("Engine", selection: $selectedEngine) {
                    ForEach(0..<engineNames.count, id: \.self) { index in
                        Text(engineNames[index])
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                .onChange(of: selectedEngine) { newValue in
                    audioEngine.setParameter(id: .plaitsModel, value: Float(newValue) / Float(engineNames.count - 1))
                }
            }
            .padding(.bottom, 10)

            // Parameter controls
            HStack(spacing: 30) {
                // Note control
                VStack {
                    Text("NOTE")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#888888"))

                    Slider(value: $note, in: 24...96, step: 1)
                        .onChange(of: note) { newValue in
                            audioEngine.setParameter(id: .plaitsFrequency, value: (newValue - 24.0) / 72.0)
                        }

                    Text(noteToName(Int(note)))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#4A9EFF"))
                }
                .frame(width: 120)

                // Harmonics
                ParameterKnob(
                    label: "HARMONICS",
                    value: $harmonics,
                    color: Color(hex: "#4A9EFF")
                )
                .onChange(of: harmonics) { newValue in
                    audioEngine.setParameter(id: .plaitsHarmonics, value: newValue)
                }

                // Timbre
                ParameterKnob(
                    label: "TIMBRE",
                    value: $timbre,
                    color: Color(hex: "#FF6B6B")
                )
                .onChange(of: timbre) { newValue in
                    audioEngine.setParameter(id: .plaitsTimbre, value: newValue)
                }

                // Morph
                ParameterKnob(
                    label: "MORPH",
                    value: $morph,
                    color: Color(hex: "#4ECDC4")
                )
                .onChange(of: morph) { newValue in
                    audioEngine.setParameter(id: .plaitsMorph, value: newValue)
                }

                // Level
                VStack {
                    Text("LEVEL")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#888888"))

                    VStack {
                        Slider(value: $level, in: 0...1)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 40, height: 100)
                    }
                    .frame(height: 100)

                    Text(String(format: "%.0f%%", level * 100))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }

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

// Simple knob component
struct ParameterKnob: View {
    let label: String
    @Binding var value: Float
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#888888"))

            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(hex: "#333333"), lineWidth: 2)
                    .frame(width: 60, height: 60)

                // Value arc
                Circle()
                    .trim(from: 0, to: CGFloat(value))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))

                // Value text
                Text(String(format: "%.2f", value))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let delta = Float(gesture.translation.height) / -100.0
                        value = max(0, min(1, value + delta))
                    }
            )
        }
    }
}

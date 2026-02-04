//
//  GrainulatorApp.swift
//  Grainulator
//
//  Main application entry point for Grainulator
//

import SwiftUI

@main
struct GrainulatorApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var audioEngine = AudioEngineWrapper()
    @StateObject private var midiManager = MIDIManager()
    @StateObject private var sequencer = MetropolixSequencer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(audioEngine)
                .environmentObject(midiManager)
                .environmentObject(sequencer)
                .frame(minWidth: 1200, minHeight: 800)
                .onAppear {
                    sequencer.connect(audioEngine: audioEngine)
                    setupMIDICallbacks()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            GrainulatorCommands()
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(audioEngine)
                .environmentObject(midiManager)
                .environmentObject(sequencer)
        }
    }

    private func setupMIDICallbacks() {
        // Connect MIDI note events to audio engine
        // Using synchronous calls for low-latency MIDI response
        midiManager.onNoteOn = { [weak audioEngine] note, velocity in
            // Trigger note with pitch and velocity (synchronous for low latency)
            audioEngine?.noteOn(note: note, velocity: velocity)
        }

        midiManager.onNoteOff = { [weak audioEngine] note in
            // Release specific note (for polyphony)
            audioEngine?.noteOff(note: note)
        }

        midiManager.onControlChange = { [weak audioEngine] controller, value in
            Task { @MainActor in
                let normalized = Float(value) / 127.0
                switch controller {
                case 1:  // Mod wheel -> Morph
                    audioEngine?.setParameter(id: .plaitsMorph, value: normalized)
                case 74: // Filter cutoff -> Timbre
                    audioEngine?.setParameter(id: .plaitsTimbre, value: normalized)
                case 71: // Resonance -> Harmonics
                    audioEngine?.setParameter(id: .plaitsHarmonics, value: normalized)
                default:
                    break
                }
            }
        }

        midiManager.onPitchBend = { [weak audioEngine] value in
            Task { @MainActor in
                // Pitch bend: ±2 semitones by default
                // value is -8192 to 8191
                let bendAmount = Float(value) / 8192.0 * 2.0  // ±2 semitones
                // This would need additional parameter support in the engine
                _ = bendAmount
            }
        }
    }
}

/// Application-wide state management
@MainActor
class AppState: ObservableObject {
    @Published var currentView: ViewMode = .multiVoice
    @Published var focusedVoice: Int = 0
    @Published var selectedGranularVoice: Int = 0
    @Published var cpuUsage: Double = 0.0
    @Published var latency: Double = 0.0

    enum ViewMode {
        case multiVoice
        case focus
        case performance
    }

    init() {
        // Initialize application state
    }

    func switchToView(_ mode: ViewMode) {
        currentView = mode
    }

    func focusVoice(_ index: Int) {
        selectedGranularVoice = index
        focusedVoice = index
        currentView = .focus
    }
}

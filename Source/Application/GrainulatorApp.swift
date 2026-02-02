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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(audioEngine)
                .environmentObject(midiManager)
                .frame(minWidth: 1200, minHeight: 800)
                .onAppear {
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
        }
    }

    private func setupMIDICallbacks() {
        // Connect MIDI note events to audio engine
        midiManager.onNoteOn = { [weak audioEngine] note, velocity in
            Task { @MainActor in
                // Set the note frequency
                audioEngine?.setParameter(id: .plaitsFrequency, value: Float(note))
                // Set level based on velocity
                audioEngine?.setParameter(id: .plaitsLevel, value: Float(velocity) / 127.0)
                // Trigger the envelope
                audioEngine?.triggerPlaits(true)
            }
        }

        midiManager.onNoteOff = { [weak audioEngine] note in
            Task { @MainActor in
                // Release the envelope (only if this was the last held note)
                audioEngine?.triggerPlaits(false)
            }
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

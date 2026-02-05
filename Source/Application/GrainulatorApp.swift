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
    @StateObject private var masterClock = MasterClock()
    @StateObject private var mixerState = MixerState()  // New modular mixer state
    @StateObject private var pluginManager = AUPluginManager()  // AU plugin browser

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(audioEngine)
                .environmentObject(midiManager)
                .environmentObject(sequencer)
                .environmentObject(masterClock)
                .environmentObject(mixerState)
                .environmentObject(pluginManager)
                .frame(minWidth: 1200, minHeight: 800)
                .onAppear {
                    sequencer.connect(audioEngine: audioEngine)
                    sequencer.connectMasterClock(masterClock)
                    masterClock.connect(audioEngine: audioEngine)
                    masterClock.connectSequencer(sequencer)
                    mixerState.syncToAudioEngine(audioEngine)  // Push default mixer/send levels to C++ engine
                    pluginManager.refreshPluginList()  // Scan for AU plugins on launch
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
                .environmentObject(masterClock)
        }
    }

    private func setupMIDICallbacks() {
        // Connect MIDI note events to audio engine on MainActor for isolation safety.
        midiManager.onNoteOn = { [weak audioEngine] note, velocity in
            Task { @MainActor in
                audioEngine?.noteOn(note: note, velocity: velocity)
            }
        }

        midiManager.onNoteOff = { [weak audioEngine] note in
            Task { @MainActor in
                audioEngine?.noteOff(note: note)
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

    // New mixer mode toggle (Phase 2 UI refactor)
    @Published var useNewMixer: Bool = false

    // New tab-based layout toggle (Phase 3 UI refactor)
    @Published var useTabLayout: Bool = true

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

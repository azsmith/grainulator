//
//  GrainulatorApp.swift
//  Grainulator
//
//  Main application entry point for Grainulator
//

import SwiftUI
import Combine

@main
struct GrainulatorApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var audioEngine = AudioEngineWrapper()
    @StateObject private var midiManager = MIDIManager()
    @StateObject private var sequencer = StepSequencer()
    @StateObject private var masterClock = MasterClock()
    @StateObject private var mixerState = MixerState()  // New modular mixer state
    @StateObject private var pluginManager = AUPluginManager()  // AU plugin browser
    @StateObject private var projectManager = ProjectManager()  // Project save/load
    @StateObject private var conversationalBridge = ConversationalControlBridge()
    @StateObject private var drumSequencer = DrumSequencer()
    @StateObject private var chordSequencer = ChordSequencer()
    @StateObject private var arcManager = MonomeArcManager()
    @StateObject private var gridManager = MonomeGridManager()
    @StateObject private var scrambleManager = ScrambleManager()

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
                .environmentObject(projectManager)
                .environmentObject(drumSequencer)
                .environmentObject(chordSequencer)
                .environmentObject(arcManager)
                .environmentObject(gridManager)
                .environmentObject(scrambleManager)
                .frame(minWidth: 1200, minHeight: 600)
                .onAppear {
                    // Ensure we get a proper menu bar when launched from terminal
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)

                    // Configure window for full-content layout (like Logic Pro / Ableton)
                    DispatchQueue.main.async {
                        if let window = NSApp.windows.first(where: { $0.contentView != nil && $0.className.contains("NSWindow") || $0.isKeyWindow }) {
                            window.titlebarAppearsTransparent = true
                            window.titleVisibility = .hidden
                            window.styleMask.insert(.fullSizeContentView)
                            // Note: isMovableByWindowBackground is intentionally NOT set —
                            // it conflicts with knob drag gestures, causing the window to
                            // move when dragging knobs. The title bar area still allows
                            // window dragging via the transparent title bar.
                        }
                    }

                    sequencer.connect(audioEngine: audioEngine)
                    sequencer.connectMasterClock(masterClock)
                    masterClock.connect(audioEngine: audioEngine)
                    masterClock.connectSequencer(sequencer)
                    masterClock.connectDrumSequencer(drumSequencer)
                    drumSequencer.connect(audioEngine: audioEngine)
                    drumSequencer.connectMasterClock(masterClock)
                    sequencer.connectDrumSequencer(drumSequencer)
                    sequencer.connectChordSequencer(chordSequencer)
                    mixerState.connectAudioEngine(audioEngine)  // Wire up Combine → engine sync
                    mixerState.syncToAudioEngine(audioEngine)  // Push default mixer/send levels to C++ engine
                    pluginManager.refreshPluginList()  // Scan for AU plugins on launch
                    projectManager.connect(
                        audioEngine: audioEngine,
                        mixerState: mixerState,
                        sequencer: sequencer,
                        masterClock: masterClock,
                        appState: appState,
                        pluginManager: pluginManager,
                        drumSequencer: drumSequencer,
                        chordSequencer: chordSequencer,
                        scrambleManager: scrambleManager
                    )
                    conversationalBridge.start(audioEngine: audioEngine, masterClock: masterClock, sequencer: sequencer, drumSequencer: drumSequencer, chordSequencer: chordSequencer, scrambleManager: scrambleManager)
                    setupMIDICallbacks()
                    arcManager.connect(audioEngine: audioEngine, appState: appState)
                    gridManager.connect(sequencer: sequencer, chordSequencer: chordSequencer, masterClock: masterClock, audioEngine: audioEngine, appState: appState)
                    scrambleManager.connect(audioEngine: audioEngine, masterClock: masterClock, sequencer: sequencer)
                    audioEngine.scrambleManager = scrambleManager  // Scope visualization bridge
                    masterClock.connectScrambleManager(scrambleManager)

                    // Wire sequencer tempo/transport to AU host context for plugin sync
                    wireAUHostContext()
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            GrainulatorCommands(
                projectManager: projectManager,
                sequencer: sequencer,
                audioEngine: audioEngine,
                masterClock: masterClock,
                mixerState: mixerState,
                appState: appState
            )
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

    private func wireAUHostContext() {
        let ctx = audioEngine.auHostContext

        // Sync initial values
        ctx.setTempo(sequencer.tempoBPM)
        ctx.setTransportState(isPlaying: sequencer.isPlaying)

        // Observe tempo changes
        sequencer.$tempoBPM
            .removeDuplicates()
            .sink { bpm in ctx.setTempo(bpm) }
            .store(in: &appState.cancellables)

        // Observe transport state changes
        sequencer.$isPlaying
            .removeDuplicates()
            .sink { playing in ctx.setTransportState(isPlaying: playing) }
            .store(in: &appState.cancellables)
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
    @Published var focusedVoice: Int = 0
    @Published var selectedGranularVoice: Int = 0
    @Published var cpuUsage: Double = 0.0
    @Published var latency: Double = 0.0
    @Published var pendingTab: WorkspaceTab?
    @Published var pendingMixerToggle: Bool = false
    var cancellables = Set<AnyCancellable>()

    init() {
        // Initialize application state
    }

    func focusVoice(_ index: Int) {
        selectedGranularVoice = index
        focusedVoice = index
    }
}

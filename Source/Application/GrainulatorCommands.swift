//
//  GrainulatorCommands.swift
//  Grainulator
//
//  Menu commands and keyboard shortcuts
//

import SwiftUI

struct GrainulatorCommands: Commands {
    @ObservedObject var projectManager: ProjectManager
    @ObservedObject var sequencer: StepSequencer
    @ObservedObject var audioEngine: AudioEngineWrapper
    @ObservedObject var masterClock: MasterClock
    @ObservedObject var mixerState: MixerState
    @ObservedObject var appState: AppState

    var body: some Commands {
        // File menu commands
        CommandGroup(replacing: .newItem) {
            Button("New Project") {
                projectManager.newProject()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open Project...") {
                projectManager.openProject()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("Save Project") {
                projectManager.saveProject()
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Save Project As...") {
                projectManager.saveProjectAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Divider()

            Button("Import Audio File...") {
                // TODO: Import audio
            }
            .keyboardShortcut("i", modifiers: .command)
        }

        // Transport menu commands
        CommandMenu("Transport") {
            Button(sequencer.isPlaying ? "Stop" : "Play") {
                sequencer.togglePlayback()
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("Stop and Reset") {
                sequencer.stop()
                sequencer.reset()
            }
            .keyboardShortcut(.return, modifiers: [])

            Divider()

            Button("Increase BPM") {
                sequencer.tempoBPM = min(sequencer.tempoBPM + 1, 300)
            }
            .keyboardShortcut(.upArrow, modifiers: .command)

            Button("Decrease BPM") {
                sequencer.tempoBPM = max(sequencer.tempoBPM - 1, 20)
            }
            .keyboardShortcut(.downArrow, modifiers: .command)

            Button("Increase BPM x10") {
                sequencer.tempoBPM = min(sequencer.tempoBPM + 10, 300)
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .shift])

            Button("Decrease BPM x10") {
                sequencer.tempoBPM = max(sequencer.tempoBPM - 10, 20)
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .shift])

            Button("Fine Increase BPM") {
                sequencer.tempoBPM = min(sequencer.tempoBPM + 0.1, 300)
            }
            .keyboardShortcut(.upArrow, modifiers: .option)

            Button("Fine Decrease BPM") {
                sequencer.tempoBPM = max(sequencer.tempoBPM - 0.1, 20)
            }
            .keyboardShortcut(.downArrow, modifiers: .option)

            Divider()

            Button("All Notes Off") {
                audioEngine.allNotesOff()
            }
            .keyboardShortcut(".", modifiers: .command)
        }

        // Sequencer menu commands
        CommandMenu("Sequencer") {
            Button("Mute Track 1") {
                sequencer.setTrackMuted(0, !sequencer.tracks[0].muted)
            }
            .keyboardShortcut("m", modifiers: .command)

            Button("Mute Track 2") {
                sequencer.setTrackMuted(1, !sequencer.tracks[1].muted)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Divider()

            Button("Direction: Forward") {
                let track = appState.focusedVoice < 2 ? appState.focusedVoice : 0
                sequencer.tracks[track].direction = .forward
            }

            Button("Direction: Reverse") {
                let track = appState.focusedVoice < 2 ? appState.focusedVoice : 0
                sequencer.tracks[track].direction = .reverse
            }

            Button("Direction: Alternate") {
                let track = appState.focusedVoice < 2 ? appState.focusedVoice : 0
                sequencer.tracks[track].direction = .alternate
            }

            Button("Direction: Random") {
                let track = appState.focusedVoice < 2 ? appState.focusedVoice : 0
                sequencer.tracks[track].direction = .random
            }

            Button("Direction: Skip 2") {
                let track = appState.focusedVoice < 2 ? appState.focusedVoice : 0
                sequencer.tracks[track].direction = .skip2
            }

            Button("Direction: Skip 3") {
                let track = appState.focusedVoice < 2 ? appState.focusedVoice : 0
                sequencer.tracks[track].direction = .skip3
            }

            Button("Direction: Climb 2") {
                let track = appState.focusedVoice < 2 ? appState.focusedVoice : 0
                sequencer.tracks[track].direction = .climb2
            }

            Button("Direction: Climb 3") {
                let track = appState.focusedVoice < 2 ? appState.focusedVoice : 0
                sequencer.tracks[track].direction = .climb3
            }

            Button("Direction: Drunk") {
                let track = appState.focusedVoice < 2 ? appState.focusedVoice : 0
                sequencer.tracks[track].direction = .drunk
            }

            Button("Direction: Random No Repeat") {
                let track = appState.focusedVoice < 2 ? appState.focusedVoice : 0
                sequencer.tracks[track].direction = .randomNoRepeat
            }

            Button("Direction: Converge") {
                let track = appState.focusedVoice < 2 ? appState.focusedVoice : 0
                sequencer.tracks[track].direction = .converge
            }

            Button("Direction: Diverge") {
                let track = appState.focusedVoice < 2 ? appState.focusedVoice : 0
                sequencer.tracks[track].direction = .diverge
            }
        }

        // View menu commands
        CommandMenu("View") {
            Button("Sequencer Tab") {
                appState.pendingTab = .sequencer
            }
            .keyboardShortcut("1", modifiers: [.command, .shift])

            Button("Synths Tab") {
                appState.pendingTab = .synths
            }
            .keyboardShortcut("2", modifiers: [.command, .shift])

            Button("Granular Tab") {
                appState.pendingTab = .granular
            }
            .keyboardShortcut("3", modifiers: [.command, .shift])

            Button("Drums Tab") {
                appState.pendingTab = .drums
            }
            .keyboardShortcut("4", modifiers: [.command, .shift])

            Divider()

            Button("Multi-Voice View") {
                // TODO: Switch to multi-voice
            }
            .keyboardShortcut("0", modifiers: .command)

            Divider()

            Button("Focus Granular 1") {
                appState.focusVoice(0)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Focus Granular 2") {
                appState.focusVoice(1)
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Focus Granular 3") {
                appState.focusVoice(2)
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Focus Granular 4") {
                appState.focusVoice(3)
            }
            .keyboardShortcut("4", modifiers: .command)

            Button("Focus Plaits") {
                // TODO: Focus Plaits voice
            }
            .keyboardShortcut("5", modifiers: .command)

            Button("Focus Rings") {
                // TODO: Focus Rings voice
            }
            .keyboardShortcut("6", modifiers: .command)

            Button("Focus Sampler") {
                // TODO: Focus Sampler
            }
            .keyboardShortcut("7", modifiers: .command)

            Button("Focus Drums") {
                // TODO: Focus Drums
            }
            .keyboardShortcut("8", modifiers: .command)

            Divider()

            Button("Toggle Mixer") {
                appState.pendingMixerToggle = true
            }
            .keyboardShortcut("x", modifiers: [])

            Button("Performance View") {
                // TODO: Switch to performance view
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Button("Cycle Focus") {
                // TODO: Cycle through focus views
            }
            .keyboardShortcut("f", modifiers: .command)
        }

        // Effects menu commands
        CommandMenu("Effects") {
            Button("Toggle Delay Bypass") {
                // TODO: Toggle delay bypass
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Button("Toggle Reverb Bypass") {
                // TODO: Toggle reverb bypass
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Toggle Master Filter Bypass") {
                // TODO: Toggle master filter bypass
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
        }

        // Audio menu commands
        CommandMenu("Audio") {
            Button("Start Audio Engine") {
                // TODO: Start engine
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button("Stop Audio Engine") {
                // TODO: Stop engine
            }
            .keyboardShortcut("e", modifiers: [.command, .option])

            Divider()

            Button("Audio Settings...") {
                // TODO: Show audio settings
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

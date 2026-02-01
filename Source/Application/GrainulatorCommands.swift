//
//  GrainulatorCommands.swift
//  Grainulator
//
//  Menu commands and keyboard shortcuts
//

import SwiftUI

struct GrainulatorCommands: Commands {
    var body: some Commands {
        // File menu commands
        CommandGroup(replacing: .newItem) {
            Button("New Project") {
                // TODO: Create new project
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open Project...") {
                // TODO: Open project
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("Import Audio File...") {
                // TODO: Import audio
            }
            .keyboardShortcut("i", modifiers: .command)
        }

        // View menu commands
        CommandMenu("View") {
            Button("Multi-Voice View") {
                // TODO: Switch to multi-voice
            }
            .keyboardShortcut("0", modifiers: .command)

            Divider()

            Button("Focus Granular 1") {
                // TODO: Focus granular voice 1
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Focus Granular 2") {
                // TODO: Focus granular voice 2
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Focus Granular 3") {
                // TODO: Focus granular voice 3
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Focus Granular 4") {
                // TODO: Focus granular voice 4
            }
            .keyboardShortcut("4", modifiers: .command)

            Button("Focus Plaits") {
                // TODO: Focus Plaits voice
            }
            .keyboardShortcut("5", modifiers: .command)

            Divider()

            Button("Performance View") {
                // TODO: Switch to performance view
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Button("Cycle Focus") {
                // TODO: Cycle through focus views
            }
            .keyboardShortcut("f", modifiers: .command)
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

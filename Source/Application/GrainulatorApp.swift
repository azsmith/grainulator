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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(audioEngine)
                .frame(minWidth: 1200, minHeight: 800)
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

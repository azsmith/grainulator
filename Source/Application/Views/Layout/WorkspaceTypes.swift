//
//  WorkspaceTypes.swift
//  Grainulator
//
//  Workspace tab types and layout state management
//

import SwiftUI

// MARK: - Workspace Tab

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case sequencer = "SEQUENCER"
    case synths = "SYNTHS"
    case granular = "GRANULAR"
    case drums = "DRUMS"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sequencer: return "clock"
        case .synths: return "waveform"
        case .granular: return "waveform.path"
        case .drums: return "drum.fill"
        }
    }

    var shortName: String {
        switch self {
        case .sequencer: return "SEQ"
        case .synths: return "SYNTH"
        case .granular: return "GRAN"
        case .drums: return "DRUM"
        }
    }

    var accentColor: Color {
        switch self {
        case .sequencer: return ColorPalette.ledAmber
        case .synths: return ColorPalette.accentPlaits
        case .granular: return ColorPalette.accentGranular1
        case .drums: return ColorPalette.accentDaisyDrum
        }
    }
}

// MARK: - Workspace Layout State

class WorkspaceLayoutState: ObservableObject {
    @Published var currentTab: WorkspaceTab = .sequencer
    @Published var isMixerWindowOpen: Bool = false
    @Published var isScopeWindowOpen: Bool = false

    func selectTab(_ tab: WorkspaceTab) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentTab = tab
        }
    }

    func toggleMixerWindow() {
        isMixerWindowOpen.toggle()
    }
}

// MARK: - Transport State

class TransportState: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var isRecording: Bool = false
    @Published var bpm: Double = 120.0
    @Published var swing: Double = 0.0

    // BPM range
    static let bpmRange: ClosedRange<Double> = 20...300

    func togglePlayback() {
        isPlaying.toggle()
    }

    func stop() {
        isPlaying = false
        isRecording = false
    }

    func toggleRecording() {
        if !isPlaying {
            isPlaying = true
        }
        isRecording.toggle()
    }

    func setBPM(_ newBPM: Double) {
        bpm = min(max(newBPM, Self.bpmRange.lowerBound), Self.bpmRange.upperBound)
    }

    func tapTempo(timestamps: [Date]) {
        guard timestamps.count >= 2 else { return }

        // Calculate average interval from recent taps
        var intervals: [TimeInterval] = []
        for i in 1..<timestamps.count {
            intervals.append(timestamps[i].timeIntervalSince(timestamps[i-1]))
        }

        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        if avgInterval > 0 {
            let newBPM = 60.0 / avgInterval
            setBPM(newBPM)
        }
    }
}

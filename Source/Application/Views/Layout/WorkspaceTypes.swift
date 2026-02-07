//
//  WorkspaceTypes.swift
//  Grainulator
//
//  Workspace tab types and layout state management
//

import SwiftUI

// MARK: - Workspace Tab (Top Section)

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case synths = "SYNTHS"
    case granular = "GRANULAR"
    case drums = "DRUMS"
    case sampler = "SAMPLER"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .synths: return "waveform"
        case .granular: return "waveform.path"
        case .drums: return "drum.fill"
        case .sampler: return "pianokeys"
        }
    }

    var shortName: String {
        switch self {
        case .synths: return "SYN"
        case .granular: return "GRN"
        case .drums: return "DRM"
        case .sampler: return "SMP"
        }
    }

    var accentColor: Color {
        switch self {
        case .synths: return ColorPalette.accentPlaits
        case .granular: return ColorPalette.accentGranular1
        case .drums: return ColorPalette.accentDaisyDrum
        case .sampler: return ColorPalette.accentSampler
        }
    }
}

// MARK: - Master Control Tab (Bottom Section)

enum MasterControlTab: String, CaseIterable, Identifiable {
    case timing = "TIMING"
    case mixer = "MIXER"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .timing: return "clock"
        case .mixer: return "slider.horizontal.3"
        }
    }

    var accentColor: Color {
        switch self {
        case .timing: return ColorPalette.ledAmber
        case .mixer: return ColorPalette.accentMaster
        }
    }
}

// MARK: - Workspace Layout State

class WorkspaceLayoutState: ObservableObject {
    @Published var currentTab: WorkspaceTab = .synths
    @Published var currentBottomTab: MasterControlTab = .mixer
    @Published var isMixerCollapsed: Bool = false
    @Published var mixerHeight: CGFloat = 380

    // Master control section heights
    static let masterControlHeightFull: CGFloat = 380
    static let masterControlHeightCompact: CGFloat = 260
    static let masterControlHeightCollapsed: CGFloat = 40

    func selectTab(_ tab: WorkspaceTab) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentTab = tab
        }
    }

    func selectBottomTab(_ tab: MasterControlTab) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentBottomTab = tab
        }
    }

    func toggleMixerCollapsed() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isMixerCollapsed.toggle()
            mixerHeight = isMixerCollapsed ? Self.masterControlHeightCollapsed : Self.masterControlHeightFull
        }
    }

    func setMixerHeight(_ height: CGFloat) {
        withAnimation(.easeOut(duration: 0.15)) {
            mixerHeight = height
            isMixerCollapsed = height <= Self.masterControlHeightCollapsed
        }
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

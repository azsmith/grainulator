//
//  TabBasedLayoutView.swift
//  Grainulator
//
//  Main layout: transport bar + workspace content
//

import SwiftUI

// MARK: - Tab Based Layout View

struct TabBasedLayoutView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var masterClock: MasterClock
    @EnvironmentObject var sequencer: StepSequencer

    @StateObject private var layoutState = WorkspaceLayoutState()
    @StateObject private var transportState = TransportState()

    var body: some View {
        VStack(spacing: 0) {
            // Transport bar with clock outputs and tabs
            TransportBarView(
                transportState: transportState,
                layoutState: layoutState
            )
            .layoutPriority(2)

            Divider()
                .background(ColorPalette.divider)

            // Main workspace content — takes all remaining space
            WorkspaceTabView(layoutState: layoutState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ColorPalette.backgroundPrimary)
        .onAppear {
            // Sync transport state with master clock
            transportState.bpm = Double(masterClock.bpm)
            transportState.isPlaying = sequencer.isPlaying
        }
        .onChange(of: sequencer.isPlaying) { isPlaying in
            transportState.isPlaying = isPlaying
        }
        .onChange(of: masterClock.bpm) { bpm in
            transportState.bpm = bpm
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TabBasedLayoutView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @StateObject private var appState = AppState()
        @StateObject private var audioEngine = AudioEngineWrapper()
        @StateObject private var masterClock = MasterClock()

        var body: some View {
            TabBasedLayoutView()
                .environmentObject(appState)
                .environmentObject(audioEngine)
                .environmentObject(masterClock)
                .frame(width: 1400, height: 900)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif

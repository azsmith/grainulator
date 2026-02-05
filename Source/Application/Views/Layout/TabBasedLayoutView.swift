//
//  TabBasedLayoutView.swift
//  Grainulator
//
//  New tab-based layout for improved creative workflow
//

import SwiftUI

// MARK: - Tab Based Layout View

struct TabBasedLayoutView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var masterClock: MasterClock
    @EnvironmentObject var sequencer: MetropolixSequencer
    @EnvironmentObject var mixerState: MixerState

    @StateObject private var layoutState = WorkspaceLayoutState()
    @StateObject private var transportState = TransportState()

    var body: some View {
        VStack(spacing: 0) {
            // Transport bar with tabs - highest priority, must always be visible
            TransportBarView(
                transportState: transportState,
                layoutState: layoutState
            )
            .layoutPriority(2)

            Divider()
                .background(ColorPalette.divider)

            // Main workspace content - lowest priority, takes remaining space
            WorkspaceTabView(layoutState: layoutState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0)

            Divider()
                .background(ColorPalette.divider)

            // Master control section (bottom tabs: Timing / Mixer)
            masterControlSection
                .layoutPriority(1)
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

    // MARK: - Master Control Section

    @ViewBuilder
    private var masterControlSection: some View {
        VStack(spacing: 0) {
            // Tab bar for bottom section - always visible with explicit zIndex
            MasterControlTabBar(
                selectedTab: $layoutState.currentBottomTab,
                onCollapse: { layoutState.toggleMixerCollapsed() },
                isCollapsed: layoutState.isMixerCollapsed,
                currentHeight: layoutState.mixerHeight,
                onSetHeight: { layoutState.setMixerHeight($0) }
            )
            .zIndex(1)  // Ensure tab bar stays on top

            if !layoutState.isMixerCollapsed {
                // Tab content - clipped to prevent overflow
                Group {
                    switch layoutState.currentBottomTab {
                    case .timing:
                        TimingTabContent()
                    case .mixer:
                        MixerTabContent(mixerState: mixerState)
                    }
                }
                .frame(height: layoutState.mixerHeight - 42)  // Subtract tab bar height
                .clipped()  // Prevent content from overflowing into tab bar area
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: layoutState.currentBottomTab)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: layoutState.isMixerCollapsed)
    }
}

// MARK: - Master Control Tab Bar

struct MasterControlTabBar: View {
    @Binding var selectedTab: MasterControlTab
    let onCollapse: () -> Void
    let isCollapsed: Bool
    let currentHeight: CGFloat
    let onSetHeight: (CGFloat) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top border for visibility
            Rectangle()
                .fill(ColorPalette.ledBlue.opacity(0.5))
                .frame(height: 2)

            HStack(spacing: 8) {
                // Tab buttons with more prominent styling
                ForEach(MasterControlTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(selectedTab == tab ? .white : ColorPalette.textMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedTab == tab ? tab.accentColor : ColorPalette.backgroundTertiary)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if !isCollapsed {
                    // Height adjustment buttons
                    HStack(spacing: 4) {
                        Button(action: { onSetHeight(WorkspaceLayoutState.masterControlHeightCompact) }) {
                            Text("S")
                                .font(Typography.buttonTiny)
                                .foregroundColor(currentHeight == WorkspaceLayoutState.masterControlHeightCompact ? ColorPalette.ledBlue : ColorPalette.textDimmed)
                        }
                        .buttonStyle(.plain)

                        Button(action: { onSetHeight(WorkspaceLayoutState.masterControlHeightFull) }) {
                            Text("L")
                                .font(Typography.buttonTiny)
                                .foregroundColor(currentHeight == WorkspaceLayoutState.masterControlHeightFull ? ColorPalette.ledBlue : ColorPalette.textDimmed)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.backgroundTertiary)
                    )
                }

                // Collapse button
                Button(action: onCollapse) {
                    Image(systemName: isCollapsed ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(ColorPalette.textMuted)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ColorPalette.backgroundSecondary)
        }
        .frame(height: 42)
    }
}

// MARK: - Timing Tab Content

struct TimingTabContent: View {
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Clock on left
                ScrollView {
                    MasterClockView()
                        .padding(12)
                }
                .frame(width: min(500, geometry.size.width * 0.4))

                Divider()
                    .background(ColorPalette.divider)

                // Sequencer on right
                ScrollView {
                    SequencerView()
                        .padding(12)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(ColorPalette.backgroundPrimary)
    }
}

// MARK: - Mixer Tab Content

struct MixerTabContent: View {
    @ObservedObject var mixerState: MixerState

    var body: some View {
        NewMixerView(mixerState: mixerState, showToolbar: false)
            .background(ColorPalette.backgroundPrimary)
    }
}

// MARK: - Preview

#if DEBUG
struct TabBasedLayoutView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @StateObject private var appState = AppState()
        @StateObject private var audioEngine = AudioEngineWrapper()
        @StateObject private var masterClock = MasterClock()
        @StateObject private var mixerState = MixerState()

        var body: some View {
            TabBasedLayoutView()
                .environmentObject(appState)
                .environmentObject(audioEngine)
                .environmentObject(masterClock)
                .environmentObject(mixerState)
                .frame(width: 1400, height: 900)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif

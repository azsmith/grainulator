//
//  TransportBarView.swift
//  Grainulator
//
//  Transport controls and workspace tab navigation bar
//

import SwiftUI

// MARK: - Transport Bar View

struct TransportBarView: View {
    @ObservedObject var transportState: TransportState
    @ObservedObject var layoutState: WorkspaceLayoutState
    @EnvironmentObject var masterClock: MasterClock
    @EnvironmentObject var sequencer: StepSequencer
    @EnvironmentObject var drumSequencer: DrumSequencer
    @EnvironmentObject var appState: AppState

    @State private var tapTimestamps: [Date] = []
    @State private var isEditingBPM: Bool = false
    @State private var bpmText: String = "120"

    var body: some View {
        VStack(spacing: 0) {
            // Reserve space for macOS title bar / traffic light buttons
            Color.clear
                .frame(height: 28)

            HStack(spacing: 0) {
                // Space for macOS traffic light buttons (hidden title bar)
                Color.clear
                    .frame(width: 78)

                // Left section: Transport controls
                transportSection
                    .frame(width: 240)

                // Divider
                Rectangle()
                    .fill(ColorPalette.divider)
                    .frame(width: 1)

                // Center section: Tab navigation
                tabNavigationSection

                // Divider
                Rectangle()
                    .fill(ColorPalette.divider)
                    .frame(width: 1)

                // Right section: Status and mixer toggle
                statusSection
                    .frame(width: 200)
            }
            .frame(height: 56)
        }
        .background(ColorPalette.backgroundSecondary)
    }

    // MARK: - Transport Section

    private var transportSection: some View {
        let transportRef = transportState
        let sequencerRef = sequencer
        let drumSeqRef = drumSequencer
        return HStack(spacing: 12) {
            // BPM display/edit
            bpmDisplay

            // Transport buttons
            HStack(spacing: 4) {
                TransportButton(type: .stop, isActive: !sequencer.isPlaying) {
                    transportRef.stop()
                    sequencerRef.stop()
                    if drumSeqRef.syncToTransport {
                        drumSeqRef.stop()
                    }
                }

                TransportButton(type: .play, isActive: sequencer.isPlaying) {
                    if sequencerRef.isPlaying {
                        sequencerRef.stop()
                    } else {
                        sequencerRef.start()
                    }
                    transportRef.isPlaying = sequencerRef.isPlaying
                }

                TransportButton(type: .record, isActive: transportState.isRecording) {
                    transportRef.toggleRecording()
                }
            }

            // Tap tempo button
            Button(action: handleTapTempo) {
                Text("TAP")
                    .font(Typography.buttonSmall)
                    .foregroundColor(ColorPalette.textMuted)
                    .frame(width: 36, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.backgroundTertiary)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
    }

    // MARK: - BPM Display

    private var bpmDisplay: some View {
        VStack(spacing: 0) {
            Text("BPM")
                .font(Typography.parameterLabelSmall)
                .foregroundColor(ColorPalette.textDimmed)

            if isEditingBPM {
                TextField("", text: $bpmText)
                    .font(Typography.valueLarge)
                    .foregroundColor(ColorPalette.accentMaster)
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        if let newBPM = Double(bpmText) {
                            transportState.setBPM(newBPM)
                            masterClock.bpm = newBPM
                        }
                        isEditingBPM = false
                    }
            } else {
                Text(String(format: "%.1f", masterClock.bpm))
                    .font(Typography.valueLarge)
                    .foregroundColor(ColorPalette.accentMaster)
                    .monospacedDigit()
                    .onTapGesture {
                        bpmText = String(format: "%.1f", masterClock.bpm)
                        isEditingBPM = true
                    }
            }
        }
        .frame(width: 60)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(ColorPalette.backgroundPrimary)
        )
    }

    // MARK: - Tab Navigation Section

    private var tabNavigationSection: some View {
        HStack(spacing: 4) {
            ForEach(WorkspaceTab.allCases) { tab in
                WorkspaceTabButton(
                    tab: tab,
                    isSelected: layoutState.currentTab == tab
                ) {
                    layoutState.selectTab(tab)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        HStack(spacing: 12) {
            // CPU/Latency
            VStack(alignment: .trailing, spacing: 0) {
                HStack(spacing: 4) {
                    Text("CPU")
                        .font(Typography.parameterLabelSmall)
                        .foregroundColor(ColorPalette.textDimmed)
                    Text(String(format: "%.0f%%", appState.cpuUsage))
                        .font(Typography.valueSmall)
                        .foregroundColor(appState.cpuUsage > 80 ? ColorPalette.ledRed : ColorPalette.textSecondary)
                        .monospacedDigit()
                }
                HStack(spacing: 4) {
                    Text("LAT")
                        .font(Typography.parameterLabelSmall)
                        .foregroundColor(ColorPalette.textDimmed)
                    Text(String(format: "%.1fms", appState.latency))
                        .font(Typography.valueSmall)
                        .foregroundColor(ColorPalette.textSecondary)
                        .monospacedDigit()
                }
            }

            // Mixer toggle/collapse button
            Button(action: { layoutState.toggleMixerCollapsed() }) {
                Image(systemName: layoutState.isMixerCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                    .font(.system(size: 14))
                    .foregroundColor(ColorPalette.textMuted)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.backgroundTertiary)
                    )
            }
            .buttonStyle(.plain)
            .help(layoutState.isMixerCollapsed ? "Expand mixer" : "Collapse mixer")
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Tap Tempo

    private func handleTapTempo() {
        let now = Date()

        // Remove old taps (older than 2 seconds)
        tapTimestamps = tapTimestamps.filter { now.timeIntervalSince($0) < 2.0 }

        // Add new tap
        tapTimestamps.append(now)

        // Calculate BPM if we have enough taps
        if tapTimestamps.count >= 2 {
            transportState.tapTempo(timestamps: tapTimestamps)
            masterClock.bpm = transportState.bpm
        }

        // Keep only last 8 taps
        if tapTimestamps.count > 8 {
            tapTimestamps.removeFirst()
        }
    }
}

// MARK: - Workspace Tab Button

struct WorkspaceTabButton: View {
    let tab: WorkspaceTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))

                Text(tab.rawValue)
                    .font(Typography.buttonStandard)
            }
            .foregroundColor(isSelected ? .white : (isHovering ? tab.accentColor : ColorPalette.textMuted))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? tab.accentColor : (isHovering ? tab.accentColor.opacity(0.1) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? tab.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TransportBarView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @StateObject private var transportState = TransportState()
        @StateObject private var layoutState = WorkspaceLayoutState()
        @StateObject private var appState = AppState()
        @StateObject private var masterClock = MasterClock()

        var body: some View {
            VStack {
                TransportBarView(
                    transportState: transportState,
                    layoutState: layoutState
                )
                .environmentObject(masterClock)
                .environmentObject(appState)

                Spacer()
            }
            .frame(height: 200)
            .background(ColorPalette.backgroundPrimary)
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
#endif

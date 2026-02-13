//
//  TransportBarView.swift
//  Grainulator
//
//  Transport controls, clock outputs, workspace tab navigation, and status bar
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
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var mixerState: MixerState
    @EnvironmentObject var pluginManager: AUPluginManager
    @EnvironmentObject var projectManager: ProjectManager

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

                // Transport + BPM group
                transportSection
                    .padding(.trailing, 12)

                sectionDivider

                // Clock outputs
                clockOutputsSection
                    .padding(.horizontal, 10)

                sectionDivider

                // Workspace tabs
                tabNavigationSection
                    .padding(.horizontal, 10)

                Spacer(minLength: 8)

                sectionDivider

                // Status: Mixer + Scope
                statusSection
                    .padding(.horizontal, 12)
            }
            .frame(height: 48)

            // Bottom edge line
            Rectangle()
                .fill(ColorPalette.divider.opacity(0.6))
                .frame(height: 1)
        }
        .background(ColorPalette.backgroundSecondary)
    }

    // MARK: - Section Divider

    private var sectionDivider: some View {
        Rectangle()
            .fill(ColorPalette.divider.opacity(0.4))
            .frame(width: 1, height: 28)
    }

    // MARK: - Transport Section

    private var transportSection: some View {
        let transportRef = transportState
        let sequencerRef = sequencer
        let drumSeqRef = drumSequencer
        return HStack(spacing: 8) {
            // Transport buttons — fixed tight cluster like a tape machine
            HStack(spacing: 2) {
                TransportButton(type: .stop, isActive: !sequencer.isPlaying) {
                    if audioEngine.isMasterRecording {
                        audioEngine.stopMasterRecording()
                    }
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

                TransportButton(type: .record, isActive: audioEngine.isMasterRecording) {
                    if audioEngine.isMasterRecording {
                        audioEngine.stopMasterRecording()
                        transportRef.isRecording = false
                    } else {
                        audioEngine.startMasterRecording(projectName: projectManager.currentProjectName)
                        transportRef.isRecording = true
                    }
                }
            }
            .fixedSize()

            // Bar:Beat counter
            barBeatCounter

            // BPM display
            bpmDisplay

            // Tap tempo
            Button(action: handleTapTempo) {
                Text("TAP")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundColor(ColorPalette.textDimmed)
                    .frame(width: 32, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.backgroundTertiary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(ColorPalette.divider, lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 8)
    }

    // MARK: - BPM Display

    private var bpmDisplay: some View {
        HStack(spacing: 0) {
            if isEditingBPM {
                TextField("", text: $bpmText)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.lcdAmber)
                    .multilineTextAlignment(.trailing)
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
                Text(bpmDisplayString)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.lcdAmber)
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
                    .onTapGesture {
                        bpmText = String(format: "%.1f", masterClock.bpm)
                        isEditingBPM = true
                    }
            }

            Text(" BPM")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(ColorPalette.backgroundPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(ColorPalette.divider.opacity(0.5), lineWidth: 0.5)
                )
        )
    }

    /// Format BPM: show integer when whole, 1 decimal otherwise. Always fits in frame.
    private var bpmDisplayString: String {
        let bpm = masterClock.bpm
        if bpm == bpm.rounded() && bpm >= 10 {
            return String(format: "%.0f", bpm)
        }
        return String(format: "%.1f", bpm)
    }

    // MARK: - Bar:Beat Counter

    private var barBeatCounter: some View {
        HStack(spacing: 0) {
            Text("\(masterClock.currentBar)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(ColorPalette.lcdAmber)
                .monospacedDigit()
                .frame(minWidth: 16, alignment: .trailing)
            Text(":")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(ColorPalette.lcdAmber.opacity(0.6))
            Text("\(masterClock.currentBeat)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(ColorPalette.lcdAmber)
                .monospacedDigit()
                .frame(minWidth: 12, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(ColorPalette.backgroundPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(ColorPalette.divider.opacity(0.5), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Clock Outputs Section

    private var clockOutputsSection: some View {
        HStack(spacing: 2) {
            ForEach(0..<8, id: \.self) { index in
                CompactClockOutputPad(output: masterClock.outputs[index], index: index)
            }
        }
    }

    // MARK: - Tab Navigation Section

    private var tabNavigationSection: some View {
        HStack(spacing: 2) {
            ForEach(WorkspaceTab.allCases) { tab in
                WorkspaceTabButton(
                    tab: tab,
                    isSelected: layoutState.currentTab == tab
                ) {
                    layoutState.selectTab(tab)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        HStack(spacing: 6) {
            // Mixer toggle
            StatusToggleButton(
                icon: "slider.horizontal.3",
                label: "MIXER",
                isActive: layoutState.isMixerWindowOpen,
                activeColor: ColorPalette.accentMaster
            ) {
                MixerWindowManager.shared.toggle(
                    mixerState: mixerState,
                    audioEngine: audioEngine,
                    pluginManager: pluginManager,
                    layoutState: layoutState
                )
            }

            // Scope toggle
            StatusToggleButton(
                icon: "waveform.path",
                label: "SCOPE",
                isActive: layoutState.isScopeWindowOpen,
                activeColor: ColorPalette.accentGranular1
            ) {
                OscilloscopeWindowManager.shared.toggle(
                    audioEngine: audioEngine,
                    layoutState: layoutState
                )
            }

            // Tuner toggle
            StatusToggleButton(
                icon: "tuningfork",
                label: "TUNER",
                isActive: layoutState.isTunerWindowOpen,
                activeColor: ColorPalette.ledGreen
            ) {
                TunerWindowManager.shared.toggle(
                    audioEngine: audioEngine,
                    layoutState: layoutState
                )
            }
        }
    }

    // MARK: - Tap Tempo

    private func handleTapTempo() {
        let now = Date()
        tapTimestamps = tapTimestamps.filter { now.timeIntervalSince($0) < 2.0 }
        tapTimestamps.append(now)

        if tapTimestamps.count >= 2 {
            transportState.tapTempo(timestamps: tapTimestamps)
            masterClock.bpm = transportState.bpm
        }

        if tapTimestamps.count > 8 {
            tapTimestamps.removeFirst()
        }
    }
}

// MARK: - Status Toggle Button

private struct StatusToggleButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
            }
            .foregroundColor(isActive ? activeColor : (isHovering ? ColorPalette.textSecondary : ColorPalette.textMuted))
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? activeColor.opacity(0.15) : ColorPalette.backgroundTertiary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isActive ? activeColor.opacity(0.3) : Color.clear, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(isActive ? "Close \(label.lowercased())" : "Open \(label.lowercased())")
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
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 10, weight: .medium))
                    Text(tab.shortName)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundColor(isSelected ? tab.accentColor : (isHovering ? ColorPalette.textSecondary : ColorPalette.textMuted))

                Spacer(minLength: 0)

                // Underline indicator
                RoundedRectangle(cornerRadius: 1)
                    .fill(isSelected ? tab.accentColor : Color.clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover { isHovering = $0 }
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

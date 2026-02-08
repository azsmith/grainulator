//
//  WorkspaceTabView.swift
//  Grainulator
//
//  Container view that displays content based on selected workspace tab
//

import SwiftUI

// MARK: - Workspace Tab View

struct WorkspaceTabView: View {
    @ObservedObject var layoutState: WorkspaceLayoutState
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    var body: some View {
        ZStack {
            // Keep all tab views alive so @State is preserved when switching tabs.
            // Only the selected tab is visible; others are hidden but retain their state.
            SynthsTabView()
                .opacity(layoutState.currentTab == .synths ? 1 : 0)
                .allowsHitTesting(layoutState.currentTab == .synths)

            GranularTabView()
                .opacity(layoutState.currentTab == .granular ? 1 : 0)
                .allowsHitTesting(layoutState.currentTab == .granular)

            DrumsTabView()
                .opacity(layoutState.currentTab == .drums ? 1 : 0)
                .allowsHitTesting(layoutState.currentTab == .drums)
        }
        .animation(.easeInOut(duration: 0.2), value: layoutState.currentTab)
    }
}

// MARK: - Synths Tab View

struct SynthsTabView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @State private var showLibraryBrowser: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                // Plaits synthesizer
                PlaitsView()

                // Rings resonator
                RingsView()

                // DaisyDrum percussion
                DaisyDrumView()

                // Sampler (SF2 / WAV)
                SoundFontPlayerView(showLibraryBrowser: $showLibraryBrowser)
            }
            .padding(20)
        }
        .sheet(isPresented: $showLibraryBrowser) {
            SampleLibraryBrowserView(library: SampleLibraryManager.shared)
                .environmentObject(audioEngine)
        }
    }
}

// MARK: - Granular Tab View

struct GranularTabView: View {
    @EnvironmentObject var appState: AppState

    private struct VoiceTab: Identifiable {
        let id: Int
        let name: String
        let icon: String
        let accentColor: Color
    }

    private let voiceTabs: [VoiceTab] = [
        VoiceTab(id: 0, name: "GRAN 1", icon: "waveform", accentColor: ColorPalette.accentGranular1),
        VoiceTab(id: 3, name: "GRAN 2", icon: "waveform", accentColor: ColorPalette.accentGranular4),
        VoiceTab(id: 1, name: "LOOPER 1", icon: "repeat", accentColor: ColorPalette.accentLooper1),
        VoiceTab(id: 2, name: "LOOPER 2", icon: "repeat", accentColor: ColorPalette.accentLooper2),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Voice selector tabs
            voiceTabBar

            // Selected voice content
            ScrollView {
                selectedVoiceView
                    .padding(20)
            }
        }
    }

    private var voiceTabBar: some View {
        HStack(spacing: 4) {
            ForEach(voiceTabs) { tab in
                GranularVoiceTabButton(
                    name: tab.name,
                    icon: tab.icon,
                    accentColor: tab.accentColor,
                    isSelected: appState.selectedGranularVoice == tab.id
                ) {
                    appState.focusVoice(tab.id)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(ColorPalette.backgroundSecondary)
        .overlay(
            Rectangle()
                .fill(ColorPalette.divider)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private var selectedVoiceView: some View {
        switch appState.selectedGranularVoice {
        case 0:
            GranularView(voiceIndex: 0)
        case 1:
            LooperView(voiceIndex: 1, title: "LOOPER 1")
        case 2:
            LooperView(voiceIndex: 2, title: "LOOPER 2")
        case 3:
            GranularView(voiceIndex: 3)
        default:
            GranularView(voiceIndex: 0)
        }
    }
}

// MARK: - Granular Voice Tab Button

struct GranularVoiceTabButton: View {
    let name: String
    let icon: String
    let accentColor: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))

                Text(name)
                    .font(Typography.buttonSmall)
            }
            .foregroundColor(isSelected ? .white : (isHovering ? accentColor : ColorPalette.textMuted))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? accentColor : (isHovering ? accentColor.opacity(0.1) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Drums Tab View

struct DrumsTabView: View {
    var body: some View {
        DrumSequencerView()
    }
}

// MARK: - Collapsed Mixer Bar

struct CollapsedMixerBar: View {
    @ObservedObject var mixerState: MixerState
    let onExpand: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Mini meters for each channel
            ForEach(mixerState.channels) { channel in
                VStack(spacing: 2) {
                    // Mini meter
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                colors: [ColorPalette.vuGreen, ColorPalette.vuYellow, ColorPalette.vuRed],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 4, height: 20)
                        .mask(
                            VStack {
                                Spacer()
                                Rectangle()
                                    .frame(height: 20 * CGFloat(channel.meterLevel))
                            }
                        )

                    // Mute indicator
                    Circle()
                        .fill(channel.isMuted ? ColorPalette.ledRed : ColorPalette.ledOff)
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            // Master level
            HStack(spacing: 4) {
                Text("MASTER")
                    .font(Typography.parameterLabelSmall)
                    .foregroundColor(ColorPalette.textDimmed)

                Text(mixerState.master.gainDB)
                    .font(Typography.valueSmall)
                    .foregroundColor(ColorPalette.accentMaster)
                    .monospacedDigit()
            }

            // Expand button
            Button(action: onExpand) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12))
                    .foregroundColor(ColorPalette.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ColorPalette.backgroundSecondary)
    }
}

// MARK: - Preview

#if DEBUG
struct WorkspaceTabView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @StateObject private var layoutState = WorkspaceLayoutState()

        var body: some View {
            VStack {
                // Tab selector for preview
                HStack {
                    ForEach(WorkspaceTab.allCases) { tab in
                        Button(tab.rawValue) {
                            layoutState.selectTab(tab)
                        }
                        .foregroundColor(layoutState.currentTab == tab ? .white : .gray)
                    }
                }
                .padding()

                WorkspaceTabView(layoutState: layoutState)
            }
            .background(ColorPalette.backgroundPrimary)
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
#endif

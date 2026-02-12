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
            SequencerTabView()
                .opacity(layoutState.currentTab == .sequencer ? 1 : 0)
                .allowsHitTesting(layoutState.currentTab == .sequencer)
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

// MARK: - Sequencer Tab View

struct SequencerTabView: View {
    @EnvironmentObject var masterClock: MasterClock

    var body: some View {
        VStack(spacing: 0) {
            // Compact swing bar
            swingBar

            Divider()
                .background(ColorPalette.divider)

            // Full sequencer view
            ScrollView {
                SequencerView()
                    .padding(20)
            }
        }
    }

    private var swingBar: some View {
        HStack(spacing: 8) {
            Text("SWING")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)

            Slider(value: $masterClock.swing, in: 0...1)
                .tint(ColorPalette.ledAmber)
                .frame(width: 80)

            Text(String(format: "%.0f%%", masterClock.swing * 100))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textMuted)
                .frame(width: 32, alignment: .trailing)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(ColorPalette.backgroundSecondary)
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

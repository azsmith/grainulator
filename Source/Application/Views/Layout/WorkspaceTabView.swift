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

    var body: some View {
        ZStack {
            // Tab content with animation
            Group {
                switch layoutState.currentTab {
                case .synths:
                    SynthsTabView()
                case .granular:
                    GranularTabView()
                case .performance:
                    PerformanceTabView()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .animation(.easeInOut(duration: 0.2), value: layoutState.currentTab)
    }
}

// MARK: - Synths Tab View

struct SynthsTabView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                // Plaits synthesizer
                PlaitsView()

                // Rings resonator
                RingsView()
            }
            .padding(20)
        }
    }
}

// MARK: - Granular Tab View

struct GranularTabView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // All granular and looper voices
                GranularView(voiceIndex: 0)
                LooperView(voiceIndex: 1, title: "LOOPER 1")
                LooperView(voiceIndex: 2, title: "LOOPER 2")
                GranularView(voiceIndex: 3)
            }
            .padding(20)
        }
    }
}

// MARK: - Performance Tab View

struct PerformanceTabView: View {
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 20) {
                // Left: Performance info
                VStack(spacing: 16) {
                    performanceSection(title: "PERFORMANCE MODE", color: ColorPalette.accentMaster) {
                        Text("Streamlined controls for live use")
                            .font(Typography.parameterLabel)
                            .foregroundColor(ColorPalette.textMuted)

                        Text("Use the existing synth and effect views for full parameter control, or switch to this tab for a minimal performance-focused interface.")
                            .font(Typography.parameterLabel)
                            .foregroundColor(ColorPalette.textDimmed)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity)

                // Right: XY Pad area (placeholder)
                VStack {
                    Text("XY PAD")
                        .font(Typography.sectionHeader)
                        .foregroundColor(ColorPalette.textDimmed)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorPalette.backgroundSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ColorPalette.divider, lineWidth: 1)
                        )
                        .overlay(
                            Text("Coming Soon")
                                .font(Typography.parameterLabel)
                                .foregroundColor(ColorPalette.textDimmed)
                        )
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func performanceSection(
        title: String,
        color: Color,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(Typography.panelTitle)
                .foregroundColor(color)

            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorPalette.backgroundSecondary)
        )
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

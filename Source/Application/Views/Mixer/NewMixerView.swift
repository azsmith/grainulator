//
//  NewMixerView.swift
//  Grainulator
//
//  Modular mixer view with channel strips, effects returns, and master section
//  Uses the new component library for vintage analog aesthetics
//

import SwiftUI

// MARK: - Mixer Layout Mode

enum MixerLayoutMode {
    case full       // Full channel strips with all controls
    case compact    // Minimal strips (fader + meter only)
    case collapsed  // Just meters and mute/solo
}

// MARK: - New Mixer View

struct NewMixerView: View {
    @ObservedObject var mixerState: MixerState
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var pluginManager: AUPluginManager
    @State private var layoutMode: MixerLayoutMode = .full
    @State private var showEffectsReturns: Bool = true
    @State private var showAUSendsSheet: Bool = false

    // Whether to show the internal toolbar (hide when embedded in tab)
    var showToolbar: Bool = true

    // Timer for meter updates
    @State private var meterTimer: Timer? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Mixer toolbar (optional - hidden when in tab container)
            if showToolbar {
                mixerToolbar

                Divider()
                    .background(ColorPalette.divider)
            }

            // Main mixer content
            HStack(spacing: 0) {
                // Channel strips
                channelStripsSection

                // Divider before master
                Rectangle()
                    .fill(ColorPalette.divider)
                    .frame(width: 2)

                // Master section
                masterSection
            }
        }
        .background(ColorPalette.backgroundPrimary)
        .sheet(isPresented: $showAUSendsSheet) {
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Text("AU SEND EFFECTS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Done") {
                        showAUSendsSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ColorPalette.backgroundSecondary)

                Divider().background(ColorPalette.divider)

                AUSendEffectsView()
                    .environmentObject(audioEngine)
                    .environmentObject(pluginManager)
            }
            .frame(minWidth: 460, minHeight: 300)
            .background(ColorPalette.backgroundPrimary)
        }
        .onAppear {
            mixerState.syncToAudioEngine(audioEngine)
            startMeterUpdates()
        }
        .onDisappear {
            stopMeterUpdates()
        }
        .onChange(of: mixerState.channels.map { $0.gain }) { _ in
            mixerState.syncToAudioEngine(audioEngine)
        }
        .onChange(of: mixerState.channels.map { $0.pan }) { _ in
            mixerState.syncToAudioEngine(audioEngine)
        }
        .onChange(of: mixerState.channels.map { $0.sendA.level }) { _ in
            mixerState.syncToAudioEngine(audioEngine)
        }
        .onChange(of: mixerState.channels.map { $0.sendB.level }) { _ in
            mixerState.syncToAudioEngine(audioEngine)
        }
        .onChange(of: mixerState.channels.map { $0.isMuted }) { _ in
            mixerState.syncToAudioEngine(audioEngine)
        }
        .onChange(of: mixerState.channels.map { $0.isSolo }) { _ in
            mixerState.syncToAudioEngine(audioEngine)
        }
        .onChange(of: mixerState.master.gain) { _ in
            mixerState.syncMasterToEngine(audioEngine)
        }
        .onChange(of: mixerState.master.delayReturnLevel) { _ in
            mixerState.syncMasterToEngine(audioEngine)
        }
        .onChange(of: mixerState.master.reverbReturnLevel) { _ in
            mixerState.syncMasterToEngine(audioEngine)
        }
    }

    // MARK: - Meter Update Timer

    private func startMeterUpdates() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { _ in
            Task { @MainActor in
                mixerState.updateMetersFromEngine(audioEngine)
            }
        }
    }

    private func stopMeterUpdates() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    // MARK: - Toolbar

    private var mixerToolbar: some View {
        HStack(spacing: 12) {
            Text("MIXER")
                .font(Typography.panelTitle)
                .foregroundColor(ColorPalette.textPrimary)

            Spacer()

            // Layout mode selector
            SegmentedButtonGroup(
                selection: $layoutMode,
                options: [
                    (.full, "Full"),
                    (.compact, "Compact"),
                    (.collapsed, "Mini")
                ],
                accentColor: ColorPalette.ledBlue
            )

            // Effects returns toggle
            Toggle(isOn: $showEffectsReturns) {
                Text("FX")
                    .font(Typography.buttonSmall)
            }
            .toggleStyle(.button)
            .tint(ColorPalette.ledAmber)

            Button(action: { showAUSendsSheet = true }) {
                Text("AU SENDS")
                    .font(Typography.buttonSmall)
                    .foregroundColor(ColorPalette.ledBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.backgroundTertiary)
                    )
            }
            .buttonStyle(.plain)

            // Reset all
            Button(action: { mixerState.resetAll() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12))
                    .foregroundColor(ColorPalette.textMuted)
            }
            .buttonStyle(.plain)
            .help("Reset all mixer settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ColorPalette.backgroundSecondary)
    }

    // MARK: - Channel Strips Section

    private var channelStripsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(mixerState.channels) { channel in
                    channelView(for: channel)
                }

                // Effects returns (optional)
                if showEffectsReturns {
                    effectsReturnsSection
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func channelView(for channel: MixerChannelState) -> some View {
        switch layoutMode {
        case .full:
            ProChannelStripView(channel: channel, isCompact: false, showInserts: false)
        case .compact:
            ProChannelStripView(channel: channel, isCompact: true, showInserts: false)
        case .collapsed:
            CollapsedChannelView(channel: channel)
        }
    }

    // MARK: - Effects Returns Section

    private var effectsReturnsSection: some View {
        VStack(spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Text("FX RTN")
                    .font(Typography.parameterLabelSmall)
                    .foregroundColor(ColorPalette.textDimmed)

                if !showToolbar {
                    Spacer(minLength: 4)

                    Button(action: { showAUSendsSheet = true }) {
                        Text("AU SENDS")
                            .font(Typography.buttonTiny)
                            .foregroundColor(ColorPalette.ledBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(ColorPalette.backgroundTertiary)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)

            HStack(spacing: 4) {
                // Delay return
                EffectReturnStripView(
                    name: "DELAY",
                    level: $mixerState.master.delayReturnLevel,
                    accentColor: ColorPalette.ledAmber,
                    isCompact: layoutMode != .full
                )

                // Reverb return
                EffectReturnStripView(
                    name: "REVERB",
                    level: $mixerState.master.reverbReturnLevel,
                    accentColor: ColorPalette.ledGreen,
                    isCompact: layoutMode != .full
                )
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Master Section

    private var masterSection: some View {
        ProMasterStripView(
            master: mixerState.master,
            showNeedleMeter: layoutMode == .full
        )
        .padding(.horizontal, 4)
    }
}

// MARK: - Collapsed Channel View

struct CollapsedChannelView: View {
    @ObservedObject var channel: MixerChannelState

    var body: some View {
        VStack(spacing: 4) {
            // Mini meter
            VUMeterBarView(
                level: .constant(channel.meterLevel),
                segments: 6,
                width: 6,
                height: 30
            )

            // Channel indicator
            Circle()
                .fill(channel.isMuted ? ColorPalette.ledOff : channel.accentColor)
                .frame(width: 8, height: 8)

            // Mini mute button
            Button(action: { channel.isMuted.toggle() }) {
                Text("M")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(channel.isMuted ? .white : ColorPalette.textDimmed)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(channel.isMuted ? ColorPalette.ledRed : ColorPalette.ledOff)
                    )
            }
            .buttonStyle(.plain)

            // Channel short name
            Text(channel.channelType.shortName)
                .font(.system(size: 6, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)
        }
        .frame(width: 24)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(ColorPalette.backgroundSecondary)
        )
    }
}

// MARK: - Effect Return Strip View

struct EffectReturnStripView: View {
    let name: String
    @Binding var level: Float
    let accentColor: Color
    let isCompact: Bool

    var body: some View {
        VStack(spacing: 4) {
            // Name
            Text(name)
                .font(Typography.parameterLabelSmall)
                .foregroundColor(accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if !isCompact {
                // Level knob
                ProKnobView(
                    value: $level,
                    label: "RTN",
                    accentColor: accentColor,
                    size: .small
                )
            } else {
                // Mini fader
                ProFaderView(
                    value: $level,
                    accentColor: accentColor,
                    size: .small,
                    showScale: false
                )
            }
        }
        .frame(width: isCompact ? 30 : 50)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(ColorPalette.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct NewMixerView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @StateObject private var mixerState = MixerState()
        @StateObject private var audioEngine = AudioEngineWrapper()
        @StateObject private var pluginManager = AUPluginManager()

        var body: some View {
            NewMixerView(mixerState: mixerState)
                .environmentObject(audioEngine)
                .environmentObject(pluginManager)
                .frame(height: 300)
                .onAppear {
                    // Set up some test values
                    mixerState.channels[0].meterLevel = 0.6
                    mixerState.channels[0].gain = 0.7
                    mixerState.channels[1].meterLevel = 0.4
                    mixerState.channels[1].isSolo = true
                    mixerState.channels[2].meterLevel = 0.8
                    mixerState.channels[2].isMuted = true
                    mixerState.master.meterLevelL = 0.5
                    mixerState.master.meterLevelR = 0.55
                }
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
#endif

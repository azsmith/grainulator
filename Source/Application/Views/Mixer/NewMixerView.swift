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

            // Main mixer content (vertical scroll if space is tight)
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
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
                    Button(action: { showAUSendsSheet = false }) {
                        Text("Done")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.white.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
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
            HStack(alignment: .top, spacing: 4) {
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
        HStack(alignment: .top, spacing: 4) {
            // Thin separator between channels and FX returns
            Rectangle()
                .fill(ColorPalette.divider)
                .frame(width: 1)
                .padding(.vertical, 8)

            // Delay return (Send A)
            FXReturnChannelStripView(
                name: "DELAY",
                shortName: "DLY",
                level: $mixerState.master.delayReturnLevel,
                accentColor: ColorPalette.ledAmber,
                isCompact: layoutMode != .full,
                isCollapsed: layoutMode == .collapsed,
                onAUSendsPressed: !showToolbar ? { showAUSendsSheet = true } : nil
            )

            // Reverb return (Send B)
            FXReturnChannelStripView(
                name: "REVERB",
                shortName: "RVB",
                level: $mixerState.master.reverbReturnLevel,
                accentColor: ColorPalette.ledGreen,
                isCompact: layoutMode != .full,
                isCollapsed: layoutMode == .collapsed,
                onAUSendsPressed: nil
            )
        }
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

// MARK: - FX Return Channel Strip View

struct FXReturnChannelStripView: View {
    let name: String
    let shortName: String
    @Binding var level: Float
    let accentColor: Color
    let isCompact: Bool
    let isCollapsed: Bool
    let onAUSendsPressed: (() -> Void)?

    @State private var isMuted: Bool = false

    /// Effective level considering mute
    private var effectiveLevel: Float {
        isMuted ? 0 : level
    }

    /// dB value for display
    private var levelDB: String {
        if level < 0.001 { return "-\u{221E}" }
        let linearGain = level * 2  // 0.5 = unity
        let db = 20 * log10(Double(linearGain))
        if db > 0 {
            return String(format: "+%.1f", db)
        }
        return String(format: "%.1f", db)
    }

    var body: some View {
        if isCollapsed {
            collapsedLayout
        } else if isCompact {
            compactLayout
        } else {
            fullLayout
        }
    }

    // MARK: - Full Layout
    // Mirrors ProChannelStripView full layout structure:
    // header → divider → [pan area] → [send area] → divider → fader → buttons
    // FX strips use the pan/send area for FX label + AU button instead.

    private var fullLayout: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                // Channel header (matches channelHeader in ProChannelStripView)
                fxHeader

                Divider()
                    .background(ColorPalette.divider)

                // FX info area (occupies the space where pan + sends would be)
                fxInfoSection

                Divider()
                    .background(ColorPalette.divider)

                // Fader with VU meter (identical to ProChannelStripView)
                faderSection

                // Mute button
                buttonSection
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .frame(width: 70)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorPalette.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ColorPalette.divider, lineWidth: 1)
        )
        .overlay(
            // Left accent stripe — visual differentiator from regular channels
            HStack {
                RoundedRectangle(cornerRadius: 1)
                    .fill(accentColor)
                    .frame(width: 3)
                Spacer()
            },
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// Fills the vertical space where pan knob + send knobs live on regular channels.
    /// Uses hidden replicas of the exact same components so SwiftUI gives identical height.
    private var fxInfoSection: some View {
        ZStack {
            // Hidden replica of panSection + sendSection from ProChannelStripView
            // This ensures pixel-perfect height matching.
            VStack(spacing: 6) {
                // panSection replica: VStack(spacing: 2) { ProKnobView.pan(.small) }
                VStack(spacing: 2) {
                    ProKnobView.pan(
                        value: .constant(0.5),
                        accentColor: .clear,
                        size: .small
                    )
                }

                // sendSection replica: HStack(spacing: 4) { two VStack(spacing: 1) with knob + label }
                HStack(spacing: 4) {
                    VStack(spacing: 1) {
                        ProKnobView(
                            value: .constant(0.5),
                            label: "A",
                            accentColor: .clear,
                            size: .small,
                            showValue: false
                        )
                        Text("Post")
                            .font(Typography.parameterLabelSmall)
                    }

                    VStack(spacing: 1) {
                        ProKnobView(
                            value: .constant(0.5),
                            label: "B",
                            accentColor: .clear,
                            size: .small,
                            showValue: false
                        )
                        Text("Post")
                            .font(Typography.parameterLabelSmall)
                    }
                }
            }
            .hidden()

            // Visible FX content overlaid on the hidden spacer
            VStack(spacing: 8) {
                // FX Return badge
                Text("FX RTN")
                    .font(Typography.buttonSmall)
                    .foregroundColor(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(accentColor.opacity(0.1))
                    )

                // Effect type label
                Text(name)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor.opacity(0.6))

                // AU Sends button (if provided)
                if let action = onAUSendsPressed {
                    Button(action: action) {
                        Text("AU SEND")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(ColorPalette.ledBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(ColorPalette.backgroundTertiary)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Compact Layout

    private var compactLayout: some View {
        VStack(spacing: 4) {
            // Mini channel name
            HStack(spacing: 3) {
                Text("FX")
                    .font(.system(size: 6, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .background(accentColor)
                    .cornerRadius(2)

                Text(shortName)
                    .font(Typography.parameterLabelSmall)
                    .foregroundColor(accentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .background(ColorPalette.backgroundPrimary)

            // Compact fader with meter alongside
            HStack(spacing: 1) {
                VUMeterBarView(
                    level: .constant(isMuted ? 0 : level * 0.6),
                    segments: 8,
                    width: 4,
                    height: 60
                )

                ProFaderView(
                    value: $level,
                    accentColor: accentColor,
                    size: .small,
                    showScale: false,
                    isMuted: isMuted
                )
            }

            // Mini mute
            MuteButton(isMuted: $isMuted, size: .small)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .frame(width: 50)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorPalette.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ColorPalette.divider, lineWidth: 1)
        )
        .overlay(
            HStack {
                RoundedRectangle(cornerRadius: 1)
                    .fill(accentColor)
                    .frame(width: 2)
                Spacer()
            },
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Collapsed Layout

    private var collapsedLayout: some View {
        VStack(spacing: 4) {
            // Mini meter
            VUMeterBarView(
                level: .constant(isMuted ? 0 : level * 0.6),
                segments: 6,
                width: 6,
                height: 30
            )

            // FX indicator
            Text("FX")
                .font(.system(size: 6, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
                .background(accentColor)
                .cornerRadius(2)

            // Mini mute button
            Button(action: { isMuted.toggle() }) {
                Text("M")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(isMuted ? .white : ColorPalette.textDimmed)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(isMuted ? ColorPalette.ledRed : ColorPalette.ledOff)
                    )
            }
            .buttonStyle(.plain)

            // Channel short name
            Text(shortName)
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

    // MARK: - FX Header

    /// Matches ProChannelStripView.channelHeader height exactly.
    private var fxHeader: some View {
        VStack(spacing: 2) {
            // Matches HStack(spacing: 4) { Circle(6x6), PeakLEDView(8x8) }
            HStack(spacing: 4) {
                Circle()
                    .fill(isMuted ? ColorPalette.ledOff : accentColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: isMuted ? .clear : accentColor.opacity(0.5), radius: 3)

                // FX badge — constrained to same 8px height as PeakLEDView
                Text("FX")
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .frame(height: 8)
                    .background(accentColor.opacity(isMuted ? 0.4 : 1.0))
                    .cornerRadius(2)
            }

            // Channel name
            Text(name)
                .font(Typography.channelLabel)
                .foregroundColor(isMuted ? ColorPalette.textDimmed : accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(ColorPalette.backgroundPrimary)
    }

    // MARK: - Fader Section

    private var faderSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                // VU meter alongside fader
                VUMeterBarView(
                    level: .constant(isMuted ? 0 : level * 0.6),
                    segments: 10,
                    width: 5,
                    height: 80
                )

                ProFaderView(
                    value: $level,
                    accentColor: accentColor,
                    size: .medium,
                    showScale: false,
                    isMuted: isMuted
                )
            }

            // dB display
            Text(levelDB)
                .font(Typography.valueSmall)
                .foregroundColor(isMuted ? ColorPalette.textDimmed : accentColor)
                .monospacedDigit()
                .frame(width: 40)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ColorPalette.backgroundPrimary)
                )
        }
    }

    // MARK: - Button Section

    private var buttonSection: some View {
        MuteButton(isMuted: $isMuted, size: .medium)
            .padding(.top, 4)
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

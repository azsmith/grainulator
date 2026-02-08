//
//  NewMixerView.swift
//  Grainulator
//
//  Modular mixer view with 8 voice channels, 2 FX return channels, and master
//

import SwiftUI

// MARK: - New Mixer View

struct NewMixerView: View {
    @ObservedObject var mixerState: MixerState
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var pluginManager: AUPluginManager
    @State private var showAUSendsSheet: Bool = false

    // Whether to show the internal toolbar (unused now but kept for API compat)
    var showToolbar: Bool = true

    // Timer for meter updates
    @State private var meterTimer: Timer? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Main mixer content
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    // Channel strips (8 voices + 2 FX returns)
                    channelStripsSection

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

    // MARK: - Channel Strips Section

    private var channelStripsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 4) {
                // 8 voice channels
                ForEach(mixerState.channels) { channel in
                    ProChannelStripView(channel: channel, isCompact: false, showInserts: false)
                }

                // Separator between voice channels and FX returns
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
                    onAUSendsPressed: { showAUSendsSheet = true }
                )

                // Reverb return (Send B)
                FXReturnChannelStripView(
                    name: "REVERB",
                    shortName: "RVB",
                    level: $mixerState.master.reverbReturnLevel,
                    accentColor: ColorPalette.ledGreen,
                    onAUSendsPressed: { showAUSendsSheet = true }
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Master Section

    private var masterSection: some View {
        ProMasterStripView(
            master: mixerState.master,
            showNeedleMeter: true
        )
        .padding(.horizontal, 4)
    }
}

// MARK: - FX Return Channel Strip View

struct FXReturnChannelStripView: View {
    let name: String
    let shortName: String
    @Binding var level: Float
    let accentColor: Color
    let onAUSendsPressed: () -> Void

    @State private var isMuted: Bool = false

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
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                // Channel header
                fxHeader

                Divider()
                    .background(ColorPalette.divider)

                // FX info area (occupies pan + sends space)
                fxInfoSection

                Divider()
                    .background(ColorPalette.divider)

                // Fader with VU meter
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
            // Left accent stripe
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

    /// Fills the vertical space where pan + sends live on regular channels.
    private var fxInfoSection: some View {
        ZStack {
            // Hidden replica of panSection + sendSection for height matching
            VStack(spacing: 6) {
                VStack(spacing: 2) {
                    ProKnobView.pan(
                        value: .constant(0.5),
                        accentColor: .clear,
                        size: .small
                    )
                }

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

            // Visible FX content
            VStack(spacing: 6) {
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

                // AU Sends button
                Button(action: onAUSendsPressed) {
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

    // MARK: - FX Header

    private var fxHeader: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(isMuted ? ColorPalette.ledOff : accentColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: isMuted ? .clear : accentColor.opacity(0.5), radius: 3)

                Text("FX")
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .frame(height: 8)
                    .background(accentColor.opacity(isMuted ? 0.4 : 1.0))
                    .cornerRadius(2)
            }

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
                VUMeterBarView(
                    level: .constant(isMuted ? 0 : level * 0.6),
                    segments: 10,
                    width: 5,
                    height: 120
                )

                ProFaderView(
                    value: $level,
                    accentColor: accentColor,
                    size: .xlarge,
                    showScale: false,
                    isMuted: isMuted
                )
            }

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
                .frame(height: 400)
                .onAppear {
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

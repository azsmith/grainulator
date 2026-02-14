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
    @EnvironmentObject var vst3PluginHost: VST3PluginHost
    // showAUSendsSheet removed — send plugin UI now inline via popover on FX return strips

    // Whether to show the internal toolbar (unused now but kept for API compat)
    var showToolbar: Bool = true

    // Timer for meter updates
    @State private var meterTimer: Timer? = nil

    // Display order: Gran 2 next to Gran 1 (engine channel 5 after channel 2)
    private static let channelDisplayOrder: [ChannelType] = [
        .plaits, .rings, .granular1, .granular2, .looper1, .looper2, .daisyDrum, .sampler
    ]

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
                // 8 voice channels (Gran 2 next to Gran 1)
                ForEach(Self.channelDisplayOrder) { channelType in
                    ProChannelStripView(
                        channel: mixerState.channel(for: channelType),
                        isCompact: false,
                        showInserts: true,
                        audioEngine: audioEngine,
                        pluginManager: pluginManager,
                        vst3PluginHost: vst3PluginHost
                    )
                }

                // Separator between voice channels and FX returns
                Rectangle()
                    .fill(ColorPalette.divider)
                    .frame(width: 1)
                    .padding(.vertical, 8)

                // Delay return (Send A)
                FXReturnChannelStripView(
                    busIndex: 0,
                    name: "DELAY",
                    shortName: "DLY",
                    level: $mixerState.master.delayReturnLevel,
                    accentColor: ColorPalette.ledAmber
                )

                // Reverb return (Send B)
                FXReturnChannelStripView(
                    busIndex: 1,
                    name: "REVERB",
                    shortName: "RVB",
                    level: $mixerState.master.reverbReturnLevel,
                    accentColor: ColorPalette.ledGreen
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
            audioEngine: audioEngine,
            showNeedleMeter: true
        )
        .padding(.horizontal, 4)
    }
}

// MARK: - FX Return Channel Strip View

struct FXReturnChannelStripView: View {
    let busIndex: Int
    let name: String
    let shortName: String
    @Binding var level: Float
    let accentColor: Color

    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var pluginManager: AUPluginManager
    @EnvironmentObject var vst3PluginHost: VST3PluginHost

    @State private var isMuted: Bool = false
    @State private var showSendPopover: Bool = false

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
        let slotData = audioEngine.getSendSlotData(busIndex: busIndex)

        return ZStack {
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

                // Send plugin slot indicator (mirrors insert slot style)
                sendSlotIndicator(slotData: slotData)
                    .popover(isPresented: $showSendPopover, arrowEdge: .trailing) {
                        FXSendPopoverView(busIndex: busIndex, accentColor: accentColor)
                            .environmentObject(audioEngine)
                            .environmentObject(pluginManager)
                            .environmentObject(vst3PluginHost)
                    }
            }
        }
    }

    /// Compact send slot indicator — shows "—" when empty, abbreviated plugin name when loaded.
    private func sendSlotIndicator(slotData: SendSlotData) -> some View {
        let slotText: String = {
            if slotData.isLoading { return "..." }
            guard slotData.hasPlugin else { return "—" }
            let name = slotData.pluginName ?? slotData.pluginDescriptor?.name ?? ""
            if name.count <= 3 { return name.uppercased() }
            return String(name.prefix(3)).uppercased()
        }()

        let slotColor: Color = {
            guard slotData.hasPlugin else { return ColorPalette.ledOff }
            return slotData.isBypassed ? ColorPalette.ledAmber : accentColor
        }()

        let textColor: Color = slotData.hasPlugin ? .white : ColorPalette.textDimmed

        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(slotColor)
                .frame(maxWidth: .infinity)
                .frame(height: 20)

            if slotData.isLoading {
                ProgressView()
                    .scaleEffect(0.4)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text(slotText)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(textColor)
            }
        }
        .shadow(color: slotData.hasPlugin && !slotData.isBypassed ? accentColor.opacity(0.3) : .clear, radius: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            DispatchQueue.main.async {
                showSendPopover.toggle()
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

// MARK: - FX Send Popover

/// Popover for managing the send bus plugin — mirrors insert popover pattern.
struct FXSendPopoverView: View {
    let busIndex: Int
    let accentColor: Color

    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var pluginManager: AUPluginManager
    @EnvironmentObject var vst3PluginHost: VST3PluginHost

    @State private var showBrowser = false

    private var isVST3: Bool { audioEngine.pluginHostBackend == .vst3 }

    var body: some View {
        let slotData = audioEngine.getSendSlotData(busIndex: busIndex)

        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("SEND \(busIndex == 0 ? "A" : "B")")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)

                Spacer()

                Text(isVST3 ? "VST3" : "AU")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(isVST3 ? ColorPalette.ledBlue : ColorPalette.ledGreen)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ColorPalette.backgroundTertiary)
                    )
            }

            Divider()
                .background(ColorPalette.divider)

            // Plugin slot
            if slotData.hasPlugin {
                loadedSlotView(slotData: slotData)
            } else {
                emptySlotView
            }

            // Return level
            returnLevelSection(slotData: slotData)
        }
        .padding(16)
        .frame(width: 280)
        .background(ColorPalette.backgroundSecondary)
        .sheet(isPresented: $showBrowser) {
            if isVST3 {
                AUPluginBrowserView(
                    isPresented: $showBrowser,
                    vst3Plugins: vst3PluginHost.scannedPlugins,
                    onVST3Select: { [audioEngine, vst3PluginHost] descriptor in
                        Task { @MainActor in
                            try? await audioEngine.loadVST3Send(descriptor, busIndex: busIndex, using: vst3PluginHost)
                        }
                    }
                )
                .environmentObject(pluginManager)
            } else {
                AUPluginBrowserView(
                    isPresented: $showBrowser,
                    onSelect: { [audioEngine, pluginManager] plugin in
                        Task { @MainActor in
                            try? await audioEngine.loadSendPlugin(plugin, busIndex: busIndex, using: pluginManager)
                        }
                    }
                )
                .environmentObject(pluginManager)
            }
        }
    }

    private func loadedSlotView(slotData: SendSlotData) -> some View {
        let displayName = slotData.pluginInfo?.name ?? slotData.pluginDescriptor?.name ?? slotData.pluginName ?? "Plugin"
        let displayManufacturer = slotData.pluginInfo?.manufacturerName ?? slotData.pluginDescriptor?.manufacturerName ?? ""
        let displayCategory = slotData.pluginInfo?.category ?? slotData.pluginDescriptor?.category
        let displayHasCustomView = slotData.pluginInfo?.hasCustomView ?? slotData.pluginDescriptor?.hasCustomView ?? false

        return VStack(alignment: .leading, spacing: 8) {
            // Slot header with bypass
            HStack {
                Text("SEND EFFECT")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textMuted)

                Spacer()

                Button(action: { [audioEngine] in
                    audioEngine.toggleSendBypass(busIndex: busIndex)
                }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(slotData.isBypassed ? ColorPalette.ledAmber : ColorPalette.ledGreen)
                            .frame(width: 8, height: 8)
                        Text(slotData.isBypassed ? "BYP" : "ON")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(slotData.isBypassed ? ColorPalette.ledAmber : ColorPalette.ledGreen)
                    }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                // Plugin icon
                RoundedRectangle(cornerRadius: 4)
                    .fill(displayCategory?.color ?? accentColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: displayCategory?.iconName ?? "waveform")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    )

                // Plugin name
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(displayManufacturer)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                        .lineLimit(1)
                }

                Spacer()

                VStack(spacing: 4) {
                    // Open editor
                    if displayHasCustomView {
                        Button(action: { openPluginEditor() }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 10))
                                .foregroundColor(ColorPalette.ledBlue)
                        }
                        .buttonStyle(.plain)
                    }

                    // Remove
                    Button(action: { [audioEngine, vst3PluginHost] in
                        audioEngine.unloadSendPlugin(busIndex: busIndex, vst3Host: vst3PluginHost)
                    }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 10))
                            .foregroundColor(ColorPalette.ledRed)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Change button
            Button(action: { showBrowser = true }) {
                Text("Change Plugin...")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(ColorPalette.textMuted)
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

    private var emptySlotView: some View {
        Button(action: { showBrowser = true }) {
            HStack {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12))
                    .foregroundColor(ColorPalette.textDimmed)

                Text("Select Plugin...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(ColorPalette.textDimmed)

                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(ColorPalette.divider, style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
        .buttonStyle(.plain)
    }

    private func returnLevelSection(slotData: SendSlotData) -> some View {
        HStack(spacing: 8) {
            Text("RETURN")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)

            ProKnobView(
                value: Binding(
                    get: { slotData.returnLevel },
                    set: { value in
                        Task { @MainActor [audioEngine] in
                            audioEngine.setSendReturnLevel(busIndex: busIndex, level: value)
                        }
                    }
                ),
                label: "",
                accentColor: accentColor,
                size: .small,
                showValue: false
            )

            Text(returnLevelDB(slotData.returnLevel))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(accentColor)
                .monospacedDigit()
                .frame(width: 36)
        }
    }

    private func returnLevelDB(_ returnLevel: Float) -> String {
        if returnLevel < 0.001 { return "-\u{221E}" }
        let linearGain = returnLevel * 2
        let db = 20 * log10(Double(linearGain))
        return db > 0 ? String(format: "+%.1f", db) : String(format: "%.1f", db)
    }

    private func openPluginEditor() {
        if isVST3 {
            guard busIndex < audioEngine.vst3SendSlots.count,
                  let instance = audioEngine.vst3SendSlots[busIndex].instance as? VST3PluginInstanceWrapper else { return }
            let pluginName = instance.descriptor.name
            instance.requestViewController { vc in
                guard let vc else { return }
                AUPluginWindowManager.shared.open(
                    viewController: vc,
                    title: pluginName,
                    subtitle: "Send \(busIndex == 0 ? "A" : "B")",
                    key: "vst3-send-\(busIndex)"
                )
            }
        } else if let audioUnit = audioEngine.getSendAudioUnit(busIndex: busIndex) {
            let slotData = audioEngine.getSendSlotData(busIndex: busIndex)
            AUPluginWindowManager.shared.open(
                audioUnit: audioUnit,
                title: slotData.pluginInfo?.name ?? "Plugin",
                subtitle: slotData.pluginInfo?.manufacturerName ?? "",
                key: "send-\(busIndex)"
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NewMixerView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @StateObject private var mixerState = MixerState()
        @StateObject private var audioEngine = AudioEngineWrapper()
        @StateObject private var pluginManager = AUPluginManager()
        @StateObject private var vst3PluginHost = VST3PluginHost(sampleRate: 48000, maxBlockSize: 2048)

        var body: some View {
            NewMixerView(mixerState: mixerState)
                .environmentObject(audioEngine)
                .environmentObject(pluginManager)
                .environmentObject(vst3PluginHost)
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

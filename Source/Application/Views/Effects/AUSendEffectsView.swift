//
//  AUSendEffectsView.swift
//  Grainulator
//
//  AU plugin send effects section (delay/reverb)
//  Replaces built-in effects with AU plugin hosting
//
//  NOTE: This file carefully avoids using @ObservedObject with AUSendSlot
//  to prevent crashes in SwiftUI's gesture handling during view hierarchy changes.
//  All slot access goes through AudioEngineWrapper using bus indices.
//

import SwiftUI
import AVFoundation

// MARK: - AU Send Effects View

/// Main view for send effects (delay/reverb) using AU plugins
struct AUSendEffectsView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var pluginManager: AUPluginManager

    var body: some View {
        HStack(spacing: 16) {
            // Delay send - use index-based access
            AUSendEffectCardByIndex(
                busIndex: 0,
                title: "DELAY",
                accentColor: ColorPalette.ledAmber
            )

            Divider()
                .background(ColorPalette.divider)

            // Reverb send - use index-based access
            AUSendEffectCardByIndex(
                busIndex: 1,
                title: "REVERB",
                accentColor: ColorPalette.ledGreen
            )
        }
        .padding(16)
        .background(ColorPalette.backgroundSecondary)
    }
}

// MARK: - AU Send Effect Card (Index-Based)

/// Send effect card that accesses slot data through audioEngine using bus index
struct AUSendEffectCardByIndex: View {
    let busIndex: Int
    let title: String
    let accentColor: Color

    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var pluginManager: AUPluginManager
    @EnvironmentObject var vst3PluginHost: VST3PluginHost

    @State private var showBrowser = false
    @State private var editFailed = false

    private var isVST3: Bool { audioEngine.pluginHostBackend == .vst3 }

    var body: some View {
        let slotData = audioEngine.getSendSlotData(busIndex: busIndex)

        VStack(spacing: 12) {
            // Header
            headerView(slotData: slotData)

            Divider()
                .background(ColorPalette.divider.opacity(0.5))

            // Plugin slot
            pluginSlotView(slotData: slotData)

            Divider()
                .background(ColorPalette.divider.opacity(0.5))

            // Return level
            returnLevelSection(slotData: slotData)
        }
        .padding(12)
        .frame(minWidth: 180)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorPalette.backgroundPrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
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
                    onSelect: { plugin in
                        Task { @MainActor [audioEngine, pluginManager] in
                            try? await audioEngine.loadSendPlugin(plugin, busIndex: busIndex, using: pluginManager)
                        }
                    }
                )
                .environmentObject(pluginManager)
            }
        }
        .onDisappear {
            showBrowser = false
        }
    }

    // MARK: - Header

    private func headerView(slotData: SendSlotData) -> some View {
        HStack {
            // Send type icon
            Image(systemName: busIndex == 0 ? "clock" : "waveform.badge.plus")
                .font(.system(size: 12))
                .foregroundColor(accentColor)

            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(accentColor)

            Spacer()

                // Bypass toggle
                if slotData.hasPlugin {
                    Text(slotData.isBypassed ? "BYP" : "ON")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(slotData.isBypassed ? ColorPalette.ledAmber : ColorPalette.ledGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(slotData.isBypassed ? ColorPalette.ledAmber.opacity(0.2) : ColorPalette.ledGreen.opacity(0.2))
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { [audioEngine] in
                        Task { @MainActor [audioEngine] in
                            audioEngine.toggleSendBypass(busIndex: busIndex)
                        }
                    }
            }
        }
    }

    // MARK: - Plugin Slot

    private func pluginSlotView(slotData: SendSlotData) -> some View {
        Group {
            if slotData.hasPlugin {
                loadedPluginView(slotData: slotData)
            } else {
                emptySlotView
            }
        }
    }

    /// Display name for the loaded plugin (works for both AU and VST3)
    private func pluginDisplayName(_ slotData: SendSlotData) -> String {
        slotData.pluginInfo?.name ?? slotData.pluginDescriptor?.name ?? slotData.pluginName ?? "Plugin"
    }

    /// Display manufacturer for the loaded plugin (works for both AU and VST3)
    private func pluginDisplayManufacturer(_ slotData: SendSlotData) -> String {
        slotData.pluginInfo?.manufacturerName ?? slotData.pluginDescriptor?.manufacturerName ?? ""
    }

    private func loadedPluginView(slotData: SendSlotData) -> some View {
        let name = pluginDisplayName(slotData)
        let manufacturer = pluginDisplayManufacturer(slotData)

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Plugin icon
                RoundedRectangle(cornerRadius: 4)
                    .fill(slotData.pluginInfo?.category?.color ?? accentColor)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: slotData.pluginInfo?.category?.iconName ?? "waveform")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    )

                // Plugin info
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(manufacturer)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                        .lineLimit(1)
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 8) {
                Spacer(minLength: 0)

                // Change plugin button
                Text("Change")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(ColorPalette.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ColorPalette.backgroundTertiary)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showBrowser = true
                    }

                // Remove button
                Image(systemName: "xmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(ColorPalette.ledRed.opacity(0.7))
                    .contentShape(Rectangle())
                    .onTapGesture { [audioEngine, vst3PluginHost] in
                        Task { @MainActor [audioEngine, vst3PluginHost] in
                            audioEngine.unloadSendPlugin(busIndex: busIndex, vst3Host: vst3PluginHost)
                        }
                    }
            }

            // Edit button to open plugin's native UI
            Text(editFailed ? "No plugin UI" : "Edit")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(editFailed ? ColorPalette.ledRed : accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(editFailed ? ColorPalette.ledRed.opacity(0.15) : accentColor.opacity(0.15))
                )
                .contentShape(Rectangle())
                .onTapGesture { [audioEngine, vst3PluginHost] in
                    if isVST3 {
                        // VST3 editor path
                        guard busIndex < audioEngine.vst3SendSlots.count,
                              let instance = audioEngine.vst3SendSlots[busIndex].instance as? VST3PluginInstanceWrapper else {
                            editFailed = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { editFailed = false }
                            return
                        }
                        let pluginName = instance.descriptor.name
                        instance.requestViewController { vc in
                            guard let vc else {
                                DispatchQueue.main.async {
                                    editFailed = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { editFailed = false }
                                }
                                return
                            }
                            let key = "vst3-send-\(busIndex)"
                            AUPluginWindowManager.shared.open(
                                viewController: vc,
                                title: pluginName,
                                subtitle: "Send \(busIndex == 0 ? "A" : "B")",
                                key: key
                            )
                        }
                    } else {
                        // AU editor path
                        if let audioUnit = audioEngine.getSendAudioUnit(busIndex: busIndex) {
                            editFailed = false
                            let slotData = audioEngine.getSendSlotData(busIndex: busIndex)
                            let pluginName = slotData.pluginInfo?.name ?? "Plugin"
                            let manufacturer = slotData.pluginInfo?.manufacturerName ?? ""
                            AUPluginWindowManager.shared.open(
                                audioUnit: audioUnit,
                                title: pluginName,
                                subtitle: manufacturer,
                                key: "send-\(busIndex)"
                            )
                        } else {
                            let slotData = audioEngine.getSendSlotData(busIndex: busIndex)
                            print("Edit failed: getSendAudioUnit(\(busIndex)) returned nil — hasPlugin=\(slotData.hasPlugin), pluginName=\(slotData.pluginName ?? "nil")")
                            editFailed = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                editFailed = false
                            }
                        }
                    }
                }
        }
    }

    private var emptySlotView: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 24))
                .foregroundColor(ColorPalette.textDimmed)

            Text("Select \(title.capitalized) Plugin")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ColorPalette.divider, style: StrokeStyle(lineWidth: 1, dash: [6]))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showBrowser = true
        }
    }

    // MARK: - Return Level

    private func returnLevelSection(slotData: SendSlotData) -> some View {
        VStack(spacing: 4) {
            Text("RETURN")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)

            HStack(spacing: 8) {
                // Return level knob - bind directly to slot through audioEngine
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

                // dB display
                Text(returnLevelDB(slotData.returnLevel))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(accentColor)
                    .monospacedDigit()
                    .frame(width: 36)
            }
        }
    }

    private func returnLevelDB(_ returnLevel: Float) -> String {
        if returnLevel < 0.001 { return "-∞" }
        let linearGain = returnLevel * 2  // 0.5 = unity
        let db = 20 * log10(Double(linearGain))
        if db > 0 {
            return String(format: "+%.1f", db)
        }
        return String(format: "%.1f", db)
    }
}

// AUSendPluginWindowViewByIndex removed — send plugin UIs now open in native NSPanel
// windows via AUPluginWindowManager for reliable sizing and re-opening.

// MARK: - Compact Send Effects Strip

/// Compact version for display in mixer footer
struct CompactAUSendEffectsView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    var body: some View {
        HStack(spacing: 16) {
            // Delay
            CompactSendIndicatorByIndex(
                busIndex: 0,
                title: "DLY",
                accentColor: ColorPalette.ledAmber
            )

            // Reverb
            CompactSendIndicatorByIndex(
                busIndex: 1,
                title: "REV",
                accentColor: ColorPalette.ledGreen
            )
        }
    }
}

/// Compact send indicator using bus index
struct CompactSendIndicatorByIndex: View {
    let busIndex: Int
    let title: String
    let accentColor: Color

    @EnvironmentObject var audioEngine: AudioEngineWrapper

    var body: some View {
        let slotData = audioEngine.getSendSlotData(busIndex: busIndex)

        HStack(spacing: 6) {
            // Activity LED
            Circle()
                .fill(slotData.hasPlugin ? (slotData.isBypassed ? ColorPalette.ledAmber : accentColor) : ColorPalette.ledOff)
                .frame(width: 8, height: 8)
                .shadow(color: (slotData.hasPlugin && !slotData.isBypassed) ? accentColor.opacity(0.5) : .clear, radius: 3)

            // Title
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(slotData.hasPlugin ? .white : ColorPalette.textDimmed)

            // Plugin name or "None"
            Text(slotData.pluginName ?? "None")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(ColorPalette.textMuted)
                .lineLimit(1)
                .frame(maxWidth: 80)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(ColorPalette.backgroundTertiary)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct AUSendEffectsView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @StateObject private var audioEngine = AudioEngineWrapper()
        @StateObject private var pluginManager = AUPluginManager()
        @StateObject private var vst3PluginHost = VST3PluginHost(sampleRate: 48000, maxBlockSize: 2048)

        var body: some View {
            VStack(spacing: 20) {
                // Full view
                AUSendEffectsView()
                    .environmentObject(audioEngine)
                    .environmentObject(pluginManager)
                    .environmentObject(vst3PluginHost)

                Divider()

                // Compact view
                CompactAUSendEffectsView()
                    .environmentObject(audioEngine)
            }
            .padding(20)
            .background(ColorPalette.backgroundPrimary)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif

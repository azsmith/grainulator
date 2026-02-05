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

    @State private var showBrowser = false
    @State private var showPluginUI = false

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
        .sheet(isPresented: $showPluginUI) {
            if let audioUnit = audioEngine.getSendAudioUnit(busIndex: busIndex),
               let pluginInfo = audioEngine.getSendSlotData(busIndex: busIndex).pluginInfo {
                let slotData = audioEngine.getSendSlotData(busIndex: busIndex)
                AUSendPluginWindowViewByIndex(
                    audioUnit: audioUnit,
                    pluginInfo: pluginInfo,
                    busIndex: busIndex,
                    slotData: slotData,
                    onToggleBypass: { [audioEngine] in
                        Task { @MainActor [audioEngine] in
                            audioEngine.toggleSendBypass(busIndex: busIndex)
                        }
                    },
                    isPresented: $showPluginUI
                )
                .frame(minWidth: 300, minHeight: 200)
            } else {
                VStack {
                    Text("Plugin not available")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(ColorPalette.textMuted)
                    Button("Close") { showPluginUI = false }
                        .padding(.top, 8)
                }
                .padding(20)
            }
        }
        .onDisappear {
            // Close sheets when view disappears to prevent crashes
            showBrowser = false
            showPluginUI = false
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
            if slotData.hasPlugin, let pluginInfo = slotData.pluginInfo {
                loadedPluginView(info: pluginInfo, slotData: slotData)
            } else {
                emptySlotView
            }
        }
    }

    private func loadedPluginView(info: AUPluginInfo, slotData: SendSlotData) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Plugin icon
                RoundedRectangle(cornerRadius: 4)
                    .fill(info.category?.color ?? accentColor)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: info.category?.iconName ?? "waveform")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    )

                // Plugin info
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(info.manufacturerName)
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
                    .onTapGesture { [audioEngine] in
                        Task { @MainActor [audioEngine] in
                            audioEngine.unloadSendPlugin(busIndex: busIndex)
                        }
                    }
            }

            // Edit button to open plugin's native UI
            Text("Edit")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accentColor.opacity(0.15))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    showPluginUI = true
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

// MARK: - AU Send Plugin Window View (Index-Based)

/// Plugin window that uses bus index rather than @ObservedObject
/// NOTE: This view avoids @EnvironmentObject to prevent SwiftUI gesture crashes.
/// All state and actions are passed in from the parent.
struct AUSendPluginWindowViewByIndex: View {
    let audioUnit: AVAudioUnit
    let pluginInfo: AUPluginInfo
    let busIndex: Int
    let slotData: SendSlotData  // Passed in from parent
    let onToggleBypass: () -> Void  // Action passed from parent

    @Binding var isPresented: Bool
    @State private var preferredSize = CGSize(width: 400, height: 300)

    var body: some View {

        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 12) {
                // Send type indicator
                Image(systemName: busIndex == 0 ? "clock" : "waveform.badge.plus")
                    .font(.system(size: 14))
                    .foregroundColor(busIndex == 0 ? ColorPalette.ledAmber : ColorPalette.ledGreen)

                // Plugin name
                VStack(alignment: .leading, spacing: 2) {
                    Text(pluginInfo.name)
                        .font(Typography.panelTitle)
                        .foregroundColor(.white)

                    Text(pluginInfo.manufacturerName)
                        .font(Typography.parameterLabelSmall)
                        .foregroundColor(ColorPalette.textDimmed)
                }

                Spacer()

                // Bypass toggle
                Button(action: onToggleBypass) {
                    Text("BYP")
                        .font(Typography.buttonTiny)
                        .foregroundColor(slotData.isBypassed ? .white : ColorPalette.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(slotData.isBypassed ? ColorPalette.ledAmber : ColorPalette.ledOff)
                        )
                }
                .buttonStyle(.plain)

                // Close button
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ColorPalette.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ColorPalette.backgroundSecondary)

            Divider()
                .background(ColorPalette.divider)

            // Plugin UI
            AUPluginHostView(audioUnit: audioUnit, preferredSize: $preferredSize)
                .frame(minWidth: 200, minHeight: 100)
                .frame(width: preferredSize.width, height: preferredSize.height)
        }
        .background(ColorPalette.backgroundPrimary)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

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

        var body: some View {
            VStack(spacing: 20) {
                // Full view
                AUSendEffectsView()
                    .environmentObject(audioEngine)
                    .environmentObject(pluginManager)

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

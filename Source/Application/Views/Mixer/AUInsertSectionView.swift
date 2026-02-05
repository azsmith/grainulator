//
//  AUInsertSectionView.swift
//  Grainulator
//
//  AU plugin insert section for channel strips
//  Displays AU plugin slots with browser integration
//
//  NOTE: This file carefully avoids using @ObservedObject with AUInsertSlot
//  to prevent crashes in SwiftUI's gesture handling during view hierarchy changes.
//  All slot access goes through AudioEngineWrapper using channel/slot indices.
//

import SwiftUI
import AVFoundation

// MARK: - AU Insert Section View

/// Insert section for channel strip that displays AU plugin slots
struct AUInsertSectionView: View {
    let channelIndex: Int
    let accentColor: Color

    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var pluginManager: AUPluginManager

    @State private var showInsertPopover = false

    var body: some View {
        Button(action: {
            DispatchQueue.main.async {
                showInsertPopover.toggle()
            }
        }) {
            HStack(spacing: 4) {
                // Use index-based access to avoid holding slot references
                AUSlotIndicatorByIndex(
                    channelIndex: channelIndex,
                    slotIndex: 0,
                    accentColor: accentColor
                )
                AUSlotIndicatorByIndex(
                    channelIndex: channelIndex,
                    slotIndex: 1,
                    accentColor: accentColor
                )
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(ColorPalette.backgroundPrimary)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showInsertPopover, arrowEdge: .trailing) {
            AUInsertPopoverByIndex(
                channelIndex: channelIndex,
                accentColor: accentColor
            )
            .environmentObject(audioEngine)
            .environmentObject(pluginManager)
        }
        .onDisappear {
            // Close popover when view disappears to prevent crashes during tab switching
            showInsertPopover = false
        }
    }
}

// MARK: - AU Slot Indicator (Index-Based)

/// Slot indicator that accesses slot data through audioEngine using indices
/// This avoids holding any direct reference to the slot object
struct AUSlotIndicatorByIndex: View {
    let channelIndex: Int
    let slotIndex: Int
    let accentColor: Color

    @EnvironmentObject var audioEngine: AudioEngineWrapper

    var body: some View {
        // Read slot data through audioEngine - no @ObservedObject needed
        let slotData = audioEngine.getInsertSlotData(channelIndex: channelIndex, slotIndex: slotIndex)

        ZStack {
            // LED background
            RoundedRectangle(cornerRadius: 2)
                .fill(slotColor(slotData))
                .frame(width: 24, height: 16)

            // Loading indicator
            if slotData.isLoading {
                ProgressView()
                    .scaleEffect(0.4)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                // Plugin abbreviation
                Text(slotText(slotData))
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(textColor(slotData))
            }
        }
        .shadow(color: shadowColor(slotData), radius: 2)
    }

    private func slotColor(_ data: InsertSlotData) -> Color {
        guard data.hasPlugin else {
            return ColorPalette.ledOff
        }
        if data.isBypassed {
            return ColorPalette.ledAmber
        }
        return accentColor
    }

    private func slotText(_ data: InsertSlotData) -> String {
        guard let name = data.pluginName else {
            return "—"
        }
        if name.count <= 3 {
            return name.uppercased()
        }
        return String(name.prefix(3)).uppercased()
    }

    private func textColor(_ data: InsertSlotData) -> Color {
        data.hasPlugin ? .white : ColorPalette.textDimmed
    }

    private func shadowColor(_ data: InsertSlotData) -> Color {
        guard data.hasPlugin, !data.isBypassed else {
            return .clear
        }
        return accentColor.opacity(0.3)
    }
}

// MARK: - AU Insert Popover (Index-Based)

/// Popover that accesses slot data through audioEngine using indices
struct AUInsertPopoverByIndex: View {
    let channelIndex: Int
    let accentColor: Color

    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var pluginManager: AUPluginManager

    @State private var showBrowserForSlot: Int? = nil
    @State private var showPluginUIForSlot: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("INSERT EFFECTS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)

                Spacer()

                // Mode indicator
                Text(audioEngine.graphMode == .multiChannel ? "AU MODE" : "LEGACY")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(audioEngine.graphMode == .multiChannel ? ColorPalette.ledGreen : ColorPalette.textDimmed)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ColorPalette.backgroundTertiary)
                    )
            }

            Divider()
                .background(ColorPalette.divider)

            // Mode switch (if not in multi-channel mode)
            if audioEngine.graphMode == .legacy {
                legacyModeNotice
            }

            // Slot editors - use index-based access
            ForEach(0..<2, id: \.self) { slotIndex in
                let slotData = audioEngine.getInsertSlotData(channelIndex: channelIndex, slotIndex: slotIndex)
                AUSlotEditorByIndex(
                    channelIndex: channelIndex,
                    slotIndex: slotIndex,
                    accentColor: accentColor,
                    slotData: slotData,
                    onShowBrowser: {
                        DispatchQueue.main.async {
                            showBrowserForSlot = slotIndex
                        }
                    },
                    onShowPluginUI: {
                        DispatchQueue.main.async {
                            showPluginUIForSlot = slotIndex
                        }
                    },
                    onToggleBypass: { [audioEngine] in
                        DispatchQueue.main.async {
                            audioEngine.toggleInsertBypass(channelIndex: channelIndex, slotIndex: slotIndex)
                        }
                    },
                    onUnloadPlugin: { [audioEngine] in
                        DispatchQueue.main.async {
                            audioEngine.unloadInsertPlugin(channelIndex: channelIndex, slotIndex: slotIndex)
                        }
                    }
                )
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(ColorPalette.backgroundSecondary)
        .sheet(item: $showBrowserForSlot) { slotIndex in
            AUPluginBrowserView(
                isPresented: Binding(
                    get: { showBrowserForSlot != nil },
                    set: { if !$0 { showBrowserForSlot = nil } }
                ),
                onSelect: { [audioEngine, pluginManager] plugin in
                    DispatchQueue.main.async {
                        Task {
                        try? await audioEngine.loadInsertPlugin(plugin, channelIndex: channelIndex, slotIndex: slotIndex, using: pluginManager)
                        }
                    }
                }
            )
            .environmentObject(pluginManager)
        }
        .sheet(item: $showPluginUIForSlot) { slotIndex in
            // Get AU and info through audioEngine
            if let slots = audioEngine.getInsertSlots(forChannel: channelIndex),
               slotIndex < slots.count,
               let au = slots[slotIndex].audioUnit,
               let info = slots[slotIndex].pluginInfo {
                let slotData = audioEngine.getInsertSlotData(channelIndex: channelIndex, slotIndex: slotIndex)
                AUPluginWindowViewByIndex(
                    audioUnit: au,
                    pluginInfo: info,
                    channelIndex: channelIndex,
                    slotIndex: slotIndex,
                    slotData: slotData,
                    onToggleBypass: { [audioEngine] in
                        DispatchQueue.main.async {
                            audioEngine.toggleInsertBypass(channelIndex: channelIndex, slotIndex: slotIndex)
                        }
                    },
                    isPresented: Binding(
                        get: { showPluginUIForSlot != nil },
                        set: { if !$0 { showPluginUIForSlot = nil } }
                    )
                )
            }
        }
        .onDisappear {
            // Close all sheets when popover disappears to prevent crashes during tab switching
            showBrowserForSlot = nil
            showPluginUIForSlot = nil
        }
    }

    private var legacyModeNotice: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(ColorPalette.ledAmber)
                Text("Legacy audio mode active")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(ColorPalette.textMuted)
            }

            Text("Switch to Multi-channel mode for AU plugin support")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)

            Button("ENABLE AU MODE") { [audioEngine] in
                // Defer mode switch to avoid mutating view graph mid-gesture callback.
                DispatchQueue.main.async {
                    audioEngine.enableMultiChannelMode()
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(ColorPalette.ledBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(ColorPalette.backgroundPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(ColorPalette.ledBlue.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorPalette.backgroundTertiary)
        )
    }
}

// MARK: - AU Slot Editor (Index-Based)

/// Slot editor that accesses slot data through audioEngine using indices
/// NOTE: This view does NOT use @EnvironmentObject to avoid SwiftUI gesture crashes.
/// All actions are passed as closures from the parent view.
struct AUSlotEditorByIndex: View {
    let channelIndex: Int
    let slotIndex: Int
    let accentColor: Color
    let slotData: InsertSlotData  // Passed in from parent to avoid @EnvironmentObject access

    let onShowBrowser: () -> Void
    let onShowPluginUI: () -> Void
    let onToggleBypass: () -> Void
    let onUnloadPlugin: () -> Void

    var body: some View {
        // slotData is passed in from parent - no @EnvironmentObject needed here

        VStack(alignment: .leading, spacing: 8) {
            // Slot header
            HStack {
                Text("INSERT \(slotIndex + 1)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textMuted)

                Spacer()

                if slotData.hasPlugin {
                    // Bypass toggle
                    Button(action: onToggleBypass) {
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
            }

            // Plugin info or "empty" state
            if slotData.hasPlugin, let pluginInfo = slotData.pluginInfo {
                // Plugin loaded
                HStack(spacing: 8) {
                    // Plugin icon
                    RoundedRectangle(cornerRadius: 4)
                        .fill(pluginInfo.category?.color ?? accentColor)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: pluginInfo.category?.iconName ?? "waveform")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        )

                    // Plugin name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pluginInfo.name)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(pluginInfo.manufacturerName)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(ColorPalette.textDimmed)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Action buttons
                    VStack(spacing: 4) {
                        // Open UI button
                        if pluginInfo.hasCustomView {
                            Button(action: onShowPluginUI) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 10))
                                    .foregroundColor(ColorPalette.ledBlue)
                            }
                            .buttonStyle(.plain)
                        }

                        // Remove button
                        Button(action: onUnloadPlugin) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 10))
                                .foregroundColor(ColorPalette.ledRed)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                // Empty slot
                Button(action: onShowBrowser) {
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

            // Loading indicator
            if slotData.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                        .progressViewStyle(CircularProgressViewStyle(tint: accentColor))

                    Text("Loading plugin...")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorPalette.backgroundPrimary)
        )
    }
}

// MARK: - AU Plugin Window View (Index-Based)

/// Plugin window that uses indices rather than @ObservedObject
/// NOTE: This view avoids @EnvironmentObject to prevent SwiftUI gesture crashes.
/// All state and actions are passed in from the parent.
struct AUPluginWindowViewByIndex: View {
    let audioUnit: AVAudioUnit
    let pluginInfo: AUPluginInfo
    let channelIndex: Int
    let slotIndex: Int
    let slotData: InsertSlotData  // Passed in from parent
    let onToggleBypass: () -> Void  // Action passed from parent

    @Binding var isPresented: Bool
    @State private var preferredSize = CGSize(width: 400, height: 300)

    var body: some View {

        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 12) {
                // Channel indicator
                Text("CH \(channelIndex + 1)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ColorPalette.backgroundTertiary)
                    )

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

// MARK: - Int Extension for Identifiable

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - Preview

#if DEBUG
struct AUInsertSectionView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @StateObject private var audioEngine = AudioEngineWrapper()
        @StateObject private var pluginManager = AUPluginManager()

        var body: some View {
            VStack(spacing: 20) {
                AUInsertSectionView(channelIndex: 0, accentColor: ColorPalette.accentPlaits)
            }
            .padding(20)
            .background(ColorPalette.backgroundPrimary)
            .environmentObject(audioEngine)
            .environmentObject(pluginManager)
            .onAppear {
                pluginManager.refreshPluginList()
            }
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif

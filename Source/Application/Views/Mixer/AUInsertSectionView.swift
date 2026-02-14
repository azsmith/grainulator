//
//  AUInsertSectionView.swift
//  Grainulator
//
//  AU plugin insert section for channel strips
//  Displays AU plugin slots with browser integration
//
//  NOTE: This file carefully avoids @EnvironmentObject and @ObservedObject to
//  prevent crashes in SwiftUI's gesture handling (MainActor.assumeIsolated)
//  when hosted inside an NSPanel via NSHostingController.
//  All dependencies are passed as explicit properties from parent views.
//

import SwiftUI
import AVFoundation

// MARK: - AU Insert Section View

/// Insert section for channel strip that displays AU plugin slots.
/// Takes explicit references instead of @EnvironmentObject to avoid
/// SwiftUI gesture crash in NSPanel-hosted views.
struct AUInsertSectionView: View {
    let channelIndex: Int
    let accentColor: Color
    @ObservedObject var audioEngine: AudioEngineWrapper
    let pluginManager: AUPluginManager
    let vst3PluginHost: VST3PluginHost?

    @State private var showInsertPopover = false
    @State private var slotData0: InsertSlotData = .empty
    @State private var slotData1: InsertSlotData = .empty

    init(channelIndex: Int, accentColor: Color, audioEngine: AudioEngineWrapper, pluginManager: AUPluginManager, vst3PluginHost: VST3PluginHost? = nil) {
        self.channelIndex = channelIndex
        self.accentColor = accentColor
        self._audioEngine = ObservedObject(wrappedValue: audioEngine)
        self.pluginManager = pluginManager
        self.vst3PluginHost = vst3PluginHost
    }

    private func refreshSlotData(source: String = "") {
        slotData0 = audioEngine.getInsertSlotData(channelIndex: channelIndex, slotIndex: 0)
        slotData1 = audioEngine.getInsertSlotData(channelIndex: channelIndex, slotIndex: 1)
    }

    var body: some View {
        HStack(spacing: 4) {
            AUSlotIndicator(
                slotData: slotData0,
                accentColor: accentColor
            )
            AUSlotIndicator(
                slotData: slotData1,
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
        .contentShape(Rectangle())
        .onTapGesture {
            DispatchQueue.main.async {
                showInsertPopover.toggle()
            }
        }
        .popover(isPresented: $showInsertPopover, arrowEdge: .trailing) {
            AUInsertPopoverByIndex(
                channelIndex: channelIndex,
                accentColor: accentColor
            )
            .environmentObject(audioEngine)
            .environmentObject(pluginManager)
            .environmentObject(vst3PluginHost ?? VST3PluginHost(sampleRate: 48000, maxBlockSize: 2048))
        }
        .onDisappear {
            showInsertPopover = false
        }
        .onAppear { refreshSlotData(source: "onAppear") }
        .onReceive(audioEngine.objectWillChange) { _ in
            DispatchQueue.main.async { [self] in refreshSlotData(source: "onReceive") }
        }
    }
}

// MARK: - AU Slot Indicator (Value-Based)

/// Slot indicator that takes pre-computed slot data — no environment objects needed.
struct AUSlotIndicator: View {
    let slotData: InsertSlotData
    let accentColor: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(slotColor)
                .frame(width: 24, height: 16)

            if slotData.isLoading {
                ProgressView()
                    .scaleEffect(0.4)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text(slotText)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(textColor)
            }
        }
        .shadow(color: shadowColor, radius: 2)
    }

    private var slotColor: Color {
        guard slotData.hasPlugin else { return ColorPalette.ledOff }
        return slotData.isBypassed ? ColorPalette.ledAmber : accentColor
    }

    private var slotText: String {
        guard let name = slotData.pluginName else { return "—" }
        if name.count <= 3 { return name.uppercased() }
        return String(name.prefix(3)).uppercased()
    }

    private var textColor: Color {
        slotData.hasPlugin ? .white : ColorPalette.textDimmed
    }

    private var shadowColor: Color {
        guard slotData.hasPlugin, !slotData.isBypassed else { return .clear }
        return accentColor.opacity(0.3)
    }
}

// MARK: - AU Insert Popover (Index-Based)

/// Popover that accesses slot data through audioEngine using indices.
/// Uses @EnvironmentObject because popovers create their own window context.
struct AUInsertPopoverByIndex: View {
    let channelIndex: Int
    let accentColor: Color

    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var pluginManager: AUPluginManager
    @EnvironmentObject var vst3PluginHost: VST3PluginHost

    @State private var showBrowserForSlot: Int? = nil
    @State private var showPluginUIForSlot: Int? = nil

    private var isVST3: Bool { audioEngine.pluginHostBackend == .vst3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("INSERT EFFECTS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)

                Spacer()

                // Mode indicator
                Text(backendBadgeText)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(backendBadgeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ColorPalette.backgroundTertiary)
                    )
            }

            Divider()
                .background(ColorPalette.divider)

            // Legacy mode notice (AU backend only, not in multi-channel mode)
            if !isVST3 && audioEngine.graphMode == .legacy {
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
                            if audioEngine.pluginHostBackend == .vst3 {
                                audioEngine.toggleVST3InsertBypass(channelIndex: channelIndex, slotIndex: slotIndex)
                            } else {
                                audioEngine.toggleInsertBypass(channelIndex: channelIndex, slotIndex: slotIndex)
                            }
                        }
                    },
                    onUnloadPlugin: { [audioEngine, vst3PluginHost] in
                        DispatchQueue.main.async {
                            if audioEngine.pluginHostBackend == .vst3 {
                                audioEngine.unloadVST3Insert(channelIndex: channelIndex, slotIndex: slotIndex, using: vst3PluginHost)
                            } else {
                                audioEngine.unloadInsertPlugin(channelIndex: channelIndex, slotIndex: slotIndex)
                            }
                        }
                    }
                )
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(ColorPalette.backgroundSecondary)
        .sheet(item: $showBrowserForSlot) { slotIndex in
            if isVST3 {
                AUPluginBrowserView(
                    isPresented: Binding(
                        get: { showBrowserForSlot != nil },
                        set: { if !$0 { showBrowserForSlot = nil } }
                    ),
                    vst3Plugins: vst3PluginHost.scannedPlugins,
                    onVST3Select: { [audioEngine, vst3PluginHost] descriptor in
                        Task { @MainActor in
                            do {
                                try await audioEngine.loadVST3Insert(descriptor, channelIndex: channelIndex, slotIndex: slotIndex, using: vst3PluginHost)
                            } catch {
                                print("VST3 insert load failed: \(error)")
                            }
                        }
                    }
                )
                .environmentObject(pluginManager)
            } else {
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
        }
        .sheet(item: $showPluginUIForSlot) { slotIndex in
            if isVST3 {
                // VST3: open editor in floating window, then dismiss sheet
                Color.clear.frame(width: 0, height: 0)
                    .onAppear { [audioEngine, vst3PluginHost] in
                        DispatchQueue.main.async {
                            showPluginUIForSlot = nil
                            guard channelIndex < audioEngine.vst3InsertSlots.count,
                                  slotIndex < audioEngine.vst3InsertSlots[channelIndex].count,
                                  let instance = audioEngine.vst3InsertSlots[channelIndex][slotIndex].instance as? VST3PluginInstanceWrapper else { return }
                            let pluginName = instance.descriptor.name
                            instance.requestViewController { vc in
                                guard let vc else { return }
                                let key = "vst3-insert-\(channelIndex)-\(slotIndex)"
                                AUPluginWindowManager.shared.open(
                                    viewController: vc,
                                    title: pluginName,
                                    subtitle: "CH \(channelIndex + 1) Insert \(slotIndex + 1)",
                                    key: key
                                )
                            }
                        }
                    }
            } else if let slots = audioEngine.getInsertSlots(forChannel: channelIndex),
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
            showBrowserForSlot = nil
            showPluginUIForSlot = nil
        }
    }

    private var backendBadgeText: String {
        if isVST3 { return "VST3" }
        return audioEngine.graphMode == .multiChannel ? "AU MODE" : "LEGACY"
    }

    private var backendBadgeColor: Color {
        if isVST3 { return ColorPalette.ledBlue }
        return audioEngine.graphMode == .multiChannel ? ColorPalette.ledGreen : ColorPalette.textDimmed
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
            if slotData.hasPlugin {
                // Plugin loaded — use AU info if available, otherwise PluginDescriptor
                let displayName = slotData.pluginInfo?.name ?? slotData.pluginDescriptor?.name ?? "Plugin"
                let displayManufacturer = slotData.pluginInfo?.manufacturerName ?? slotData.pluginDescriptor?.manufacturerName ?? ""
                let displayCategory = slotData.pluginInfo?.category ?? slotData.pluginDescriptor?.category
                let displayHasCustomView = slotData.pluginInfo?.hasCustomView ?? slotData.pluginDescriptor?.hasCustomView ?? false

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

                    // Action buttons
                    VStack(spacing: 4) {
                        // Open UI button
                        if displayHasCustomView {
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
        @StateObject private var vst3PluginHost = VST3PluginHost(sampleRate: 48000, maxBlockSize: 2048)

        var body: some View {
            VStack(spacing: 20) {
                AUInsertSectionView(channelIndex: 0, accentColor: ColorPalette.accentPlaits, audioEngine: audioEngine, pluginManager: pluginManager, vst3PluginHost: vst3PluginHost)
            }
            .padding(20)
            .background(ColorPalette.backgroundPrimary)
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

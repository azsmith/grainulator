//
//  MixerWindowManager.swift
//  Grainulator
//
//  Manages a floating NSPanel window for the mixer.
//  Follows the same pattern as AUPluginWindowController.
//

import AppKit
import SwiftUI

@MainActor
final class MixerWindowManager {
    static let shared = MixerWindowManager()

    private var mixerPanel: NSPanel?
    private weak var layoutState: WorkspaceLayoutState?

    private init() {}

    func open(
        mixerState: MixerState,
        audioEngine: AudioEngineWrapper,
        pluginManager: AUPluginManager,
        vst3PluginHost: VST3PluginHost,
        layoutState: WorkspaceLayoutState
    ) {
        self.layoutState = layoutState

        // If already open, bring to front
        if let existing = mixerPanel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let contentSize = CGSize(width: 950, height: 500)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Mixer"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.minSize = CGSize(width: 600, height: 300)
        panel.setFrameAutosaveName("")  // Prevent macOS from restoring old size

        // Host SwiftUI mixer view
        let mixerView = NewMixerView(mixerState: mixerState, showToolbar: true)
            .environmentObject(audioEngine)
            .environmentObject(pluginManager)
            .environmentObject(vst3PluginHost)
        let hostingController = NSHostingController(rootView: mixerView)
        panel.contentViewController = hostingController

        // Explicitly set size and center
        panel.setContentSize(contentSize)
        panel.center()

        mixerPanel = panel

        // Observe close to sync state
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.layoutState?.isMixerWindowOpen = false
                self?.mixerPanel = nil
            }
        }

        panel.makeKeyAndOrderFront(nil)
        layoutState.isMixerWindowOpen = true
    }

    func close() {
        mixerPanel?.close()
        mixerPanel = nil
        layoutState?.isMixerWindowOpen = false
    }

    func toggle(
        mixerState: MixerState,
        audioEngine: AudioEngineWrapper,
        pluginManager: AUPluginManager,
        vst3PluginHost: VST3PluginHost,
        layoutState: WorkspaceLayoutState
    ) {
        if mixerPanel?.isVisible == true {
            close()
        } else {
            open(
                mixerState: mixerState,
                audioEngine: audioEngine,
                pluginManager: pluginManager,
                vst3PluginHost: vst3PluginHost,
                layoutState: layoutState
            )
        }
    }

    var isOpen: Bool {
        mixerPanel?.isVisible ?? false
    }
}

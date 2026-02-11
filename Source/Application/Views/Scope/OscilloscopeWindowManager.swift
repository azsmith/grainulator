//
//  OscilloscopeWindowManager.swift
//  Grainulator
//
//  Manages a floating NSPanel window for the oscilloscope.
//  Follows the same pattern as MixerWindowManager.
//

import AppKit
import SwiftUI

@MainActor
final class OscilloscopeWindowManager {
    static let shared = OscilloscopeWindowManager()

    private var scopePanel: NSPanel?
    private weak var layoutState: WorkspaceLayoutState?
    private weak var audioEngine: AudioEngineWrapper?
    private var scopePollingRetained: Bool = false

    private init() {}

    func open(
        audioEngine: AudioEngineWrapper,
        layoutState: WorkspaceLayoutState
    ) {
        self.layoutState = layoutState
        self.audioEngine = audioEngine

        // If already open, bring to front
        if let existing = scopePanel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let contentSize = CGSize(width: 600, height: 300)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Oscilloscope"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.minSize = CGSize(width: 400, height: 200)
        panel.setFrameAutosaveName("")

        // Host SwiftUI oscilloscope view
        let scopeView = OscilloscopeView(audioEngine: audioEngine)
        let hostingController = NSHostingController(rootView: scopeView)
        panel.contentViewController = hostingController

        // Explicitly set size and center
        panel.setContentSize(contentSize)
        panel.center()

        scopePanel = panel
        retainScopePollingIfNeeded()

        // Observe close to sync state
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.releaseScopePollingIfNeeded()
                self?.layoutState?.isScopeWindowOpen = false
                self?.scopePanel = nil
            }
        }

        panel.makeKeyAndOrderFront(nil)
        layoutState.isScopeWindowOpen = true
    }

    func close() {
        scopePanel?.close()
        releaseScopePollingIfNeeded()
        scopePanel = nil
        layoutState?.isScopeWindowOpen = false
    }

    func toggle(
        audioEngine: AudioEngineWrapper,
        layoutState: WorkspaceLayoutState
    ) {
        if scopePanel?.isVisible == true {
            close()
        } else {
            open(
                audioEngine: audioEngine,
                layoutState: layoutState
            )
        }
    }

    var isOpen: Bool {
        scopePanel?.isVisible ?? false
    }

    private func retainScopePollingIfNeeded() {
        guard !scopePollingRetained, let audioEngine else { return }
        scopePollingRetained = true
        audioEngine.retainScopeMonitoring()
    }

    private func releaseScopePollingIfNeeded() {
        guard scopePollingRetained else { return }
        scopePollingRetained = false
        audioEngine?.releaseScopeMonitoring()
    }
}

//
//  TunerWindowManager.swift
//  Grainulator
//
//  Manages a floating NSPanel window for the chromatic tuner.
//  Same pattern as OscilloscopeWindowManager.
//

import AppKit
import SwiftUI

@MainActor
final class TunerWindowManager {
    static let shared = TunerWindowManager()

    private var tunerPanel: NSPanel?
    private weak var layoutState: WorkspaceLayoutState?

    private init() {}

    func open(
        audioEngine: AudioEngineWrapper,
        layoutState: WorkspaceLayoutState
    ) {
        self.layoutState = layoutState

        // If already open, bring to front
        if let existing = tunerPanel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let contentSize = CGSize(width: 280, height: 200)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Tuner"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.minSize = CGSize(width: 240, height: 160)
        panel.setFrameAutosaveName("")

        // Host SwiftUI tuner view
        let tunerView = TunerView(audioEngine: audioEngine)
        let hostingController = NSHostingController(rootView: tunerView)
        panel.contentViewController = hostingController

        // Explicitly set size and center
        panel.setContentSize(contentSize)
        panel.center()

        tunerPanel = panel

        // Observe close to sync state
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.layoutState?.isTunerWindowOpen = false
                self?.tunerPanel = nil
            }
        }

        panel.makeKeyAndOrderFront(nil)
        layoutState.isTunerWindowOpen = true
    }

    func close() {
        tunerPanel?.close()
        tunerPanel = nil
        layoutState?.isTunerWindowOpen = false
    }

    func toggle(
        audioEngine: AudioEngineWrapper,
        layoutState: WorkspaceLayoutState
    ) {
        if tunerPanel?.isVisible == true {
            close()
        } else {
            open(
                audioEngine: audioEngine,
                layoutState: layoutState
            )
        }
    }

    var isOpen: Bool {
        tunerPanel?.isVisible ?? false
    }
}

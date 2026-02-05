//
//  AUPluginWindowController.swift
//  Grainulator
//
//  Opens AU plugin native UIs in proper floating NSPanel windows.
//  This is the standard approach used by DAWs — the plugin's view controller
//  is set as the NSPanel's contentViewController, so the window automatically
//  adopts the plugin's preferred content size. No SwiftUI container sizing issues.
//

import AppKit
@preconcurrency import AVFoundation

/// Manages floating windows for AU plugin UIs.
/// Call `open(audioUnit:title:)` to show a plugin's native interface.
@MainActor
final class AUPluginWindowManager {
    static let shared = AUPluginWindowManager()

    /// Tracks open windows by a key (e.g. "send-0", "insert-2-1")
    private var openWindows: [String: NSPanel] = [:]

    private init() {}

    /// Opens the AU plugin's native UI in a floating NSPanel.
    /// If a window is already open for this key, it brings it to front.
    func open(audioUnit: AVAudioUnit, title: String, subtitle: String = "", key: String) {
        // If already open, just bring to front
        if let existing = openWindows[key], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        // Request the plugin's view controller
        audioUnit.auAudioUnit.requestViewController { [weak self] viewController in
            DispatchQueue.main.async {
                guard let self else { return }
                self.presentWindow(viewController: viewController, audioUnit: audioUnit, title: title, subtitle: subtitle, key: key)
            }
        }
    }

    /// Closes a plugin window by key
    func close(key: String) {
        if let window = openWindows[key] {
            window.close()
            openWindows.removeValue(forKey: key)
        }
    }

    /// Check if a window is open for this key
    func isOpen(key: String) -> Bool {
        return openWindows[key]?.isVisible ?? false
    }

    private func presentWindow(viewController: NSViewController?, audioUnit: AVAudioUnit, title: String, subtitle: String, key: String) {
        guard let vc = viewController else {
            // Plugin has no custom UI — show a small info panel
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = "This plugin has no custom interface."
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        // Determine the window size from the view controller
        var contentSize = vc.preferredContentSize
        if contentSize.width < 50 || contentSize.height < 50 {
            // Fallback: try the view's frame
            let viewFrame = vc.view.frame
            if viewFrame.width > 50 && viewFrame.height > 50 {
                contentSize = viewFrame.size
            } else {
                // Force a layout pass and try again
                vc.view.layoutSubtreeIfNeeded()
                let fitting = vc.view.fittingSize
                if fitting.width > 50 && fitting.height > 50 {
                    contentSize = fitting
                } else {
                    contentSize = CGSize(width: 600, height: 400)
                }
            }
        }

        // Create a floating panel (stays on top of the main window)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.subtitle = subtitle
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentViewController = vc
        panel.center()

        // Track the window and handle close
        openWindows[key] = panel

        // Observe window close to clean up
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openWindows.removeValue(forKey: key)
            }
        }

        panel.makeKeyAndOrderFront(nil)
    }
}

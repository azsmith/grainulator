//
//  AUInsertSlot.swift
//  Grainulator
//
//  Represents an insert effect slot that can hold an Audio Unit plugin.
//  Manages plugin lifecycle, bypass state, and state persistence.
//

import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - AU Insert Slot

/// An insert effect slot that can host an Audio Unit plugin
/// Note: Not marked @MainActor to avoid crashes with SwiftUI gesture handling.
/// Uses thread-safe shadow copies for UI access to prevent crashes during gesture evaluation.
class AUInsertSlot: ObservableObject, Identifiable, @unchecked Sendable {
    let id = UUID()
    let slotIndex: Int

    // MARK: - Thread-Safe Shadow State (for SwiftUI access)
    // These are updated atomically when MainActor state changes
    // SwiftUI can safely read these from any thread

    private let _hasPluginLock = NSLock()
    private var _hasPlugin: Bool = false

    private let _pluginNameLock = NSLock()
    private var _pluginName: String?

    private let _isBypassedLock = NSLock()
    private var _isBypassedShadow: Bool = false

    private let _pluginInfoLock = NSLock()
    private var _pluginInfoShadow: AUPluginInfo?

    private let _isLoadingLock = NSLock()
    private var _isLoadingShadow: Bool = false

    /// Thread-safe accessor for hasPlugin state (can be called from any thread)
    nonisolated var hasPluginSafe: Bool {
        _hasPluginLock.lock()
        defer { _hasPluginLock.unlock() }
        return _hasPlugin
    }

    /// Thread-safe accessor for plugin name (can be called from any thread)
    nonisolated var pluginNameSafe: String? {
        _pluginNameLock.lock()
        defer { _pluginNameLock.unlock() }
        return _pluginName
    }

    /// Thread-safe accessor for plugin info (can be called from any thread)
    nonisolated var pluginInfoSafe: AUPluginInfo? {
        _pluginInfoLock.lock()
        defer { _pluginInfoLock.unlock() }
        return _pluginInfoShadow
    }

    /// Thread-safe accessor for isBypassed state (can be called from any thread)
    nonisolated var isBypassedSafe: Bool {
        _isBypassedLock.lock()
        defer { _isBypassedLock.unlock() }
        return _isBypassedShadow
    }

    /// Thread-safe accessor for isLoading state (can be called from any thread)
    nonisolated var isLoadingSafe: Bool {
        _isLoadingLock.lock()
        defer { _isLoadingLock.unlock() }
        return _isLoadingShadow
    }

    // MARK: - Published State (MainActor-isolated)

    /// The loaded Audio Unit instance (nil if slot is empty)
    @MainActor @Published var audioUnit: AVAudioUnit? {
        didSet {
            _hasPluginLock.lock()
            _hasPlugin = audioUnit != nil
            _hasPluginLock.unlock()
        }
    }

    /// Information about the loaded plugin
    @MainActor @Published var pluginInfo: AUPluginInfo? {
        didSet {
            _pluginNameLock.lock()
            _pluginName = pluginInfo?.name
            _pluginNameLock.unlock()

            _pluginInfoLock.lock()
            _pluginInfoShadow = pluginInfo
            _pluginInfoLock.unlock()
        }
    }

    /// Whether the effect is bypassed (audio passes through unchanged)
    @MainActor @Published var isBypassed: Bool = false {
        didSet {
            _isBypassedLock.lock()
            _isBypassedShadow = isBypassed
            _isBypassedLock.unlock()
        }
    }

    /// Whether a plugin is currently being loaded
    @MainActor @Published var isLoading: Bool = false {
        didSet {
            _isLoadingLock.lock()
            _isLoadingShadow = isLoading
            _isLoadingLock.unlock()
        }
    }

    /// Error message if loading failed
    @MainActor @Published var loadError: String?

    /// The plugin's view controller for native UI (lazy-loaded)
    @MainActor @Published var viewController: NSViewController?

    /// Whether the plugin's native UI is being loaded
    @MainActor @Published var isLoadingUI: Bool = false

    // MARK: - Host Context

    /// Shared musical context for tempo/transport sync with hosted AU plugins
    weak var hostContext: AUHostContext?

    // MARK: - Callbacks

    /// Called when the audio unit changes (load/unload) - host should rebuild audio graph
    var onAudioUnitChanged: ((AVAudioUnit?) -> Void)?

    /// Called when bypass state changes - host should update routing
    var onBypassChanged: ((Bool) -> Void)?

    // MARK: - Initialization

    init(slotIndex: Int) {
        self.slotIndex = slotIndex
    }

    // MARK: - Plugin Loading

    /// Loads an Audio Unit plugin into this slot
    /// - Parameters:
    ///   - info: Plugin info from the plugin manager
    ///   - pluginManager: The manager to use for instantiation
    @MainActor
    func loadPlugin(_ info: AUPluginInfo, using pluginManager: AUPluginManager) async throws {
        // Clear previous plugin
        unloadPlugin()

        isLoading = true
        loadError = nil

        do {
            let au = try await pluginManager.instantiatePlugin(info, outOfProcess: true)

            // Update state on main actor
            self.audioUnit = au
            self.pluginInfo = info
            self.isLoading = false

            // Attach host musical context so tempo-synced plugins can read BPM/transport
            hostContext?.attachToAudioUnit(au.auAudioUnit)

            // Defer graph mutations until after the current gesture/action cycle.
            DispatchQueue.main.async { [weak self] in
                self?.onAudioUnitChanged?(au)
            }

            print("✓ Loaded AU into slot \(slotIndex): \(info.name)")
        } catch {
            self.isLoading = false
            self.loadError = error.localizedDescription
            print("✗ Failed to load AU into slot \(slotIndex): \(error)")
            throw error
        }
    }

    /// Unloads the current plugin from this slot
    @MainActor
    func unloadPlugin() {
        if audioUnit != nil {
            print("✓ Unloading AU from slot \(slotIndex): \(pluginInfo?.name ?? "unknown")")

            // Clear UI first
            viewController = nil

            // Clear the AU
            audioUnit = nil
            pluginInfo = nil

            // Defer graph mutations until after the current gesture/action cycle.
            DispatchQueue.main.async { [weak self] in
                self?.onAudioUnitChanged?(nil)
            }
        }
    }

    /// Sets the bypass state for this slot
    @MainActor
    func setBypass(_ bypassed: Bool) {
        guard isBypassed != bypassed else { return }
        isBypassed = bypassed

        // If AU supports bypass parameter, set it
        if let au = audioUnit {
            au.auAudioUnit.shouldBypassEffect = bypassed
        }

        DispatchQueue.main.async { [weak self] in
            self?.onBypassChanged?(bypassed)
        }
    }

    // MARK: - Native UI

    /// Requests the plugin's native UI view controller
    @MainActor
    func loadPluginUI() {
        guard let au = audioUnit else { return }
        guard viewController == nil else { return }

        isLoadingUI = true

        au.auAudioUnit.requestViewController { [weak self] vc in
            DispatchQueue.main.async {
                self?.viewController = vc
                self?.isLoadingUI = false

                if vc != nil {
                    print("✓ Loaded native UI for AU in slot \(self?.slotIndex ?? -1)")
                } else {
                    print("⚠ AU in slot \(self?.slotIndex ?? -1) has no native UI")
                }
            }
        }
    }

    /// Clears the cached view controller
    @MainActor
    func unloadPluginUI() {
        viewController = nil
    }

    // MARK: - State Persistence

    /// Returns the full state of the Audio Unit for saving
    @MainActor
    var fullState: [String: Any]? {
        audioUnit?.auAudioUnit.fullState
    }

    /// Restores the Audio Unit state from saved data
    @MainActor
    func restoreState(_ state: [String: Any]) {
        guard let au = audioUnit else { return }
        au.auAudioUnit.fullState = state
        print("✓ Restored state for AU in slot \(slotIndex)")
    }

    /// Creates a snapshot of this slot for project saving
    @MainActor
    func createSnapshot() -> AUSlotSnapshot? {
        guard let info = pluginInfo else { return nil }

        // Serialize fullState to Data
        var stateData: Data?
        if let state = fullState {
            stateData = try? NSKeyedArchiver.archivedData(withRootObject: state, requiringSecureCoding: false)
        }

        return AUSlotSnapshot(
            componentType: info.componentDescription.componentType,
            componentSubType: info.componentDescription.componentSubType,
            componentManufacturer: info.componentDescription.componentManufacturer,
            fullState: stateData,
            isBypassed: isBypassed
        )
    }

    /// Restores this slot from a saved snapshot
    @MainActor
    func restoreFromSnapshot(_ snapshot: AUSlotSnapshot, using pluginManager: AUPluginManager) async throws {
        // Create component description from snapshot
        var desc = AudioComponentDescription()
        desc.componentType = snapshot.componentType
        desc.componentSubType = snapshot.componentSubType
        desc.componentManufacturer = snapshot.componentManufacturer
        desc.componentFlags = 0
        desc.componentFlagsMask = 0

        // Find matching plugin in available plugins
        guard let info = pluginManager.availableEffects.first(where: {
            $0.componentDescription.componentType == desc.componentType &&
            $0.componentDescription.componentSubType == desc.componentSubType &&
            $0.componentDescription.componentManufacturer == desc.componentManufacturer
        }) else {
            throw AUPluginError.pluginNotFound
        }

        // Load the plugin
        try await loadPlugin(info, using: pluginManager)

        // Restore state if available
        if let stateData = snapshot.fullState,
           let state = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(stateData) as? [String: Any] {
            restoreState(state)
        }

        // Restore bypass
        setBypass(snapshot.isBypassed)
    }
}

// MARK: - AU Slot Snapshot

/// Codable snapshot of an AU insert slot for project saving
struct AUSlotSnapshot: Codable {
    let componentType: UInt32
    let componentSubType: UInt32
    let componentManufacturer: UInt32
    let fullState: Data?
    let isBypassed: Bool

    /// Returns a human-readable identifier for debugging
    var identifier: String {
        let typeChars = fourCharCode(componentType)
        let subTypeChars = fourCharCode(componentSubType)
        let manufacturerChars = fourCharCode(componentManufacturer)
        return "\(manufacturerChars):\(typeChars):\(subTypeChars)"
    }

    /// Converts a UInt32 to a 4-character string (FourCC)
    private func fourCharCode(_ value: UInt32) -> String {
        let chars: [Character] = [
            Character(UnicodeScalar((value >> 24) & 0xFF)!),
            Character(UnicodeScalar((value >> 16) & 0xFF)!),
            Character(UnicodeScalar((value >> 8) & 0xFF)!),
            Character(UnicodeScalar(value & 0xFF)!)
        ]
        return String(chars)
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension AUInsertSlot {
    static var preview: AUInsertSlot {
        AUInsertSlot(slotIndex: 0)
    }

    static var previewWithPlugin: AUInsertSlot {
        let slot = AUInsertSlot(slotIndex: 0)
        // Note: Can't actually load a plugin in preview
        return slot
    }
}
#endif

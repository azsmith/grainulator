//
//  AUSendSlot.swift
//  Grainulator
//
//  Represents a send effect bus that hosts an Audio Unit plugin.
//  Includes return level control and wet/dry mix management.
//

import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - AU Send Slot

/// A send effect bus that can host an Audio Unit plugin (delay, reverb, etc.)
/// Note: Not marked @MainActor to avoid crashes with SwiftUI gesture handling.
/// Uses thread-safe shadow copies for UI access to prevent crashes during gesture evaluation.
class AUSendSlot: ObservableObject, Identifiable, @unchecked Sendable {
    let id = UUID()
    let busIndex: Int
    let busName: String

    // MARK: - Thread-Safe Shadow State (for SwiftUI access)
    // These are updated atomically when MainActor state changes
    // SwiftUI can safely read these from any thread

    private let _hasPluginLock = NSLock()
    private var _hasPlugin: Bool = false

    private let _pluginNameLock = NSLock()
    private var _pluginName: String?

    private let _pluginInfoLock = NSLock()
    private var _pluginInfoShadow: AUPluginInfo?

    private let _isBypassedLock = NSLock()
    private var _isBypassedShadow: Bool = false

    private let _isLoadingLock = NSLock()
    private var _isLoadingShadow: Bool = false

    private let _returnLevelLock = NSLock()
    private var _returnLevelShadow: Float = 0.5

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

    /// Thread-safe accessor for returnLevel (can be called from any thread)
    nonisolated var returnLevelSafe: Float {
        _returnLevelLock.lock()
        defer { _returnLevelLock.unlock() }
        return _returnLevelShadow
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

    /// Whether the send effect is bypassed
    @MainActor @Published var isBypassed: Bool = false {
        didSet {
            _isBypassedLock.lock()
            _isBypassedShadow = isBypassed
            _isBypassedLock.unlock()
        }
    }

    /// Return level (0-1) - how much of the wet signal returns to master
    @MainActor @Published var returnLevel: Float = 0.5 {
        didSet {
            _returnLevelLock.lock()
            _returnLevelShadow = returnLevel
            _returnLevelLock.unlock()
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

    /// The plugin's view controller for native UI
    @MainActor @Published var viewController: NSViewController?

    /// Whether the plugin's native UI is being loaded
    @MainActor @Published var isLoadingUI: Bool = false

    // MARK: - Callbacks

    /// Called when the audio unit changes
    var onAudioUnitChanged: ((AVAudioUnit?) -> Void)?

    /// Called when bypass or return level changes
    var onParameterChanged: (() -> Void)?

    // MARK: - Initialization

    init(busIndex: Int, busName: String) {
        self.busIndex = busIndex
        self.busName = busName
    }

    // MARK: - Computed Properties

    /// Return level as dB string for display
    @MainActor
    var returnLevelDB: String {
        if returnLevel < 0.001 { return "-∞" }
        let db = 20 * log10(Double(returnLevel))
        if db > 0 {
            return String(format: "+%.1f", db)
        }
        return String(format: "%.1f", db)
    }

    /// Whether this send is active (has plugin and not bypassed)
    @MainActor
    var isActive: Bool {
        audioUnit != nil && !isBypassed
    }

    // MARK: - Plugin Loading

    /// Loads an Audio Unit plugin into this send bus
    @MainActor
    func loadPlugin(_ info: AUPluginInfo, using pluginManager: AUPluginManager) async throws {
        unloadPlugin()

        isLoading = true
        loadError = nil

        do {
            let au = try await pluginManager.instantiatePlugin(info, outOfProcess: true)

            self.audioUnit = au
            self.pluginInfo = info
            self.isLoading = false

            // Defer graph mutations until after the current gesture/action cycle.
            DispatchQueue.main.async { [weak self] in
                self?.onAudioUnitChanged?(au)
            }

            print("✓ Loaded AU into send bus \(busName): \(info.name)")
        } catch {
            self.isLoading = false
            self.loadError = error.localizedDescription
            print("✗ Failed to load AU into send bus \(busName): \(error)")
            throw error
        }
    }

    /// Unloads the current plugin
    @MainActor
    func unloadPlugin() {
        if audioUnit != nil {
            print("✓ Unloading AU from send bus \(busName)")

            viewController = nil
            audioUnit = nil
            pluginInfo = nil

            // Defer graph mutations until after the current gesture/action cycle.
            DispatchQueue.main.async { [weak self] in
                self?.onAudioUnitChanged?(nil)
            }
        }
    }

    /// Sets the bypass state
    @MainActor
    func setBypass(_ bypassed: Bool) {
        guard isBypassed != bypassed else { return }
        isBypassed = bypassed

        if let au = audioUnit {
            au.auAudioUnit.shouldBypassEffect = bypassed
        }

        DispatchQueue.main.async { [weak self] in
            self?.onParameterChanged?()
        }
    }

    /// Sets the return level (0-1)
    @MainActor
    func setReturnLevel(_ level: Float) {
        returnLevel = max(0, min(1, level))
        DispatchQueue.main.async { [weak self] in
            self?.onParameterChanged?()
        }
    }

    // MARK: - Native UI

    /// Requests the plugin's native UI
    @MainActor
    func loadPluginUI() {
        guard let au = audioUnit else { return }
        guard viewController == nil else { return }

        isLoadingUI = true

        au.auAudioUnit.requestViewController { [weak self] vc in
            DispatchQueue.main.async {
                self?.viewController = vc
                self?.isLoadingUI = false
            }
        }
    }

    /// Clears the cached view controller
    @MainActor
    func unloadPluginUI() {
        viewController = nil
    }

    // MARK: - State Persistence

    @MainActor
    var fullState: [String: Any]? {
        audioUnit?.auAudioUnit.fullState
    }

    @MainActor
    func restoreState(_ state: [String: Any]) {
        guard let au = audioUnit else { return }
        au.auAudioUnit.fullState = state
    }

    @MainActor
    func createSnapshot() -> AUSendSnapshot? {
        guard let info = pluginInfo else { return nil }

        var stateData: Data?
        if let state = fullState {
            stateData = try? NSKeyedArchiver.archivedData(withRootObject: state, requiringSecureCoding: false)
        }

        return AUSendSnapshot(
            busIndex: busIndex,
            componentType: info.componentDescription.componentType,
            componentSubType: info.componentDescription.componentSubType,
            componentManufacturer: info.componentDescription.componentManufacturer,
            fullState: stateData,
            isBypassed: isBypassed,
            returnLevel: returnLevel
        )
    }

    @MainActor
    func restoreFromSnapshot(_ snapshot: AUSendSnapshot, using pluginManager: AUPluginManager) async throws {
        var desc = AudioComponentDescription()
        desc.componentType = snapshot.componentType
        desc.componentSubType = snapshot.componentSubType
        desc.componentManufacturer = snapshot.componentManufacturer
        desc.componentFlags = 0
        desc.componentFlagsMask = 0

        guard let info = pluginManager.availableEffects.first(where: {
            $0.componentDescription.componentType == desc.componentType &&
            $0.componentDescription.componentSubType == desc.componentSubType &&
            $0.componentDescription.componentManufacturer == desc.componentManufacturer
        }) else {
            throw AUPluginError.pluginNotFound
        }

        try await loadPlugin(info, using: pluginManager)

        if let stateData = snapshot.fullState,
           let state = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(stateData) as? [String: Any] {
            restoreState(state)
        }

        setBypass(snapshot.isBypassed)
        setReturnLevel(snapshot.returnLevel)
    }
}

// MARK: - AU Send Snapshot

/// Codable snapshot of a send effect bus for project saving
struct AUSendSnapshot: Codable {
    let busIndex: Int
    let componentType: UInt32
    let componentSubType: UInt32
    let componentManufacturer: UInt32
    let fullState: Data?
    let isBypassed: Bool
    let returnLevel: Float
}

// MARK: - Send Effect Configuration

/// Pre-configured send effect types with recommended default plugins
enum SendEffectType: String, CaseIterable, Identifiable {
    case delay = "Delay"
    case reverb = "Reverb"

    var id: String { rawValue }

    /// Recommended plugin search keywords for this send type
    var searchKeywords: [String] {
        switch self {
        case .delay: return ["delay", "echo", "tape"]
        case .reverb: return ["reverb", "room", "hall", "plate"]
        }
    }

    /// Bus index for this send type
    var busIndex: Int {
        switch self {
        case .delay: return 0
        case .reverb: return 1
        }
    }

    /// Default color for UI
    var accentColor: Color {
        switch self {
        case .delay: return ColorPalette.ledAmber
        case .reverb: return ColorPalette.ledGreen
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension AUSendSlot {
    static var previewDelay: AUSendSlot {
        AUSendSlot(busIndex: 0, busName: "Delay")
    }

    static var previewReverb: AUSendSlot {
        AUSendSlot(busIndex: 1, busName: "Reverb")
    }
}
#endif

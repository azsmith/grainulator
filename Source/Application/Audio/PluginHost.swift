//
//  PluginHost.swift
//  Grainulator
//
//  Backend-agnostic plugin hosting protocol. AU is backend 1, VST3 is backend 2.
//  Mixer code talks only to this protocol — never to AVAudioUnit or VST3 types directly.
//

import AVFoundation
import AppKit

// MARK: - Plugin Backend Enum

/// Which plugin hosting backend to use
enum PluginBackend: String, CaseIterable, Codable {
    case au = "au"
    case vst3 = "vst3"
}

// MARK: - Plugin Descriptor

/// Backend-agnostic plugin identity — enough info to find, load, and save/restore a plugin
struct PluginDescriptor: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let manufacturerName: String
    let backend: PluginBackend

    /// AU: AudioComponentDescription fields. VST3: class ID bytes
    let componentType: UInt32
    let componentSubType: UInt32
    let componentManufacturer: UInt32

    /// For VST3: the 128-bit FUID as hex string (e.g. "58E595CC2DB24EFF...")
    let vst3ClassID: String?

    /// Human-readable category hint (from plugin metadata)
    let typeName: String

    /// Whether the plugin advertises a custom GUI
    let hasCustomView: Bool

    /// Short name for compact UI
    var abbreviation: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return words.prefix(3).map { String($0.first ?? Character("")) }.joined().uppercased()
        } else if name.count >= 3 {
            return String(name.prefix(3)).uppercased()
        }
        return name.uppercased()
    }

    /// Category based on name keywords
    var category: AUPluginCategory? {
        let lowercaseName = name.lowercased()
        for cat in AUPluginCategory.allCases where cat != .all && cat != .other {
            if cat.keywords.contains(where: { lowercaseName.contains($0) }) {
                return cat
            }
        }
        return .other
    }

    /// Create from existing AUPluginInfo (bridge from legacy type)
    init(from auInfo: AUPluginInfo) {
        self.id = auInfo.id
        self.name = auInfo.name
        self.manufacturerName = auInfo.manufacturerName
        self.backend = .au
        self.componentType = auInfo.componentDescription.componentType
        self.componentSubType = auInfo.componentDescription.componentSubType
        self.componentManufacturer = auInfo.componentDescription.componentManufacturer
        self.vst3ClassID = nil
        self.typeName = auInfo.typeName
        self.hasCustomView = auInfo.hasCustomView
    }

    /// Create for VST3 plugin
    init(name: String, manufacturerName: String, vst3ClassID: String, typeName: String = "Effect", hasCustomView: Bool = true) {
        self.id = UUID()
        self.name = name
        self.manufacturerName = manufacturerName
        self.backend = .vst3
        self.componentType = 0
        self.componentSubType = 0
        self.componentManufacturer = 0
        self.vst3ClassID = vst3ClassID
        self.typeName = typeName
        self.hasCustomView = hasCustomView
    }
}

// MARK: - Plugin Instance

/// Opaque handle to a loaded plugin instance.
/// Each backend provides its own conforming type.
protocol PluginInstance: AnyObject, Sendable {
    /// The descriptor that was used to load this instance
    var descriptor: PluginDescriptor { get }

    /// Which backend owns this instance
    var backend: PluginBackend { get }

    /// Set bypass state on the underlying plugin
    func setBypass(_ bypassed: Bool)

    /// Get/set the full state dictionary for save/restore
    var fullState: [String: Any]? { get set }

    /// Request the plugin's native UI view controller (nil if no custom view)
    func requestViewController(completion: @escaping (NSViewController?) -> Void)

    /// For AU backend: the underlying AVAudioUnit (needed for graph connection)
    var avAudioUnit: AVAudioUnit? { get }

    /// For VST3 backend: opaque C++ handle for bridge calls
    var vst3Handle: OpaquePointer? { get }
}

// MARK: - Plugin Host Protocol

/// Backend-agnostic plugin host. Implementations scan for plugins,
/// instantiate them, and manage their lifecycle.
@MainActor
protocol PluginHost: AnyObject {
    /// Which backend this host provides
    var backend: PluginBackend { get }

    /// All available plugins discovered on the system
    var availablePlugins: [PluginDescriptor] { get }

    /// Whether a scan is in progress
    var isScanning: Bool { get }

    /// Scan/refresh the list of available plugins
    func refreshPluginList()

    /// Instantiate a plugin from its descriptor
    /// - Parameters:
    ///   - descriptor: Which plugin to load
    ///   - outOfProcess: If true, load in separate process for crash isolation (AU only)
    /// - Returns: A loaded plugin instance
    func instantiate(_ descriptor: PluginDescriptor, outOfProcess: Bool) async throws -> PluginInstance

    /// Release a previously loaded instance
    func release(_ instance: PluginInstance)

    /// Search available plugins by query string
    func search(_ query: String) -> [PluginDescriptor]

    /// Filter available plugins by category
    func plugins(in category: AUPluginCategory) -> [PluginDescriptor]
}

// MARK: - AU Plugin Host (Backend 1)

/// Wraps AUPluginManager behind the PluginHost protocol
@MainActor
final class AUPluginHost: PluginHost {
    let backend: PluginBackend = .au
    private let manager: AUPluginManager

    var availablePlugins: [PluginDescriptor] {
        manager.availableEffects.map { PluginDescriptor(from: $0) }
    }

    var isScanning: Bool { manager.isScanning }

    init(manager: AUPluginManager) {
        self.manager = manager
    }

    func refreshPluginList() {
        manager.refreshPluginList()
    }

    func instantiate(_ descriptor: PluginDescriptor, outOfProcess: Bool) async throws -> PluginInstance {
        // Find the matching AUPluginInfo
        guard let auInfo = manager.availableEffects.first(where: {
            $0.componentDescription.componentType == descriptor.componentType &&
            $0.componentDescription.componentSubType == descriptor.componentSubType &&
            $0.componentDescription.componentManufacturer == descriptor.componentManufacturer
        }) else {
            throw AUPluginError.pluginNotFound
        }

        let au = try await manager.instantiatePlugin(auInfo, outOfProcess: outOfProcess)
        return AUPluginInstanceWrapper(avAudioUnit: au, descriptor: descriptor)
    }

    func release(_ instance: PluginInstance) {
        if let wrapper = instance as? AUPluginInstanceWrapper {
            manager.releasePlugin(wrapper.wrappedAU)
        }
    }

    func search(_ query: String) -> [PluginDescriptor] {
        manager.search(query).map { PluginDescriptor(from: $0) }
    }

    func plugins(in category: AUPluginCategory) -> [PluginDescriptor] {
        manager.plugins(in: category).map { PluginDescriptor(from: $0) }
    }

    /// Access the underlying AUPluginManager for legacy code that still needs it
    var legacyManager: AUPluginManager { manager }
}

// MARK: - AU Plugin Instance Wrapper

/// Wraps AVAudioUnit as a PluginInstance
final class AUPluginInstanceWrapper: PluginInstance, @unchecked Sendable {
    let descriptor: PluginDescriptor
    let backend: PluginBackend = .au
    let wrappedAU: AVAudioUnit

    init(avAudioUnit: AVAudioUnit, descriptor: PluginDescriptor) {
        self.wrappedAU = avAudioUnit
        self.descriptor = descriptor
    }

    func setBypass(_ bypassed: Bool) {
        wrappedAU.auAudioUnit.shouldBypassEffect = bypassed
    }

    var fullState: [String: Any]? {
        get { wrappedAU.auAudioUnit.fullState }
        set { wrappedAU.auAudioUnit.fullState = newValue }
    }

    func requestViewController(completion: @escaping (NSViewController?) -> Void) {
        wrappedAU.auAudioUnit.requestViewController { vc in
            DispatchQueue.main.async { completion(vc) }
        }
    }

    var avAudioUnit: AVAudioUnit? { wrappedAU }
    var vst3Handle: OpaquePointer? { nil }
}

// MARK: - Plugin Snapshot (backend-agnostic)

/// Codable snapshot for project save/restore — replaces AUSlotSnapshot and AUSendSnapshot
/// for new code paths while remaining compatible with legacy snapshots
struct PluginSnapshot: Codable {
    let backend: PluginBackend
    let componentType: UInt32
    let componentSubType: UInt32
    let componentManufacturer: UInt32
    let vst3ClassID: String?
    let fullState: Data?
    let isBypassed: Bool
    let returnLevel: Float?  // nil for insert slots

    /// Convert from legacy AUSlotSnapshot
    init(from legacy: AUSlotSnapshot) {
        self.backend = .au
        self.componentType = legacy.componentType
        self.componentSubType = legacy.componentSubType
        self.componentManufacturer = legacy.componentManufacturer
        self.vst3ClassID = nil
        self.fullState = legacy.fullState
        self.isBypassed = legacy.isBypassed
        self.returnLevel = nil
    }

    /// Convert from legacy AUSendSnapshot
    init(from legacy: AUSendSnapshot) {
        self.backend = .au
        self.componentType = legacy.componentType
        self.componentSubType = legacy.componentSubType
        self.componentManufacturer = legacy.componentManufacturer
        self.vst3ClassID = nil
        self.fullState = legacy.fullState
        self.isBypassed = legacy.isBypassed
        self.returnLevel = legacy.returnLevel
    }

    /// Convert to legacy AUSlotSnapshot (for backward compat)
    func toAUSlotSnapshot() -> AUSlotSnapshot? {
        guard backend == .au else { return nil }
        return AUSlotSnapshot(
            componentType: componentType,
            componentSubType: componentSubType,
            componentManufacturer: componentManufacturer,
            fullState: fullState,
            isBypassed: isBypassed
        )
    }

    /// Convert to legacy AUSendSnapshot (for backward compat)
    func toAUSendSnapshot(busIndex: Int) -> AUSendSnapshot? {
        guard backend == .au else { return nil }
        return AUSendSnapshot(
            busIndex: busIndex,
            componentType: componentType,
            componentSubType: componentSubType,
            componentManufacturer: componentManufacturer,
            fullState: fullState,
            isBypassed: isBypassed,
            returnLevel: returnLevel ?? 0.5
        )
    }
}

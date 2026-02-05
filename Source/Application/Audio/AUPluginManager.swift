//
//  AUPluginManager.swift
//  Grainulator
//
//  Manages Audio Unit plugin enumeration, instantiation, and lifecycle.
//  Provides SwiftUI-friendly interface for browsing and loading AU effect plugins.
//

import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - AU Plugin Info

/// Represents metadata for an available Audio Unit plugin
struct AUPluginInfo: Identifiable, Hashable {
    let id: UUID
    let name: String
    let manufacturerName: String
    let componentDescription: AudioComponentDescription
    let typeName: String
    let hasCustomView: Bool
    let version: UInt32

    /// Short name for display in compact UI (first 3 chars or abbreviation)
    var abbreviation: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            // Use first letter of each word (up to 3)
            return words.prefix(3).map { String($0.first ?? Character("")) }.joined().uppercased()
        } else if name.count >= 3 {
            return String(name.prefix(3)).uppercased()
        }
        return name.uppercased()
    }

    /// Determines the category based on plugin name
    var category: AUPluginCategory? {
        let lowercaseName = name.lowercased()
        for cat in AUPluginCategory.allCases where cat != .all && cat != .other {
            if cat.keywords.contains(where: { lowercaseName.contains($0) }) {
                return cat
            }
        }
        return .other
    }

    /// Creates AUPluginInfo from an AVAudioUnitComponent
    init(component: AVAudioUnitComponent) {
        self.id = UUID()
        self.name = component.name
        self.manufacturerName = component.manufacturerName
        self.componentDescription = component.audioComponentDescription
        self.hasCustomView = component.hasCustomView
        self.version = UInt32(component.version)

        // Determine type name from component type
        switch component.audioComponentDescription.componentType {
        case kAudioUnitType_Effect:
            self.typeName = "Effect"
        case kAudioUnitType_MusicEffect:
            self.typeName = "Music Effect"
        case kAudioUnitType_Mixer:
            self.typeName = "Mixer"
        case kAudioUnitType_Panner:
            self.typeName = "Panner"
        case kAudioUnitType_Generator:
            self.typeName = "Generator"
        case kAudioUnitType_MusicDevice:
            self.typeName = "Instrument"
        case kAudioUnitType_FormatConverter:
            self.typeName = "Converter"
        default:
            self.typeName = "Other"
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(componentDescription.componentType)
        hasher.combine(componentDescription.componentSubType)
        hasher.combine(componentDescription.componentManufacturer)
    }

    static func == (lhs: AUPluginInfo, rhs: AUPluginInfo) -> Bool {
        lhs.componentDescription.componentType == rhs.componentDescription.componentType &&
        lhs.componentDescription.componentSubType == rhs.componentDescription.componentSubType &&
        lhs.componentDescription.componentManufacturer == rhs.componentDescription.componentManufacturer
    }
}

// MARK: - AU Plugin Category

/// Categories for organizing plugins in the browser
enum AUPluginCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case eq = "EQ"
    case dynamics = "Dynamics"
    case delay = "Delay"
    case reverb = "Reverb"
    case modulation = "Modulation"
    case distortion = "Distortion"
    case filter = "Filter"
    case other = "Other"

    var id: String { rawValue }

    /// Keywords used to categorize plugins by name
    var keywords: [String] {
        switch self {
        case .all: return []
        case .eq: return ["eq", "equalizer", "band", "parametric", "graphic", "shelf", "low cut", "high cut"]
        case .dynamics: return ["compressor", "limiter", "gate", "expander", "dynamics", "transient"]
        case .delay: return ["delay", "echo", "tape", "pingpong"]
        case .reverb: return ["reverb", "room", "hall", "plate", "spring", "convolution", "ambience"]
        case .modulation: return ["chorus", "flanger", "phaser", "tremolo", "vibrato", "rotary", "ensemble"]
        case .distortion: return ["distortion", "overdrive", "saturation", "fuzz", "amp", "tube", "tape"]
        case .filter: return ["filter", "wah", "formant", "vowel", "resonant"]
        case .other: return []
        }
    }

    /// Determines if a plugin belongs to this category
    func matches(_ pluginName: String) -> Bool {
        if self == .all { return true }
        let lowercaseName = pluginName.lowercased()
        return keywords.contains { lowercaseName.contains($0) }
    }
}

// MARK: - AU Plugin Manager

/// Manages the discovery and instantiation of Audio Unit plugins
@MainActor
class AUPluginManager: ObservableObject {
    // MARK: - Published Properties

    /// All available effect plugins on the system
    @Published var availableEffects: [AUPluginInfo] = []

    /// Plugins grouped by manufacturer
    @Published var effectsByManufacturer: [String: [AUPluginInfo]] = [:]

    /// List of all manufacturer names (sorted)
    @Published var manufacturers: [String] = []

    /// Whether plugin scanning is in progress
    @Published var isScanning: Bool = false

    /// Error message if scanning failed
    @Published var scanError: String?

    // MARK: - Private Properties

    private let componentManager = AVAudioUnitComponentManager.shared()

    // MARK: - Initialization

    init() {
        // Register for plugin change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(componentsDidChange),
            name: .AVAudioUnitComponentTagsDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Plugin Discovery

    /// Scans the system for available AU effect plugins
    func refreshPluginList() {
        isScanning = true
        scanError = nil

        Task {
            do {
                let effects = try await scanForEffectPlugins()
                await MainActor.run {
                    self.availableEffects = effects
                    self.organizeByManufacturer()
                    self.isScanning = false
                    print("✓ Found \(effects.count) AU effect plugins")
                }
            } catch {
                await MainActor.run {
                    self.scanError = error.localizedDescription
                    self.isScanning = false
                    print("✗ AU plugin scan failed: \(error)")
                }
            }
        }
    }

    /// Scans for effect-type Audio Units
    private func scanForEffectPlugins() async throws -> [AUPluginInfo] {
        // Create description to match all effect-type AUs
        var effectDescription = AudioComponentDescription()
        effectDescription.componentType = kAudioUnitType_Effect
        effectDescription.componentSubType = 0  // Match all
        effectDescription.componentManufacturer = 0  // Match all
        effectDescription.componentFlags = 0
        effectDescription.componentFlagsMask = 0

        let effectComponents = componentManager.components(matching: effectDescription)

        // Also get "music effect" type (effects that respond to MIDI)
        var musicEffectDescription = AudioComponentDescription()
        musicEffectDescription.componentType = kAudioUnitType_MusicEffect
        musicEffectDescription.componentSubType = 0
        musicEffectDescription.componentManufacturer = 0
        musicEffectDescription.componentFlags = 0
        musicEffectDescription.componentFlagsMask = 0

        let musicEffectComponents = componentManager.components(matching: musicEffectDescription)

        // Combine and convert to AUPluginInfo
        let allComponents = effectComponents + musicEffectComponents
        let plugins = allComponents.map { AUPluginInfo(component: $0) }

        // Sort by manufacturer, then name
        return plugins.sorted {
            if $0.manufacturerName == $1.manufacturerName {
                return $0.name < $1.name
            }
            return $0.manufacturerName < $1.manufacturerName
        }
    }

    /// Organizes plugins by manufacturer for grouped display
    private func organizeByManufacturer() {
        var grouped: [String: [AUPluginInfo]] = [:]

        for plugin in availableEffects {
            let manufacturer = plugin.manufacturerName
            if grouped[manufacturer] == nil {
                grouped[manufacturer] = []
            }
            grouped[manufacturer]?.append(plugin)
        }

        effectsByManufacturer = grouped
        manufacturers = grouped.keys.sorted()
    }

    /// Filters plugins by category
    func plugins(in category: AUPluginCategory) -> [AUPluginInfo] {
        if category == .all {
            return availableEffects
        }
        return availableEffects.filter { category.matches($0.name) }
    }

    /// Filters plugins by search text
    func search(_ query: String) -> [AUPluginInfo] {
        guard !query.isEmpty else { return availableEffects }
        let lowercaseQuery = query.lowercased()
        return availableEffects.filter {
            $0.name.lowercased().contains(lowercaseQuery) ||
            $0.manufacturerName.lowercased().contains(lowercaseQuery)
        }
    }

    // MARK: - Plugin Instantiation

    /// Instantiates an Audio Unit from plugin info
    /// - Parameters:
    ///   - info: The plugin to instantiate
    ///   - outOfProcess: If true, loads plugin in separate process for crash isolation
    /// - Returns: The instantiated AVAudioUnit
    func instantiatePlugin(_ info: AUPluginInfo, outOfProcess: Bool = true) async throws -> AVAudioUnit {
        let options: AudioComponentInstantiationOptions = outOfProcess ? [.loadOutOfProcess] : []

        return try await withCheckedThrowingContinuation { continuation in
            AVAudioUnit.instantiate(
                with: info.componentDescription,
                options: options
            ) { audioUnit, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let audioUnit = audioUnit {
                    print("✓ Instantiated AU: \(info.name)")
                    continuation.resume(returning: audioUnit)
                } else {
                    continuation.resume(throwing: AUPluginError.instantiationFailed)
                }
            }
        }
    }

    /// Releases an Audio Unit instance
    func releasePlugin(_ unit: AVAudioUnit) {
        // The AU will be released when there are no more strong references
        // This method exists for explicit lifecycle management
        print("✓ Released AU: \(unit.name)")
    }

    // MARK: - Notifications

    @objc private func componentsDidChange(_ notification: Notification) {
        // Refresh plugin list when system AUs change (plugin installed/removed)
        refreshPluginList()
    }
}

// MARK: - AU Plugin Error

enum AUPluginError: Error, LocalizedError {
    case instantiationFailed
    case connectionFailed
    case formatMismatch
    case pluginNotFound
    case stateSaveLoadFailed

    var errorDescription: String? {
        switch self {
        case .instantiationFailed:
            return "Failed to instantiate Audio Unit plugin"
        case .connectionFailed:
            return "Failed to connect Audio Unit to audio graph"
        case .formatMismatch:
            return "Audio format mismatch with Audio Unit"
        case .pluginNotFound:
            return "Audio Unit plugin not found on system"
        case .stateSaveLoadFailed:
            return "Failed to save or load Audio Unit state"
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension AUPluginManager {
    /// Creates a manager with mock data for previews
    static var preview: AUPluginManager {
        let manager = AUPluginManager()
        // Note: Actual plugins won't be available in previews
        // The manager will scan for real plugins when refreshPluginList() is called
        return manager
    }
}
#endif

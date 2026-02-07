//
//  MixerChannel.swift
//  Grainulator
//
//  Model representing a mixer channel's state
//

import SwiftUI
import Combine

// MARK: - Channel Identity

enum ChannelType: Int, CaseIterable, Identifiable {
    case plaits = 0
    case rings = 1
    case granular1 = 2
    case looper1 = 3
    case looper2 = 4
    case granular4 = 5
    case daisyDrum = 6
    case sampler = 7

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .plaits: return "PLAITS"
        case .rings: return "RINGS"
        case .granular1: return "GRAN 1"
        case .looper1: return "LOOP 1"
        case .looper2: return "LOOP 2"
        case .granular4: return "GRAN 4"
        case .daisyDrum: return "DRUMS"
        case .sampler: return "SAMPLER"
        }
    }

    var shortName: String {
        switch self {
        case .plaits: return "PLA"
        case .rings: return "RNG"
        case .granular1: return "GR1"
        case .looper1: return "LP1"
        case .looper2: return "LP2"
        case .granular4: return "GR4"
        case .daisyDrum: return "DRM"
        case .sampler: return "SMP"
        }
    }

    var accentColor: Color {
        ColorPalette.channelColor(for: rawValue)
    }

    var voiceIndex: Int {
        // Maps channel type to audio engine voice index
        switch self {
        case .plaits: return 0
        case .rings: return 1
        case .granular1: return 0  // Granular voice 0
        case .looper1: return 1    // Looper voice 1
        case .looper2: return 2    // Looper voice 2
        case .granular4: return 3  // Granular voice 3
        case .daisyDrum: return 0  // Single drum voice
        case .sampler: return 0    // Single SoundFont voice
        }
    }
}

// MARK: - Insert Effect Slot

enum InsertEffectType: String, CaseIterable, Identifiable {
    case none = "None"
    case eq = "EQ"
    case compressor = "Comp"
    case filter = "Filter"
    case saturator = "Sat"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var abbreviation: String {
        switch self {
        case .none: return "—"
        case .eq: return "EQ"
        case .compressor: return "CP"
        case .filter: return "FL"
        case .saturator: return "ST"
        }
    }

    var parameterCount: Int {
        switch self {
        case .none: return 0
        case .eq: return 3        // Low, Mid, High
        case .compressor: return 3 // Threshold, Ratio, Gain
        case .filter: return 3    // Cutoff, Resonance, Type
        case .saturator: return 3 // Drive, Tone, Mix
        }
    }
}

// MARK: - Insert Effect State

class InsertEffectState: ObservableObject, Identifiable {
    let id = UUID()
    let slotIndex: Int

    @Published var effectType: InsertEffectType = .none
    @Published var isBypassed: Bool = false
    @Published var parameters: [Float]

    init(slotIndex: Int) {
        self.slotIndex = slotIndex
        self.parameters = Array(repeating: 0.5, count: 6) // Max params
    }

    func setEffect(_ type: InsertEffectType) {
        effectType = type
        // Reset parameters to defaults when changing effect
        if type.parameterCount > 0 {
            parameters = Array(repeating: 0.5, count: max(type.parameterCount, 3))
        }
    }

    // Convenience accessors for first 3 parameters
    var param1: Float {
        get { parameters.count > 0 ? parameters[0] : 0.5 }
        set { if parameters.count > 0 { parameters[0] = newValue } }
    }

    var param2: Float {
        get { parameters.count > 1 ? parameters[1] : 0.5 }
        set { if parameters.count > 1 { parameters[1] = newValue } }
    }

    var param3: Float {
        get { parameters.count > 2 ? parameters[2] : 0.5 }
        set { if parameters.count > 2 { parameters[2] = newValue } }
    }
}

// MARK: - Send Configuration

enum SendMode: String, CaseIterable {
    case preFader = "Pre"
    case postFader = "Post"
}

struct SendState {
    var level: Float = 0.3      // 0-1 send amount (default ~-10dB so AU plugins have signal)
    var mode: SendMode = .postFader
    var isEnabled: Bool = true
}

// MARK: - Mixer Channel State

class MixerChannelState: ObservableObject, Identifiable {
    let id: UUID
    let channelType: ChannelType

    // Basic mix parameters
    @Published var gain: Float = 0.5        // 0-1, 0.5 = unity (0dB)
    @Published var pan: Float = 0.5         // 0-1, 0.5 = center
    @Published var isMuted: Bool = false
    @Published var isSolo: Bool = false

    // Send levels (dual send architecture)
    @Published var sendA: SendState = SendState()  // Delay send
    @Published var sendB: SendState = SendState()  // Reverb send

    // Insert effects (2 slots per channel)
    @Published var insert1: InsertEffectState
    @Published var insert2: InsertEffectState

    // Metering
    @Published var meterLevel: Float = 0.0
    @Published var peakLevel: Float = 0.0

    // Micro-delay for timing alignment (samples)
    @Published var microDelay: Int = 0      // 0-2400 samples (50ms @ 48kHz)

    // Phase invert
    @Published var isPhaseInverted: Bool = false

    init(channelType: ChannelType) {
        self.id = UUID()
        self.channelType = channelType
        self.insert1 = InsertEffectState(slotIndex: 0)
        self.insert2 = InsertEffectState(slotIndex: 1)
    }

    // Computed properties
    var name: String { channelType.name }
    var accentColor: Color { channelType.accentColor }
    var channelIndex: Int { channelType.rawValue }

    /// Effective gain considering mute state
    var effectiveGain: Float {
        isMuted ? 0.0 : gain
    }

    /// dB value for display
    var gainDB: String {
        if gain < 0.001 { return "-∞" }
        let linearGain = gain * 2  // 0.5 = unity
        let db = 20 * log10(Double(linearGain))
        if db > 0 {
            return String(format: "+%.1f", db)
        }
        return String(format: "%.1f", db)
    }

    /// Pan display string
    var panDisplay: String {
        let panValue = (pan - 0.5) * 2  // -1 to +1
        if abs(panValue) < 0.05 { return "C" }
        if panValue < 0 { return String(format: "L%d", Int(abs(panValue) * 100)) }
        return String(format: "R%d", Int(panValue * 100))
    }
}

// MARK: - Master Channel State

class MasterChannelState: ObservableObject {
    @Published var gain: Float = 0.5        // Master fader
    @Published var isMuted: Bool = false

    // Stereo metering
    @Published var meterLevelL: Float = 0.0
    @Published var meterLevelR: Float = 0.0
    @Published var peakLevelL: Float = 0.0
    @Published var peakLevelR: Float = 0.0

    // Master effects returns
    @Published var delayReturnLevel: Float = 0.5   // Send A return
    @Published var reverbReturnLevel: Float = 0.5  // Send B return

    // Master filter (existing)
    @Published var filterCutoff: Float = 1.0
    @Published var filterResonance: Float = 0.0
    @Published var filterModel: Int = 0

    var gainDB: String {
        if gain < 0.001 { return "-∞" }
        let linearGain = gain * 2
        let db = 20 * log10(Double(linearGain))
        if db > 0 {
            return String(format: "+%.1f", db)
        }
        return String(format: "%.1f", db)
    }
}

// MARK: - Mixer State (All Channels)

@MainActor
class MixerState: ObservableObject {
    @Published var channels: [MixerChannelState]
    @Published var master: MasterChannelState

    // Solo state tracking
    @Published var anySolo: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Create all channel states
        self.channels = ChannelType.allCases.map { MixerChannelState(channelType: $0) }
        self.master = MasterChannelState()

        // Subscribe to solo changes
        for channel in channels {
            channel.$isSolo
                .sink { [weak self] _ in
                    self?.updateSoloState()
                }
                .store(in: &cancellables)
        }
    }

    private func updateSoloState() {
        anySolo = channels.contains { $0.isSolo }
    }

    /// Get channel by type
    func channel(for type: ChannelType) -> MixerChannelState {
        channels[type.rawValue]
    }

    /// Get channel by index
    func channel(at index: Int) -> MixerChannelState? {
        guard index >= 0 && index < channels.count else { return nil }
        return channels[index]
    }

    /// Check if a channel should be audible (considering solo)
    func isChannelAudible(_ channel: MixerChannelState) -> Bool {
        if channel.isMuted { return false }
        if anySolo && !channel.isSolo { return false }
        return true
    }

    /// Reset all channels to default
    func resetAll() {
        for channel in channels {
            channel.gain = 0.5
            channel.pan = 0.5
            channel.isMuted = false
            channel.isSolo = false
            channel.sendA = SendState()
            channel.sendB = SendState()
        }
        master.gain = 0.5
        master.isMuted = false
    }

    // MARK: - Audio Engine Synchronization

    /// Push all mixer state to the audio engine
    func syncToAudioEngine(_ audioEngine: AudioEngineWrapper) {
        for channel in channels {
            syncChannelToEngine(channel, audioEngine: audioEngine)
        }
        syncMasterToEngine(audioEngine)
    }

    /// Push a single channel's state to the audio engine
    func syncChannelToEngine(_ channel: MixerChannelState, audioEngine: AudioEngineWrapper) {
        let voiceIndex = channel.channelIndex

        // Effective gain (considering mute/solo)
        let effectiveGain: Float
        if channel.isMuted || (anySolo && !channel.isSolo) {
            effectiveGain = 0.0
        } else {
            effectiveGain = channel.gain
        }

        audioEngine.setParameter(id: .voiceGain, value: effectiveGain, voiceIndex: voiceIndex)
        audioEngine.setParameter(id: .voicePan, value: channel.pan, voiceIndex: voiceIndex)
        audioEngine.setSendLevel(channelIndex: voiceIndex, sendIndex: 0, level: channel.sendA.level)
        audioEngine.setSendLevel(channelIndex: voiceIndex, sendIndex: 1, level: channel.sendB.level)
    }

    /// Push master state to the audio engine
    func syncMasterToEngine(_ audioEngine: AudioEngineWrapper) {
        let effectiveGain = master.isMuted ? 0.0 : master.gain
        audioEngine.setParameter(id: .masterGain, value: Float(effectiveGain))

        // Master filter
        audioEngine.setParameter(id: .masterFilterCutoff, value: master.filterCutoff)
        audioEngine.setParameter(id: .masterFilterResonance, value: master.filterResonance)

        // Route aux returns through AU send slots in legacy mode.
        audioEngine.setSendReturnLevel(busIndex: 0, level: master.delayReturnLevel)
        audioEngine.setSendReturnLevel(busIndex: 1, level: master.reverbReturnLevel)
        // Keep internal effects disabled to avoid double returns.
        audioEngine.setParameter(id: .delayMix, value: 0.0)
        audioEngine.setParameter(id: .reverbMix, value: 0.0)
    }

    /// Update meter levels from audio engine
    func updateMetersFromEngine(_ audioEngine: AudioEngineWrapper) {
        // Update channel meters
        for (index, channel) in channels.enumerated() {
            if index < audioEngine.channelLevels.count {
                channel.meterLevel = audioEngine.channelLevels[index]
            }
        }

        // Update master meters
        master.meterLevelL = audioEngine.masterLevelL
        master.meterLevelR = audioEngine.masterLevelR
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension MixerChannelState {
    static var preview: MixerChannelState {
        let state = MixerChannelState(channelType: .plaits)
        state.gain = 0.7
        state.pan = 0.6
        state.sendA.level = 0.3
        state.sendB.level = 0.2
        state.meterLevel = 0.5
        return state
    }
}

extension MixerState {
    static var preview: MixerState {
        let state = MixerState()
        state.channels[0].gain = 0.7
        state.channels[0].meterLevel = 0.6
        state.channels[1].gain = 0.5
        state.channels[1].isSolo = true
        state.channels[2].isMuted = true
        return state
    }
}
#endif

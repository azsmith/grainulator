//
//  ProjectSnapshot.swift
//  Grainulator
//
//  Top-level Codable model for serializing entire project state
//  Covers: engine parameters, mixer, sequencer, clock, AU plugins, audio files
//

import Foundation

// MARK: - Top-Level Project Snapshot

struct ProjectSnapshot: Codable {
    let version: Int
    var name: String
    var createdAt: Date
    var modifiedAt: Date

    var engineParameters: EngineParametersSnapshot
    var mixer: MixerSnapshot
    var sequencer: SequencerSnapshot
    var masterClock: MasterClockSnapshot
    var auPlugins: AUPluginsSnapshot
    var audioFiles: AudioFilesSnapshot
    var uiPreferences: UIPreferencesSnapshot

    static let currentVersion = 1
}

// MARK: - Engine Parameters Snapshot

struct EngineParametersSnapshot: Codable {
    var granularVoices: [GranularVoiceSnapshot]  // 4 granular voices (indices 0-3)
    var plaits: PlaitsSnapshot
    var rings: RingsSnapshot
    var delay: DelaySnapshot
    var reverb: ReverbSnapshot
    var masterFilter: MasterFilterSnapshot
    var loopers: [LooperSnapshot]  // 2 loopers (indices 1-2)
}

struct GranularVoiceSnapshot: Codable {
    var voiceIndex: Int
    var speed: Float
    var pitch: Float
    var size: Float
    var density: Float
    var jitter: Float
    var spread: Float
    var pan: Float
    var filterCutoff: Float
    var filterResonance: Float
    var gain: Float
    var send: Float
    var envelope: Float
    var decay: Float
    var filterModel: Float
    var reverse: Float
    var morph: Float
}

struct PlaitsSnapshot: Codable {
    var model: Float
    var harmonics: Float
    var timbre: Float
    var morph: Float
    var frequency: Float
    var level: Float
    var lpgColor: Float
    var lpgDecay: Float
    var lpgAttack: Float
    var lpgBypass: Float
}

struct RingsSnapshot: Codable {
    var model: Float
    var structure: Float
    var brightness: Float
    var damping: Float
    var position: Float
    var level: Float
}

struct DelaySnapshot: Codable {
    var time: Float
    var feedback: Float
    var mix: Float
    var headMode: Float
    var wow: Float
    var flutter: Float
    var tone: Float
    var sync: Float
    var tempo: Float
    var subdivision: Float
}

struct ReverbSnapshot: Codable {
    var size: Float
    var damping: Float
    var mix: Float
}

struct MasterFilterSnapshot: Codable {
    var cutoff: Float
    var resonance: Float
    var model: Float
}

struct LooperSnapshot: Codable {
    var voiceIndex: Int
    var rate: Float
    var reverse: Float
    var loopStart: Float
    var loopEnd: Float
    var cut: Float
}

// MARK: - Mixer Snapshot

struct MixerSnapshot: Codable {
    var channels: [MixerChannelSnapshot]
    var master: MasterChannelSnapshot
}

struct MixerChannelSnapshot: Codable {
    var channelIndex: Int
    var gain: Float
    var pan: Float
    var isMuted: Bool
    var isSolo: Bool
    var sendA: SendStateSnapshot
    var sendB: SendStateSnapshot
    var insert1: InsertEffectSnapshot
    var insert2: InsertEffectSnapshot
    var microDelay: Int
    var isPhaseInverted: Bool
}

struct SendStateSnapshot: Codable {
    var level: Float
    var mode: String  // SendMode raw value
    var isEnabled: Bool
}

struct InsertEffectSnapshot: Codable {
    var effectType: String  // InsertEffectType raw value
    var isBypassed: Bool
    var parameters: [Float]
}

struct MasterChannelSnapshot: Codable {
    var gain: Float
    var isMuted: Bool
    var delayReturnLevel: Float
    var reverbReturnLevel: Float
    var filterCutoff: Float
    var filterResonance: Float
    var filterModel: Int
}

// MARK: - Sequencer Snapshot

struct SequencerSnapshot: Codable {
    var tempoBPM: Double
    var rootNote: Int
    var sequenceOctave: Int
    var scaleIndex: Int
    var interEngineCompensationSamples: Int
    var plaitsTriggerOffsetMs: Double
    var ringsTriggerOffsetMs: Double
    var tracks: [SequencerTrackSnapshot]
}

struct SequencerTrackSnapshot: Codable {
    var id: Int
    var name: String
    var muted: Bool
    var direction: String       // SequencerDirection raw value
    var division: String        // SequencerClockDivision raw value
    var loopStart: Int
    var loopEnd: Int
    var transpose: Int
    var baseOctave: Int
    var velocity: Int
    var output: String          // SequencerTrackOutput raw value
    var stages: [SequencerStageSnapshot]
}

struct SequencerStageSnapshot: Codable {
    var id: Int
    var pulses: Int
    var gateMode: String        // SequencerGateMode raw value
    var ratchets: Int
    var probability: Double
    var noteSlot: Int
    var octave: Int
    var stepType: String        // SequencerStepType raw value
    var slide: Bool
}

// MARK: - Master Clock Snapshot

struct MasterClockSnapshot: Codable {
    var bpm: Double
    var swing: Float
    var externalSync: Bool
    var outputs: [ClockOutputSnapshot]
}

struct ClockOutputSnapshot: Codable {
    var id: Int
    var mode: String            // ClockOutputMode raw value
    var waveform: String        // ClockWaveform raw value
    var division: String        // SequencerClockDivision raw value
    var slowMode: Bool
    var level: Float
    var offset: Float
    var phase: Float
    var width: Float
    var destination: String     // ModulationDestination raw value
    var modulationAmount: Float
    var muted: Bool
}

// MARK: - AU Plugins Snapshot

struct AUPluginsSnapshot: Codable {
    var sendSlots: [AUSendSnapshot]       // Reuse existing Codable type
    var insertSlots: [[AUSlotSnapshot?]]  // [channelIndex][slotIndex]
}

// MARK: - Audio Files Snapshot

struct AudioFilesSnapshot: Codable {
    var reels: [AudioReelReference]
}

struct AudioReelReference: Codable {
    var reelIndex: Int
    var filePath: String  // Relative or absolute path
}

// MARK: - UI Preferences Snapshot

struct UIPreferencesSnapshot: Codable {
    var focusedVoice: Int
    var selectedGranularVoice: Int

    // Legacy fields kept for backward compatibility when loading old project files
    var useTabLayout: Bool?
    var useNewMixer: Bool?
    var currentView: String?
}

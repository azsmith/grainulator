//
//  MasterClock.swift
//  Grainulator
//
//  Pam's Pro Workout-inspired master clock and modulation system.
//  Provides a central BPM with 8 configurable outputs that can serve
//  as clock divisions or LFO waveforms for parameter modulation.
//

import Foundation
import Combine

// MARK: - Clock Output Waveform

enum ClockWaveform: String, CaseIterable, Identifiable {
    case gate = "GATE"
    case sine = "SINE"
    case triangle = "TRI"
    case saw = "SAW"
    case ramp = "RAMP"
    case square = "SQR"
    case random = "RAND"
    case sampleHold = "S&H"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .gate: return "Gate/Trigger"
        case .sine: return "Sine Wave"
        case .triangle: return "Triangle"
        case .saw: return "Sawtooth (down)"
        case .ramp: return "Ramp (up)"
        case .square: return "Square Wave"
        case .random: return "Random/Noise"
        case .sampleHold: return "Sample & Hold"
        }
    }
}

// MARK: - Clock Output Mode

enum ClockOutputMode: String, CaseIterable, Identifiable {
    case clock = "CLK"
    case lfo = "LFO"

    var id: String { rawValue }
}

// MARK: - Modulation Destination

enum ModulationDestination: String, CaseIterable, Identifiable {
    case none = "NONE"

    // Macro Osc destinations
    case plaitsHarmonics = "MOS:HARM"
    case plaitsTimbre = "MOS:TMBR"
    case plaitsMorph = "MOS:MRPH"
    case plaitsLPGDecay = "MOS:DCAY"

    // Resonator destinations
    case ringsStructure = "RES:STRC"
    case ringsBrightness = "RES:BRIT"
    case ringsDamping = "RES:DAMP"
    case ringsPosition = "RES:POS"

    // Delay destinations
    case delayTime = "DLY:TIME"
    case delayFeedback = "DLY:FDBK"
    case delayWow = "DLY:WOW"
    case delayFlutter = "DLY:FLTR"

    // Granular 1 destinations
    case granular1Speed = "GR1:SPED"
    case granular1Pitch = "GR1:PTCH"
    case granular1Size = "GR1:SIZE"
    case granular1Density = "GR1:DENS"
    case granular1Filter = "GR1:FILT"

    // Granular 2 destinations
    case granular2Speed = "GR2:SPED"
    case granular2Pitch = "GR2:PTCH"
    case granular2Size = "GR2:SIZE"
    case granular2Density = "GR2:DENS"
    case granular2Filter = "GR2:FILT"

    // DaisyDrum destinations
    case daisyDrumHarmonics = "DRM:HARM"
    case daisyDrumTimbre = "DRM:TMBR"
    case daisyDrumMorph = "DRM:MRPH"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .plaitsHarmonics: return "Macro Osc Harmonics"
        case .plaitsTimbre: return "Macro Osc Timbre"
        case .plaitsMorph: return "Macro Osc Morph"
        case .plaitsLPGDecay: return "Macro Osc LPG Decay"
        case .ringsStructure: return "Resonator Structure"
        case .ringsBrightness: return "Resonator Brightness"
        case .ringsDamping: return "Resonator Damping"
        case .ringsPosition: return "Resonator Position"
        case .delayTime: return "Delay Time"
        case .delayFeedback: return "Delay Feedback"
        case .delayWow: return "Delay Wow"
        case .delayFlutter: return "Delay Flutter"
        case .granular1Speed: return "Granular 1 Speed"
        case .granular1Pitch: return "Granular 1 Pitch"
        case .granular1Size: return "Granular 1 Size"
        case .granular1Density: return "Granular 1 Density"
        case .granular1Filter: return "Granular 1 Filter"
        case .granular2Speed: return "Granular 2 Speed"
        case .granular2Pitch: return "Granular 2 Pitch"
        case .granular2Size: return "Granular 2 Size"
        case .granular2Density: return "Granular 2 Density"
        case .granular2Filter: return "Granular 2 Filter"
        case .daisyDrumHarmonics: return "Drums Harmonics"
        case .daisyDrumTimbre: return "Drums Timbre"
        case .daisyDrumMorph: return "Drums Morph"
        }
    }

    var category: String {
        switch self {
        case .none: return "None"
        case .plaitsHarmonics, .plaitsTimbre, .plaitsMorph, .plaitsLPGDecay: return "Macro Osc"
        case .ringsStructure, .ringsBrightness, .ringsDamping, .ringsPosition: return "Resonator"
        case .delayTime, .delayFeedback, .delayWow, .delayFlutter: return "Delay"
        case .granular1Speed, .granular1Pitch, .granular1Size, .granular1Density, .granular1Filter: return "Granular 1"
        case .granular2Speed, .granular2Pitch, .granular2Size, .granular2Density, .granular2Filter: return "Granular 2"
        case .daisyDrumHarmonics, .daisyDrumTimbre, .daisyDrumMorph: return "Drums"
        }
    }

    // Backward compat: accept old raw values from saved project files
    init?(rawValue: String) {
        switch rawValue {
        case "NONE": self = .none
        // New values
        case "MOS:HARM": self = .plaitsHarmonics
        case "MOS:TMBR": self = .plaitsTimbre
        case "MOS:MRPH": self = .plaitsMorph
        case "MOS:DCAY": self = .plaitsLPGDecay
        case "RES:STRC": self = .ringsStructure
        case "RES:BRIT": self = .ringsBrightness
        case "RES:DAMP": self = .ringsDamping
        case "RES:POS": self = .ringsPosition
        // Old values (backward compat)
        case "PLT:HARM": self = .plaitsHarmonics
        case "PLT:TMBR": self = .plaitsTimbre
        case "PLT:MRPH": self = .plaitsMorph
        case "PLT:DCAY": self = .plaitsLPGDecay
        case "RNG:STRC": self = .ringsStructure
        case "RNG:BRIT": self = .ringsBrightness
        case "RNG:DAMP": self = .ringsDamping
        case "RNG:POS": self = .ringsPosition
        // Other destinations
        case "DLY:TIME": self = .delayTime
        case "DLY:FDBK": self = .delayFeedback
        case "DLY:WOW": self = .delayWow
        case "DLY:FLTR": self = .delayFlutter
        case "GR1:SPED": self = .granular1Speed
        case "GR1:PTCH": self = .granular1Pitch
        case "GR1:SIZE": self = .granular1Size
        case "GR1:DENS": self = .granular1Density
        case "GR1:FILT": self = .granular1Filter
        case "GR2:SPED": self = .granular2Speed
        case "GR2:PTCH": self = .granular2Pitch
        case "GR2:SIZE": self = .granular2Size
        case "GR2:DENS": self = .granular2Density
        case "GR2:FILT": self = .granular2Filter
        case "DRM:HARM": self = .daisyDrumHarmonics
        case "DRM:TMBR": self = .daisyDrumTimbre
        case "DRM:MRPH": self = .daisyDrumMorph
        default: return nil
        }
    }
}

// MARK: - Clock Output

/// Represents a single clock output channel (1 of 8).
/// Each output can function as either a clock divider or an LFO.
class ClockOutput: ObservableObject, Identifiable {
    let id: Int

    @Published var mode: ClockOutputMode = .clock
    @Published var waveform: ClockWaveform = .gate
    @Published var division: SequencerClockDivision = .x1
    @Published var slowMode: Bool = false      // When true, applies /4 multiplier to LFO rate

    // Output shaping
    @Published var level: Float = 1.0          // 0-1 amplitude
    @Published var offset: Float = 0.0         // -1 to +1 bipolar offset
    @Published var phase: Float = 0.0          // 0-1 (maps to 0-360 degrees)
    @Published var width: Float = 0.5          // Pulse width / skew (0-1)

    // Modulation routing
    @Published var destination: ModulationDestination = .none
    @Published var modulationAmount: Float = 0.5  // 0-1 mod depth

    // Mute control
    @Published var muted: Bool = false

    // Current output value (updated from audio thread)
    @Published var currentValue: Float = 0.0

    init(index: Int) {
        self.id = index

        // Default different divisions for variety
        let defaultDivisions: [SequencerClockDivision] = [
            .x1, .x2, .x4, .div2, .div4, .x3, .div3, .x8
        ]
        if index < defaultDivisions.count {
            self.division = defaultDivisions[index]
        }
    }

    /// Frequency multiplier relative to master clock quarter note
    var frequencyMultiplier: Double {
        return division.multiplier
    }
}

// MARK: - Master Clock

/// Central clock and modulation hub inspired by Pam's Pro Workout.
/// Provides master BPM and 8 configurable clock/LFO outputs.
@MainActor
class MasterClock: ObservableObject {
    // Master tempo - stored separately to avoid didSet recursion
    private var _bpm: Double = 120.0
    var bpm: Double {
        get { _bpm }
        set {
            let clamped = max(10.0, min(330.0, newValue))
            if clamped != _bpm {
                _bpm = clamped
                objectWillChange.send()
                if isConnected {
                    updateAudioEngine()
                }
            }
        }
    }

    // 8 clock outputs
    @Published var outputs: [ClockOutput]

    // Transport state
    @Published var isRunning: Bool = false

    // Swing amount (0 = straight, 1 = max swing)
    @Published var swing: Float = 0.0

    // External sync
    @Published var externalSync: Bool = false

    // Reference to audio engine for parameter updates
    weak var audioEngine: AudioEngineWrapper?

    // Reference to sequencer for BPM sync
    weak var sequencer: StepSequencer?

    // Cancellables for output observation
    private var outputCancellables: [AnyCancellable] = []

    // Track whether we're connected to prevent updates before connection
    private var isConnected: Bool = false

    init() {
        // Create 8 outputs
        self.outputs = (0..<8).map { ClockOutput(index: $0) }

        // Observe changes to outputs
        setupOutputObservers()
    }

    func connect(audioEngine: AudioEngineWrapper) {
        self.audioEngine = audioEngine
        self.isConnected = true
        // Sync all parameters to the audio engine
        syncAllOutputsToEngine()
    }

    func connectSequencer(_ sequencer: StepSequencer) {
        self.sequencer = sequencer
        // Sync initial BPM
        sequencer.setTempoBPM(_bpm)
    }

    private func setupOutputObservers() {
        outputCancellables.removeAll()

        for (index, output) in outputs.enumerated() {
            // Observe all relevant properties
            // Use .dropFirst() to skip the initial value on subscription
            output.$mode
                .dropFirst()
                .sink { [weak self] _ in self?.outputDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$waveform
                .dropFirst()
                .sink { [weak self] _ in self?.outputDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$division
                .dropFirst()
                .sink { [weak self] _ in self?.outputDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$level
                .dropFirst()
                .sink { [weak self] _ in self?.outputDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$offset
                .dropFirst()
                .sink { [weak self] _ in self?.outputDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$phase
                .dropFirst()
                .sink { [weak self] _ in self?.outputDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$width
                .dropFirst()
                .sink { [weak self] _ in self?.outputDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$destination
                .dropFirst()
                .sink { [weak self] _ in self?.outputDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$modulationAmount
                .dropFirst()
                .sink { [weak self] _ in self?.outputDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$muted
                .dropFirst()
                .sink { [weak self] _ in self?.outputDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$slowMode
                .dropFirst()
                .sink { [weak self] _ in self?.outputSlowModeDidChange(index: index) }
                .store(in: &outputCancellables)
        }
    }

    private func outputSlowModeDidChange(index: Int) {
        // Defer to next run loop iteration so the @Published value is fully stored
        // (Combine's sink fires on willSet, before the new value is committed)
        DispatchQueue.main.async { [weak self] in
            guard let self, let engine = self.audioEngine, index < self.outputs.count else { return }
            engine.setClockOutputSlowMode(index: index, slow: self.outputs[index].slowMode)
        }
    }

    private func outputDidChange(index: Int) {
        // Defer to next run loop iteration so the @Published value is fully stored
        DispatchQueue.main.async { [weak self] in
            self?.sendOutputParametersToEngine(outputIndex: index)
        }
    }

    // MARK: - Transport Control

    func start() {
        isRunning = true
        audioEngine?.setClockRunning(true)
    }

    /// Start with explicit sync sample (called by sequencer)
    func startSynced(startSample: UInt64) {
        isRunning = true
        audioEngine?.setClockStartSample(startSample)
        audioEngine?.setClockRunning(true)
    }

    func stop() {
        isRunning = false
        audioEngine?.setClockRunning(false)
    }

    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    /// Sync the clock start sample without changing running state (for phase alignment)
    func syncStartSample(_ startSample: UInt64) {
        audioEngine?.setClockStartSample(startSample)
    }

    // MARK: - Tempo Control

    func tap() {
        // Tap tempo implementation - track tap intervals
        // Could be expanded with proper tap tempo logic
    }

    func nudgeUp() {
        bpm = min(330.0, bpm + 1.0)
    }

    func nudgeDown() {
        bpm = max(10.0, bpm - 1.0)
    }

    // MARK: - Audio Engine Communication

    private func updateAudioEngine() {
        audioEngine?.setMasterClockBPM(Float(bpm))
        audioEngine?.setClockSwing(swing)
        // Sync sequencer BPM to master clock
        sequencer?.setTempoBPM(bpm)
    }

    private func sendOutputParametersToEngine(outputIndex: Int) {
        guard let engine = audioEngine, outputIndex < outputs.count else { return }
        let output = outputs[outputIndex]

        // Send all output parameters to the audio engine
        engine.setClockOutput(
            index: outputIndex,
            mode: output.mode == .clock ? 0 : 1,
            waveform: ClockWaveform.allCases.firstIndex(of: output.waveform) ?? 0,
            division: SequencerClockDivision.allCases.firstIndex(of: output.division) ?? 9, // x1 default
            level: output.level,
            offset: output.offset,
            phase: output.phase,
            width: output.width,
            destination: ModulationDestination.allCases.firstIndex(of: output.destination) ?? 0,
            modulationAmount: output.modulationAmount,
            muted: output.muted
        )
    }

    /// Sync all output parameters to the audio engine
    func syncAllOutputsToEngine() {
        for i in 0..<outputs.count {
            sendOutputParametersToEngine(outputIndex: i)
        }
        updateAudioEngine()
    }

    // MARK: - Output Value Updates (called from audio engine)

    func updateOutputValue(index: Int, value: Float) {
        guard index < outputs.count else { return }
        outputs[index].currentValue = value
    }
}

// MARK: - Clock Utility Extensions

extension MasterClock {
    /// Seconds per beat (quarter note) at current BPM
    var secondsPerBeat: Double {
        60.0 / bpm
    }

    /// Samples per beat at a given sample rate
    func samplesPerBeat(sampleRate: Double = 48000.0) -> Double {
        secondsPerBeat * sampleRate
    }

    /// Frequency in Hz for a given clock division
    func frequencyForDivision(_ division: SequencerClockDivision) -> Double {
        let baseFreq = bpm / 60.0  // Beats per second
        return baseFreq * division.multiplier
    }
}

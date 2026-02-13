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

// MARK: - Clock Quantize Mode

/// Quantize mode for clock output triggers.
/// When set, trigger events snap to the nearest grid boundary.
enum ClockQuantizeMode: String, CaseIterable, Identifiable {
    case none = "OFF"
    case sixteenth = "1/16"
    case eighth = "1/8"
    case quarter = "1/4"
    case bar = "BAR"

    var id: String { rawValue }

    /// Engine integer value (sent to C++ side)
    var engineValue: Int {
        switch self {
        case .none: return 0
        case .sixteenth: return 1
        case .eighth: return 2
        case .quarter: return 3
        case .bar: return 4
        }
    }

    var displayName: String {
        switch self {
        case .none: return "Off"
        case .sixteenth: return "1/16"
        case .eighth: return "1/8"
        case .quarter: return "1/4"
        case .bar: return "Bar"
        }
    }

    init?(engineValue: Int) {
        switch engineValue {
        case 0: self = .none
        case 1: self = .sixteenth
        case 2: self = .eighth
        case 3: self = .quarter
        case 4: self = .bar
        default: return nil
        }
    }
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

    // SoundFont Sampler destinations (match C++ enum order)
    case samplerFilterCutoff = "SMP:FILT"
    case samplerLevel = "SMP:LEVL"

    // Trigger destinations (fire NoteOn on clock rising edge)
    case plaitsGate = "MOS:GATE"
    case ringsGate = "RES:GATE"
    case ringsInput = "RES:INPT"
    case daisyDrumGate = "DRM:GATE"
    case drumLane0Gate = "DL0:GATE"
    case drumLane1Gate = "DL1:GATE"
    case drumLane2Gate = "DL2:GATE"
    case drumLane3Gate = "DL3:GATE"
    case samplerGate = "SMP:GATE"

    var id: String { rawValue }

    /// Returns true if this destination fires triggers rather than CV modulation.
    var isTriggerDestination: Bool {
        switch self {
        case .plaitsGate, .ringsGate, .ringsInput, .daisyDrumGate,
             .drumLane0Gate, .drumLane1Gate, .drumLane2Gate, .drumLane3Gate,
             .samplerGate:
            return true
        default:
            return false
        }
    }

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
        case .samplerFilterCutoff: return "Sampler Filter"
        case .samplerLevel: return "Sampler Level"
        // Trigger destinations
        case .plaitsGate: return "Macro Osc Gate"
        case .ringsGate: return "Resonator Gate"
        case .ringsInput: return "Resonator Input"
        case .daisyDrumGate: return "Drums Gate"
        case .drumLane0Gate: return "Analog Kick Gate"
        case .drumLane1Gate: return "Synth Kick Gate"
        case .drumLane2Gate: return "Analog Snare Gate"
        case .drumLane3Gate: return "Hi-Hat Gate"
        case .samplerGate: return "Sampler Gate"
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
        case .samplerFilterCutoff, .samplerLevel: return "Sampler"
        case .plaitsGate: return "Triggers"
        case .ringsGate, .ringsInput: return "Triggers"
        case .daisyDrumGate: return "Triggers"
        case .drumLane0Gate, .drumLane1Gate, .drumLane2Gate, .drumLane3Gate: return "Triggers"
        case .samplerGate: return "Triggers"
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
        // Sampler modulation
        case "SMP:FILT": self = .samplerFilterCutoff
        case "SMP:LEVL": self = .samplerLevel
        // Trigger destinations
        case "MOS:GATE": self = .plaitsGate
        case "RES:GATE": self = .ringsGate
        case "RES:INPT": self = .ringsInput
        case "DRM:GATE": self = .daisyDrumGate
        case "DL0:GATE": self = .drumLane0Gate
        case "DL1:GATE": self = .drumLane1Gate
        case "DL2:GATE": self = .drumLane2Gate
        case "DL3:GATE": self = .drumLane3Gate
        case "SMP:GATE": self = .samplerGate
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

    // Trigger quantize mode (snaps triggers to grid boundary)
    @Published var quantize: ClockQuantizeMode = .none

    // Euclidean rhythm parameters (Clock sub-mode)
    @Published var euclideanEnabled: Bool = false
    @Published var euclideanSteps: Int = 8       // 1-32
    @Published var euclideanFills: Int = 4       // 0-steps
    @Published var euclideanRotation: Int = 0    // 0 to steps-1

    // Precomputed euclidean pattern (sent to engine)
    var euclideanPattern: [Bool] = Array(repeating: false, count: 32)

    // Current step (read back from engine for UI display)
    @Published var euclideanCurrentStep: Int = 0

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

        // Compute initial euclidean pattern
        euclideanPattern = ClockOutput.computeEuclideanPattern(
            steps: euclideanSteps, fills: euclideanFills, rotation: euclideanRotation
        )
    }

    /// Frequency multiplier relative to master clock quarter note
    var frequencyMultiplier: Double {
        return division.multiplier
    }

    // MARK: - Bjorklund Euclidean Pattern

    /// Computes a euclidean rhythm pattern using the Bjorklund algorithm.
    /// Distributes `fills` active triggers as evenly as possible across `steps` total steps,
    /// then rotates the result by `rotation` positions.
    static func computeEuclideanPattern(steps: Int, fills: Int, rotation: Int) -> [Bool] {
        let totalSteps = max(1, min(steps, 32))
        let activeFills = max(0, min(fills, totalSteps))

        guard totalSteps > 0 else { return Array(repeating: false, count: 32) }
        guard activeFills > 0 else {
            // All silent
            return Array(repeating: false, count: 32)
        }
        guard activeFills < totalSteps else {
            // All active
            var pattern = Array(repeating: true, count: 32)
            for i in totalSteps..<32 { pattern[i] = false }
            return pattern
        }

        // Bjorklund algorithm: iterative binary distribution
        var groups: [[Bool]] = []
        for i in 0..<totalSteps {
            groups.append([i < activeFills])
        }

        var remainderCount = totalSteps - activeFills
        var distributionCount = activeFills

        while remainderCount > 1 {
            let numToDistribute = min(distributionCount, remainderCount)
            for i in 0..<numToDistribute {
                groups[i].append(contentsOf: groups[groups.count - 1 - (numToDistribute - 1 - i)])
            }
            // Remove distributed groups from end
            groups.removeLast(numToDistribute)

            let newTotal = groups.count
            remainderCount = newTotal - numToDistribute
            distributionCount = numToDistribute

            if remainderCount <= 1 { break }
        }

        // Flatten groups into pattern
        var raw: [Bool] = []
        for group in groups {
            raw.append(contentsOf: group)
        }

        // Apply rotation — right-shift so triggers move later in time
        // while the grid ("1" = step 0 = downbeat) stays fixed
        let rot = ((rotation % totalSteps) + totalSteps) % totalSteps
        var rotated: [Bool] = []
        for i in 0..<totalSteps {
            rotated.append(raw[(i - rot + totalSteps) % totalSteps])
        }

        // Pad to 32
        var pattern = Array(repeating: false, count: 32)
        for i in 0..<totalSteps {
            pattern[i] = rotated[i]
        }
        return pattern
    }

    /// Recomputes the euclidean pattern from current parameters
    func recomputeEuclideanPattern() {
        euclideanPattern = ClockOutput.computeEuclideanPattern(
            steps: euclideanSteps, fills: euclideanFills, rotation: euclideanRotation
        )
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

    // Time signature
    @Published var timeSignatureNumerator: Int = 4 {
        didSet {
            let clamped = max(1, min(15, timeSignatureNumerator))
            if clamped != timeSignatureNumerator { timeSignatureNumerator = clamped }
        }
    }
    @Published var timeSignatureDenominator: Int = 4 {
        didSet {
            // Only allow valid denominators: 2, 4, 8, 16
            let valid = [2, 4, 8, 16]
            if !valid.contains(timeSignatureDenominator) {
                timeSignatureDenominator = 4
            }
        }
    }

    /// Quarter notes per bar for the current time signature.
    /// This is THE key derived value: 4/4 → 4.0, 3/4 → 3.0, 6/8 → 3.0, 7/8 → 3.5, 5/4 → 5.0
    var quarterNotesPerBar: Double {
        return Double(timeSignatureNumerator) * (4.0 / Double(timeSignatureDenominator))
    }

    /// Display string like "4/4", "3/4", "6/8"
    var timeSignatureDisplay: String {
        return "\(timeSignatureNumerator)/\(timeSignatureDenominator)"
    }

    // Bar:beat transport counter (updated by polling)
    @Published var currentBar: Int = 1
    @Published var currentBeat: Int = 1

    // External sync
    @Published var externalSync: Bool = false

    // Reference to audio engine for parameter updates
    weak var audioEngine: AudioEngineWrapper?

    // Reference to sequencer for BPM sync
    weak var sequencer: StepSequencer?

    // Reference to drum sequencer for loop auto-adjustment
    weak var drumSequencer: DrumSequencer?

    // Reference to scramble manager for transport sync
    private weak var scrambleManager: ScrambleManager?

    // Cancellables for output observation
    private var outputCancellables: [AnyCancellable] = []

    // Track whether we're connected to prevent updates before connection
    private var isConnected: Bool = false

    // Timer for polling clock output values + euclidean step from engine
    private var pollTimer: Timer?

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
        // Start polling clock output values + euclidean step from engine at 15 Hz
        startPolling()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollEngineState()
            }
        }
    }

    private func pollEngineState() {
        guard let engine = audioEngine else { return }
        for i in 0..<outputs.count {
            let value = engine.getClockOutputValue(index: i)
            if outputs[i].currentValue != value {
                outputs[i].currentValue = value
            }
            // Only poll euclidean step if euclidean is active (avoid unnecessary updates)
            if outputs[i].euclideanEnabled {
                let step = engine.getClockOutputEuclideanStep(index: i)
                if outputs[i].euclideanCurrentStep != step {
                    outputs[i].euclideanCurrentStep = step
                }
            }
        }

        // Update bar:beat transport counter
        if engine.isClockRunning() {
            let currentSample = engine.currentSampleTime()
            let startSample = engine.getClockStartSample()
            let sampleRate = 48000.0
            let beatsPerSecond = bpm / 60.0
            let samplesPerBeatVal = sampleRate / beatsPerSecond

            if currentSample >= startSample && samplesPerBeatVal > 0 {
                let elapsedSamples = Double(currentSample - startSample)
                let elapsedBeats = elapsedSamples / samplesPerBeatVal  // in quarter notes
                let qnPerBar = quarterNotesPerBar

                // Bar is 1-based, beat is 1-based
                let totalBars = elapsedBeats / qnPerBar
                let bar = Int(totalBars) + 1
                let beatInBar = Int(elapsedBeats - Double(Int(totalBars)) * qnPerBar) + 1

                if currentBar != bar { currentBar = bar }
                if currentBeat != beatInBar { currentBeat = beatInBar }
            }
        } else {
            // Reset to 1:1 when stopped
            if currentBar != 1 { currentBar = 1 }
            if currentBeat != 1 { currentBeat = 1 }
        }
    }

    func connectSequencer(_ sequencer: StepSequencer) {
        self.sequencer = sequencer
        // Sync initial BPM
        sequencer.setTempoBPM(_bpm)
    }

    func connectDrumSequencer(_ drumSequencer: DrumSequencer) {
        self.drumSequencer = drumSequencer
    }

    func connectScrambleManager(_ manager: ScrambleManager) {
        self.scrambleManager = manager
    }

    /// Adjusts sequencer loop endpoints to align with bar boundaries for the current time signature.
    /// Step seq: target 2 bars at its clock division. Drum seq: target 1 bar at x4 (16ths).
    func adjustSequencerLoopsForTimeSignature() {
        let qnPerBar = quarterNotesPerBar

        // Step sequencer: 2 bars, using track's clock division
        if let seq = sequencer {
            for i in 0..<seq.tracks.count {
                let division = seq.tracks[i].division
                let stepsFor2Bars = Int(round(2.0 * qnPerBar * division.multiplier))
                let clamped = max(1, min(stepsFor2Bars, 8))  // 8 steps max
                seq.tracks[i].loopEnd = clamped - 1  // 0-indexed
            }
        }

        // Drum sequencer: 1 bar at x4 (16th notes)
        if let drumSeq = drumSequencer {
            let stepsFor1Bar = Int(round(qnPerBar * 4.0))  // x4 = 16th notes
            let clamped = max(1, min(stepsFor1Bar, 16))
            drumSeq.loopEnd = clamped - 1  // 0-indexed
            drumSeq.loopStart = 0
        }
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

            output.$quantize
                .dropFirst()
                .sink { [weak self] _ in self?.outputQuantizeDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$slowMode
                .dropFirst()
                .sink { [weak self] _ in self?.outputSlowModeDidChange(index: index) }
                .store(in: &outputCancellables)

            // Euclidean parameter observers
            output.$euclideanEnabled
                .dropFirst()
                .sink { [weak self] _ in self?.euclideanEnabledDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$euclideanSteps
                .dropFirst()
                .sink { [weak self] _ in self?.euclideanDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$euclideanFills
                .dropFirst()
                .sink { [weak self] _ in self?.euclideanDidChange(index: index) }
                .store(in: &outputCancellables)

            output.$euclideanRotation
                .dropFirst()
                .sink { [weak self] _ in self?.euclideanDidChange(index: index) }
                .store(in: &outputCancellables)
        }
    }

    private func outputQuantizeDidChange(index: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let engine = self.audioEngine, index < self.outputs.count else { return }
            engine.setClockOutputQuantize(index: index, mode: self.outputs[index].quantize.engineValue)
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

    private func euclideanDidChange(index: Int) {
        // Defer so @Published value is committed, then recompute pattern and send to engine
        DispatchQueue.main.async { [weak self] in
            guard let self, index < self.outputs.count else { return }
            let output = self.outputs[index]

            // Clamp fills and rotation to valid ranges when steps change
            if output.euclideanFills > output.euclideanSteps {
                output.euclideanFills = output.euclideanSteps
            }
            if output.euclideanRotation >= output.euclideanSteps {
                output.euclideanRotation = max(0, output.euclideanSteps - 1)
            }

            // Recompute Bjorklund pattern
            output.recomputeEuclideanPattern()

            // Send to audio engine
            self.sendEuclideanToEngine(outputIndex: index)
        }
    }

    /// Called when euclideanEnabled transitions to true — sets steps to one bar.
    private func euclideanEnabledDidChange(index: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self, index < self.outputs.count else { return }
            let output = self.outputs[index]

            if output.euclideanEnabled {
                // Auto-set steps to one bar at this output's clock division
                let barSteps = self.euclideanStepsPerBar(for: output)
                output.euclideanSteps = barSteps
                output.euclideanFills = max(1, barSteps / 2)  // Default fills to half
                output.euclideanRotation = 0
            }

            // Clamp, recompute, and sync (same as euclideanDidChange)
            if output.euclideanFills > output.euclideanSteps {
                output.euclideanFills = output.euclideanSteps
            }
            if output.euclideanRotation >= output.euclideanSteps {
                output.euclideanRotation = max(0, output.euclideanSteps - 1)
            }
            output.recomputeEuclideanPattern()
            self.sendEuclideanToEngine(outputIndex: index)
        }
    }

    /// Computes the number of clock ticks in one bar for a given clock output's division.
    private func euclideanStepsPerBar(for output: ClockOutput) -> Int {
        let raw = Int(round(quarterNotesPerBar * output.division.multiplier))
        return max(1, min(raw, 32))  // Clamp to valid euclidean range
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
        scrambleManager?.start(startSample: startSample)
    }

    func stop() {
        isRunning = false
        audioEngine?.setClockRunning(false)
        scrambleManager?.stop()
    }

    /// Reset Scramble engine state and re-sync with transport (called by sequencer reset).
    /// If transport is running, stops Scramble, resets, then restarts from the new start sample
    /// so gate patterns are phase-aligned with the sequencer.
    func resetScramble(startSample: UInt64? = nil) {
        guard let mgr = scrambleManager else { return }
        let wasRunning = isRunning
        if wasRunning { mgr.stop() }
        mgr.reset()
        if wasRunning, let sample = startSample ?? audioEngine?.currentSampleTime() {
            mgr.start(startSample: sample)
        }
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

    /// Reset a single clock output's phase and euclidean step back to 1.
    func resetOutput(index: Int) {
        audioEngine?.resetClockOutput(index: index)
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

    /// Push time signature to the C++ audio engine
    func updateTimeSignatureInEngine() {
        audioEngine?.setTimeSignature(
            numerator: timeSignatureNumerator,
            denominator: timeSignatureDenominator
        )
    }

    /// Set time signature and propagate to engine + sequencers
    func setTimeSignature(numerator: Int, denominator: Int) {
        timeSignatureNumerator = numerator
        timeSignatureDenominator = denominator
        if isConnected {
            updateTimeSignatureInEngine()
            adjustSequencerLoopsForTimeSignature()
            adjustEuclideanStepsForTimeSignature()
        }
    }

    /// Updates Euclidean step counts for all outputs with Euclidean enabled to match bar length.
    private func adjustEuclideanStepsForTimeSignature() {
        for (index, output) in outputs.enumerated() {
            guard output.euclideanEnabled else { continue }
            let barSteps = euclideanStepsPerBar(for: output)
            // Scale fills proportionally to maintain the same density
            let oldSteps = max(1, output.euclideanSteps)
            let fillRatio = Double(output.euclideanFills) / Double(oldSteps)
            output.euclideanSteps = barSteps
            output.euclideanFills = max(1, min(barSteps, Int(round(fillRatio * Double(barSteps)))))
            if output.euclideanRotation >= barSteps {
                output.euclideanRotation = max(0, barSteps - 1)
            }
            output.recomputeEuclideanPattern()
            sendEuclideanToEngine(outputIndex: index)
        }
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

    private func sendEuclideanToEngine(outputIndex: Int) {
        guard let engine = audioEngine, outputIndex < outputs.count else { return }
        let output = outputs[outputIndex]
        engine.setClockOutputEuclidean(
            index: outputIndex,
            enabled: output.euclideanEnabled,
            steps: output.euclideanSteps,
            pattern: output.euclideanPattern
        )
    }

    /// Sync all output parameters to the audio engine
    func syncAllOutputsToEngine() {
        for i in 0..<outputs.count {
            sendOutputParametersToEngine(outputIndex: i)
            sendEuclideanToEngine(outputIndex: i)
            // Sync quantize mode
            if let engine = audioEngine {
                engine.setClockOutputQuantize(index: i, mode: outputs[i].quantize.engineValue)
            }
        }
        updateAudioEngine()
        updateTimeSignatureInEngine()
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

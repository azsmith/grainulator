//
//  SequencerEngine.swift
//  Grainulator
//
//  Step sequencer — dual-track for Plaits playback.
//

import Foundation

enum SequencerDirection: String, CaseIterable, Identifiable {
    case forward = "FWD"
    case reverse = "REV"
    case alternate = "ALT"
    case random = "RND"
    case skip2 = "SKP2"
    case skip3 = "SKP3"
    case climb2 = "CLM2"
    case climb3 = "CLM3"
    case drunk = "DRNK"
    case randomNoRepeat = "RN!R"
    case converge = "CNVG"
    case diverge = "DIVG"

    var id: String { rawValue }
}

enum SequencerClockDivision: String, CaseIterable, Identifiable {
    case div16 = "/16"
    case div12 = "/12"
    case div8 = "/8"
    case div6 = "/6"
    case div4 = "/4"
    case div3 = "/3"
    case div2 = "/2"
    case div3Over2 = "2/3x"
    case div4Over3 = "3/4x"
    case x1 = "x1"
    case x4Over3 = "x4/3"
    case x3Over2 = "x3/2"
    case x2 = "x2"
    case x3 = "x3"
    case x4 = "x4"
    case x6 = "x6"
    case x8 = "x8"
    case x12 = "x12"
    case x16 = "x16"

    var id: String { rawValue }

    // Track tempo multiplier relative to BPM-derived quarter-note pulse.
    // x1 = quarter-note, x2 = eighth-note, /2 = half-note, etc.
    var multiplier: Double {
        switch self {
        case .div16: return 1.0 / 16.0
        case .div12: return 1.0 / 12.0
        case .div8: return 1.0 / 8.0
        case .div6: return 1.0 / 6.0
        case .div4: return 1.0 / 4.0
        case .div3: return 1.0 / 3.0
        case .div2: return 1.0 / 2.0
        case .div3Over2: return 2.0 / 3.0
        case .div4Over3: return 3.0 / 4.0
        case .x1: return 1.0
        case .x4Over3: return 4.0 / 3.0
        case .x3Over2: return 3.0 / 2.0
        case .x2: return 2.0
        case .x3: return 3.0
        case .x4: return 4.0
        case .x6: return 6.0
        case .x8: return 8.0
        case .x12: return 12.0
        case .x16: return 16.0
        }
    }
}

enum SequencerGateMode: String, CaseIterable, Identifiable {
    case every = "EVERY"
    case first = "FIRST"
    case last = "LAST"
    case tie = "TIE"
    case rest = "REST"

    var id: String { rawValue }
}

enum SequencerStepType: String, CaseIterable, Identifiable {
    case play = "PLAY"
    case skip = "SKIP"
    case elide = "ELIDE"
    case rest = "REST"
    case tie = "TIE"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .play: return "PLY"
        case .skip: return "SKP"
        case .elide: return "ELD"
        case .rest: return "RST"
        case .tie: return "TIE"
        }
    }
}

enum AccumulatorTrigger: String, CaseIterable, Identifiable {
    case stage = "STG"
    case pulse = "PLS"
    case ratchet = "RCH"

    var id: String { rawValue }
}

enum AccumulatorMode: String, CaseIterable, Identifiable {
    case stage = "STG"
    case track = "TRK"

    var id: String { rawValue }
}

enum SequencerTrackOutput: String, CaseIterable, Identifiable {
    case plaits = "PLAITS"
    case rings = "RINGS"
    case both = "BOTH"
    case daisyDrum = "DRUMS"
    case sampler = "SAMPLER"

    var id: String { rawValue }
}

struct SequencerScaleDefinition: Identifiable, Hashable {
    let id: Int
    let name: String
    let intervals: [Int]
}

struct SequencerStage: Identifiable {
    let id: Int
    var pulses: Int
    var gateMode: SequencerGateMode
    var ratchets: Int
    var probability: Double
    var noteSlot: Int
    var octave: Int
    var stepType: SequencerStepType
    var gateLength: Double   // 0.0-1.0, default 0.65
    var slide: Bool
    var accumTranspose: Int = 0              // ±7 scale degrees per trigger
    var accumTrigger: AccumulatorTrigger = .stage
    var accumRange: Int = 7                  // 1-7 scale degrees, wraps at boundary
    var accumMode: AccumulatorMode = .stage   // per-stage or shared track counter
}

struct SequencerTrack: Identifiable {
    let id: Int
    var name: String
    var muted: Bool
    var running: Bool = true
    var direction: SequencerDirection
    var division: SequencerClockDivision
    var loopStart: Int
    var loopEnd: Int
    var transpose: Int
    var baseOctave: Int
    var velocity: Int
    var output: SequencerTrackOutput
    var stages: [SequencerStage]

    static func makeDefault(id: Int, name: String, noteSlots: [Int], division: SequencerClockDivision, output: SequencerTrackOutput = .both, stepType: SequencerStepType = .play) -> SequencerTrack {
        let stageCount = 8
        var stages: [SequencerStage] = []
        stages.reserveCapacity(stageCount)
        for index in 0..<stageCount {
            let noteSlot = index < noteSlots.count ? noteSlots[index] : 0
            stages.append(
                SequencerStage(
                    id: index,
                    pulses: 1,
                    gateMode: .every,
                    ratchets: 1,
                    probability: 1.0,
                    noteSlot: min(max(noteSlot, 0), 8),
                    octave: 0,
                    stepType: stepType,
                    gateLength: 1.0,
                    slide: false
                )
            )
        }

        return SequencerTrack(
            id: id,
            name: name,
            muted: false,
            direction: .forward,
            division: division,
            loopStart: 0,
            loopEnd: stageCount - 1,
            transpose: 0,
            baseOctave: 4,
            velocity: 100,
            output: output,
            stages: stages
        )
    }
}

@MainActor
final class StepSequencer: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var tempoBPM: Double = 120.0
    @Published var rootNote: Int = 0 // 0=C ... 11=B
    @Published var sequenceOctave: Int = 0
    @Published var scaleIndex: Int = 0
    @Published var tracks: [SequencerTrack] = [
        SequencerTrack.makeDefault(id: 0, name: "TRACK 1", noteSlots: [0, 0, 0, 0, 0, 0, 0, 0], division: .x1, output: .plaits),
        SequencerTrack.makeDefault(id: 1, name: "TRACK 2", noteSlots: [0, 0, 0, 0, 0, 0, 0, 0], division: .x1, output: .rings)
    ]
    @Published var selectedStagePerTrack: [Int] = [0, 0]
    @Published var playheadStagePerTrack: [Int] = [0, 0]
    @Published var playheadPulsePerTrack: [Int] = [0, 0]
    @Published var lastPlayedNotePerTrack: [UInt8?] = [nil, nil]
    @Published var lastGateSamplePerTrack: [UInt64?] = [nil, nil]
    @Published var lastScheduledNoteOnSamplePerTrack: [UInt64?] = [nil, nil]

    private struct TrackRuntimeState {
        var stageIndex: Int = 0
        var pulseInStage: Int = 0
        var nextPulseSample: UInt64 = 0
        var alternateForward: Bool = true
        var heldTieNote: UInt8?
        var patternStep: Int = 0       // Counter for skip/converge/diverge patterns
        var climbWindowStart: Int = 0  // Window origin for climb patterns
        var accumCounters: [Int] = Array(repeating: 0, count: 8) // Per-stage accumulator counters
        var trackAccumCounter: Int = 0  // Shared counter for track-mode stages
    }

    private struct NoteOnDedupKey: Hashable {
        let sampleTime: UInt64
        let note: UInt8
        let targetRaw: UInt8
    }

    /// Immutable snapshot of sequencer state for off-MainActor scheduling.
    /// Captured on MainActor, consumed on clockQueue — no shared mutable state.
    private struct SchedulingSnapshot {
        let tracks: [SequencerTrack]
        let tempoBPM: Double
        let rootNote: Int
        let sequenceOctave: Int
        let scaleIntervals: [Int]
        let transportToken: UInt64
        let plaitsTriggerOffsetMs: Double
        let ringsTriggerOffsetMs: Double
        let sampleRate: Double
        let lookaheadSamples: UInt64
        let dedupe: Bool

        // Chord sequencer data (captured from ChordSequencer on MainActor)
        let chordEnabled: Bool
        let chordDivision: SequencerClockDivision
        let chordStepCount: Int
        /// Chord intervals per step: index = step, value = intervals array or nil for empty/muted
        let chordStepIntervals: [[Int]?]
        /// Whether scaleIndex selects the "Chord Sequencer" dynamic scale
        let isChordScale: Bool
    }

    /// Mutable scheduling state protected by schedulingLock for clockQueue access.
    private struct SchedulingState {
        var runtimes: [TrackRuntimeState]
        var transportStartSample: UInt64 = 0
        // Playhead feedback (written on clockQueue, read on MainActor)
        var playheadStages: [Int] = [0, 0]
        var playheadPulses: [Int] = [0, 0]
        var lastPlayedNotes: [UInt8?] = [nil, nil]
        var lastGateSamples: [UInt64?] = [nil, nil]
        var lastScheduledNoteOnSamples: [UInt64?] = [nil, nil]

        // Chord sequencer playhead runtime
        var chordStageIndex: Int = 0
        var chordNextPulseSample: UInt64 = 0
        var chordPlayheadStep: Int = 0
    }

    private weak var audioEngine: AudioEngineWrapper?
    private weak var masterClock: MasterClock?
    private weak var drumSequencer: DrumSequencer?
    private weak var chordSequencer: ChordSequencer?
    private var clockTimer: DispatchSourceTimer?
    private let clockQueue = DispatchQueue(label: "com.grainulator.sequencer.clock", qos: .userInteractive)

    /// Lock protecting schedulingState for cross-thread access (MainActor ↔ clockQueue)
    private let schedulingLock = NSLock()
    private var schedulingState = SchedulingState(
        runtimes: [TrackRuntimeState(), TrackRuntimeState()]
    )

    private var transportToken: UInt64 = 0
    private let schedulerLookaheadSeconds: Double = 0.10
    private let schedulerLeadInSeconds: Double = 0.02
    /// Counter for throttling playhead UI updates from clockQueue
    private var playheadUpdateCounter: Int = 0
    // Temporarily disabled while diagnosing onset/attack mismatch.
    @Published var interEngineCompensationSamples: Int = 0
    @Published var plaitsTriggerOffsetMs: Double = 0.0
    @Published var ringsTriggerOffsetMs: Double = 0.0
    private let dedupeSameSampleSharedTargetNoteOn = false

    let rootNames: [String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    let scaleOptions: [SequencerScaleDefinition] = [
        SequencerScaleDefinition(id: 0, name: "Major", intervals: [0, 2, 4, 5, 7, 9, 11]),
        SequencerScaleDefinition(id: 1, name: "Natural Minor", intervals: [0, 2, 3, 5, 7, 8, 10]),
        SequencerScaleDefinition(id: 2, name: "Harmonic Minor", intervals: [0, 2, 3, 5, 7, 8, 11]),
        SequencerScaleDefinition(id: 3, name: "Melodic Minor", intervals: [0, 2, 3, 5, 7, 9, 11]),
        SequencerScaleDefinition(id: 4, name: "Dorian", intervals: [0, 2, 3, 5, 7, 9, 10]),
        SequencerScaleDefinition(id: 5, name: "Phrygian", intervals: [0, 1, 3, 5, 7, 8, 10]),
        SequencerScaleDefinition(id: 6, name: "Lydian", intervals: [0, 2, 4, 6, 7, 9, 11]),
        SequencerScaleDefinition(id: 7, name: "Mixolydian", intervals: [0, 2, 4, 5, 7, 9, 10]),
        SequencerScaleDefinition(id: 8, name: "Locrian", intervals: [0, 1, 3, 5, 6, 8, 10]),
        SequencerScaleDefinition(id: 9, name: "Whole Tone", intervals: [0, 2, 4, 6, 8, 10]),
        SequencerScaleDefinition(id: 10, name: "Major Pentatonic", intervals: [0, 2, 4, 7, 9]),
        SequencerScaleDefinition(id: 11, name: "Minor Pentatonic", intervals: [0, 3, 5, 7, 10]),
        SequencerScaleDefinition(id: 12, name: "Major Bebop", intervals: [0, 2, 4, 5, 7, 8, 9, 11]),
        SequencerScaleDefinition(id: 13, name: "Altered Scale", intervals: [0, 1, 3, 4, 6, 8, 10]),
        SequencerScaleDefinition(id: 14, name: "Dorian Bebop", intervals: [0, 2, 3, 4, 5, 7, 9, 10]),
        SequencerScaleDefinition(id: 15, name: "Mixolydian Bebop", intervals: [0, 2, 4, 5, 7, 9, 10, 11]),
        SequencerScaleDefinition(id: 16, name: "Blues Scale", intervals: [0, 3, 5, 6, 7, 10]),
        SequencerScaleDefinition(id: 17, name: "Diminished Whole Half", intervals: [0, 2, 3, 5, 6, 8, 9, 11]),
        SequencerScaleDefinition(id: 18, name: "Diminished Half Whole", intervals: [0, 1, 3, 4, 6, 7, 9, 10]),
        SequencerScaleDefinition(id: 19, name: "Neapolitan Major", intervals: [0, 1, 3, 5, 7, 9, 11]),
        SequencerScaleDefinition(id: 20, name: "Hungarian Major", intervals: [0, 3, 4, 6, 7, 9, 10]),
        SequencerScaleDefinition(id: 21, name: "Harmonic Major", intervals: [0, 2, 4, 5, 7, 8, 11]),
        SequencerScaleDefinition(id: 22, name: "Hungarian Minor", intervals: [0, 2, 3, 6, 7, 8, 11]),
        SequencerScaleDefinition(id: 23, name: "Lydian Minor", intervals: [0, 2, 4, 6, 7, 8, 10]),
        SequencerScaleDefinition(id: 24, name: "Neapolitan Minor", intervals: [0, 1, 3, 5, 7, 8, 11]),
        SequencerScaleDefinition(id: 25, name: "Major Locrian", intervals: [0, 2, 4, 5, 6, 8, 10]),
        SequencerScaleDefinition(id: 26, name: "Leading Whole Tone", intervals: [0, 2, 4, 6, 8, 10, 11]),
        SequencerScaleDefinition(id: 27, name: "Six Tone Symmetrical", intervals: [0, 1, 4, 5, 8, 9]),
        SequencerScaleDefinition(id: 28, name: "Balinese", intervals: [0, 1, 3, 7, 8]),
        SequencerScaleDefinition(id: 29, name: "Persian", intervals: [0, 1, 4, 5, 6, 8, 11]),
        SequencerScaleDefinition(id: 30, name: "East Indian Purvi", intervals: [0, 1, 4, 6, 7, 8, 11]),
        SequencerScaleDefinition(id: 31, name: "Oriental", intervals: [0, 1, 4, 5, 6, 9, 10]),
        SequencerScaleDefinition(id: 32, name: "Double Harmonic", intervals: [0, 1, 4, 5, 7, 8, 11]),
        SequencerScaleDefinition(id: 33, name: "Enigmatic", intervals: [0, 1, 4, 6, 8, 10, 11]),
        SequencerScaleDefinition(id: 34, name: "Overtone", intervals: [0, 2, 4, 6, 7, 9, 10]),
        SequencerScaleDefinition(id: 35, name: "Eight Tone Spanish", intervals: [0, 1, 3, 4, 5, 6, 8, 10]),
        SequencerScaleDefinition(id: 36, name: "Prometheus", intervals: [0, 2, 4, 6, 9, 10]),
        SequencerScaleDefinition(id: 37, name: "Gagaku Rittsu Sen Pou", intervals: [0, 2, 5, 7, 9]),
        SequencerScaleDefinition(id: 38, name: "In Sen Pou", intervals: [0, 1, 5, 7, 10]),
        SequencerScaleDefinition(id: 39, name: "Okinawa", intervals: [0, 4, 5, 7, 11]),
        SequencerScaleDefinition(id: 40, name: "Chromatic", intervals: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]),
        SequencerScaleDefinition(id: 41, name: "Chord Sequencer", intervals: [0, 4, 7]),  // Default major triad; dynamically replaced by chord sequencer
    ]

    /// Index of the "Chord Sequencer" scale in scaleOptions
    static let chordSequencerScaleIndex = 41

    func connect(audioEngine: AudioEngineWrapper) {
        self.audioEngine = audioEngine
        applySyncDebugPreset()
    }

    func connectMasterClock(_ masterClock: MasterClock) {
        self.masterClock = masterClock
    }

    func connectDrumSequencer(_ drumSeq: DrumSequencer) {
        self.drumSequencer = drumSeq
    }

    func connectChordSequencer(_ chordSeq: ChordSequencer) {
        self.chordSequencer = chordSeq
    }

    func togglePlayback() {
        isPlaying ? stop() : start()
    }

    func start() {
        guard !isPlaying else { return }
        isPlaying = true
        transportToken &+= 1
        audioEngine?.clearScheduledNotes()
        audioEngine?.allNotesOff()
        let startSample = (audioEngine?.currentSampleTime() ?? 0) + secondsToSamples(schedulerLeadInSeconds)
        resetRuntimeState(startSample: startSample)
        playheadUpdateCounter = 0
        // Sync the master clock to the same start sample for phase alignment
        masterClock?.startSynced(startSample: startSample)
        scheduleTimer()

        // Start drum sequencer with the same startSample for beat alignment
        if drumSequencer?.syncToTransport == true {
            drumSequencer?.startSynced(startSample: startSample)
        }
    }

    /// Start synced to an external start sample (e.g. for unified transport)
    func startSynced(startSample: UInt64) {
        guard !isPlaying else { return }
        isPlaying = true
        transportToken &+= 1
        audioEngine?.clearScheduledNotes()
        audioEngine?.allNotesOff()
        resetRuntimeState(startSample: startSample)
        playheadUpdateCounter = 0
        masterClock?.startSynced(startSample: startSample)
        scheduleTimer()

        // Start drum sequencer with the same startSample for beat alignment
        if drumSequencer?.syncToTransport == true {
            drumSequencer?.startSynced(startSample: startSample)
        }
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        transportToken &+= 1
        clockTimer?.cancel()
        clockTimer = nil
        snapshotRefreshTimer?.invalidate()
        snapshotRefreshTimer = nil
        audioEngine?.clearScheduledNotes()
        audioEngine?.allNotesOff()
        releaseAllHeldTieNotes()
        // Pull final playhead state
        pullPlayheadUpdates()
        // Stop the master clock too
        masterClock?.stop()

        // Stop drum sequencer in sync
        if drumSequencer?.syncToTransport == true {
            drumSequencer?.stop()
        }
    }

    func reset() {
        transportToken &+= 1
        audioEngine?.clearScheduledNotes()
        audioEngine?.allNotesOff()
        releaseAllHeldTieNotes()
        let startSample = (audioEngine?.currentSampleTime() ?? 0) + secondsToSamples(schedulerLeadInSeconds)
        resetRuntimeState(startSample: startSample)
    }

    func applySyncDebugPreset() {
        for trackIndex in tracks.indices {
            tracks[trackIndex].division = .x1
            tracks[trackIndex].direction = .forward
            tracks[trackIndex].transpose = 0
            tracks[trackIndex].baseOctave = 4
            tracks[trackIndex].loopStart = 0
            tracks[trackIndex].loopEnd = tracks[trackIndex].stages.count - 1

            for stageIndex in tracks[trackIndex].stages.indices {
                tracks[trackIndex].stages[stageIndex].noteSlot = 0
                tracks[trackIndex].stages[stageIndex].pulses = 1
                tracks[trackIndex].stages[stageIndex].ratchets = 1
                tracks[trackIndex].stages[stageIndex].probability = 1.0
                tracks[trackIndex].stages[stageIndex].stepType = .play
                tracks[trackIndex].stages[stageIndex].gateMode = .every
                tracks[trackIndex].stages[stageIndex].octave = 0
                tracks[trackIndex].stages[stageIndex].slide = false
            }
        }

        // Debug voicing: Plaits String (11/15), Rings String (2/5).
        audioEngine?.setParameter(id: .plaitsModel, value: Float(11.0 / 16.0))
        audioEngine?.setParameter(id: .ringsModel, value: Float(2.0 / 5.0))
    }

    var lastTrackGateDeltaSamples: Int? {
        guard let sampleA = lastGateSamplePerTrack[0], let sampleB = lastGateSamplePerTrack[1] else {
            return nil
        }
        return Int(abs(Int64(sampleA) - Int64(sampleB)))
    }

    var lastTrackNoteOnDeltaSamples: Int? {
        guard let sampleA = lastScheduledNoteOnSamplePerTrack[0], let sampleB = lastScheduledNoteOnSamplePerTrack[1] else {
            return nil
        }
        return Int(abs(Int64(sampleA) - Int64(sampleB)))
    }

    func randomizeTrack(_ trackIndex: Int) {
        guard tracks.indices.contains(trackIndex) else { return }
        for stageIndex in tracks[trackIndex].stages.indices {
            tracks[trackIndex].stages[stageIndex].noteSlot = Int.random(in: 0...8)
            tracks[trackIndex].stages[stageIndex].pulses = Int.random(in: 1...4)
            tracks[trackIndex].stages[stageIndex].ratchets = Int.random(in: 1...4)
            tracks[trackIndex].stages[stageIndex].probability = Double.random(in: 0.55...1.0)
            tracks[trackIndex].stages[stageIndex].gateMode = SequencerGateMode.allCases.randomElement() ?? .every
            let weightedTypes: [SequencerStepType] = [.play, .play, .play, .play, .tie, .rest, .skip, .elide]
            tracks[trackIndex].stages[stageIndex].stepType = weightedTypes.randomElement() ?? .play
        }
    }

    func setTrackMuted(_ trackIndex: Int, _ muted: Bool) {
        guard tracks.indices.contains(trackIndex) else { return }
        tracks[trackIndex].muted = muted
    }

    func setTrackRunning(_ trackIndex: Int, _ running: Bool) {
        guard tracks.indices.contains(trackIndex) else { return }
        tracks[trackIndex].running = running
        if running {
            // Quantize resume to the next beat boundary
            let nextBeat = nextBeatBoundarySample()
            schedulingLock.lock()
            schedulingState.runtimes[trackIndex].nextPulseSample = nextBeat
            schedulingLock.unlock()
        }
    }

    func resetTrack(_ trackIndex: Int) {
        guard tracks.indices.contains(trackIndex) else { return }
        let start = tracks[trackIndex].loopStart
        let nextBeat = nextBeatBoundarySample()
        schedulingLock.lock()
        schedulingState.runtimes[trackIndex] = TrackRuntimeState(
            stageIndex: start,
            pulseInStage: 0,
            nextPulseSample: nextBeat,
            alternateForward: true,
            heldTieNote: nil,
            patternStep: 0,
            climbWindowStart: start,
            accumCounters: Array(repeating: 0, count: 8),
            trackAccumCounter: 0
        )
        schedulingState.playheadStages[trackIndex] = start
        schedulingState.playheadPulses[trackIndex] = 0
        schedulingState.lastPlayedNotes[trackIndex] = nil
        schedulingLock.unlock()
        playheadStagePerTrack[trackIndex] = start
        playheadPulsePerTrack[trackIndex] = 0
        lastPlayedNotePerTrack[trackIndex] = nil
    }

    /// Returns the sample time of the next quarter-note beat boundary,
    /// aligned to `transportStartSample`.
    private func nextBeatBoundarySample() -> UInt64 {
        let nowSample = (audioEngine?.currentSampleTime() ?? 0) + secondsToSamples(schedulerLeadInSeconds)
        let bpm = max(tempoBPM, 1.0)
        let beatSamples = secondsToSamples(60.0 / bpm)
        guard beatSamples > 0 else { return nowSample }

        schedulingLock.lock()
        let transportStart = schedulingState.transportStartSample
        schedulingLock.unlock()

        guard nowSample >= transportStart else { return nowSample }
        let elapsed = nowSample - transportStart
        let remainder = elapsed % beatSamples
        if remainder == 0 {
            return nowSample
        }
        return nowSample + (beatSamples - remainder)
    }

    func setTempoBPM(_ bpm: Double) {
        tempoBPM = min(max(bpm, 40.0), 240.0)
    }

    func setRootNote(_ note: Int) {
        rootNote = min(max(note, 0), 11)
    }

    func setSequenceOctave(_ octave: Int) {
        sequenceOctave = min(max(octave, -4), 4)
    }

    func setScaleIndex(_ index: Int) {
        let maxIndex = max(scaleOptions.count - 1, 0)
        scaleIndex = min(max(index, 0), maxIndex)
    }

    func setTrackDirection(_ trackIndex: Int, _ direction: SequencerDirection) {
        guard tracks.indices.contains(trackIndex) else { return }
        tracks[trackIndex].direction = direction
    }

    func setTrackDivision(_ trackIndex: Int, _ division: SequencerClockDivision) {
        guard tracks.indices.contains(trackIndex) else { return }
        tracks[trackIndex].division = division
        if isPlaying {
            schedulingLock.lock()
            if schedulingState.runtimes.indices.contains(trackIndex) {
                let now = audioEngine?.currentSampleTime() ?? 0
                let anchor = schedulingState.transportStartSample
                let pulse = pulseDurationSamples(for: tracks[trackIndex])
                if now <= anchor {
                    schedulingState.runtimes[trackIndex].nextPulseSample = anchor
                } else {
                    let elapsed = now - anchor
                    let stepCount = (elapsed + pulse - 1) / pulse
                    schedulingState.runtimes[trackIndex].nextPulseSample = anchor + (stepCount * pulse)
                }
            }
            schedulingLock.unlock()
        }
    }

    func setTrackTranspose(_ trackIndex: Int, _ transpose: Int) {
        guard tracks.indices.contains(trackIndex) else { return }
        tracks[trackIndex].transpose = min(max(transpose, -24), 24)
    }

    func setTrackOctaveOffset(_ trackIndex: Int, _ octaveOffset: Int) {
        guard tracks.indices.contains(trackIndex) else { return }
        let clampedOffset = min(max(octaveOffset, -4), 4)
        tracks[trackIndex].baseOctave = 4 + clampedOffset
    }

    func trackOctaveOffset(_ trackIndex: Int) -> Int {
        guard tracks.indices.contains(trackIndex) else { return 0 }
        return min(max(tracks[trackIndex].baseOctave - 4, -4), 4)
    }

    func setTrackVelocity(_ trackIndex: Int, _ velocity: Int) {
        guard tracks.indices.contains(trackIndex) else { return }
        tracks[trackIndex].velocity = min(max(velocity, 1), 127)
    }

    func setTrackOutput(_ trackIndex: Int, _ output: SequencerTrackOutput) {
        guard tracks.indices.contains(trackIndex) else { return }
        tracks[trackIndex].output = output
    }

    func setTrackLoopStart(_ trackIndex: Int, _ start: Int) {
        guard tracks.indices.contains(trackIndex) else { return }
        let stageCount = tracks[trackIndex].stages.count
        let clampedStart = min(max(start, 0), stageCount - 1)
        tracks[trackIndex].loopStart = min(clampedStart, tracks[trackIndex].loopEnd)
        selectedStagePerTrack[trackIndex] = min(max(selectedStagePerTrack[trackIndex], tracks[trackIndex].loopStart), tracks[trackIndex].loopEnd)
    }

    func setTrackLoopEnd(_ trackIndex: Int, _ end: Int) {
        guard tracks.indices.contains(trackIndex) else { return }
        let stageCount = tracks[trackIndex].stages.count
        let clampedEnd = min(max(end, 0), stageCount - 1)
        tracks[trackIndex].loopEnd = max(clampedEnd, tracks[trackIndex].loopStart)
        selectedStagePerTrack[trackIndex] = min(max(selectedStagePerTrack[trackIndex], tracks[trackIndex].loopStart), tracks[trackIndex].loopEnd)
    }

    func selectStage(_ trackIndex: Int, _ stageIndex: Int) {
        guard tracks.indices.contains(trackIndex) else { return }
        guard tracks[trackIndex].stages.indices.contains(stageIndex) else { return }
        selectedStagePerTrack[trackIndex] = stageIndex
    }

    func setStagePulses(track: Int, stage: Int, value: Int) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].pulses = min(max(value, 1), 8)
    }

    func setStageGateMode(track: Int, stage: Int, value: SequencerGateMode) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].gateMode = value
    }

    func setStageRatchets(track: Int, stage: Int, value: Int) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].ratchets = min(max(value, 1), 8)
    }

    func setStageProbability(track: Int, stage: Int, value: Double) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].probability = min(max(value, 0.0), 1.0)
    }

    func setStageNoteSlot(track: Int, stage: Int, value: Int) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].noteSlot = min(max(value, 0), 8)
    }

    func setStageOctave(track: Int, stage: Int, value: Int) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].octave = min(max(value, -4), 4)
    }

    func setStageSlide(track: Int, stage: Int, value: Bool) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].slide = value
    }

    func setStageGateLength(track: Int, stage: Int, value: Double) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].gateLength = min(max(value, 0.01), 1.0)
    }

    func setStageStepType(track: Int, stage: Int, value: SequencerStepType) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].stepType = value
    }

    func setStageAccumTranspose(track: Int, stage: Int, value: Int) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].accumTranspose = min(max(value, -7), 7)
    }

    func setStageAccumTrigger(track: Int, stage: Int, value: AccumulatorTrigger) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].accumTrigger = value
    }

    func setStageAccumRange(track: Int, stage: Int, value: Int) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].accumRange = min(max(value, 1), 7)
    }

    func setStageAccumMode(track: Int, stage: Int, value: AccumulatorMode) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].accumMode = value
    }

    func resetTrackToDefaults(_ trackIndex: Int) {
        guard tracks.indices.contains(trackIndex) else { return }
        let track = tracks[trackIndex]
        tracks[trackIndex].direction = .forward
        tracks[trackIndex].division = .x1
        tracks[trackIndex].transpose = 0
        tracks[trackIndex].baseOctave = 4
        tracks[trackIndex].velocity = 100
        tracks[trackIndex].loopStart = 0
        tracks[trackIndex].loopEnd = track.stages.count - 1
        tracks[trackIndex].muted = false
        tracks[trackIndex].running = true
        for stageIndex in tracks[trackIndex].stages.indices {
            resetStageToDefaults(track: trackIndex, stage: stageIndex)
        }
        resetTrack(trackIndex)
    }

    func resetStageToDefaults(track: Int, stage: Int) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].noteSlot = 0
        tracks[track].stages[stage].pulses = 1
        tracks[track].stages[stage].gateMode = .every
        tracks[track].stages[stage].ratchets = 1
        tracks[track].stages[stage].probability = 1.0
        tracks[track].stages[stage].octave = 0
        tracks[track].stages[stage].stepType = .play
        tracks[track].stages[stage].gateLength = 1.0
        tracks[track].stages[stage].slide = false
        tracks[track].stages[stage].accumTranspose = 0
        tracks[track].stages[stage].accumTrigger = .stage
        tracks[track].stages[stage].accumRange = 7
        tracks[track].stages[stage].accumMode = .stage
    }

    func stageNoteText(track: Int, stage: Int) -> String {
        guard isValidStage(track: track, stage: stage) else { return "--" }
        let note = noteForStage(track: tracks[track], stage: tracks[track].stages[stage])
        return midiNoteName(Int(note))
    }

    private func isValidStage(track: Int, stage: Int) -> Bool {
        guard tracks.indices.contains(track) else { return false }
        return tracks[track].stages.indices.contains(stage)
    }

    /// Creates a frozen snapshot of sequencer state for off-MainActor scheduling.
    /// Must be called on MainActor.
    private func createSchedulingSnapshot() -> SchedulingSnapshot {
        let scale = currentScale
        let isChordScale = scaleIndex == StepSequencer.chordSequencerScaleIndex

        // Capture chord sequencer state
        let chordEnabled = chordSequencer?.isEnabled ?? false
        let chordDivision = chordSequencer?.division ?? .div4
        let chordSteps = chordSequencer?.steps ?? []
        let chordStepCount = chordSteps.count
        let chordStepIntervals: [[Int]?] = chordSteps.indices.map { i in
            chordSequencer?.chordIntervalsForStep(i)
        }

        return SchedulingSnapshot(
            tracks: tracks,
            tempoBPM: tempoBPM,
            rootNote: rootNote,
            sequenceOctave: sequenceOctave,
            scaleIntervals: scale.intervals,
            transportToken: transportToken,
            plaitsTriggerOffsetMs: plaitsTriggerOffsetMs,
            ringsTriggerOffsetMs: ringsTriggerOffsetMs,
            sampleRate: max(audioEngine?.sampleRate ?? 48_000.0, 1.0),
            lookaheadSamples: secondsToSamples(schedulerLookaheadSeconds),
            dedupe: dedupeSameSampleSharedTargetNoteOn,
            chordEnabled: chordEnabled,
            chordDivision: chordDivision,
            chordStepCount: chordStepCount,
            chordStepIntervals: chordStepIntervals,
            isChordScale: isChordScale
        )
    }

    private func scheduleTimer() {
        clockTimer?.cancel()

        // Capture initial snapshot and engine handle on MainActor
        let snapshot = createSchedulingSnapshot()
        let engineHandle = audioEngine?.cppEngineHandle

        let timer = DispatchSource.makeTimerSource(queue: clockQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(5), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            // Run scheduling directly on clockQueue — no MainActor dispatch needed
            self.scheduleLookaheadOnClockQueue(snapshot: snapshot, engineHandle: engineHandle)
        }

        clockTimer = timer
        timer.resume()

        // Periodically refresh the snapshot from MainActor (catches track/scale/BPM edits)
        // This runs on MainActor and updates the snapshot the clock queue uses
        startSnapshotRefreshTimer()
    }

    /// Holds the latest snapshot for the clock queue to read
    private var _latestSnapshot: SchedulingSnapshot?
    private let snapshotLock = NSLock()
    private var snapshotRefreshTimer: Timer?
    private var snapshotRefreshInFlight = false

    private func startSnapshotRefreshTimer() {
        snapshotRefreshTimer?.invalidate()
        snapshotRefreshInFlight = false
        snapshotRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, !self.snapshotRefreshInFlight else { return }
            self.snapshotRefreshInFlight = true
            // This runs on MainActor (RunLoop.main)
            Task { @MainActor in
                defer { self.snapshotRefreshInFlight = false }
                guard self.isPlaying else { return }
                let snap = self.createSchedulingSnapshot()
                self.snapshotLock.lock()
                self._latestSnapshot = snap
                self.snapshotLock.unlock()

                // Also pull playhead updates from clockQueue → MainActor
                self.pullPlayheadUpdates()
            }
        }
    }

    /// Pull playhead state from scheduling state to @Published properties (on MainActor)
    private func pullPlayheadUpdates() {
        schedulingLock.lock()
        let stages = schedulingState.playheadStages
        let pulses = schedulingState.playheadPulses
        let lastNotes = schedulingState.lastPlayedNotes
        let lastGates = schedulingState.lastGateSamples
        let lastScheduled = schedulingState.lastScheduledNoteOnSamples
        let chordPlayhead = schedulingState.chordPlayheadStep
        schedulingLock.unlock()

        playheadStagePerTrack = stages
        playheadPulsePerTrack = pulses
        lastPlayedNotePerTrack = lastNotes
        lastGateSamplePerTrack = lastGates
        lastScheduledNoteOnSamplePerTrack = lastScheduled

        // Update chord sequencer playhead on MainActor
        chordSequencer?.playheadStep = chordPlayhead
    }

    private func resetRuntimeState(startSample: UInt64) {
        lastGateSamplePerTrack = [nil, nil]
        lastScheduledNoteOnSamplePerTrack = [nil, nil]

        schedulingLock.lock()
        schedulingState.transportStartSample = startSample
        schedulingState.lastGateSamples = [nil, nil]
        schedulingState.lastScheduledNoteOnSamples = [nil, nil]
        for trackIndex in tracks.indices {
            let start = tracks[trackIndex].loopStart
            schedulingState.runtimes[trackIndex] = TrackRuntimeState(
                stageIndex: start,
                pulseInStage: 0,
                nextPulseSample: startSample,
                alternateForward: true,
                heldTieNote: nil,
                patternStep: 0,
                climbWindowStart: start,
                accumCounters: Array(repeating: 0, count: 8),
                trackAccumCounter: 0
            )
            schedulingState.playheadStages[trackIndex] = start
            schedulingState.playheadPulses[trackIndex] = 0
            schedulingState.lastPlayedNotes[trackIndex] = nil
        }
        // Reset chord sequencer playhead
        schedulingState.chordStageIndex = 0
        schedulingState.chordNextPulseSample = startSample
        schedulingState.chordPlayheadStep = 0
        schedulingLock.unlock()

        for trackIndex in tracks.indices {
            playheadStagePerTrack[trackIndex] = tracks[trackIndex].loopStart
            playheadPulsePerTrack[trackIndex] = 0
            lastPlayedNotePerTrack[trackIndex] = nil
        }

        // Reset chord sequencer playhead on MainActor
        chordSequencer?.playheadStep = 0
    }

    // MARK: - Clock Queue Scheduling (runs OFF MainActor)

    /// Main scheduling entry point — runs on clockQueue, never blocks MainActor.
    /// Uses snapshot for immutable state, schedulingState (under lock) for mutable runtime.
    private func scheduleLookaheadOnClockQueue(snapshot initialSnapshot: SchedulingSnapshot, engineHandle: OpaquePointer?) {
        guard let handle = engineHandle else { return }

        // Check for a newer snapshot from the refresh timer
        snapshotLock.lock()
        let snapshot = _latestSnapshot ?? initialSnapshot
        snapshotLock.unlock()

        // Get current sample time directly from C++ (thread-safe, no MainActor needed)
        let nowSample = AudioEngine_GetCurrentSampleTime(handle)
        let horizonSample = nowSample &+ snapshot.lookaheadSamples

        // Grab mutable runtime state under lock
        schedulingLock.lock()
        var state = schedulingState
        schedulingLock.unlock()

        let tracks = snapshot.tracks

        // Advance chord sequencer playhead if needed (before note scheduling so
        // the correct chord intervals are used in the same lookahead window)
        if snapshot.chordEnabled && snapshot.chordStepCount > 0 {
            let chordPulseSamples = chordPulseDurationSamples(snapshot: snapshot)
            while state.chordNextPulseSample <= horizonSample {
                state.chordStageIndex = (state.chordStageIndex + 1) % snapshot.chordStepCount
                state.chordPlayheadStep = state.chordStageIndex
                state.chordNextPulseSample = state.chordNextPulseSample &+ chordPulseSamples
            }
        }

        while true {
            var earliestSample: UInt64 = UInt64.max

            for trackIndex in tracks.indices {
                guard tracks[trackIndex].running else { continue }
                let nextSample = state.runtimes[trackIndex].nextPulseSample
                if nextSample <= horizonSample && nextSample < earliestSample {
                    earliestSample = nextSample
                }
            }

            guard earliestSample != UInt64.max else { break }

            var dueTracks: [Int] = []
            dueTracks.reserveCapacity(tracks.count)
            for trackIndex in tracks.indices {
                if tracks[trackIndex].running && state.runtimes[trackIndex].nextPulseSample == earliestSample {
                    dueTracks.append(trackIndex)
                }
            }

            var dedupKeys = Set<NoteOnDedupKey>()

            for trackIndex in dueTracks {
                let pulseSamples = pulseDurationSamplesFromSnapshot(for: tracks[trackIndex], snapshot: snapshot)
                processPulseOnClockQueue(
                    trackIndex: trackIndex,
                    pulseDurationSamples: pulseSamples,
                    eventSample: earliestSample,
                    snapshot: snapshot,
                    state: &state,
                    handle: handle,
                    dedupKeys: &dedupKeys
                )
                state.runtimes[trackIndex].nextPulseSample = earliestSample &+ pulseSamples
            }
        }

        // Write back mutable state under lock
        schedulingLock.lock()
        schedulingState = state
        schedulingLock.unlock()
    }

    /// Process a single pulse for a track — runs on clockQueue.
    private func processPulseOnClockQueue(
        trackIndex: Int,
        pulseDurationSamples: UInt64,
        eventSample: UInt64,
        snapshot: SchedulingSnapshot,
        state: inout SchedulingState,
        handle: OpaquePointer,
        dedupKeys: inout Set<NoteOnDedupKey>
    ) {
        let tracks = snapshot.tracks
        guard tracks.indices.contains(trackIndex) else { return }
        var runtime = state.runtimes[trackIndex]
        let track = tracks[trackIndex]

        runtime.stageIndex = min(max(runtime.stageIndex, track.loopStart), track.loopEnd)
        runtime.stageIndex = resolveNextPlayableStage(track: track, candidate: runtime.stageIndex, runtime: &runtime)
        guard track.stages.indices.contains(runtime.stageIndex) else { return }

        var stage = track.stages[runtime.stageIndex]
        var elideHops = 0
        while stage.stepType == .elide && elideHops < track.stages.count {
            runtime.pulseInStage = 0
            runtime.stageIndex = nextStageIndex(track: track, runtime: &runtime)
            runtime.stageIndex = resolveNextPlayableStage(track: track, candidate: runtime.stageIndex, runtime: &runtime)
            stage = track.stages[runtime.stageIndex]
            elideHops += 1
        }
        if elideHops >= track.stages.count {
            state.runtimes[trackIndex] = runtime
            return
        }

        let pulsePosition = runtime.pulseInStage
        let shouldGate: Bool
        switch stage.stepType {
        case .rest, .skip, .elide:
            shouldGate = false
        case .tie:
            shouldGate = pulsePosition == 0
        case .play:
            switch stage.gateMode {
            case .every:
                shouldGate = true
            case .first:
                shouldGate = pulsePosition == 0
            case .last:
                shouldGate = pulsePosition == stage.pulses - 1
            case .tie:
                shouldGate = pulsePosition == 0
            case .rest:
                shouldGate = false
            }
        }

        let tId = UInt8(trackIndex + 1)  // Track IDs: 1+ for sequencer tracks, 0 = keyboard

        if stage.stepType == .rest || stage.stepType == .skip {
            if let oldNote = runtime.heldTieNote {
                scheduleNoteOffDirect(note: oldNote, sampleTime: eventSample, output: track.output, snapshot: snapshot, handle: handle, trackId: tId)
                runtime.heldTieNote = nil
            }
        }

        if shouldGate && stage.probability >= Double.random(in: 0...1) {
            let note = noteForStageFromSnapshot(track: track, stage: stage, snapshot: snapshot, state: state, trackIndex: trackIndex)
            state.lastPlayedNotes[trackIndex] = note
            state.lastGateSamples[trackIndex] = eventSample

            if stage.stepType == .tie || stage.slide {
                if !track.muted {
                    if runtime.heldTieNote != note {
                        if let oldNote = runtime.heldTieNote {
                            scheduleNoteOffDirect(note: oldNote, sampleTime: eventSample, output: track.output, snapshot: snapshot, handle: handle, trackId: tId)
                        }
                        scheduleNoteOnDirect(
                            note: note, velocity: UInt8(track.velocity), sampleTime: eventSample,
                            output: track.output, snapshot: snapshot, handle: handle, dedupKeys: &dedupKeys, trackId: tId
                        )
                    }
                }
                runtime.heldTieNote = note
            } else if !track.muted {
                if let oldNote = runtime.heldTieNote {
                    scheduleNoteOffDirect(note: oldNote, sampleTime: eventSample, output: track.output, snapshot: snapshot, handle: handle, trackId: tId)
                    runtime.heldTieNote = nil
                }
                triggerRatchetsDirect(
                    note: note, velocity: UInt8(track.velocity), ratchets: stage.ratchets,
                    gateLength: stage.gateLength, pulseDurationSamples: pulseDurationSamples,
                    eventSample: eventSample,
                    target: targetMask(for: track.output), snapshot: snapshot, handle: handle,
                    dedupKeys: &dedupKeys,
                    track: track, stage: stage, trackIndex: trackIndex,
                    runtime: &runtime, state: &state,
                    trackId: tId
                )
            }

            // Accumulator counter increments (stage and pulse triggers; ratchet handled in triggerRatchetsDirect)
            if stage.accumTranspose != 0 {
                let stageIdx = runtime.stageIndex
                switch stage.accumTrigger {
                case .stage:
                    if pulsePosition == 0 {
                        incrementAccumCounter(runtime: &runtime, stageIndex: stageIdx, mode: stage.accumMode)
                    }
                case .pulse:
                    incrementAccumCounter(runtime: &runtime, stageIndex: stageIdx, mode: stage.accumMode)
                case .ratchet:
                    break // Handled in triggerRatchetsDirect
                }
            }

            if trackIndex < state.lastScheduledNoteOnSamples.count {
                state.lastScheduledNoteOnSamples[trackIndex] = eventSample
            }
        }

        // Update playhead in scheduling state (pulled to MainActor by refresh timer)
        state.playheadStages[trackIndex] = runtime.stageIndex
        state.playheadPulses[trackIndex] = runtime.pulseInStage

        runtime.pulseInStage += 1
        if runtime.pulseInStage >= stage.pulses {
            runtime.pulseInStage = 0

            if let held = runtime.heldTieNote, stage.stepType != .tie, !stage.slide {
                scheduleNoteOffDirect(note: held, sampleTime: eventSample, output: track.output, snapshot: snapshot, handle: handle, trackId: tId)
                runtime.heldTieNote = nil
            }

            runtime.stageIndex = nextStageIndex(track: track, runtime: &runtime)
            runtime.stageIndex = resolveNextPlayableStage(track: track, candidate: runtime.stageIndex, runtime: &runtime)
        }

        state.runtimes[trackIndex] = runtime
    }

    // MARK: - Direct C Bridge Helpers (called from clockQueue, no MainActor)

    private func pulseDurationSamplesFromSnapshot(for track: SequencerTrack, snapshot: SchedulingSnapshot) -> UInt64 {
        let bpm = max(snapshot.tempoBPM, 1.0)
        let quarterSeconds = 60.0 / bpm
        let multiplier = max(track.division.multiplier, 0.0001)
        let pulseSeconds = quarterSeconds / multiplier
        return UInt64(max(1.0, (pulseSeconds * snapshot.sampleRate).rounded()))
    }

    /// Pulse duration for chord sequencer clock division
    private func chordPulseDurationSamples(snapshot: SchedulingSnapshot) -> UInt64 {
        let bpm = max(snapshot.tempoBPM, 1.0)
        let quarterSeconds = 60.0 / bpm
        let multiplier = max(snapshot.chordDivision.multiplier, 0.0001)
        let pulseSeconds = quarterSeconds / multiplier
        return UInt64(max(1.0, (pulseSeconds * snapshot.sampleRate).rounded()))
    }

    /// Compute the diatonic accumulator offset for a stage given its counter value.
    /// Wraps symmetrically within ±range using negative-safe modulo.
    private func accumOffset(counter: Int, transpose: Int, range: Int) -> Int {
        guard transpose != 0 else { return 0 }
        let raw = counter * transpose
        let span = 2 * range + 1 // e.g. range=7 → span=15 (-7..+7)
        return mod(raw + range, span) - range
    }

    /// Compute the MIDI note for a stage with an explicit accumulator counter applied.
    private func noteForStageWithAccumOffset(
        track: SequencerTrack, stage: SequencerStage,
        accumCounter: Int, snapshot: SchedulingSnapshot, state: SchedulingState
    ) -> UInt8 {
        let rootMidi = (track.baseOctave + snapshot.sequenceOctave + 1) * 12 + snapshot.rootNote

        let intervals: [Int]
        if snapshot.isChordScale && snapshot.chordEnabled && snapshot.chordStepCount > 0 {
            let chordStep = state.chordPlayheadStep % snapshot.chordStepCount
            if let chordIntervals = snapshot.chordStepIntervals[chordStep], !chordIntervals.isEmpty {
                intervals = chordIntervals
            } else {
                intervals = snapshot.scaleIntervals
            }
        } else {
            intervals = snapshot.scaleIntervals
        }

        let offset = accumOffset(counter: accumCounter, transpose: stage.accumTranspose, range: stage.accumRange)
        let degree = degreeForNoteSlot(stage.noteSlot) + track.transpose + offset
        let semitoneOffset = semitoneForDegree(degree, intervals: intervals)
        let note = rootMidi + semitoneOffset + stage.octave * 12
        return UInt8(min(max(note, 0), 127))
    }

    private func noteForStageFromSnapshot(track: SequencerTrack, stage: SequencerStage, snapshot: SchedulingSnapshot, state: SchedulingState, trackIndex: Int = 0) -> UInt8 {
        // Read accumulator counter based on stage's mode
        let counter: Int
        if stage.accumTranspose != 0, state.runtimes.indices.contains(trackIndex) {
            let runtime = state.runtimes[trackIndex]
            switch stage.accumMode {
            case .stage:
                counter = stage.id < runtime.accumCounters.count ? runtime.accumCounters[stage.id] : 0
            case .track:
                counter = runtime.trackAccumCounter
            }
        } else {
            counter = 0
        }
        return noteForStageWithAccumOffset(track: track, stage: stage, accumCounter: counter, snapshot: snapshot, state: state)
    }

    private func compensatedSampleTimeDirect(base: UInt64, for target: AudioEngineWrapper.NoteTargetMask, snapshot: SchedulingSnapshot) -> UInt64 {
        let offsetMs: Double
        switch target {
        case .plaits: offsetMs = snapshot.plaitsTriggerOffsetMs
        case .rings: offsetMs = snapshot.ringsTriggerOffsetMs
        case .both: offsetMs = 0.0
        case .daisyDrum: offsetMs = 0.0
        case .sampler: offsetMs = 0.0
        case .drumLane0, .drumLane1, .drumLane2, .drumLane3: offsetMs = 0.0
        }
        let offsetSamples = Int64((offsetMs * snapshot.sampleRate / 1000.0).rounded())
        let shifted = Int64(base) + offsetSamples
        return shifted <= 0 ? 0 : UInt64(shifted)
    }

    private func scheduleNoteOnDirect(
        note: UInt8, velocity: UInt8, sampleTime: UInt64,
        output: SequencerTrackOutput, snapshot: SchedulingSnapshot, handle: OpaquePointer,
        dedupKeys: inout Set<NoteOnDedupKey>,
        trackId: UInt8 = 0
    ) {
        let target = targetMask(for: output)
        scheduleNoteOnDirect(note: note, velocity: velocity, sampleTime: sampleTime,
                             target: target, snapshot: snapshot, handle: handle, dedupKeys: &dedupKeys, trackId: trackId)
    }

    private func scheduleNoteOnDirect(
        note: UInt8, velocity: UInt8, sampleTime: UInt64,
        target: AudioEngineWrapper.NoteTargetMask, snapshot: SchedulingSnapshot, handle: OpaquePointer,
        dedupKeys: inout Set<NoteOnDedupKey>,
        trackId: UInt8 = 0
    ) {
        switch target {
        case .plaits:
            emitNoteOnDirect(note: note, velocity: velocity,
                             sampleTime: compensatedSampleTimeDirect(base: sampleTime, for: .plaits, snapshot: snapshot),
                             target: .plaits, handle: handle, dedupe: snapshot.dedupe, dedupKeys: &dedupKeys, trackId: trackId)
        case .rings:
            emitNoteOnDirect(note: note, velocity: velocity,
                             sampleTime: compensatedSampleTimeDirect(base: sampleTime, for: .rings, snapshot: snapshot),
                             target: .rings, handle: handle, dedupe: snapshot.dedupe, dedupKeys: &dedupKeys, trackId: trackId)
        case .both:
            let ps = compensatedSampleTimeDirect(base: sampleTime, for: .plaits, snapshot: snapshot)
            let rs = compensatedSampleTimeDirect(base: sampleTime, for: .rings, snapshot: snapshot)
            if rs <= ps {
                emitNoteOnDirect(note: note, velocity: velocity, sampleTime: rs, target: .rings, handle: handle, dedupe: snapshot.dedupe, dedupKeys: &dedupKeys, trackId: trackId)
                emitNoteOnDirect(note: note, velocity: velocity, sampleTime: ps, target: .plaits, handle: handle, dedupe: snapshot.dedupe, dedupKeys: &dedupKeys, trackId: trackId)
            } else {
                emitNoteOnDirect(note: note, velocity: velocity, sampleTime: ps, target: .plaits, handle: handle, dedupe: snapshot.dedupe, dedupKeys: &dedupKeys, trackId: trackId)
                emitNoteOnDirect(note: note, velocity: velocity, sampleTime: rs, target: .rings, handle: handle, dedupe: snapshot.dedupe, dedupKeys: &dedupKeys, trackId: trackId)
            }
        case .daisyDrum:
            emitNoteOnDirect(note: note, velocity: velocity,
                             sampleTime: sampleTime,
                             target: .daisyDrum, handle: handle, dedupe: snapshot.dedupe, dedupKeys: &dedupKeys, trackId: trackId)
        case .sampler:
            emitNoteOnDirect(note: note, velocity: velocity,
                             sampleTime: sampleTime,
                             target: .sampler, handle: handle, dedupe: snapshot.dedupe, dedupKeys: &dedupKeys, trackId: trackId)
        case .drumLane0, .drumLane1, .drumLane2, .drumLane3:
            break  // Drum seq lanes are driven by DrumSequencer, not StepSequencer
        }
    }

    private func emitNoteOnDirect(
        note: UInt8, velocity: UInt8, sampleTime: UInt64,
        target: AudioEngineWrapper.NoteTargetMask, handle: OpaquePointer,
        dedupe: Bool, dedupKeys: inout Set<NoteOnDedupKey>,
        trackId: UInt8 = 0
    ) {
        if dedupe {
            let key = NoteOnDedupKey(sampleTime: sampleTime, note: note, targetRaw: target.rawValue)
            if dedupKeys.contains(key) { return }
            dedupKeys.insert(key)
        }
        AudioEngine_ScheduleNoteOnTargetTagged(handle, Int32(note), Int32(velocity), sampleTime, target.rawValue, trackId)
    }

    private func scheduleNoteOffDirect(
        note: UInt8, sampleTime: UInt64, output: SequencerTrackOutput,
        snapshot: SchedulingSnapshot, handle: OpaquePointer,
        trackId: UInt8 = 0
    ) {
        let target = targetMask(for: output)
        switch target {
        case .plaits:
            AudioEngine_ScheduleNoteOffTargetTagged(handle, Int32(note),
                compensatedSampleTimeDirect(base: sampleTime, for: .plaits, snapshot: snapshot), AudioEngineWrapper.NoteTargetMask.plaits.rawValue, trackId)
        case .rings:
            AudioEngine_ScheduleNoteOffTargetTagged(handle, Int32(note),
                compensatedSampleTimeDirect(base: sampleTime, for: .rings, snapshot: snapshot), AudioEngineWrapper.NoteTargetMask.rings.rawValue, trackId)
        case .both:
            let ps = compensatedSampleTimeDirect(base: sampleTime, for: .plaits, snapshot: snapshot)
            let rs = compensatedSampleTimeDirect(base: sampleTime, for: .rings, snapshot: snapshot)
            if rs <= ps {
                AudioEngine_ScheduleNoteOffTargetTagged(handle, Int32(note), rs, AudioEngineWrapper.NoteTargetMask.rings.rawValue, trackId)
                AudioEngine_ScheduleNoteOffTargetTagged(handle, Int32(note), ps, AudioEngineWrapper.NoteTargetMask.plaits.rawValue, trackId)
            } else {
                AudioEngine_ScheduleNoteOffTargetTagged(handle, Int32(note), ps, AudioEngineWrapper.NoteTargetMask.plaits.rawValue, trackId)
                AudioEngine_ScheduleNoteOffTargetTagged(handle, Int32(note), rs, AudioEngineWrapper.NoteTargetMask.rings.rawValue, trackId)
            }
        case .daisyDrum:
            AudioEngine_ScheduleNoteOffTargetTagged(handle, Int32(note),
                sampleTime, AudioEngineWrapper.NoteTargetMask.daisyDrum.rawValue, trackId)
        case .sampler:
            AudioEngine_ScheduleNoteOffTargetTagged(handle, Int32(note),
                sampleTime, AudioEngineWrapper.NoteTargetMask.sampler.rawValue, trackId)
        case .drumLane0, .drumLane1, .drumLane2, .drumLane3:
            break  // Drum seq lanes are driven by DrumSequencer, not StepSequencer
        }
    }

    /// Increment the appropriate accumulator counter (per-stage or shared track).
    private func incrementAccumCounter(runtime: inout TrackRuntimeState, stageIndex: Int, mode: AccumulatorMode) {
        switch mode {
        case .stage:
            if stageIndex < runtime.accumCounters.count {
                runtime.accumCounters[stageIndex] += 1
            }
        case .track:
            runtime.trackAccumCounter += 1
        }
    }

    private func triggerRatchetsDirect(
        note: UInt8, velocity: UInt8, ratchets: Int, gateLength: Double,
        pulseDurationSamples: UInt64,
        eventSample: UInt64, target: AudioEngineWrapper.NoteTargetMask,
        snapshot: SchedulingSnapshot, handle: OpaquePointer,
        dedupKeys: inout Set<NoteOnDedupKey>,
        track: SequencerTrack? = nil, stage: SequencerStage? = nil,
        trackIndex: Int = 0,
        runtime: inout TrackRuntimeState, state: inout SchedulingState,
        trackId: UInt8 = 0
    ) {
        let ratchetCount = max(ratchets, 1)
        let subdivisionSamples = max(1, Int(pulseDurationSamples) / ratchetCount)
        let isRatchetTrigger = stage?.accumTrigger == .ratchet && (stage?.accumTranspose ?? 0) != 0

        for ratchetIndex in 0..<ratchetCount {
            let onSample = eventSample &+ UInt64(ratchetIndex * subdivisionSamples)
            let gateLengthSamples = max(1, Int(Double(subdivisionSamples) * gateLength))
            let offSample = onSample &+ UInt64(gateLengthSamples)

            let ratchetNote: UInt8
            if isRatchetTrigger, let trk = track, let stg = stage {
                if ratchetIndex == 0 {
                    // First ratchet uses the pre-computed note, then increment
                    ratchetNote = note
                    incrementAccumCounter(runtime: &runtime, stageIndex: runtime.stageIndex, mode: stg.accumMode)
                    state.runtimes[trackIndex] = runtime
                } else {
                    // Subsequent ratchets re-compute note from updated counter
                    let counter: Int
                    switch stg.accumMode {
                    case .stage:
                        counter = stg.id < runtime.accumCounters.count ? runtime.accumCounters[stg.id] : 0
                    case .track:
                        counter = runtime.trackAccumCounter
                    }
                    ratchetNote = noteForStageWithAccumOffset(
                        track: trk, stage: stg, accumCounter: counter,
                        snapshot: snapshot, state: state
                    )
                    incrementAccumCounter(runtime: &runtime, stageIndex: runtime.stageIndex, mode: stg.accumMode)
                    state.runtimes[trackIndex] = runtime
                }
            } else {
                ratchetNote = note
            }

            scheduleNoteOnDirect(note: ratchetNote, velocity: velocity, sampleTime: onSample,
                                 target: target, snapshot: snapshot, handle: handle, dedupKeys: &dedupKeys, trackId: trackId)
            scheduleNoteOffDirect(note: ratchetNote, sampleTime: offSample, output: targetToOutput(target), snapshot: snapshot, handle: handle, trackId: trackId)
        }
    }

    private func targetToOutput(_ target: AudioEngineWrapper.NoteTargetMask) -> SequencerTrackOutput {
        switch target {
        case .plaits: return .plaits
        case .rings: return .rings
        case .both: return .both
        case .daisyDrum: return .daisyDrum
        case .sampler: return .sampler
        case .drumLane0, .drumLane1, .drumLane2, .drumLane3: return .daisyDrum  // Fallback; not used for drum seq lanes
        }
    }

    private func resolveNextPlayableStage(track: SequencerTrack, candidate: Int, runtime: inout TrackRuntimeState) -> Int {
        let loopRange = track.loopStart...track.loopEnd
        let index = min(max(candidate, track.loopStart), track.loopEnd)
        _ = runtime
        _ = loopRange
        return index
    }

    private func nextStageIndex(track: SequencerTrack, runtime: inout TrackRuntimeState) -> Int {
        let lower = track.loopStart
        let upper = track.loopEnd

        switch track.direction {
        case .forward:
            return runtime.stageIndex >= upper ? lower : runtime.stageIndex + 1
        case .reverse:
            return runtime.stageIndex <= lower ? upper : runtime.stageIndex - 1
        case .alternate:
            if runtime.alternateForward {
                if runtime.stageIndex >= upper {
                    runtime.alternateForward = false
                    return max(upper - 1, lower)
                }
                return runtime.stageIndex + 1
            } else {
                if runtime.stageIndex <= lower {
                    runtime.alternateForward = true
                    return min(lower + 1, upper)
                }
                return runtime.stageIndex - 1
            }
        case .random:
            let loopIndices = Array(lower...upper)
            return loopIndices.randomElement() ?? runtime.stageIndex

        case .skip2:
            return nextSkipIndex(step: 2, lower: lower, upper: upper, runtime: &runtime)

        case .skip3:
            return nextSkipIndex(step: 3, lower: lower, upper: upper, runtime: &runtime)

        case .climb2:
            return nextClimbIndex(windowSize: 2, lower: lower, upper: upper, runtime: &runtime)

        case .climb3:
            return nextClimbIndex(windowSize: 3, lower: lower, upper: upper, runtime: &runtime)

        case .drunk:
            let delta = Bool.random() ? 1 : -1
            let next = runtime.stageIndex + delta
            return min(max(next, lower), upper)

        case .randomNoRepeat:
            let loopLen = upper - lower + 1
            if loopLen <= 1 { return lower }
            var next: Int
            repeat {
                next = Int.random(in: lower...upper)
            } while next == runtime.stageIndex
            return next

        case .converge:
            let loopLen = upper - lower + 1
            runtime.patternStep += 1
            if runtime.patternStep >= loopLen { runtime.patternStep = 0 }
            let step = runtime.patternStep
            if step % 2 == 0 {
                return lower + step / 2
            } else {
                return upper - step / 2
            }

        case .diverge:
            let loopLen = upper - lower + 1
            runtime.patternStep += 1
            if runtime.patternStep >= loopLen { runtime.patternStep = 0 }
            let step = runtime.patternStep
            let mid = (lower + upper) / 2
            if step == 0 {
                return mid
            } else if step % 2 == 1 {
                // Expand outward: right side first
                let offset = (step + 1) / 2
                return min(mid + offset, upper)
            } else {
                // Then left side
                let offset = step / 2
                return max(mid - offset, lower)
            }
        }
    }

    /// Skip pattern: advance by `step` each time, multi-pass to cover all positions.
    private func nextSkipIndex(step: Int, lower: Int, upper: Int, runtime: inout TrackRuntimeState) -> Int {
        let next = runtime.stageIndex + step
        if next <= upper {
            return next
        }
        // Wrap to next pass
        runtime.patternStep += 1
        if runtime.patternStep >= step { runtime.patternStep = 0 }
        return lower + runtime.patternStep
    }

    /// Climb pattern: play a window of `windowSize` steps, then shift window forward by 1.
    private func nextClimbIndex(windowSize: Int, lower: Int, upper: Int, runtime: inout TrackRuntimeState) -> Int {
        runtime.patternStep += 1
        if runtime.patternStep >= windowSize {
            // Window complete — advance window start
            runtime.patternStep = 0
            runtime.climbWindowStart += 1
            if runtime.climbWindowStart > upper {
                runtime.climbWindowStart = lower
            }
        }
        // Return position within window, wrapping around loop bounds
        let loopLen = upper - lower + 1
        let pos = runtime.climbWindowStart + runtime.patternStep
        return lower + ((pos - lower) % loopLen)
    }

    private func noteForStage(track: SequencerTrack, stage: SequencerStage) -> UInt8 {
        let rootMidi = (track.baseOctave + sequenceOctave + 1) * 12 + rootNote

        // Use chord intervals for display when Chord Sequencer scale is active
        let intervals: [Int]
        if scaleIndex == StepSequencer.chordSequencerScaleIndex,
           let chordIntervals = chordSequencer?.currentChordIntervals(), !chordIntervals.isEmpty {
            intervals = chordIntervals
        } else {
            intervals = currentScale.intervals
        }

        let degree = degreeForNoteSlot(stage.noteSlot) + track.transpose
        let semitoneOffset = semitoneForDegree(degree, intervals: intervals)
        let note = rootMidi + semitoneOffset + stage.octave * 12
        let clamped = min(max(note, 0), 127)
        return UInt8(clamped)
    }

    private func degreeForNoteSlot(_ slot: Int) -> Int {
        let clamped = min(max(slot, 0), 8)
        return clamped
    }

    private var currentScale: SequencerScaleDefinition {
        if scaleOptions.isEmpty {
            return SequencerScaleDefinition(id: 0, name: "Major", intervals: [0, 2, 4, 5, 7, 9, 11])
        }
        let index = min(max(scaleIndex, 0), scaleOptions.count - 1)
        return scaleOptions[index]
    }

    private func semitoneForDegree(_ degree: Int, intervals: [Int]) -> Int {
        let count = intervals.count
        guard count > 0 else { return 0 }

        let octave = floorDiv(degree, count)
        let index = mod(degree, count)
        return octave * 12 + intervals[index]
    }

    private func floorDiv(_ value: Int, _ divisor: Int) -> Int {
        precondition(divisor > 0)
        if value >= 0 {
            return value / divisor
        }
        return -(((-value) + divisor - 1) / divisor)
    }

    private func mod(_ value: Int, _ divisor: Int) -> Int {
        precondition(divisor > 0)
        let result = value % divisor
        return result >= 0 ? result : result + divisor
    }

    private var engineSampleRate: Double {
        max(audioEngine?.sampleRate ?? 48_000.0, 1.0)
    }

    var interEngineCompensationMs: Double {
        (Double(interEngineCompensationSamples) / engineSampleRate) * 1000.0
    }

    func setInterEngineCompensationMs(_ ms: Double) {
        _ = ms
        interEngineCompensationSamples = 0
    }

    func setPlaitsTriggerOffsetMs(_ ms: Double) {
        plaitsTriggerOffsetMs = min(max(ms, -30.0), 30.0)
    }

    func setRingsTriggerOffsetMs(_ ms: Double) {
        ringsTriggerOffsetMs = min(max(ms, -30.0), 30.0)
    }

    private func secondsToSamples(_ seconds: Double) -> UInt64 {
        UInt64(max(1.0, (seconds * engineSampleRate).rounded()))
    }

    private func pulseDurationSamples(for track: SequencerTrack) -> UInt64 {
        let bpm = max(tempoBPM, 1.0)
        let quarterSeconds = 60.0 / bpm
        let multiplier = max(track.division.multiplier, 0.0001)
        let pulseSeconds = quarterSeconds / multiplier
        return secondsToSamples(pulseSeconds)
    }

    // Old MainActor scheduling methods removed — replaced by clockQueue versions above

    private func targetMask(for output: SequencerTrackOutput) -> AudioEngineWrapper.NoteTargetMask {
        switch output {
        case .plaits:
            return .plaits
        case .rings:
            return .rings
        case .both:
            return .both
        case .daisyDrum:
            return .daisyDrum
        case .sampler:
            return .sampler
        }
    }

    private func releaseAllHeldTieNotes() {
        schedulingLock.lock()
        var rts = schedulingState.runtimes
        schedulingLock.unlock()

        let now = audioEngine?.currentSampleTime() ?? 0
        for index in rts.indices {
            if let note = rts[index].heldTieNote {
                let output = tracks.indices.contains(index) ? tracks[index].output : .both
                let target = targetMask(for: output)
                audioEngine?.scheduleNoteOff(note: note, sampleTime: now, target: target)
            }
            rts[index].heldTieNote = nil
        }

        schedulingLock.lock()
        schedulingState.runtimes = rts
        schedulingLock.unlock()
    }

    private func midiNoteName(_ midiNote: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let clamped = min(max(midiNote, 0), 127)
        let octave = (clamped / 12) - 1
        let noteName = names[clamped % 12]
        return "\(noteName)\(octave)"
    }
}

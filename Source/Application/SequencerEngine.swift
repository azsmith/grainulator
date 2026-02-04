//
//  SequencerEngine.swift
//  Grainulator
//
//  Metropolix-inspired dual-track sequencer for Plaits playback.
//

import Foundation

enum SequencerDirection: String, CaseIterable, Identifiable {
    case forward = "FWD"
    case reverse = "REV"
    case alternate = "ALT"
    case random = "RND"

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

enum SequencerTrackOutput: String, CaseIterable, Identifiable {
    case plaits = "PLAITS"
    case rings = "RINGS"
    case both = "BOTH"

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
    var slide: Bool
}

struct SequencerTrack: Identifiable {
    let id: Int
    var name: String
    var muted: Bool
    var direction: SequencerDirection
    var division: SequencerClockDivision
    var loopStart: Int
    var loopEnd: Int
    var transpose: Int
    var baseOctave: Int
    var velocity: Int
    var output: SequencerTrackOutput
    var stages: [SequencerStage]

    static func makeDefault(id: Int, name: String, noteSlots: [Int], division: SequencerClockDivision) -> SequencerTrack {
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
                    stepType: .play,
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
            output: .both,
            stages: stages
        )
    }
}

@MainActor
final class MetropolixSequencer: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var tempoBPM: Double = 120.0
    @Published var rootNote: Int = 0 // 0=C ... 11=B
    @Published var sequenceOctave: Int = 0
    @Published var scaleIndex: Int = 0
    @Published var tracks: [SequencerTrack] = [
        SequencerTrack.makeDefault(id: 0, name: "TRACK 1", noteSlots: [0, 0, 0, 0, 0, 0, 0, 0], division: .x1),
        SequencerTrack.makeDefault(id: 1, name: "TRACK 2", noteSlots: [0, 0, 0, 0, 0, 0, 0, 0], division: .x1)
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
    }

    private struct NoteOnDedupKey: Hashable {
        let sampleTime: UInt64
        let note: UInt8
        let targetRaw: UInt8
    }

    private weak var audioEngine: AudioEngineWrapper?
    private weak var masterClock: MasterClock?
    private var clockTimer: DispatchSourceTimer?
    private let clockQueue = DispatchQueue(label: "com.grainulator.sequencer.clock", qos: .userInteractive)
    private var runtimes: [TrackRuntimeState] = [
        TrackRuntimeState(),
        TrackRuntimeState()
    ]
    private var transportStartSample: UInt64 = 0
    private var transportToken: UInt64 = 0
    private let schedulerLookaheadSeconds: Double = 0.10
    private let schedulerLeadInSeconds: Double = 0.02
    // Temporarily disabled while diagnosing onset/attack mismatch.
    @Published var interEngineCompensationSamples: Int = 0
    @Published var plaitsTriggerOffsetMs: Double = 0.0
    @Published var ringsTriggerOffsetMs: Double = 0.0
    private let dedupeSameSampleSharedTargetNoteOn = true

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
        SequencerScaleDefinition(id: 40, name: "Chromatic", intervals: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
    ]

    func connect(audioEngine: AudioEngineWrapper) {
        self.audioEngine = audioEngine
        applySyncDebugPreset()
    }

    func connectMasterClock(_ masterClock: MasterClock) {
        self.masterClock = masterClock
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
        // Sync the master clock to the same start sample for phase alignment
        masterClock?.startSynced(startSample: startSample)
        scheduleTimer()
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        transportToken &+= 1
        clockTimer?.cancel()
        clockTimer = nil
        audioEngine?.clearScheduledNotes()
        audioEngine?.allNotesOff()
        releaseAllHeldTieNotes()
        // Stop the master clock too
        masterClock?.stop()
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
        audioEngine?.setParameter(id: .plaitsModel, value: Float(11.0 / 15.0))
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

    func setTempoBPM(_ bpm: Double) {
        tempoBPM = min(max(bpm, 40.0), 240.0)
    }

    func setRootNote(_ note: Int) {
        rootNote = min(max(note, 0), 11)
    }

    func setSequenceOctave(_ octave: Int) {
        sequenceOctave = min(max(octave, -2), 2)
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
        if isPlaying, runtimes.indices.contains(trackIndex) {
            let now = audioEngine?.currentSampleTime() ?? 0
            runtimes[trackIndex].nextPulseSample = quantizedNextPulseSample(for: tracks[trackIndex], nowSample: now)
        }
    }

    func setTrackTranspose(_ trackIndex: Int, _ transpose: Int) {
        guard tracks.indices.contains(trackIndex) else { return }
        tracks[trackIndex].transpose = min(max(transpose, -24), 24)
    }

    func setTrackOctaveOffset(_ trackIndex: Int, _ octaveOffset: Int) {
        guard tracks.indices.contains(trackIndex) else { return }
        let clampedOffset = min(max(octaveOffset, -2), 2)
        tracks[trackIndex].baseOctave = 4 + clampedOffset
    }

    func trackOctaveOffset(_ trackIndex: Int) -> Int {
        guard tracks.indices.contains(trackIndex) else { return 0 }
        return min(max(tracks[trackIndex].baseOctave - 4, -2), 2)
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
        tracks[track].stages[stage].octave = min(max(value, -2), 2)
    }

    func setStageSlide(track: Int, stage: Int, value: Bool) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].slide = value
    }

    func setStageStepType(track: Int, stage: Int, value: SequencerStepType) {
        guard isValidStage(track: track, stage: stage) else { return }
        tracks[track].stages[stage].stepType = value
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

    private func scheduleTimer() {
        clockTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: clockQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(5), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.scheduleLookahead()
            }
        }

        clockTimer = timer
        timer.resume()
    }

    private func resetRuntimeState(startSample: UInt64) {
        transportStartSample = startSample
        lastGateSamplePerTrack = [nil, nil]
        lastScheduledNoteOnSamplePerTrack = [nil, nil]
        for trackIndex in tracks.indices {
            let start = tracks[trackIndex].loopStart
            runtimes[trackIndex] = TrackRuntimeState(
                stageIndex: start,
                pulseInStage: 0,
                nextPulseSample: startSample,
                alternateForward: true,
                heldTieNote: nil
            )
            playheadStagePerTrack[trackIndex] = start
            playheadPulsePerTrack[trackIndex] = 0
            lastPlayedNotePerTrack[trackIndex] = nil
        }
    }

    private func scheduleLookahead() {
        guard isPlaying else { return }
        guard let audioEngine else { return }

        let nowSample = audioEngine.currentSampleTime()
        let lookaheadSamples = secondsToSamples(schedulerLookaheadSeconds)
        let horizonSample = nowSample &+ lookaheadSamples

        while true {
            var earliestSample: UInt64 = UInt64.max

            for trackIndex in tracks.indices {
                let nextSample = runtimes[trackIndex].nextPulseSample
                if nextSample <= horizonSample && nextSample < earliestSample {
                    earliestSample = nextSample
                }
            }

            guard earliestSample != UInt64.max else { break }

            var dueTracks: [Int] = []
            dueTracks.reserveCapacity(tracks.count)
            for trackIndex in tracks.indices {
                if runtimes[trackIndex].nextPulseSample == earliestSample {
                    dueTracks.append(trackIndex)
                }
            }

            var dedupKeys = Set<NoteOnDedupKey>()

            for trackIndex in dueTracks {
                let pulseSamples = pulseDurationSamples(for: tracks[trackIndex])
                processPulse(
                    trackIndex: trackIndex,
                    pulseDurationSamples: pulseSamples,
                    eventSample: earliestSample,
                    token: transportToken,
                    dedupKeys: &dedupKeys
                )
                runtimes[trackIndex].nextPulseSample = earliestSample &+ pulseSamples
            }
        }
    }

    private func processPulse(
        trackIndex: Int,
        pulseDurationSamples: UInt64,
        eventSample: UInt64,
        token: UInt64,
        dedupKeys: inout Set<NoteOnDedupKey>
    ) {
        guard tracks.indices.contains(trackIndex) else { return }
        var runtime = runtimes[trackIndex]
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
            runtimes[trackIndex] = runtime
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

        if stage.stepType == .rest || stage.stepType == .skip {
            if let oldNote = runtime.heldTieNote {
                scheduleAlignedNoteOff(note: oldNote, sampleTime: eventSample, output: track.output)
                runtime.heldTieNote = nil
            }
        }

        if shouldGate && stage.probability >= Double.random(in: 0...1) {
            let note = noteForStage(track: track, stage: stage)
            lastPlayedNotePerTrack[trackIndex] = note
            lastGateSamplePerTrack[trackIndex] = eventSample

            if stage.stepType == .tie || stage.slide {
                if !track.muted {
                    if runtime.heldTieNote != note {
                        if let oldNote = runtime.heldTieNote {
                            scheduleAlignedNoteOff(note: oldNote, sampleTime: eventSample, output: track.output)
                        }
                        scheduleAlignedNoteOn(
                            note: note,
                            velocity: UInt8(track.velocity),
                            sampleTime: eventSample,
                            output: track.output,
                            trackIndex: trackIndex,
                            dedupKeys: &dedupKeys
                        )
                    }
                }
                runtime.heldTieNote = note
            } else if !track.muted {
                if let oldNote = runtime.heldTieNote {
                    scheduleAlignedNoteOff(note: oldNote, sampleTime: eventSample, output: track.output)
                    runtime.heldTieNote = nil
                }
                triggerRatchets(
                    note: note,
                    velocity: UInt8(track.velocity),
                    ratchets: stage.ratchets,
                    pulseDurationSamples: pulseDurationSamples,
                    eventSample: eventSample,
                    token: token,
                    target: targetMask(for: track.output),
                    trackIndex: trackIndex,
                    dedupKeys: &dedupKeys
                )
            }
        }

        // UI playhead should indicate the step currently being processed.
        playheadStagePerTrack[trackIndex] = runtime.stageIndex
        playheadPulsePerTrack[trackIndex] = runtime.pulseInStage

        runtime.pulseInStage += 1
        if runtime.pulseInStage >= stage.pulses {
            runtime.pulseInStage = 0

            if let held = runtime.heldTieNote, stage.stepType != .tie, !stage.slide {
                scheduleAlignedNoteOff(note: held, sampleTime: eventSample, output: track.output)
                runtime.heldTieNote = nil
            }

            runtime.stageIndex = nextStageIndex(track: track, runtime: &runtime)
            runtime.stageIndex = resolveNextPlayableStage(track: track, candidate: runtime.stageIndex, runtime: &runtime)
        }

        runtimes[trackIndex] = runtime
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
        }
    }

    private func noteForStage(track: SequencerTrack, stage: SequencerStage) -> UInt8 {
        let rootMidi = (track.baseOctave + sequenceOctave + 1) * 12 + rootNote
        let degree = degreeForNoteSlot(stage.noteSlot) + track.transpose
        let semitoneOffset = semitoneForDegree(degree, intervals: currentScale.intervals)
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

    private func quantizedNextPulseSample(for track: SequencerTrack, nowSample: UInt64) -> UInt64 {
        let pulse = pulseDurationSamples(for: track)
        let anchor = transportStartSample
        if nowSample <= anchor {
            return anchor
        }

        let elapsed = nowSample - anchor
        let stepCount = (elapsed + pulse - 1) / pulse
        return anchor + (stepCount * pulse)
    }

    private func triggerRatchets(
        note: UInt8,
        velocity: UInt8,
        ratchets: Int,
        pulseDurationSamples: UInt64,
        eventSample: UInt64,
        token: UInt64,
        target: AudioEngineWrapper.NoteTargetMask,
        trackIndex: Int,
        dedupKeys: inout Set<NoteOnDedupKey>
    ) {
        _ = token
        let ratchetCount = max(ratchets, 1)
        let subdivisionSamples = max(1, Int(pulseDurationSamples) / ratchetCount)
        let maxGateLengthSamples = max(1, Int(engineSampleRate * 0.14))

        for ratchetIndex in 0..<ratchetCount {
            let onSample = eventSample &+ UInt64(ratchetIndex * subdivisionSamples)
            let gateLengthSamples = max(
                1,
                min(maxGateLengthSamples, Int(Double(subdivisionSamples) * 0.65))
            )
            let offSample = onSample &+ UInt64(gateLengthSamples)

            scheduleAlignedNoteOn(
                note: note,
                velocity: velocity,
                sampleTime: onSample,
                target: target,
                trackIndex: trackIndex,
                dedupKeys: &dedupKeys
            )
            scheduleAlignedNoteOff(note: note, sampleTime: offSample, target: target)
        }
    }

    private func scheduleAlignedNoteOn(
        note: UInt8,
        velocity: UInt8,
        sampleTime: UInt64,
        output: SequencerTrackOutput,
        trackIndex: Int,
        dedupKeys: inout Set<NoteOnDedupKey>
    ) {
        scheduleAlignedNoteOn(
            note: note,
            velocity: velocity,
            sampleTime: sampleTime,
            target: targetMask(for: output),
            trackIndex: trackIndex,
            dedupKeys: &dedupKeys
        )
    }

    private func scheduleAlignedNoteOff(note: UInt8, sampleTime: UInt64, output: SequencerTrackOutput) {
        scheduleAlignedNoteOff(note: note, sampleTime: sampleTime, target: targetMask(for: output))
    }

    private func emitScheduledNoteOn(
        note: UInt8,
        velocity: UInt8,
        sampleTime: UInt64,
        target: AudioEngineWrapper.NoteTargetMask,
        dedupKeys: inout Set<NoteOnDedupKey>
    ) {
        if dedupeSameSampleSharedTargetNoteOn {
            let key = NoteOnDedupKey(sampleTime: sampleTime, note: note, targetRaw: target.rawValue)
            if dedupKeys.contains(key) {
                return
            }
            dedupKeys.insert(key)
        }

        audioEngine?.scheduleNoteOn(note: note, velocity: velocity, sampleTime: sampleTime, target: target)
    }

    private func scheduleAlignedNoteOn(
        note: UInt8,
        velocity: UInt8,
        sampleTime: UInt64,
        target: AudioEngineWrapper.NoteTargetMask,
        trackIndex: Int,
        dedupKeys: inout Set<NoteOnDedupKey>
    ) {
        if trackIndex >= 0 && trackIndex < lastScheduledNoteOnSamplePerTrack.count {
            lastScheduledNoteOnSamplePerTrack[trackIndex] = sampleTime
        }

        switch target {
        case .plaits:
            emitScheduledNoteOn(
                note: note,
                velocity: velocity,
                sampleTime: compensatedSampleTime(base: sampleTime, for: .plaits),
                target: .plaits,
                dedupKeys: &dedupKeys
            )
        case .rings:
            emitScheduledNoteOn(
                note: note,
                velocity: velocity,
                sampleTime: compensatedSampleTime(base: sampleTime, for: .rings),
                target: .rings,
                dedupKeys: &dedupKeys
            )
        case .both:
            let plaitsSample = compensatedSampleTime(base: sampleTime, for: .plaits)
            let ringsSample = compensatedSampleTime(base: sampleTime, for: .rings)
            emitScheduledNoteOn(
                note: note,
                velocity: velocity,
                sampleTime: ringsSample,
                target: .rings,
                dedupKeys: &dedupKeys
            )
            emitScheduledNoteOn(
                note: note,
                velocity: velocity,
                sampleTime: plaitsSample,
                target: .plaits,
                dedupKeys: &dedupKeys
            )
        }
    }

    private func scheduleAlignedNoteOff(note: UInt8, sampleTime: UInt64, target: AudioEngineWrapper.NoteTargetMask) {
        switch target {
        case .plaits:
            audioEngine?.scheduleNoteOff(
                note: note,
                sampleTime: compensatedSampleTime(base: sampleTime, for: .plaits),
                target: .plaits
            )
        case .rings:
            audioEngine?.scheduleNoteOff(
                note: note,
                sampleTime: compensatedSampleTime(base: sampleTime, for: .rings),
                target: .rings
            )
        case .both:
            let plaitsSample = compensatedSampleTime(base: sampleTime, for: .plaits)
            let ringsSample = compensatedSampleTime(base: sampleTime, for: .rings)
            audioEngine?.scheduleNoteOff(note: note, sampleTime: ringsSample, target: .rings)
            audioEngine?.scheduleNoteOff(note: note, sampleTime: plaitsSample, target: .plaits)
        }
    }

    private func compensatedSampleTime(base: UInt64, for target: AudioEngineWrapper.NoteTargetMask) -> UInt64 {
        let offsetMs: Double
        switch target {
        case .plaits:
            offsetMs = plaitsTriggerOffsetMs
        case .rings:
            offsetMs = ringsTriggerOffsetMs
        case .both:
            offsetMs = 0.0
        }

        let offsetSamples = Int64((offsetMs * engineSampleRate / 1000.0).rounded())
        let shifted = Int64(base) + offsetSamples
        if shifted <= 0 {
            return 0
        }
        return UInt64(shifted)
    }

    private func targetMask(for output: SequencerTrackOutput) -> AudioEngineWrapper.NoteTargetMask {
        switch output {
        case .plaits:
            return .plaits
        case .rings:
            return .rings
        case .both:
            return .both
        }
    }

    private func releaseAllHeldTieNotes() {
        for index in runtimes.indices {
            if let note = runtimes[index].heldTieNote {
                let output = tracks.indices.contains(index) ? tracks[index].output : .both
                let target = targetMask(for: output)
                let now = audioEngine?.currentSampleTime() ?? 0
                audioEngine?.scheduleNoteOff(note: note, sampleTime: now, target: target)
            }
            runtimes[index].heldTieNote = nil
        }
    }

    private func midiNoteName(_ midiNote: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let clamped = min(max(midiNote, 0), 127)
        let octave = (clamped / 12) - 1
        let noteName = names[clamped % 12]
        return "\(noteName)\(octave)"
    }
}

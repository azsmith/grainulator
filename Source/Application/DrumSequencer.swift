//
//  DrumSequencer.swift
//  Grainulator
//
//  4-lane x 16-step drum trigger sequencer.
//  Each lane drives a dedicated DaisyDrumVoice (Analog Kick, Synth Kick, Analog Snare, Hi-Hat).
//  Uses snapshot-based scheduling on a dedicated clockQueue (same pattern as StepSequencer).
//

import Foundation
import Combine

// MARK: - Drum Lane Definition

enum DrumLane: Int, CaseIterable, Identifiable {
    case analogKick = 0
    case synthKick = 1
    case analogSnare = 2
    case hiHat = 3

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .analogKick: return "Analog Kick"
        case .synthKick: return "Synth Kick"
        case .analogSnare: return "Analog Snare"
        case .hiHat: return "Hi-Hat"
        }
    }

    var shortName: String {
        switch self {
        case .analogKick: return "A.KCK"
        case .synthKick: return "S.KCK"
        case .analogSnare: return "A.SNR"
        case .hiHat: return "HHAT"
        }
    }

    /// NoteTarget bitmask for this lane (bits 3-6)
    var targetMask: UInt8 {
        return 1 << (3 + rawValue)
    }
}

// MARK: - Drum Step

struct DrumStep: Identifiable {
    let id: Int           // 0-15
    var isActive: Bool = false
    var velocity: Float = 0.8   // 0-1
}

// MARK: - Drum Lane State

struct DrumLaneState: Identifiable {
    let id: Int
    let lane: DrumLane
    var steps: [DrumStep]
    var isMuted: Bool = false
    var level: Float = 0.8
    var harmonics: Float = 0.5
    var timbre: Float = 0.5
    var morph: Float = 0.5
    var note: UInt8 = 60       // MIDI note (controls drum pitch)

    init(lane: DrumLane, harmonics: Float = 0.5, timbre: Float = 0.5, morph: Float = 0.5, level: Float = 0.8, note: UInt8 = 60) {
        self.id = lane.rawValue
        self.lane = lane
        self.steps = (0..<16).map { DrumStep(id: $0) }
        self.harmonics = harmonics
        self.timbre = timbre
        self.morph = morph
        self.level = level
        self.note = note
    }
}

// MARK: - Drum Sequencer

@MainActor
class DrumSequencer: ObservableObject {
    static let numLanes = 4
    static let numSteps = 16

    // MARK: - Published State

    @Published var lanes: [DrumLaneState]
    @Published var isPlaying: Bool = false
    @Published var currentStep: Int = 0
    @Published var stepDivision: SequencerClockDivision = .x4  // 16th notes
    @Published var syncToTransport: Bool = true  // When true, drums start/stop with master transport
    @Published var loopStart: Int = 0       // First step in loop range (inclusive)
    @Published var loopEnd: Int = 15        // Last step in loop range (inclusive)

    // MARK: - Private Scheduling

    /// Immutable snapshot captured on MainActor, consumed on clockQueue.
    private struct SchedulingSnapshot {
        let lanes: [DrumLaneState]
        let tempoBPM: Double
        let division: SequencerClockDivision
        let transportToken: UInt64
        let sampleRate: Double
        let lookaheadSamples: UInt64
        let loopStart: Int
        let loopEnd: Int
    }

    /// Mutable scheduling state protected by schedulingLock.
    private struct SchedulingState {
        var currentStep: Int = 0
        var nextStepSample: UInt64 = 0
        var transportStartSample: UInt64 = 0
        var samplesPerStep: UInt64 = 0  // Cached for playhead calculation
    }

    private weak var audioEngine: AudioEngineWrapper?
    private weak var masterClock: MasterClock?
    private var clockTimer: DispatchSourceTimer?
    private let clockQueue = DispatchQueue(label: "com.grainulator.drumseq.clock", qos: .userInteractive)

    private let schedulingLock = NSLock()
    private var schedulingState = SchedulingState()

    private var transportToken: UInt64 = 0
    private let schedulerLookaheadSeconds: Double = 0.10
    private let schedulerLeadInSeconds: Double = 0.02
    /// Gate duration in seconds for drum triggers
    private let gateDurationSeconds: Double = 0.05

    // Snapshot refresh
    private var _latestSnapshot: SchedulingSnapshot?
    private let snapshotLock = NSLock()
    private var snapshotRefreshTimer: Timer?
    private var refreshFrameCount: Int = 0
    private var snapshotRefreshInFlight = false

    // MARK: - Init

    init() {
        self.lanes = [
            DrumLaneState(lane: .analogKick,  harmonics: 0.55, timbre: 0.27, morph: 0.50, level: 0.70, note: 36),
            DrumLaneState(lane: .synthKick,   harmonics: 0.50, timbre: 0.50, morph: 0.50, level: 0.71, note: 36),
            DrumLaneState(lane: .analogSnare, harmonics: 0.26, timbre: 0.48, morph: 0.35, level: 0.71, note: 52),
            DrumLaneState(lane: .hiHat,       harmonics: 0.63, timbre: 0.45, morph: 0.69, level: 0.71, note: 69),
        ]
    }

    // MARK: - Connection

    func connect(audioEngine: AudioEngineWrapper) {
        self.audioEngine = audioEngine
        // Sync lane parameters to engine
        for lane in lanes {
            audioEngine.setDrumSeqLaneLevel(lane.id, value: lane.level)
            audioEngine.setDrumSeqLaneHarmonics(lane.id, value: lane.harmonics)
            audioEngine.setDrumSeqLaneTimbre(lane.id, value: lane.timbre)
            audioEngine.setDrumSeqLaneMorph(lane.id, value: lane.morph)
        }
    }

    func connectMasterClock(_ masterClock: MasterClock) {
        self.masterClock = masterClock
    }

    // MARK: - Transport

    func togglePlayback() {
        isPlaying ? stop() : start()
    }

    func start() {
        guard !isPlaying else { return }
        isPlaying = true
        transportToken &+= 1

        let startSample = (audioEngine?.currentSampleTime() ?? 0) + secondsToSamples(schedulerLeadInSeconds)
        resetSchedulingState(startSample: startSample)

        scheduleTimer()
    }

    /// Start synced to an external start sample (called by master transport)
    func startSynced(startSample: UInt64) {
        guard !isPlaying else { return }
        isPlaying = true
        transportToken &+= 1

        resetSchedulingState(startSample: startSample)
        scheduleTimer()
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        transportToken &+= 1

        clockTimer?.cancel()
        clockTimer = nil
        snapshotRefreshTimer?.invalidate()
        snapshotRefreshTimer = nil

        pullPlayheadUpdates()
    }

    // MARK: - Step Editing

    func toggleStep(lane laneIndex: Int, step stepIndex: Int) {
        guard laneIndex < lanes.count, stepIndex < DrumSequencer.numSteps else { return }
        lanes[laneIndex].steps[stepIndex].isActive.toggle()
    }

    func setStepActive(lane laneIndex: Int, step stepIndex: Int, active: Bool) {
        guard laneIndex < lanes.count, stepIndex < DrumSequencer.numSteps else { return }
        lanes[laneIndex].steps[stepIndex].isActive = active
    }

    func setLaneMuted(_ laneIndex: Int, muted: Bool) {
        guard laneIndex < lanes.count else { return }
        lanes[laneIndex].isMuted = muted
    }

    func toggleLaneMute(_ laneIndex: Int) {
        guard laneIndex < lanes.count else { return }
        lanes[laneIndex].isMuted.toggle()
    }

    func setLaneLevel(_ laneIndex: Int, value: Float) {
        guard laneIndex < lanes.count else { return }
        lanes[laneIndex].level = value
        audioEngine?.setDrumSeqLaneLevel(laneIndex, value: value)
    }

    func setLaneHarmonics(_ laneIndex: Int, value: Float) {
        guard laneIndex < lanes.count else { return }
        lanes[laneIndex].harmonics = value
        audioEngine?.setDrumSeqLaneHarmonics(laneIndex, value: value)
    }

    func setLaneTimbre(_ laneIndex: Int, value: Float) {
        guard laneIndex < lanes.count else { return }
        lanes[laneIndex].timbre = value
        audioEngine?.setDrumSeqLaneTimbre(laneIndex, value: value)
    }

    func setLaneMorph(_ laneIndex: Int, value: Float) {
        guard laneIndex < lanes.count else { return }
        lanes[laneIndex].morph = value
        audioEngine?.setDrumSeqLaneMorph(laneIndex, value: value)
    }

    func setLaneNote(_ laneIndex: Int, note: UInt8) {
        guard laneIndex < lanes.count else { return }
        lanes[laneIndex].note = min(max(note, 24), 96)  // Clamp to reasonable drum range
    }

    func setStepVelocity(lane laneIndex: Int, step stepIndex: Int, velocity: Float) {
        guard laneIndex < lanes.count, stepIndex < DrumSequencer.numSteps else { return }
        lanes[laneIndex].steps[stepIndex].velocity = max(0, min(1, velocity))
    }

    /// Clear all steps for a lane
    func clearLane(_ laneIndex: Int) {
        guard laneIndex < lanes.count else { return }
        for i in 0..<DrumSequencer.numSteps {
            lanes[laneIndex].steps[i].isActive = false
        }
    }

    /// Clear all steps for all lanes
    func clearAll() {
        for laneIndex in 0..<lanes.count {
            clearLane(laneIndex)
        }
    }

    // MARK: - Snapshot Creation

    private func createSchedulingSnapshot() -> SchedulingSnapshot {
        let bpm = masterClock?.bpm ?? 120.0
        let sr = max(audioEngine?.sampleRate ?? 48_000.0, 1.0)
        return SchedulingSnapshot(
            lanes: lanes,
            tempoBPM: bpm,
            division: stepDivision,
            transportToken: transportToken,
            sampleRate: sr,
            lookaheadSamples: secondsToSamples(schedulerLookaheadSeconds),
            loopStart: loopStart,
            loopEnd: loopEnd
        )
    }

    // MARK: - Timer Setup

    private func scheduleTimer() {
        clockTimer?.cancel()

        let snapshot = createSchedulingSnapshot()
        let engineHandle = audioEngine?.cppEngineHandle

        let timer = DispatchSource.makeTimerSource(queue: clockQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(5), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.scheduleLookaheadOnClockQueue(snapshot: snapshot, engineHandle: engineHandle)
        }

        clockTimer = timer
        timer.resume()

        startSnapshotRefreshTimer()
    }

    private func startSnapshotRefreshTimer() {
        snapshotRefreshTimer?.invalidate()
        refreshFrameCount = 0
        snapshotRefreshInFlight = false
        // 16ms (~60fps) for smooth playhead display
        snapshotRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self, !self.snapshotRefreshInFlight else { return }
            self.snapshotRefreshInFlight = true
            Task { @MainActor in
                defer { self.snapshotRefreshInFlight = false }
                guard self.isPlaying else { return }

                // Pull playhead from audio clock every frame for smooth display
                self.pullPlayheadUpdates()

                // Refresh scheduling snapshot every ~48ms (every 3rd frame)
                // to keep parameter/step changes flowing to the clockQueue
                self.refreshFrameCount += 1
                if self.refreshFrameCount >= 3 {
                    self.refreshFrameCount = 0
                    let snap = self.createSchedulingSnapshot()
                    self.snapshotLock.lock()
                    self._latestSnapshot = snap
                    self.snapshotLock.unlock()
                }
            }
        }
    }

    private func pullPlayheadUpdates() {
        guard let handle = audioEngine?.cppEngineHandle else { return }

        // Read scheduling state atomically
        schedulingLock.lock()
        let startSample = schedulingState.transportStartSample
        let sps = schedulingState.samplesPerStep
        schedulingLock.unlock()

        guard sps > 0 else { return }

        // Compute the currently-playing step from the actual audio clock position,
        // wrapping within the loop range (loopStart...loopEnd) to match scheduling
        let nowSample = AudioEngine_GetCurrentSampleTime(handle)
        if nowSample >= startSample {
            let elapsed = nowSample - startSample
            let loopLen = max(1, loopEnd - loopStart + 1)
            let stepInLoop = Int((elapsed / sps) % UInt64(loopLen))
            currentStep = loopStart + stepInLoop
        }
    }

    private func resetSchedulingState(startSample: UInt64) {
        schedulingLock.lock()
        schedulingState.currentStep = loopStart
        schedulingState.nextStepSample = startSample
        schedulingState.transportStartSample = startSample
        schedulingState.samplesPerStep = 0
        schedulingLock.unlock()

        currentStep = loopStart
    }

    // MARK: - Clock Queue Scheduling

    private func scheduleLookaheadOnClockQueue(snapshot initialSnapshot: SchedulingSnapshot, engineHandle: OpaquePointer?) {
        guard let handle = engineHandle else { return }

        // Check for a newer snapshot
        snapshotLock.lock()
        let snapshot = _latestSnapshot ?? initialSnapshot
        snapshotLock.unlock()

        // Verify transport is still valid
        guard snapshot.transportToken == transportToken else { return }

        let nowSample = AudioEngine_GetCurrentSampleTime(handle)
        let horizonSample = nowSample + snapshot.lookaheadSamples

        // Calculate samples per step
        let beatsPerSecond = snapshot.tempoBPM / 60.0
        let stepsPerSecond = beatsPerSecond * snapshot.division.multiplier
        let samplesPerStep = UInt64(snapshot.sampleRate / stepsPerSecond)

        // Gate duration in samples
        let gateSamples = UInt64(gateDurationSeconds * snapshot.sampleRate)

        schedulingLock.lock()
        var state = schedulingState
        schedulingLock.unlock()

        // Cache samplesPerStep for playhead calculation on UI thread
        state.samplesPerStep = samplesPerStep

        while state.nextStepSample < horizonSample {
            let stepIndex = state.currentStep

            // Schedule triggers for each active, unmuted lane
            for laneState in snapshot.lanes {
                guard !laneState.isMuted else { continue }
                let step = laneState.steps[stepIndex]
                guard step.isActive else { continue }

                let velocity = UInt8(max(1, min(127, step.velocity * 127.0)))
                let targetMask = laneState.lane.targetMask
                let midiNote = Int32(laneState.note)

                // Schedule note-on
                AudioEngine_ScheduleNoteOnTarget(
                    handle,
                    midiNote,
                    Int32(velocity),
                    state.nextStepSample,
                    targetMask
                )

                // Schedule note-off (gate release)
                AudioEngine_ScheduleNoteOffTarget(
                    handle,
                    midiNote,
                    state.nextStepSample + gateSamples,
                    targetMask
                )
            }

            // Advance to next step, respecting loop range
            let loopS = max(0, min(snapshot.loopStart, DrumSequencer.numSteps - 1))
            let loopE = max(loopS, min(snapshot.loopEnd, DrumSequencer.numSteps - 1))
            let nextStep = stepIndex + 1
            if nextStep > loopE {
                state.currentStep = loopS
            } else {
                state.currentStep = nextStep
            }
            state.nextStepSample += samplesPerStep
        }

        schedulingLock.lock()
        schedulingState = state
        schedulingLock.unlock()
    }

    // MARK: - Utility

    private func secondsToSamples(_ seconds: Double) -> UInt64 {
        let sr = audioEngine?.sampleRate ?? 48_000.0
        return UInt64(seconds * sr)
    }
}

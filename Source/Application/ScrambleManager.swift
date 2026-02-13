//
//  ScrambleManager.swift
//  Grainulator
//
//  Manages the Scramble probabilistic sequencer: owns a ScrambleEngine,
//  handles clock polling, and routes T/X/Y outputs to the audio engine.
//

import Foundation
import Combine

// MARK: - Scramble Note Target

enum ScrambleNoteTarget: String, CaseIterable, Identifiable, Codable {
    case plaits = "Macro Osc"
    case rings = "Resonator"
    case daisyDrum = "Drums"
    case sampler = "Sampler"
    case drumLane0 = "Analog Kick"
    case drumLane1 = "Synth Kick"
    case drumLane2 = "Analog Snare"
    case drumLane3 = "Hi-Hat"
    case none = "None"

    var id: String { rawValue }

    var noteTargetMask: AudioEngineWrapper.NoteTargetMask? {
        switch self {
        case .plaits: return .plaits
        case .rings: return .rings
        case .daisyDrum: return .daisyDrum
        case .sampler: return .sampler
        case .drumLane0: return .drumLane0
        case .drumLane1: return .drumLane1
        case .drumLane2: return .drumLane2
        case .drumLane3: return .drumLane3
        case .none: return nil
        }
    }
}

// MARK: - Scramble Manager

@MainActor
class ScrambleManager: ObservableObject {

    // MARK: - Published State

    @Published var enabled: Bool = false
    @Published var engine: ScrambleEngine = ScrambleEngine()
    @Published var division: SequencerClockDivision = .x1

    // T routing
    @Published var t1Destination: ModulationDestination = .plaitsGate
    @Published var t2Destination: ModulationDestination = .ringsGate
    @Published var t3Destination: ModulationDestination = .daisyDrumGate

    // X routing
    @Published var x1Destination: ScrambleNoteTarget = .plaits
    @Published var x2Destination: ScrambleNoteTarget = .rings
    @Published var x3Destination: ScrambleNoteTarget = .none

    // Y routing
    @Published var yDestination: ModulationDestination = .plaitsTimbre
    @Published var yAmount: Double = 0.5

    // Visualization
    @Published var lastTOutput: ScrambleEngine.TOutput = ScrambleEngine.TOutput()
    @Published var lastXOutput: ScrambleEngine.XOutput = ScrambleEngine.XOutput()
    @Published var lastYOutput: ScrambleEngine.YOutput = ScrambleEngine.YOutput()
    @Published var tHistory: [ScrambleEngine.TOutput] = []
    @Published var xHistory: [UInt8] = []
    @Published var yHistory: [Double] = []

    // MARK: - Connections

    private weak var audioEngine: AudioEngineWrapper?
    private weak var masterClock: MasterClock?
    private weak var sequencer: StepSequencer?

    // MARK: - Clock State

    private var clockTimer: DispatchSourceTimer?
    private let clockQueue = DispatchQueue(label: "com.grainulator.scramble.clock", qos: .userInteractive)
    private var isRunning: Bool = false
    private var transportToken: UInt64 = 0

    /// Scheduling state protected by schedulingLock for cross-thread access.
    private struct SchedulingState {
        var nextStepSample: UInt64 = 0
        var transportStartSample: UInt64 = 0
    }

    private let schedulingLock = NSLock()
    private var schedulingState = SchedulingState()

    /// Immutable snapshot captured on MainActor, consumed on clockQueue.
    private struct ClockSnapshot {
        let enabled: Bool
        let division: SequencerClockDivision
        let bpm: Double
        let sampleRate: Double
        let transportToken: UInt64

        // Engine state (value copy)
        let engine: ScrambleEngine

        // Routing
        let t1Destination: ModulationDestination
        let t2Destination: ModulationDestination
        let t3Destination: ModulationDestination
        let x1Destination: ScrambleNoteTarget
        let x2Destination: ScrambleNoteTarget
        let x3Destination: ScrambleNoteTarget
        let yDestination: ModulationDestination
        let yAmount: Double

        // Scale info
        let rootNote: Int
        let sequenceOctave: Int
        let scaleIntervals: [Int]
    }

    private var _latestSnapshot: ClockSnapshot?
    private let snapshotLock = NSLock()
    private var snapshotRefreshTimer: Timer?

    private static let historyLength = 16
    private static let lookaheadSeconds: Double = 0.10
    private static let gateDurationSeconds: Double = 0.05

    // Track ID for ScheduleNoteOnTargetTagged
    private static let scrambleTrackId: UInt8 = 10

    // MARK: - Init / Connect

    func connect(audioEngine: AudioEngineWrapper, masterClock: MasterClock, sequencer: StepSequencer) {
        self.audioEngine = audioEngine
        self.masterClock = masterClock
        self.sequencer = sequencer
    }

    // MARK: - Transport

    func start(startSample: UInt64) {
        guard enabled, !isRunning else { return }
        isRunning = true
        transportToken &+= 1

        schedulingLock.lock()
        schedulingState.nextStepSample = startSample
        schedulingState.transportStartSample = startSample
        schedulingLock.unlock()

        scheduleTimer()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        transportToken &+= 1

        clockTimer?.cancel()
        clockTimer = nil
        snapshotRefreshTimer?.invalidate()
        snapshotRefreshTimer = nil
    }

    func reset() {
        engine = ScrambleEngine()
        tHistory.removeAll()
        xHistory.removeAll()
        yHistory.removeAll()
        lastTOutput = ScrambleEngine.TOutput()
        lastXOutput = ScrambleEngine.XOutput()
        lastYOutput = ScrambleEngine.YOutput()
    }

    // MARK: - Snapshot

    private func createSnapshot() -> ClockSnapshot {
        let bpm = masterClock?.bpm ?? 120.0
        let sr = max(audioEngine?.sampleRate ?? 48_000.0, 1.0)
        let root = sequencer?.rootNote ?? 0
        let octave = sequencer?.sequenceOctave ?? 0

        // Access the scale intervals through the sequencer's published scaleIndex
        let scaleIntervals: [Int]
        if let seq = sequencer {
            let scaleIdx = min(max(seq.scaleIndex, 0), seq.scaleOptions.count - 1)
            scaleIntervals = seq.scaleOptions[scaleIdx].intervals
        } else {
            scaleIntervals = [0, 2, 4, 5, 7, 9, 11] // Major scale fallback
        }

        return ClockSnapshot(
            enabled: enabled,
            division: division,
            bpm: bpm,
            sampleRate: sr,
            transportToken: transportToken,
            engine: engine,
            t1Destination: t1Destination,
            t2Destination: t2Destination,
            t3Destination: t3Destination,
            x1Destination: x1Destination,
            x2Destination: x2Destination,
            x3Destination: x3Destination,
            yDestination: yDestination,
            yAmount: yAmount,
            rootNote: root,
            sequenceOctave: octave,
            scaleIntervals: scaleIntervals
        )
    }

    // MARK: - Timer Setup

    private func scheduleTimer() {
        clockTimer?.cancel()

        let snapshot = createSnapshot()
        let engineHandle = audioEngine?.cppEngineHandle

        let timer = DispatchSource.makeTimerSource(queue: clockQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(5), leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.pollClock(initialSnapshot: snapshot, engineHandle: engineHandle)
        }

        clockTimer = timer
        timer.resume()

        startSnapshotRefreshTimer()
    }

    private func startSnapshotRefreshTimer() {
        snapshotRefreshTimer?.invalidate()
        snapshotRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.048, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                let snap = self.createSnapshot()
                self.snapshotLock.lock()
                self._latestSnapshot = snap
                self.snapshotLock.unlock()
            }
        }
    }

    // MARK: - Clock Polling (runs on clockQueue)

    private func pollClock(initialSnapshot: ClockSnapshot, engineHandle: OpaquePointer?) {
        guard let handle = engineHandle else { return }

        // Get latest snapshot
        snapshotLock.lock()
        let snapshot = _latestSnapshot ?? initialSnapshot
        snapshotLock.unlock()

        guard snapshot.transportToken == transportToken, snapshot.enabled else { return }

        let nowSample = AudioEngine_GetCurrentSampleTime(handle)
        let lookaheadSamples = UInt64(Self.lookaheadSeconds * snapshot.sampleRate)
        let horizonSample = nowSample + lookaheadSamples

        // Calculate samples per tick
        let beatsPerSecond = snapshot.bpm / 60.0
        let stepsPerSecond = beatsPerSecond * snapshot.division.multiplier
        let samplesPerTick = UInt64(snapshot.sampleRate / stepsPerSecond)

        guard samplesPerTick > 0 else { return }

        let gateSamples = UInt64(Self.gateDurationSeconds * snapshot.sampleRate)

        schedulingLock.lock()
        var state = schedulingState
        schedulingLock.unlock()

        // Work with a mutable copy of the engine for generating outputs
        var eng = snapshot.engine

        // Root MIDI note
        let rootMidi = UInt8(clamped: (snapshot.sequenceOctave + 5) * 12 + snapshot.rootNote)

        // Collect visualization data per step (dispatched once after the loop)
        var vizT: [ScrambleEngine.TOutput] = []
        var vizX: [UInt8] = []
        var vizY: [Double] = []
        var lastT = ScrambleEngine.TOutput()
        var lastX = ScrambleEngine.XOutput()
        var lastY = ScrambleEngine.YOutput()

        while state.nextStepSample < horizonSample {
            // Generate T
            let tOut = eng.generateT()

            // Generate X
            let xOut = eng.generateX(
                scaleIntervals: snapshot.scaleIntervals,
                rootMidi: rootMidi
            )

            // Generate Y
            let yOut = eng.generateY()

            // Route T outputs (gate triggers)
            routeTrigger(tOut.t1, destination: snapshot.t1Destination, note: xOut.x1, handle: handle, sampleTime: state.nextStepSample, gateSamples: gateSamples)
            routeTrigger(tOut.t2, destination: snapshot.t2Destination, note: xOut.x2, handle: handle, sampleTime: state.nextStepSample, gateSamples: gateSamples)
            routeTrigger(tOut.t3, destination: snapshot.t3Destination, note: xOut.x3, handle: handle, sampleTime: state.nextStepSample, gateSamples: gateSamples)

            // Route X note outputs (only when the corresponding T fires)
            if tOut.t1 { routeNote(xOut.x1, target: snapshot.x1Destination, handle: handle, sampleTime: state.nextStepSample, gateSamples: gateSamples) }
            if tOut.t2 { routeNote(xOut.x2, target: snapshot.x2Destination, handle: handle, sampleTime: state.nextStepSample, gateSamples: gateSamples) }
            if tOut.t3 { routeNote(xOut.x3, target: snapshot.x3Destination, handle: handle, sampleTime: state.nextStepSample, gateSamples: gateSamples) }

            // Collect for visualization
            vizT.append(tOut)
            vizX.append(xOut.x1)
            vizY.append(yOut.value)
            lastT = tOut
            lastX = xOut
            lastY = yOut

            state.nextStepSample += samplesPerTick
        }

        // Update visualization and sync engine state back (single dispatch)
        if !vizT.isEmpty {
            let finalEngine = eng
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.lastTOutput = lastT
                    self.lastXOutput = lastX
                    self.lastYOutput = lastY

                    self.tHistory.append(contentsOf: vizT)
                    if self.tHistory.count > Self.historyLength {
                        self.tHistory.removeFirst(self.tHistory.count - Self.historyLength)
                    }

                    self.xHistory.append(contentsOf: vizX)
                    if self.xHistory.count > Self.historyLength {
                        self.xHistory.removeFirst(self.xHistory.count - Self.historyLength)
                    }

                    self.yHistory.append(contentsOf: vizY)
                    if self.yHistory.count > Self.historyLength {
                        self.yHistory.removeFirst(self.yHistory.count - Self.historyLength)
                    }

                    self.engine = finalEngine
                }
            }
        }

        schedulingLock.lock()
        schedulingState = state
        schedulingLock.unlock()
    }

    // MARK: - Routing Helpers

    /// Routes a T trigger to the audio engine if the gate is active and destination is a trigger type.
    private func routeTrigger(_ active: Bool, destination: ModulationDestination, note: UInt8, handle: OpaquePointer, sampleTime: UInt64, gateSamples: UInt64) {
        guard active, destination.isTriggerDestination else { return }
        guard let mask = triggerDestinationToMask(destination) else { return }

        AudioEngine_ScheduleNoteOnTargetTagged(
            handle,
            Int32(note),
            Int32(100),
            sampleTime,
            mask,
            Self.scrambleTrackId
        )
        AudioEngine_ScheduleNoteOffTargetTagged(
            handle,
            Int32(note),
            sampleTime + gateSamples,
            mask,
            Self.scrambleTrackId
        )
    }

    /// Routes an X note output to a ScrambleNoteTarget.
    private func routeNote(_ note: UInt8, target: ScrambleNoteTarget, handle: OpaquePointer, sampleTime: UInt64, gateSamples: UInt64) {
        guard let mask = target.noteTargetMask else { return }

        AudioEngine_ScheduleNoteOnTargetTagged(
            handle,
            Int32(note),
            Int32(100),
            sampleTime,
            mask.rawValue,
            Self.scrambleTrackId
        )
        AudioEngine_ScheduleNoteOffTargetTagged(
            handle,
            Int32(note),
            sampleTime + gateSamples,
            mask.rawValue,
            Self.scrambleTrackId
        )
    }

    /// Maps a trigger-type ModulationDestination to a NoteTargetMask raw value.
    private func triggerDestinationToMask(_ dest: ModulationDestination) -> UInt8? {
        switch dest {
        case .plaitsGate: return AudioEngineWrapper.NoteTargetMask.plaits.rawValue
        case .ringsGate, .ringsInput: return AudioEngineWrapper.NoteTargetMask.rings.rawValue
        case .daisyDrumGate: return AudioEngineWrapper.NoteTargetMask.daisyDrum.rawValue
        case .drumLane0Gate: return AudioEngineWrapper.NoteTargetMask.drumLane0.rawValue
        case .drumLane1Gate: return AudioEngineWrapper.NoteTargetMask.drumLane1.rawValue
        case .drumLane2Gate: return AudioEngineWrapper.NoteTargetMask.drumLane2.rawValue
        case .drumLane3Gate: return AudioEngineWrapper.NoteTargetMask.drumLane3.rawValue
        case .samplerGate: return AudioEngineWrapper.NoteTargetMask.sampler.rawValue
        default: return nil
        }
    }

    // MARK: - Project Save/Load

    struct SavedState: Codable {
        var enabled: Bool
        var engine: ScrambleEngine
        var division: String                // SequencerClockDivision rawValue
        var t1Destination: String           // ModulationDestination rawValue
        var t2Destination: String           // ModulationDestination rawValue
        var t3Destination: String           // ModulationDestination rawValue
        var x1Destination: String           // ScrambleNoteTarget rawValue
        var x2Destination: String           // ScrambleNoteTarget rawValue
        var x3Destination: String           // ScrambleNoteTarget rawValue
        var yDestination: String            // ModulationDestination rawValue
        var yAmount: Double
    }

    func savedState() -> SavedState {
        SavedState(
            enabled: enabled,
            engine: engine,
            division: division.rawValue,
            t1Destination: t1Destination.rawValue,
            t2Destination: t2Destination.rawValue,
            t3Destination: t3Destination.rawValue,
            x1Destination: x1Destination.rawValue,
            x2Destination: x2Destination.rawValue,
            x3Destination: x3Destination.rawValue,
            yDestination: yDestination.rawValue,
            yAmount: yAmount
        )
    }

    func restore(from state: SavedState) {
        enabled = state.enabled
        engine = state.engine
        division = SequencerClockDivision(rawValue: state.division) ?? .x1
        t1Destination = ModulationDestination(rawValue: state.t1Destination) ?? .plaitsGate
        t2Destination = ModulationDestination(rawValue: state.t2Destination) ?? .ringsGate
        t3Destination = ModulationDestination(rawValue: state.t3Destination) ?? .daisyDrumGate
        x1Destination = ScrambleNoteTarget(rawValue: state.x1Destination) ?? .plaits
        x2Destination = ScrambleNoteTarget(rawValue: state.x2Destination) ?? .rings
        x3Destination = ScrambleNoteTarget(rawValue: state.x3Destination) ?? .none
        yDestination = ModulationDestination(rawValue: state.yDestination) ?? .plaitsTimbre
        yAmount = state.yAmount
    }
}

// MARK: - UInt8 Clamped Init

private extension UInt8 {
    init(clamped value: Int) {
        self = UInt8(Swift.max(0, Swift.min(127, value)))
    }
}

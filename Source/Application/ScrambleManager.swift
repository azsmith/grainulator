//
//  ScrambleManager.swift
//  Grainulator
//
//  Manages the Scramble probabilistic sequencer: owns a ScrambleEngine,
//  handles clock polling, and routes Gate/Note/Mod outputs to the audio engine.
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

    // Gate routing
    @Published var gate1Destination: ModulationDestination = .plaitsGate
    @Published var gate2Destination: ModulationDestination = .none
    @Published var gate3Destination: ModulationDestination = .ringsGate

    // Note routing
    @Published var note1Destination: ScrambleNoteTarget = .plaits
    @Published var note2Destination: ScrambleNoteTarget = .none
    @Published var note3Destination: ScrambleNoteTarget = .rings

    // Mod routing
    @Published var modDestination: ModulationDestination = .plaitsTimbre
    @Published var modAmount: Double = 0.5

    // Visualization
    @Published var lastGateOutput: ScrambleEngine.GateOutput = ScrambleEngine.GateOutput()
    @Published var lastNoteOutput: ScrambleEngine.NoteOutput = ScrambleEngine.NoteOutput()
    @Published var lastModOutput: ScrambleEngine.ModOutput = ScrambleEngine.ModOutput()
    @Published var gateHistory: [ScrambleEngine.GateOutput] = []
    @Published var noteHistory: [UInt8] = []
    @Published var modHistory: [Double] = []

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
        let gate1Destination: ModulationDestination
        let gate2Destination: ModulationDestination
        let gate3Destination: ModulationDestination
        let note1Destination: ScrambleNoteTarget
        let note2Destination: ScrambleNoteTarget
        let note3Destination: ScrambleNoteTarget
        let modDestination: ModulationDestination
        let modAmount: Double

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

    // MARK: - Scope Ring Buffers (Task 10)

    /// Ring buffer size for scope visualization (~682ms @ 48kHz, matches C++ kScopeBufferSize)
    private static let scopeBufferSize = 32768
    /// 4 scope sources: 0=Gate Pattern, 1=Note 1, 2=Note 2, 3=Mod
    /// Protected by scopeLock for cross-thread access (clockQueue writes, main thread reads).
    private nonisolated(unsafe) var scopeBuffers: [[Float]] = Array(repeating: Array(repeating: 0, count: 32768), count: 4)
    private nonisolated(unsafe) var scopeWriteIndex: Int = 0
    private let scopeLock = NSLock()

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
        gateHistory.removeAll()
        noteHistory.removeAll()
        modHistory.removeAll()
        lastGateOutput = ScrambleEngine.GateOutput()
        lastNoteOutput = ScrambleEngine.NoteOutput()
        lastModOutput = ScrambleEngine.ModOutput()
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
            gate1Destination: gate1Destination,
            gate2Destination: gate2Destination,
            gate3Destination: gate3Destination,
            note1Destination: note1Destination,
            note2Destination: note2Destination,
            note3Destination: note3Destination,
            modDestination: modDestination,
            modAmount: modAmount,
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

        schedulingLock.lock()
        var state = schedulingState
        schedulingLock.unlock()

        // Work with a mutable copy of the engine for generating outputs
        var eng = snapshot.engine

        // Task 2: Gate length from engine (duty cycle 0.0–1.0)
        let gateLength = eng.gateSection.gateLength
        let gateSamples = max(1, UInt64(gateLength * Double(samplesPerTick)))

        // Task 4: Jitter amount
        let jitterAmount = eng.gateSection.jitter

        // Root MIDI note
        let rootMidi = UInt8(clamped: (snapshot.sequenceOctave + 5) * 12 + snapshot.rootNote)

        // Collect visualization data per step (dispatched once after the loop)
        var vizGate: [ScrambleEngine.GateOutput] = []
        var vizNote: [UInt8] = []
        var vizMod: [Double] = []
        var lastGate = ScrambleEngine.GateOutput()
        var lastNote = ScrambleEngine.NoteOutput()
        var lastMod = ScrambleEngine.ModOutput()

        while state.nextStepSample < horizonSample {
            // Generate gates
            let gateOut = eng.generateGates()

            // Generate notes (clocked by respective gates)
            let noteOut = eng.generateNotes(
                gates: gateOut,
                scaleIntervals: snapshot.scaleIntervals,
                rootMidi: rootMidi
            )

            // Generate mod
            let modOut = eng.generateMod()

            // Task 4: Apply jitter as random offset to scheduling time
            var noteOnSample = state.nextStepSample
            if jitterAmount > 0.001 {
                let maxJitter = Double(samplesPerTick) * jitterAmount * 0.5
                let offset = Int64(Double.random(in: -maxJitter...maxJitter))
                noteOnSample = UInt64(max(0, Int64(state.nextStepSample) + offset))
            }

            // Route gate outputs (gate triggers)
            routeTrigger(gateOut.gate1, destination: snapshot.gate1Destination, note: noteOut.note1, handle: handle, sampleTime: noteOnSample, gateSamples: gateSamples)
            routeTrigger(gateOut.gate2, destination: snapshot.gate2Destination, note: noteOut.note2, handle: handle, sampleTime: noteOnSample, gateSamples: gateSamples)
            routeTrigger(gateOut.gate3, destination: snapshot.gate3Destination, note: noteOut.note3, handle: handle, sampleTime: noteOnSample, gateSamples: gateSamples)

            // Route note outputs (only when the corresponding gate fires)
            if gateOut.gate1 { routeNote(noteOut.note1, target: snapshot.note1Destination, handle: handle, sampleTime: noteOnSample, gateSamples: gateSamples) }
            if gateOut.gate2 { routeNote(noteOut.note2, target: snapshot.note2Destination, handle: handle, sampleTime: noteOnSample, gateSamples: gateSamples) }
            if gateOut.gate3 { routeNote(noteOut.note3, target: snapshot.note3Destination, handle: handle, sampleTime: noteOnSample, gateSamples: gateSamples) }

            // Collect for visualization
            vizGate.append(gateOut)
            vizNote.append(noteOut.note1)
            vizMod.append(modOut.value)
            lastGate = gateOut
            lastNote = noteOut
            lastMod = modOut

            // Task 10: Write scope data for this step
            writeScopeStep(gate: gateOut, note: noteOut, mod: modOut, samplesPerStep: Int(samplesPerTick))

            state.nextStepSample += samplesPerTick
        }

        // Update visualization and sync ONLY runtime state back (single dispatch).
        // We must NOT overwrite section parameters (gateSection, noteSection, modSection)
        // because those are controlled by the UI — overwriting them causes slider snapping.
        if !vizGate.isEmpty {
            let runtimeSource = eng
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.lastGateOutput = lastGate
                    self.lastNoteOutput = lastNote
                    self.lastModOutput = lastMod

                    self.gateHistory.append(contentsOf: vizGate)
                    if self.gateHistory.count > Self.historyLength {
                        self.gateHistory.removeFirst(self.gateHistory.count - Self.historyLength)
                    }

                    self.noteHistory.append(contentsOf: vizNote)
                    if self.noteHistory.count > Self.historyLength {
                        self.noteHistory.removeFirst(self.noteHistory.count - Self.historyLength)
                    }

                    self.modHistory.append(contentsOf: vizMod)
                    if self.modHistory.count > Self.historyLength {
                        self.modHistory.removeFirst(self.modHistory.count - Self.historyLength)
                    }

                    // Sync only runtime state (sequences, counters, held notes)
                    // NOT section parameters which are UI-controlled
                    self.engine.syncRuntimeState(from: runtimeSource)
                }
            }
        }

        schedulingLock.lock()
        schedulingState = state
        schedulingLock.unlock()
    }

    // MARK: - Routing Helpers

    /// Routes a gate trigger to the audio engine if the gate is active and destination is a trigger type.
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

    /// Routes a note output to a ScrambleNoteTarget.
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
        var gate1Destination: String        // ModulationDestination rawValue
        var gate2Destination: String        // ModulationDestination rawValue
        var gate3Destination: String        // ModulationDestination rawValue
        var note1Destination: String        // ScrambleNoteTarget rawValue
        var note2Destination: String        // ScrambleNoteTarget rawValue
        var note3Destination: String        // ScrambleNoteTarget rawValue
        var modDestination: String          // ModulationDestination rawValue
        var modAmount: Double

        // Backward-compatible decoding from old t1/t2/t3/x1/x2/x3/y names
        enum CodingKeys: String, CodingKey {
            case enabled, engine, division
            case gate1Destination, gate2Destination, gate3Destination
            case note1Destination, note2Destination, note3Destination
            case modDestination, modAmount
            // Legacy keys
            case t1Destination, t2Destination, t3Destination
            case x1Destination, x2Destination, x3Destination
            case yDestination, yAmount
        }

        init(enabled: Bool, engine: ScrambleEngine, division: String,
             gate1Destination: String, gate2Destination: String, gate3Destination: String,
             note1Destination: String, note2Destination: String, note3Destination: String,
             modDestination: String, modAmount: Double) {
            self.enabled = enabled
            self.engine = engine
            self.division = division
            self.gate1Destination = gate1Destination
            self.gate2Destination = gate2Destination
            self.gate3Destination = gate3Destination
            self.note1Destination = note1Destination
            self.note2Destination = note2Destination
            self.note3Destination = note3Destination
            self.modDestination = modDestination
            self.modAmount = modAmount
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try container.decode(Bool.self, forKey: .enabled)
            engine = try container.decode(ScrambleEngine.self, forKey: .engine)
            division = try container.decode(String.self, forKey: .division)

            // Try new names, fall back to legacy
            gate1Destination = (try? container.decode(String.self, forKey: .gate1Destination))
                ?? (try? container.decode(String.self, forKey: .t1Destination))
                ?? ModulationDestination.plaitsGate.rawValue
            gate2Destination = (try? container.decode(String.self, forKey: .gate2Destination))
                ?? (try? container.decode(String.self, forKey: .t2Destination))
                ?? ModulationDestination.none.rawValue
            gate3Destination = (try? container.decode(String.self, forKey: .gate3Destination))
                ?? (try? container.decode(String.self, forKey: .t3Destination))
                ?? ModulationDestination.ringsGate.rawValue
            note1Destination = (try? container.decode(String.self, forKey: .note1Destination))
                ?? (try? container.decode(String.self, forKey: .x1Destination))
                ?? ScrambleNoteTarget.plaits.rawValue
            note2Destination = (try? container.decode(String.self, forKey: .note2Destination))
                ?? (try? container.decode(String.self, forKey: .x2Destination))
                ?? ScrambleNoteTarget.none.rawValue
            note3Destination = (try? container.decode(String.self, forKey: .note3Destination))
                ?? (try? container.decode(String.self, forKey: .x3Destination))
                ?? ScrambleNoteTarget.rings.rawValue
            modDestination = (try? container.decode(String.self, forKey: .modDestination))
                ?? (try? container.decode(String.self, forKey: .yDestination))
                ?? ModulationDestination.plaitsTimbre.rawValue
            modAmount = (try? container.decode(Double.self, forKey: .modAmount))
                ?? (try? container.decode(Double.self, forKey: .yAmount))
                ?? 0.5
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(enabled, forKey: .enabled)
            try container.encode(engine, forKey: .engine)
            try container.encode(division, forKey: .division)
            try container.encode(gate1Destination, forKey: .gate1Destination)
            try container.encode(gate2Destination, forKey: .gate2Destination)
            try container.encode(gate3Destination, forKey: .gate3Destination)
            try container.encode(note1Destination, forKey: .note1Destination)
            try container.encode(note2Destination, forKey: .note2Destination)
            try container.encode(note3Destination, forKey: .note3Destination)
            try container.encode(modDestination, forKey: .modDestination)
            try container.encode(modAmount, forKey: .modAmount)
        }
    }

    func savedState() -> SavedState {
        SavedState(
            enabled: enabled,
            engine: engine,
            division: division.rawValue,
            gate1Destination: gate1Destination.rawValue,
            gate2Destination: gate2Destination.rawValue,
            gate3Destination: gate3Destination.rawValue,
            note1Destination: note1Destination.rawValue,
            note2Destination: note2Destination.rawValue,
            note3Destination: note3Destination.rawValue,
            modDestination: modDestination.rawValue,
            modAmount: modAmount
        )
    }

    func restore(from state: SavedState) {
        enabled = state.enabled
        engine = state.engine
        division = SequencerClockDivision(rawValue: state.division) ?? .x1
        gate1Destination = ModulationDestination(rawValue: state.gate1Destination) ?? .plaitsGate
        gate2Destination = ModulationDestination(rawValue: state.gate2Destination) ?? .none
        gate3Destination = ModulationDestination(rawValue: state.gate3Destination) ?? .ringsGate
        note1Destination = ScrambleNoteTarget(rawValue: state.note1Destination) ?? .plaits
        note2Destination = ScrambleNoteTarget(rawValue: state.note2Destination) ?? .none
        note3Destination = ScrambleNoteTarget(rawValue: state.note3Destination) ?? .rings
        modDestination = ModulationDestination(rawValue: state.modDestination) ?? .plaitsTimbre
        modAmount = state.modAmount
    }

    // MARK: - Scope Ring Buffer (Task 10)

    /// Write scope data for a single step (called from clockQueue during pollClock).
    /// Fills `samplesPerStep` samples in the ring buffer to match audio-rate scope display.
    private func writeScopeStep(gate: ScrambleEngine.GateOutput, note: ScrambleEngine.NoteOutput, mod: ScrambleEngine.ModOutput, samplesPerStep: Int) {
        let gateValue: Float = gate.gate1 ? 1.0 : 0.0
        let note1Value: Float = Float(note.note1) / 127.0
        let note2Value: Float = Float(note.note2) / 127.0
        let modValue: Float = Float(mod.value)

        scopeLock.lock()
        let bufSize = Self.scopeBufferSize
        for _ in 0..<samplesPerStep {
            scopeBuffers[0][scopeWriteIndex] = gateValue
            scopeBuffers[1][scopeWriteIndex] = note1Value
            scopeBuffers[2][scopeWriteIndex] = note2Value
            scopeBuffers[3][scopeWriteIndex] = modValue
            scopeWriteIndex = (scopeWriteIndex + 1) % bufSize
        }
        scopeLock.unlock()
    }

    /// Read scope buffer for OscilloscopeView (called from main thread at 30Hz).
    /// scrambleIndex: 0=Gate Pattern, 1=Note 1, 2=Note 2, 3=Mod
    nonisolated func readScopeBuffer(scrambleIndex: Int, numFrames: Int) -> [Float] {
        guard scrambleIndex >= 0, scrambleIndex < 4 else {
            return [Float](repeating: 0, count: numFrames)
        }

        scopeLock.lock()
        let bufSize = 32768  // Must match scopeBufferSize
        let wi = scopeWriteIndex
        let frames = min(numFrames, bufSize)
        var output = [Float](repeating: 0, count: frames)
        for i in 0..<frames {
            let idx = (wi + bufSize - frames + i) % bufSize
            output[i] = scopeBuffers[scrambleIndex][idx]
        }
        scopeLock.unlock()
        return output
    }
}

// MARK: - UInt8 Clamped Init

private extension UInt8 {
    init(clamped value: Int) {
        self = UInt8(Swift.max(0, Swift.min(127, value)))
    }
}

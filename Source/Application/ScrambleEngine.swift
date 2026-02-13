// ScrambleEngine.swift — Probabilistic sequencer inspired by Marbles
//
// Generates gate patterns, quantized notes, and modulation CV values
// using various probabilistic algorithms with Deja Vu looping support.

import Foundation

struct ScrambleEngine: Codable {

    // MARK: - Enums

    enum GateMode: String, CaseIterable, Identifiable, Codable {
        case coinToss
        case ratio
        case alternating
        case drums
        case markov
        case clusters
        case divider

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .coinToss: return "Coin Toss"
            case .ratio: return "Ratio"
            case .alternating: return "Alternating"
            case .drums: return "Drums"
            case .markov: return "Markov"
            case .clusters: return "Clusters"
            case .divider: return "Divider"
            }
        }

        // Backward-compatible decoding from old T/X/Y names
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            switch raw {
            case "complementaryBernoulli": self = .coinToss
            case "independentBernoulli": self = .ratio
            case "threeStates": self = .alternating
            default:
                guard let mode = GateMode(rawValue: raw) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown GateMode: \(raw)")
                }
                self = mode
            }
        }
    }

    enum NoteControlMode: String, CaseIterable, Identifiable, Codable {
        case identical
        case bump
        case tilt

        var id: String { rawValue }
    }

    enum NoteRange: String, CaseIterable, Identifiable, Codable {
        case oneOctave
        case twoOctaves
        case fourOctaves

        var id: String { rawValue }

        var semitones: Int {
            switch self {
            case .oneOctave: return 12
            case .twoOctaves: return 24
            case .fourOctaves: return 48
            }
        }
    }

    enum DejaVuState: String, CaseIterable, Identifiable, Codable {
        case off
        case on
        case locked

        var id: String { rawValue }
    }

    // NoteClockSource removed — notes are now clocked by their respective gate outputs

    // MARK: - RandomSequence

    struct RandomSequence: Codable {
        private var buffer: [Double] = Array(repeating: 0.0, count: 16)
        private var writeIndex: Int = 0
        private var length: Int = 0
        private var isLocked: Bool = false
        private var playIndex: Int = 0

        mutating func record(_ value: Double, loopLength: Int = 16) {
            let maxLen = max(1, min(loopLength, 16))
            buffer[writeIndex] = value
            writeIndex = (writeIndex + 1) % maxLen
            if length < maxLen {
                length += 1
            }
        }

        func replay(at index: Int, loopLength: Int = 16) -> Double {
            let maxLen = max(1, min(loopLength, 16))
            let wrappedIndex = index % maxLen
            return buffer[wrappedIndex]
        }

        mutating func lock() {
            isLocked = true
            playIndex = 0
        }

        mutating func unlock() {
            isLocked = false
        }

        mutating func reset() {
            buffer = Array(repeating: 0.0, count: 16)
            writeIndex = 0
            length = 0
            isLocked = false
            playIndex = 0
        }

        mutating func next(dejaVu: DejaVuState, amount: Double, loopLength: Int = 16, generate: () -> Double) -> Double {
            let maxLen = max(1, min(loopLength, 16))

            switch dejaVu {
            case .off:
                let value = generate()
                record(value, loopLength: maxLen)
                return value

            case .on:
                let effectiveLength = min(length, maxLen)
                let useRecorded = Double.random(in: 0...1) < amount
                if useRecorded && effectiveLength > 0 {
                    let index = playIndex % max(effectiveLength, 1)
                    playIndex = (playIndex + 1) % max(effectiveLength, 1)
                    return replay(at: index, loopLength: maxLen)
                } else {
                    let value = generate()
                    record(value, loopLength: maxLen)
                    return value
                }

            case .locked:
                let effectiveLength = min(length, maxLen)
                if effectiveLength == 0 {
                    let value = generate()
                    record(value, loopLength: maxLen)
                    return value
                }
                let index = playIndex % max(effectiveLength, 1)
                playIndex = (playIndex + 1) % max(effectiveLength, 1)
                return replay(at: index, loopLength: maxLen)
            }
        }
    }

    // MARK: - Section Structs

    struct GateSection: Codable {
        var mode: GateMode = .coinToss
        var bias: Double = 0.5
        var jitter: Double = 0.0
        var gateLength: Double = 0.5       // Task 2: duty cycle 0.0–1.0
        var dejaVu: DejaVuState = .off
        var dejaVuAmount: Double = 0.5
        var dejaVuLoopLength: Int = 16     // Task 5: Deja Vu loop length 1–16
        var dividerRatio: Int = 1
    }

    struct NoteSection: Codable {
        var spread: Double = 0.5
        var bias: Double = 0.5
        var steps: Double = 0.0      // 0=bypass, <0.45=smooth, >0.55=quantize
        var controlMode: NoteControlMode = .tilt
        var range: NoteRange = .twoOctaves
        var dejaVu: DejaVuState = .off
        var dejaVuAmount: Double = 0.5
        var dejaVuLoopLength: Int = 16     // Task 5: Deja Vu loop length 1–16
        var dividerRatio: Int = 1
    }

    struct ModSection: Codable {
        var spread: Double = 0.5
        var bias: Double = 0.5
        var steps: Double = 0.0
        var dividerRatio: Int = 1
    }

    // MARK: - Output Structs

    struct GateOutput {
        var gate1: Bool = false
        var gate2: Bool = false
        var gate3: Bool = false
    }

    struct NoteOutput {
        var note1: UInt8 = 60
        var note2: UInt8 = 60
        var note3: UInt8 = 60
    }

    struct ModOutput {
        var value: Double = 0.5
        var triggered: Bool = false
    }

    // MARK: - State

    var gateSection: GateSection = GateSection()
    var noteSection: NoteSection = NoteSection()
    var modSection: ModSection = ModSection()

    var gateSequence: RandomSequence = RandomSequence()
    var noteSequence: RandomSequence = RandomSequence()
    var modSequence: RandomSequence = RandomSequence()

    private var gateStepCount: Int = 0
    private var gateDividerCount: Int = 0
    private var noteDividerCount: Int = 0
    private var modDividerCount: Int = 0
    private var markovState: Int = 0
    private var burstPhase: Int = 0
    private var inBurst: Bool = false

    // Only persist section parameters and sequences; runtime counters are excluded.
    enum CodingKeys: String, CodingKey {
        // New names
        case gateSection, noteSection, modSection
        case gateSequence, noteSequence, modSequence
    }

    // Backward-compatible decoding: try new names first, fall back to old T/X/Y names
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try new names, fall back to old names via dynamic key lookup
        if let gs = try? container.decode(GateSection.self, forKey: .gateSection) {
            gateSection = gs
        } else if let gs = try? ScrambleEngine.decodeLegacy(GateSection.self, from: decoder, key: "tSection") {
            gateSection = gs
        }

        if let ns = try? container.decode(NoteSection.self, forKey: .noteSection) {
            noteSection = ns
        } else if let ns = try? ScrambleEngine.decodeLegacy(NoteSection.self, from: decoder, key: "xSection") {
            noteSection = ns
        }

        if let ms = try? container.decode(ModSection.self, forKey: .modSection) {
            modSection = ms
        } else if let ms = try? ScrambleEngine.decodeLegacy(ModSection.self, from: decoder, key: "ySection") {
            modSection = ms
        }

        if let seq = try? container.decode(RandomSequence.self, forKey: .gateSequence) {
            gateSequence = seq
        } else if let seq = try? ScrambleEngine.decodeLegacy(RandomSequence.self, from: decoder, key: "tSequence") {
            gateSequence = seq
        }

        if let seq = try? container.decode(RandomSequence.self, forKey: .noteSequence) {
            noteSequence = seq
        } else if let seq = try? ScrambleEngine.decodeLegacy(RandomSequence.self, from: decoder, key: "xSequence") {
            noteSequence = seq
        }

        if let seq = try? container.decode(RandomSequence.self, forKey: .modSequence) {
            modSequence = seq
        } else if let seq = try? ScrambleEngine.decodeLegacy(RandomSequence.self, from: decoder, key: "ySequence") {
            modSequence = seq
        }
    }

    init() {}

    /// Dynamic coding key for backward-compatible decoding.
    private struct LegacyCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    /// Helper to decode a value using an arbitrary string key (for backward compat with old T/X/Y names).
    private static func decodeLegacy<T: Decodable>(_ type: T.Type, from decoder: Decoder, key: String) -> T? {
        guard let container = try? decoder.container(keyedBy: LegacyCodingKey.self) else { return nil }
        return try? container.decode(T.self, forKey: LegacyCodingKey(stringValue: key))
    }

    // MARK: - Runtime State (not persisted)

    /// Task 6: Held notes — returned when divider skips a step
    private var heldNotes: NoteOutput = NoteOutput()
    /// Task 9: Previous values for STEPS smoothing
    private var prevNoteValue: Double = 0.5
    private var prevModValue: Double = 0.5

    // Internal counters (not persisted, but mutated by generateGates/Notes/Mod)
    // Already declared above: gateStepCount, gateDividerCount, noteDividerCount, modDividerCount,
    //                         markovState, burstPhase, inBurst

    // Exclude runtime state from Codable
    // (already excluded via CodingKeys — these are private and not in CodingKeys)

    /// Copies only runtime state (sequences, counters, held notes) from another engine instance.
    /// Used by ScrambleManager to sync clock-queue mutations back without overwriting
    /// UI-controlled section parameters (which would cause slider snapping).
    mutating func syncRuntimeState(from other: ScrambleEngine) {
        gateSequence = other.gateSequence
        noteSequence = other.noteSequence
        modSequence = other.modSequence
        gateStepCount = other.gateStepCount
        gateDividerCount = other.gateDividerCount
        noteDividerCount = other.noteDividerCount
        modDividerCount = other.modDividerCount
        markovState = other.markovState
        burstPhase = other.burstPhase
        inBurst = other.inBurst
        heldNotes = other.heldNotes
        prevNoteValue = other.prevNoteValue
        prevModValue = other.prevModValue
    }

    // MARK: - Helpers

    private static func fract(_ x: Double) -> Double {
        return x - x.rounded(.down)
    }

    // MARK: - Task 7: SPREAD Distribution Shaping

    /// Shapes a uniform random value according to spread parameter.
    /// spread=0: tight bell curve around center; spread=0.5: uniform; spread=1.0: bimodal (extremes)
    static func shapedBySpread(_ raw: Double, spread: Double) -> Double {
        if spread < 0.5 {
            // Tighten distribution toward center using averaged random values
            let narrowing = 1.0 - spread * 2.0  // 1.0 at spread=0, 0.0 at spread=0.5
            // Triangle distribution approximation: average with 0.5
            let shaped = raw * (1.0 - narrowing) + 0.5 * narrowing
            return shaped
        } else if spread > 0.5 {
            // Bimodal: push toward extremes
            let bimodal = (spread - 0.5) * 2.0  // 0.0 at spread=0.5, 1.0 at spread=1.0
            let pushed: Double
            if raw < 0.5 {
                pushed = raw * (1.0 - bimodal)
            } else {
                pushed = 1.0 - (1.0 - raw) * (1.0 - bimodal)
            }
            return pushed
        } else {
            return raw  // spread=0.5: uniform passthrough
        }
    }

    // MARK: - Task 8: BIAS as Probability Skew

    /// Power-curve skew: bias < 0.5 favors low values, bias > 0.5 favors high values.
    static func skewedByBias(_ value: Double, bias: Double) -> Double {
        let clamped = value.clamped(to: 0.0...1.0)
        guard clamped > 0.0 && clamped < 1.0 else { return clamped }
        let exponent = pow(2.0, (bias - 0.5) * -4.0)
        return pow(clamped, exponent)
    }

    // MARK: - Task 9: STEPS Dual Behavior (Smooth ← → Quantize)

    /// steps = 0.0: bypass (no processing)
    /// steps > 0.0 and < 0.45: smoothing (slew between consecutive values)
    /// steps 0.45–0.55: dead zone / light smoothing
    /// steps > 0.55: quantization (snap to 2–16 discrete levels)
    static func applySteps(_ value: Double, steps: Double, prev: Double) -> Double {
        if steps < 0.01 {
            return value  // Bypass at zero — no smoothing or quantization
        } else if steps < 0.45 {
            // Smoothing: interpolate between previous and new value
            // At steps=0.01 → very light smoothing, steps=0.44 → heavy smoothing
            let smoothAmount = steps / 0.45  // 0.0 at steps=0, 1.0 at steps=0.45
            return prev * smoothAmount + value * (1.0 - smoothAmount)
        } else if steps > 0.55 {
            // Quantization: snap to discrete levels
            let t = (steps - 0.55) / 0.45  // 0.0 at steps=0.55, 1.0 at steps=1.0
            let levelCount = max(2.0, (t * 14.0 + 2.0).rounded())  // 2–16 levels
            return (value * levelCount).rounded(.down) / levelCount
        } else {
            return value  // Dead zone around 0.5: bypass
        }
    }

    // MARK: - Gate Generator

    mutating func generateGates() -> GateOutput {
        gateDividerCount += 1
        guard gateDividerCount % gateSection.dividerRatio == 0 else {
            return GateOutput()
        }

        let r = gateSequence.next(
            dejaVu: gateSection.dejaVu,
            amount: gateSection.dejaVuAmount,
            loopLength: gateSection.dejaVuLoopLength
        ) { Double.random(in: 0.0...1.0) }

        gateStepCount += 1
        let bias = gateSection.bias

        switch gateSection.mode {
        case .coinToss:
            return generateCoinToss(r: r, bias: bias)
        case .ratio:
            return generateRatio(r: r, bias: bias)
        case .alternating:
            return generateAlternating(r: r, bias: bias)
        case .drums:
            return generateDrums(bias: bias)
        case .markov:
            return generateMarkov(r: r, bias: bias)
        case .clusters:
            return generateClusters(r: r, bias: bias)
        case .divider:
            return generateDivider(bias: bias)
        }
    }

    // Task 3: In all modes, gate2 = master clock (always true).
    // gate1 fires probabilistically, gate3 = complement of gate1.

    private func generateCoinToss(r: Double, bias: Double) -> GateOutput {
        // gate1 fires with probability = bias, gate3 = !gate1, gate2 = master clock
        let gate1 = r < bias
        let gate3 = !gate1
        return GateOutput(gate1: gate1, gate2: true, gate3: gate3)
    }

    private func generateRatio(r: Double, bias: Double) -> GateOutput {
        // gate1 fires every N steps (bias selects N from 1–8), gate3 = complementary
        let n = max(1, Int(bias * 8.0) + 1)
        let gate1 = (gateStepCount % n) == 0
        let gate3 = !gate1
        return GateOutput(gate1: gate1, gate2: true, gate3: gate3)
    }

    private func generateAlternating(r: Double, bias: Double) -> GateOutput {
        // Cycle: gate1 only → both → gate3 only → both, with bias weighting
        let phase = gateStepCount % 4
        let gate1: Bool
        let gate3: Bool
        switch phase {
        case 0: gate1 = true;  gate3 = false  // gate1 only
        case 1: gate1 = true;  gate3 = true   // both
        case 2: gate1 = false; gate3 = true   // gate3 only
        case 3: gate1 = true;  gate3 = true   // both
        default: gate1 = false; gate3 = false
        }
        return GateOutput(gate1: gate1, gate2: true, gate3: gate3)
    }

    private func generateDrums(bias: Double) -> GateOutput {
        // 8 preset patterns; bias selects which one
        let patterns: [[Bool]] = [
            [true, false, false, false, true, false, false, false],  // four-on-floor
            [true, false, true, false, true, false, true, false],    // 8ths
            [true, false, false, true, false, false, true, false],   // tresillo
            [true, false, false, false, false, false, false, false], // sparse
            [true, false, true, false, false, true, false, true],    // funk
            [false, true, false, true, false, true, false, true],    // offbeat
            [true, false, false, true, false, true, false, false],   // syncopated
            [true, false, false, false, false, false, false, false], // halftime
        ]
        let patternIndex = min(Int(bias * 8.0), 7)
        let stepInPattern = (gateStepCount - 1) % 8
        let gate1 = patterns[patternIndex][stepInPattern]
        let gate3 = patterns[patternIndex][(stepInPattern + 4) % 8]
        return GateOutput(gate1: gate1, gate2: true, gate3: gate3)
    }

    private mutating func generateMarkov(r: Double, bias: Double) -> GateOutput {
        // 8-state machine, transition probability controlled by bias
        if r < bias {
            markovState = (markovState + 1) % 8
        }
        let gate1 = markovState == 0
        let gate3 = markovState >= 4
        return GateOutput(gate1: gate1, gate2: true, gate3: gate3)
    }

    private mutating func generateClusters(r: Double, bias: Double) -> GateOutput {
        if !inBurst && r < bias {
            inBurst = true
            burstPhase = 0
        }

        if inBurst {
            let gate1 = burstPhase == 0
            let gate3 = burstPhase == 1 || burstPhase == 2
            burstPhase += 1
            if burstPhase >= 3 {
                inBurst = false
            }
            return GateOutput(gate1: gate1, gate2: true, gate3: gate3)
        }

        return GateOutput(gate1: false, gate2: true, gate3: false)
    }

    private func generateDivider(bias: Double) -> GateOutput {
        // Gate 1 every N steps (bias-selected), Gate 3 every M steps, gate2 = master
        let shift = Int(bias * 4.0)
        let step = gateStepCount - 1
        let gate1 = (step + shift) % 2 == 0
        let gate3 = (step + shift) % 4 == 0
        return GateOutput(gate1: gate1, gate2: true, gate3: gate3)
    }

    // MARK: - Note Generator

    static func quantizeToScale(rawValue: Double, scaleIntervals: [Int], rootMidi: UInt8, range: Int) -> UInt8 {
        guard !scaleIntervals.isEmpty else { return rootMidi }

        let halfRange = Double(range) / 2.0
        let semitoneOffset = (rawValue - 0.5) * Double(range)
        let targetMidi = Double(rootMidi) + semitoneOffset

        // Build all valid scale degrees within MIDI range
        var candidates: [Int] = []
        let lowestOctave = (Int(targetMidi - halfRange) / 12) - 1
        let highestOctave = (Int(targetMidi + halfRange) / 12) + 1

        for octave in lowestOctave...highestOctave {
            for interval in scaleIntervals {
                let note = octave * 12 + interval
                if note >= 0 && note <= 127 {
                    candidates.append(note)
                }
            }
        }

        guard !candidates.isEmpty else { return rootMidi }

        // Find nearest scale degree
        var bestNote = candidates[0]
        var bestDistance = abs(Double(bestNote) - targetMidi)
        for note in candidates {
            let distance = abs(Double(note) - targetMidi)
            if distance < bestDistance {
                bestDistance = distance
                bestNote = note
            }
        }

        return UInt8(bestNote.clamped(to: 0...127))
    }

    /// Generate notes gated by their respective gate outputs.
    /// Each note only updates when its corresponding gate fires; otherwise it holds.
    /// Gate 2 (master clock) triggers the random sequence to advance.
    mutating func generateNotes(gates: GateOutput, scaleIntervals: [Int], rootMidi: UInt8) -> NoteOutput {
        noteDividerCount += 1
        guard noteDividerCount % noteSection.dividerRatio == 0 else {
            // Task 6: Return held notes instead of defaults when divider skips
            return heldNotes
        }

        // Only advance the random sequence when gate2 (master clock) fires
        if gates.gate2 {
            let rawValue = noteSequence.next(
                dejaVu: noteSection.dejaVu,
                amount: noteSection.dejaVuAmount,
                loopLength: noteSection.dejaVuLoopLength
            ) { Double.random(in: 0.0...1.0) }

            let spread = noteSection.spread
            let bias = noteSection.bias
            let steps = noteSection.steps

            // SPREAD → BIAS → STEPS pipeline
            let shaped = ScrambleEngine.shapedBySpread(rawValue, spread: spread)
            let biased = ScrambleEngine.skewedByBias(shaped, bias: bias)
            let stepped = ScrambleEngine.applySteps(biased, steps: steps, prev: prevNoteValue)
            prevNoteValue = stepped

            let range = noteSection.range.semitones

            let v1: Double
            let v2: Double
            let v3: Double

            switch noteSection.controlMode {
            case .identical:
                v1 = stepped; v2 = stepped; v3 = stepped
            case .bump:
                v2 = stepped; v1 = 1.0 - stepped; v3 = 1.0 - stepped
            case .tilt:
                v2 = stepped; v1 = stepped - 0.15; v3 = stepped + 0.15
            }

            // Only update each note when its respective gate fires
            if gates.gate1 {
                heldNotes.note1 = ScrambleEngine.quantizeToScale(
                    rawValue: v1.clamped(to: 0.0...1.0),
                    scaleIntervals: scaleIntervals, rootMidi: rootMidi, range: range)
            }
            // gate2 always true (master), so note2 always updates
            heldNotes.note2 = ScrambleEngine.quantizeToScale(
                rawValue: v2.clamped(to: 0.0...1.0),
                scaleIntervals: scaleIntervals, rootMidi: rootMidi, range: range)
            if gates.gate3 {
                heldNotes.note3 = ScrambleEngine.quantizeToScale(
                    rawValue: v3.clamped(to: 0.0...1.0),
                    scaleIntervals: scaleIntervals, rootMidi: rootMidi, range: range)
            }
        }

        return heldNotes
    }

    // MARK: - Mod Generator

    mutating func generateMod() -> ModOutput {
        modDividerCount += 1

        let triggered = modDividerCount % modSection.dividerRatio == 0
        guard triggered else {
            return ModOutput(value: 0.5, triggered: false)
        }

        let rawValue = modSequence.next(
            dejaVu: .off,
            amount: 0.0
        ) { Double.random(in: 0.0...1.0) }

        let spread = modSection.spread
        let bias = modSection.bias
        let steps = modSection.steps

        // Task 7: SPREAD distribution shaping
        let shaped = ScrambleEngine.shapedBySpread(rawValue, spread: spread)
        // Task 8: BIAS probability skew
        let biased = ScrambleEngine.skewedByBias(shaped, bias: bias)
        // Task 9: STEPS dual behavior
        let stepped = ScrambleEngine.applySteps(biased, steps: steps, prev: prevModValue)
        prevModValue = stepped

        let result = stepped.clamped(to: 0.0...1.0)

        return ModOutput(value: result, triggered: true)
    }
}

// MARK: - Comparable Extension

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

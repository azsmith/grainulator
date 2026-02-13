// ScrambleEngine.swift — Probabilistic sequencer inspired by Marbles
//
// Generates gate patterns (T), quantized notes (X), and CV values (Y)
// using various probabilistic algorithms with Deja Vu looping support.

struct ScrambleEngine: Codable {

    // MARK: - Enums

    enum TMode: String, CaseIterable, Identifiable, Codable {
        case complementaryBernoulli
        case independentBernoulli
        case threeStates
        case drums
        case markov
        case clusters
        case divider

        var id: String { rawValue }
    }

    enum XControlMode: String, CaseIterable, Identifiable, Codable {
        case identical
        case bump
        case tilt

        var id: String { rawValue }
    }

    enum XRange: String, CaseIterable, Identifiable, Codable {
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

    enum XClockSource: String, CaseIterable, Identifiable, Codable {
        case t1
        case t2
        case t3
        case combined

        var id: String { rawValue }
    }

    // MARK: - RandomSequence

    struct RandomSequence: Codable {
        private var buffer: [Double] = Array(repeating: 0.0, count: 16)
        private var writeIndex: Int = 0
        private var length: Int = 0
        private var isLocked: Bool = false
        private var playIndex: Int = 0

        mutating func record(_ value: Double) {
            buffer[writeIndex] = value
            writeIndex = (writeIndex + 1) % 16
            if length < 16 {
                length += 1
            }
        }

        func replay(at index: Int) -> Double {
            let wrappedIndex = index % 16
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

        mutating func next(dejaVu: DejaVuState, amount: Double, generate: () -> Double) -> Double {
            switch dejaVu {
            case .off:
                let value = generate()
                record(value)
                return value

            case .on:
                let useRecorded = Double.random(in: 0...1) < amount
                if useRecorded && length > 0 {
                    let index = playIndex % max(length, 1)
                    playIndex = (playIndex + 1) % max(length, 1)
                    return replay(at: index)
                } else {
                    let value = generate()
                    record(value)
                    return value
                }

            case .locked:
                if length == 0 {
                    let value = generate()
                    record(value)
                    return value
                }
                let index = playIndex % max(length, 1)
                playIndex = (playIndex + 1) % max(length, 1)
                return replay(at: index)
            }
        }
    }

    // MARK: - Section Structs

    struct TSection: Codable {
        var mode: TMode = .complementaryBernoulli
        var bias: Double = 0.5
        var jitter: Double = 0.0
        var dejaVu: DejaVuState = .off
        var dejaVuAmount: Double = 0.5
    }

    struct XSection: Codable {
        var spread: Double = 0.5
        var bias: Double = 0.5
        var steps: Double = 0.0
        var controlMode: XControlMode = .identical
        var range: XRange = .twoOctaves
        var clockSource: XClockSource = .t1
        var dejaVu: DejaVuState = .off
        var dejaVuAmount: Double = 0.5
    }

    struct YSection: Codable {
        var spread: Double = 0.5
        var bias: Double = 0.5
        var steps: Double = 0.0
        var dividerRatio: Int = 1
    }

    // MARK: - Output Structs

    struct TOutput {
        var t1: Bool = false
        var t2: Bool = false
        var t3: Bool = false
    }

    struct XOutput {
        var x1: UInt8 = 60
        var x2: UInt8 = 60
        var x3: UInt8 = 60
    }

    struct YOutput {
        var value: Double = 0.5
        var triggered: Bool = false
    }

    // MARK: - State

    var tSection: TSection = TSection()
    var xSection: XSection = XSection()
    var ySection: YSection = YSection()

    var tSequence: RandomSequence = RandomSequence()
    var xSequence: RandomSequence = RandomSequence()
    var ySequence: RandomSequence = RandomSequence()

    private var tStepCount: Int = 0
    private var yDividerCount: Int = 0
    private var markovState: Int = 0
    private var burstPhase: Int = 0
    private var inBurst: Bool = false

    // MARK: - Helpers

    private static func fract(_ x: Double) -> Double {
        return x - x.rounded(.down)
    }

    // MARK: - T Generator

    mutating func generateT() -> TOutput {
        let r = tSequence.next(
            dejaVu: tSection.dejaVu,
            amount: tSection.dejaVuAmount
        ) { Double.random(in: 0.0...1.0) }

        tStepCount += 1
        let bias = tSection.bias

        switch tSection.mode {
        case .complementaryBernoulli:
            return generateComplementaryBernoulli(r: r, bias: bias)
        case .independentBernoulli:
            return generateIndependentBernoulli(r: r, bias: bias)
        case .threeStates:
            return generateThreeStates(r: r, bias: bias)
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

    private func generateComplementaryBernoulli(r: Double, bias: Double) -> TOutput {
        let t1 = r >= bias
        let t2 = !t1
        let t3 = t1 || t2
        return TOutput(t1: t1, t2: t2, t3: t3)
    }

    private func generateIndependentBernoulli(r: Double, bias: Double) -> TOutput {
        let r1 = ScrambleEngine.fract(r)
        let r2 = ScrambleEngine.fract(r + 0.333)
        let r3 = ScrambleEngine.fract(r + 0.666)
        let t1 = r1 < bias
        let t2 = r2 < bias
        let t3 = r3 < bias
        return TOutput(t1: t1, t2: t2, t3: t3)
    }

    private func generateThreeStates(r: Double, bias: Double) -> TOutput {
        let pNone = 0.75 - abs(bias - 0.5)
        if r < pNone {
            return TOutput(t1: false, t2: false, t3: false)
        } else if r < pNone + (1.0 - pNone) * bias {
            return TOutput(t1: true, t2: false, t3: true)
        } else {
            return TOutput(t1: false, t2: true, t3: true)
        }
    }

    private func generateDrums(bias: Double) -> TOutput {
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
        let stepInPattern = (tStepCount - 1) % 8
        let t1 = patterns[patternIndex][stepInPattern]
        let t2 = patterns[patternIndex][(stepInPattern + 2) % 8]
        let t3 = patterns[patternIndex][(stepInPattern + 4) % 8]
        return TOutput(t1: t1, t2: t2, t3: t3)
    }

    private mutating func generateMarkov(r: Double, bias: Double) -> TOutput {
        // 8-state machine, transition probability controlled by bias
        if r < bias {
            markovState = (markovState + 1) % 8
        }
        let t1 = markovState == 0
        let t2 = markovState == 4
        let t3 = t1 || t2
        return TOutput(t1: t1, t2: t2, t3: t3)
    }

    private mutating func generateClusters(r: Double, bias: Double) -> TOutput {
        if !inBurst && r < bias {
            inBurst = true
            burstPhase = 0
        }

        if inBurst {
            let t1 = burstPhase == 0
            let t2 = burstPhase == 1 || burstPhase == 2
            let t3 = true
            burstPhase += 1
            if burstPhase >= 3 {
                inBurst = false
            }
            return TOutput(t1: t1, t2: t2, t3: t3)
        }

        return TOutput()
    }

    private func generateDivider(bias: Double) -> TOutput {
        // T1 every 2, T2 every 3, T3 every 4, shifted by bias
        let shift = Int(bias * 4.0)
        let step = tStepCount - 1
        let t1 = (step + shift) % 2 == 0
        let t2 = (step + shift) % 3 == 0
        let t3 = (step + shift) % 4 == 0
        return TOutput(t1: t1, t2: t2, t3: t3)
    }
}

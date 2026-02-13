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
}

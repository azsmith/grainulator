import XCTest
@testable import Grainulator

final class ScrambleEngineTests: XCTestCase {

    // MARK: - Task 1: Enums & Data Types

    func testTModeHasSevenCases() {
        XCTAssertEqual(ScrambleEngine.TMode.allCases.count, 7)
    }

    func testXControlModeHasThreeCases() {
        XCTAssertEqual(ScrambleEngine.XControlMode.allCases.count, 3)
    }

    func testXRangeSemitones() {
        XCTAssertEqual(ScrambleEngine.XRange.oneOctave.semitones, 12)
        XCTAssertEqual(ScrambleEngine.XRange.twoOctaves.semitones, 24)
        XCTAssertEqual(ScrambleEngine.XRange.fourOctaves.semitones, 48)
    }

    func testDejaVuStateHasThreeCases() {
        XCTAssertEqual(ScrambleEngine.DejaVuState.allCases.count, 3)
    }

    func testXClockSourceHasFourCases() {
        XCTAssertEqual(ScrambleEngine.XClockSource.allCases.count, 4)
    }

    func testRandomSequenceRecordAndReplay() {
        var seq = ScrambleEngine.RandomSequence()
        seq.record(0.1)
        seq.record(0.2)
        seq.record(0.3)

        XCTAssertEqual(seq.replay(at: 0), 0.1, accuracy: 1e-10)
        XCTAssertEqual(seq.replay(at: 1), 0.2, accuracy: 1e-10)
        XCTAssertEqual(seq.replay(at: 2), 0.3, accuracy: 1e-10)
    }

    func testRandomSequenceWrapsAt16() {
        var seq = ScrambleEngine.RandomSequence()
        for i in 0..<16 {
            seq.record(Double(i) / 16.0)
        }
        // Record one more — should wrap to position 0
        seq.record(0.99)
        XCTAssertEqual(seq.replay(at: 0), 0.99, accuracy: 1e-10)
        // Position 1 should still have its original value
        XCTAssertEqual(seq.replay(at: 1), 1.0 / 16.0, accuracy: 1e-10)
    }

    func testRandomSequenceLockedReplay() {
        var seq = ScrambleEngine.RandomSequence()
        seq.record(0.5)
        seq.record(0.7)
        seq.lock()

        // When locked, replay should cycle through recorded values
        let val0 = seq.replay(at: 0)
        let val1 = seq.replay(at: 1)
        XCTAssertEqual(val0, 0.5, accuracy: 1e-10)
        XCTAssertEqual(val1, 0.7, accuracy: 1e-10)
    }

    func testRandomSequenceReset() {
        var seq = ScrambleEngine.RandomSequence()
        seq.record(0.5)
        seq.record(0.7)
        seq.reset()

        // After reset, replay at 0 should return 0 (default buffer value)
        XCTAssertEqual(seq.replay(at: 0), 0.0, accuracy: 1e-10)
    }

    func testDefaultTSectionValues() {
        let t = ScrambleEngine.TSection()
        XCTAssertEqual(t.mode, .complementaryBernoulli)
        XCTAssertEqual(t.bias, 0.5, accuracy: 1e-10)
        XCTAssertEqual(t.jitter, 0.0, accuracy: 1e-10)
        XCTAssertEqual(t.dejaVu, .off)
        XCTAssertEqual(t.dejaVuAmount, 0.5, accuracy: 1e-10)
    }

    func testDefaultXSectionValues() {
        let x = ScrambleEngine.XSection()
        XCTAssertEqual(x.spread, 0.5, accuracy: 1e-10)
        XCTAssertEqual(x.bias, 0.5, accuracy: 1e-10)
        XCTAssertEqual(x.steps, 0.0, accuracy: 1e-10)
        XCTAssertEqual(x.controlMode, .identical)
        XCTAssertEqual(x.range, .twoOctaves)
        XCTAssertEqual(x.clockSource, .t1)
        XCTAssertEqual(x.dejaVu, .off)
        XCTAssertEqual(x.dejaVuAmount, 0.5, accuracy: 1e-10)
    }

    func testDefaultYSectionValues() {
        let y = ScrambleEngine.YSection()
        XCTAssertEqual(y.spread, 0.5, accuracy: 1e-10)
        XCTAssertEqual(y.bias, 0.5, accuracy: 1e-10)
        XCTAssertEqual(y.steps, 0.0, accuracy: 1e-10)
        XCTAssertEqual(y.dividerRatio, 1)
    }

    func testDefaultTOutputValues() {
        let out = ScrambleEngine.TOutput()
        XCTAssertFalse(out.t1)
        XCTAssertFalse(out.t2)
        XCTAssertFalse(out.t3)
    }

    func testDefaultXOutputValues() {
        let out = ScrambleEngine.XOutput()
        XCTAssertEqual(out.x1, 60)
        XCTAssertEqual(out.x2, 60)
        XCTAssertEqual(out.x3, 60)
    }

    func testDefaultYOutputValues() {
        let out = ScrambleEngine.YOutput()
        XCTAssertEqual(out.value, 0.5, accuracy: 1e-10)
        XCTAssertFalse(out.triggered)
    }

    // MARK: - Task 2: T Generator

    func testComplementaryBernoulliGatesNeverBothTrue() {
        var engine = ScrambleEngine()
        engine.tSection.mode = .complementaryBernoulli

        for _ in 0..<200 {
            let out = engine.generateT()
            // T1 and T2 are complementary — never both true simultaneously
            XCTAssertFalse(out.t1 && out.t2, "Complementary gates T1 and T2 must never both be true")
        }
    }

    func testComplementaryBernoulliT3IsOR() {
        var engine = ScrambleEngine()
        engine.tSection.mode = .complementaryBernoulli

        for _ in 0..<200 {
            let out = engine.generateT()
            // T3 should always be the OR of T1 and T2
            XCTAssertEqual(out.t3, out.t1 || out.t2, "T3 must be OR of T1 and T2")
        }
    }

    func testIndependentBernoulliZeroBiasProducesNoGates() {
        var engine = ScrambleEngine()
        engine.tSection.mode = .independentBernoulli
        engine.tSection.bias = 0.0

        var anyGate = false
        for _ in 0..<200 {
            let out = engine.generateT()
            if out.t1 || out.t2 || out.t3 {
                anyGate = true
            }
        }
        XCTAssertFalse(anyGate, "With bias=0, independent Bernoulli should produce no gates")
    }

    func testIndependentBernoulliFullBiasProducesAllGates() {
        var engine = ScrambleEngine()
        engine.tSection.mode = .independentBernoulli
        engine.tSection.bias = 1.0

        var allTrue = true
        for _ in 0..<200 {
            let out = engine.generateT()
            if !out.t1 || !out.t2 || !out.t3 {
                allTrue = false
            }
        }
        XCTAssertTrue(allTrue, "With bias=1, independent Bernoulli should produce all gates")
    }

    func testDividerProducesRegularPattern() {
        var engine = ScrambleEngine()
        engine.tSection.mode = .divider
        engine.tSection.bias = 0.5

        var results: [ScrambleEngine.TOutput] = []
        for _ in 0..<24 {
            results.append(engine.generateT())
        }

        // Divider should produce a regular pattern, not all-on or all-off
        let t1Count = results.filter { $0.t1 }.count
        let t2Count = results.filter { $0.t2 }.count

        // T1 fires every 2 steps, T2 every 3 steps
        XCTAssertGreaterThan(t1Count, 0, "Divider T1 should fire some steps")
        XCTAssertGreaterThan(t2Count, 0, "Divider T2 should fire some steps")
        XCTAssertLessThan(t1Count, 24, "Divider T1 should not fire every step")
        XCTAssertLessThan(t2Count, 24, "Divider T2 should not fire every step")
    }

    // MARK: - Task 3: X Generator

    func testGenerateXProducesValidMIDINotes() {
        var engine = ScrambleEngine()
        let cMajor = [0, 2, 4, 5, 7, 9, 11]

        for _ in 0..<200 {
            let out = engine.generateX(scaleIntervals: cMajor, rootMidi: 60)
            XCTAssertGreaterThanOrEqual(out.x1, 0, "MIDI note must be >= 0")
            XCTAssertLessThanOrEqual(out.x1, 127, "MIDI note must be <= 127")
            XCTAssertGreaterThanOrEqual(out.x2, 0)
            XCTAssertLessThanOrEqual(out.x2, 127)
            XCTAssertGreaterThanOrEqual(out.x3, 0)
            XCTAssertLessThanOrEqual(out.x3, 127)
        }
    }

    func testIdenticalModeProducesSameNotes() {
        var engine = ScrambleEngine()
        engine.xSection.controlMode = .identical
        let cMajor = [0, 2, 4, 5, 7, 9, 11]

        for _ in 0..<100 {
            let out = engine.generateX(scaleIntervals: cMajor, rootMidi: 60)
            XCTAssertEqual(out.x1, out.x2, "Identical mode: X1 must equal X2")
            XCTAssertEqual(out.x2, out.x3, "Identical mode: X2 must equal X3")
        }
    }

    func testSpreadZeroProducesConstant() {
        var engine = ScrambleEngine()
        engine.xSection.spread = 0.0
        engine.xSection.bias = 0.5
        engine.xSection.controlMode = .identical
        let cMajor = [0, 2, 4, 5, 7, 9, 11]

        var notes: Set<UInt8> = []
        for _ in 0..<100 {
            let out = engine.generateX(scaleIntervals: cMajor, rootMidi: 60)
            notes.insert(out.x1)
        }
        XCTAssertEqual(notes.count, 1, "With spread=0, all notes should be the same value")
    }

    func testQuantizerStaysInRange() {
        let cMajor = [0, 2, 4, 5, 7, 9, 11]

        // Test extremes of rawValue
        let low = ScrambleEngine.quantizeToScale(rawValue: 0.0, scaleIntervals: cMajor, rootMidi: 60, range: 24)
        let high = ScrambleEngine.quantizeToScale(rawValue: 1.0, scaleIntervals: cMajor, rootMidi: 60, range: 24)

        XCTAssertGreaterThanOrEqual(low, 0)
        XCTAssertLessThanOrEqual(low, 127)
        XCTAssertGreaterThanOrEqual(high, 0)
        XCTAssertLessThanOrEqual(high, 127)
    }
}

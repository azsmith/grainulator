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
}

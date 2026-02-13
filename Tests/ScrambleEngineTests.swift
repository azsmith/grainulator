import XCTest
@testable import Grainulator

final class ScrambleEngineTests: XCTestCase {

    // MARK: - Enums & Data Types

    func testGateModeHasSevenCases() {
        XCTAssertEqual(ScrambleEngine.GateMode.allCases.count, 7)
    }

    func testNoteControlModeHasThreeCases() {
        XCTAssertEqual(ScrambleEngine.NoteControlMode.allCases.count, 3)
    }

    func testNoteRangeSemitones() {
        XCTAssertEqual(ScrambleEngine.NoteRange.oneOctave.semitones, 12)
        XCTAssertEqual(ScrambleEngine.NoteRange.twoOctaves.semitones, 24)
        XCTAssertEqual(ScrambleEngine.NoteRange.fourOctaves.semitones, 48)
    }

    func testDejaVuStateHasThreeCases() {
        XCTAssertEqual(ScrambleEngine.DejaVuState.allCases.count, 3)
    }

    // NoteClockSource removed — notes clocked by respective gates

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

        XCTAssertEqual(seq.replay(at: 0), 0.0, accuracy: 1e-10)
    }

    func testDefaultGateSectionValues() {
        let g = ScrambleEngine.GateSection()
        XCTAssertEqual(g.mode, .coinToss)
        XCTAssertEqual(g.bias, 0.5, accuracy: 1e-10)
        XCTAssertEqual(g.jitter, 0.0, accuracy: 1e-10)
        XCTAssertEqual(g.gateLength, 0.5, accuracy: 1e-10)
        XCTAssertEqual(g.dejaVu, .off)
        XCTAssertEqual(g.dejaVuAmount, 0.5, accuracy: 1e-10)
        XCTAssertEqual(g.dejaVuLoopLength, 16)
    }

    func testDefaultNoteSectionValues() {
        let n = ScrambleEngine.NoteSection()
        XCTAssertEqual(n.spread, 0.5, accuracy: 1e-10)
        XCTAssertEqual(n.bias, 0.5, accuracy: 1e-10)
        XCTAssertEqual(n.steps, 0.0, accuracy: 1e-10)
        XCTAssertEqual(n.controlMode, .tilt)
        XCTAssertEqual(n.range, .twoOctaves)
        XCTAssertEqual(n.dejaVu, .off)
        XCTAssertEqual(n.dejaVuAmount, 0.5, accuracy: 1e-10)
        XCTAssertEqual(n.dejaVuLoopLength, 16)
    }

    func testDefaultModSectionValues() {
        let m = ScrambleEngine.ModSection()
        XCTAssertEqual(m.spread, 0.5, accuracy: 1e-10)
        XCTAssertEqual(m.bias, 0.5, accuracy: 1e-10)
        XCTAssertEqual(m.steps, 0.0, accuracy: 1e-10)
        XCTAssertEqual(m.dividerRatio, 1)
    }

    func testDefaultGateOutputValues() {
        let out = ScrambleEngine.GateOutput()
        XCTAssertFalse(out.gate1)
        XCTAssertFalse(out.gate2)
        XCTAssertFalse(out.gate3)
    }

    func testDefaultNoteOutputValues() {
        let out = ScrambleEngine.NoteOutput()
        XCTAssertEqual(out.note1, 60)
        XCTAssertEqual(out.note2, 60)
        XCTAssertEqual(out.note3, 60)
    }

    func testDefaultModOutputValues() {
        let out = ScrambleEngine.ModOutput()
        XCTAssertEqual(out.value, 0.5, accuracy: 1e-10)
        XCTAssertFalse(out.triggered)
    }

    // MARK: - GateMode displayName + backward compat

    func testGateModeDisplayNames() {
        XCTAssertEqual(ScrambleEngine.GateMode.coinToss.displayName, "Coin Toss")
        XCTAssertEqual(ScrambleEngine.GateMode.ratio.displayName, "Ratio")
        XCTAssertEqual(ScrambleEngine.GateMode.alternating.displayName, "Alternating")
        XCTAssertEqual(ScrambleEngine.GateMode.drums.displayName, "Drums")
        XCTAssertEqual(ScrambleEngine.GateMode.markov.displayName, "Markov")
        XCTAssertEqual(ScrambleEngine.GateMode.clusters.displayName, "Clusters")
        XCTAssertEqual(ScrambleEngine.GateMode.divider.displayName, "Divider")
    }

    func testGateModeBackwardCompatDecoding() throws {
        let oldJSON = "\"complementaryBernoulli\""
        let data = oldJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ScrambleEngine.GateMode.self, from: data)
        XCTAssertEqual(decoded, .coinToss)

        let oldJSON2 = "\"independentBernoulli\""
        let data2 = oldJSON2.data(using: .utf8)!
        let decoded2 = try JSONDecoder().decode(ScrambleEngine.GateMode.self, from: data2)
        XCTAssertEqual(decoded2, .ratio)

        let oldJSON3 = "\"threeStates\""
        let data3 = oldJSON3.data(using: .utf8)!
        let decoded3 = try JSONDecoder().decode(ScrambleEngine.GateMode.self, from: data3)
        XCTAssertEqual(decoded3, .alternating)
    }

    // NoteClockSource backward compat test removed — enum deleted

    // MARK: - Task 3: Gate2 = Master Clock

    func testCoinTossGate2AlwaysTrue() {
        var engine = ScrambleEngine()
        engine.gateSection.mode = .coinToss

        for _ in 0..<200 {
            let out = engine.generateGates()
            XCTAssertTrue(out.gate2, "CoinToss: gate2 (master clock) must always be true")
        }
    }

    func testCoinTossGate1AndGate3AreComplementary() {
        var engine = ScrambleEngine()
        engine.gateSection.mode = .coinToss

        for _ in 0..<200 {
            let out = engine.generateGates()
            // gate1 and gate3 are complementary
            XCTAssertNotEqual(out.gate1, out.gate3, "CoinToss: gate1 and gate3 must be complementary")
        }
    }

    func testRatioGate2AlwaysTrue() {
        var engine = ScrambleEngine()
        engine.gateSection.mode = .ratio
        engine.gateSection.bias = 0.5

        for _ in 0..<200 {
            let out = engine.generateGates()
            XCTAssertTrue(out.gate2, "Ratio: gate2 (master clock) must always be true")
        }
    }

    func testAlternatingGate2AlwaysTrue() {
        var engine = ScrambleEngine()
        engine.gateSection.mode = .alternating

        for _ in 0..<200 {
            let out = engine.generateGates()
            XCTAssertTrue(out.gate2, "Alternating: gate2 (master clock) must always be true")
        }
    }

    func testDrumsGate2AlwaysTrue() {
        var engine = ScrambleEngine()
        engine.gateSection.mode = .drums
        engine.gateSection.bias = 0.5

        for _ in 0..<200 {
            let out = engine.generateGates()
            XCTAssertTrue(out.gate2, "Drums: gate2 (master clock) must always be true")
        }
    }

    func testDividerGate2AlwaysTrue() {
        var engine = ScrambleEngine()
        engine.gateSection.mode = .divider
        engine.gateSection.bias = 0.5

        for _ in 0..<200 {
            let out = engine.generateGates()
            XCTAssertTrue(out.gate2, "Divider: gate2 (master clock) must always be true")
        }
    }

    func testDividerProducesRegularPattern() {
        var engine = ScrambleEngine()
        engine.gateSection.mode = .divider
        engine.gateSection.bias = 0.5

        var results: [ScrambleEngine.GateOutput] = []
        for _ in 0..<24 {
            results.append(engine.generateGates())
        }

        let gate1Count = results.filter { $0.gate1 }.count
        let gate3Count = results.filter { $0.gate3 }.count

        // Gate 1 fires every 2 steps, Gate 3 every 4 steps
        XCTAssertGreaterThan(gate1Count, 0, "Divider Gate 1 should fire some steps")
        XCTAssertLessThan(gate1Count, 24, "Divider Gate 1 should not fire every step")
        XCTAssertGreaterThan(gate3Count, 0, "Divider Gate 3 should fire some steps")
        XCTAssertLessThan(gate3Count, 24, "Divider Gate 3 should not fire every step")
    }

    // MARK: - Task 2: Gate Length Default

    func testGateLengthDefault() {
        let g = ScrambleEngine.GateSection()
        XCTAssertEqual(g.gateLength, 0.5, accuracy: 1e-10, "Default gate length should be 0.5")
    }

    // MARK: - Task 5: Deja Vu Loop Length

    func testRandomSequenceCustomLoopLength() {
        var seq = ScrambleEngine.RandomSequence()
        // Record 4 values with loopLength = 4
        for i in 0..<4 {
            seq.record(Double(i) * 0.25, loopLength: 4)
        }
        // Record one more — should wrap to position 0 (not position 4)
        seq.record(0.99, loopLength: 4)
        XCTAssertEqual(seq.replay(at: 0, loopLength: 4), 0.99, accuracy: 1e-10)
        // Position 1 should still hold its original value
        XCTAssertEqual(seq.replay(at: 1, loopLength: 4), 0.25, accuracy: 1e-10)
    }

    func testDejaVuLoopLengthDefault() {
        let g = ScrambleEngine.GateSection()
        XCTAssertEqual(g.dejaVuLoopLength, 16)

        let n = ScrambleEngine.NoteSection()
        XCTAssertEqual(n.dejaVuLoopLength, 16)
    }

    // MARK: - Task 6: Note Output Holds Last Value

    func testNoteHoldsLastValueOnDividerSkip() {
        var engine = ScrambleEngine()
        engine.noteSection.dividerRatio = 2
        engine.noteSection.controlMode = .identical
        let cMajor = [0, 2, 4, 5, 7, 9, 11]

        // First call (step 1): divider skips → held notes (default 60)
        let out1 = engine.generateNotes(gates: ScrambleEngine.GateOutput(gate1: true, gate2: true, gate3: true), scaleIntervals: cMajor, rootMidi: 60)
        XCTAssertEqual(out1.note1, 60, "First divider skip returns default held note")

        // Second call (step 2): generates new notes
        let out2 = engine.generateNotes(gates: ScrambleEngine.GateOutput(gate1: true, gate2: true, gate3: true), scaleIntervals: cMajor, rootMidi: 60)
        let generatedNote = out2.note1

        // Third call (step 3): divider skips → should hold the previously generated note
        let out3 = engine.generateNotes(gates: ScrambleEngine.GateOutput(gate1: true, gate2: true, gate3: true), scaleIntervals: cMajor, rootMidi: 60)
        XCTAssertEqual(out3.note1, generatedNote, "Divider skip should hold last generated note")
    }

    // MARK: - Note Generator

    func testGenerateNotesProducesValidMIDINotes() {
        var engine = ScrambleEngine()
        let cMajor = [0, 2, 4, 5, 7, 9, 11]

        for _ in 0..<200 {
            let out = engine.generateNotes(gates: ScrambleEngine.GateOutput(gate1: true, gate2: true, gate3: true), scaleIntervals: cMajor, rootMidi: 60)
            XCTAssertGreaterThanOrEqual(out.note1, 0, "MIDI note must be >= 0")
            XCTAssertLessThanOrEqual(out.note1, 127, "MIDI note must be <= 127")
            XCTAssertGreaterThanOrEqual(out.note2, 0)
            XCTAssertLessThanOrEqual(out.note2, 127)
            XCTAssertGreaterThanOrEqual(out.note3, 0)
            XCTAssertLessThanOrEqual(out.note3, 127)
        }
    }

    func testIdenticalModeProducesSameNotes() {
        var engine = ScrambleEngine()
        engine.noteSection.controlMode = .identical
        let cMajor = [0, 2, 4, 5, 7, 9, 11]

        for _ in 0..<100 {
            let out = engine.generateNotes(gates: ScrambleEngine.GateOutput(gate1: true, gate2: true, gate3: true), scaleIntervals: cMajor, rootMidi: 60)
            XCTAssertEqual(out.note1, out.note2, "Identical mode: Note 1 must equal Note 2")
            XCTAssertEqual(out.note2, out.note3, "Identical mode: Note 2 must equal Note 3")
        }
    }

    func testQuantizerStaysInRange() {
        let cMajor = [0, 2, 4, 5, 7, 9, 11]

        let low = ScrambleEngine.quantizeToScale(rawValue: 0.0, scaleIntervals: cMajor, rootMidi: 60, range: 24)
        let high = ScrambleEngine.quantizeToScale(rawValue: 1.0, scaleIntervals: cMajor, rootMidi: 60, range: 24)

        XCTAssertGreaterThanOrEqual(low, 0)
        XCTAssertLessThanOrEqual(low, 127)
        XCTAssertGreaterThanOrEqual(high, 0)
        XCTAssertLessThanOrEqual(high, 127)
    }

    // MARK: - Task 7: SPREAD Distribution Shaping

    func testSpreadZeroProducesNarrowDistribution() {
        // spread=0 should pull values toward center (0.5)
        let result = ScrambleEngine.shapedBySpread(0.0, spread: 0.0)
        XCTAssertEqual(result, 0.5, accuracy: 1e-10, "spread=0 with raw=0 should produce 0.5 (center)")

        let result2 = ScrambleEngine.shapedBySpread(1.0, spread: 0.0)
        XCTAssertEqual(result2, 0.5, accuracy: 1e-10, "spread=0 with raw=1 should produce 0.5 (center)")
    }

    func testSpreadHalfIsPassthrough() {
        let result = ScrambleEngine.shapedBySpread(0.3, spread: 0.5)
        XCTAssertEqual(result, 0.3, accuracy: 1e-10, "spread=0.5 should be passthrough")
    }

    func testSpreadOneProducesBimodal() {
        // spread=1 should push toward extremes
        let lowResult = ScrambleEngine.shapedBySpread(0.1, spread: 1.0)
        XCTAssertEqual(lowResult, 0.0, accuracy: 1e-10, "spread=1 should push low values to 0")

        let highResult = ScrambleEngine.shapedBySpread(0.9, spread: 1.0)
        XCTAssertEqual(highResult, 1.0, accuracy: 1e-10, "spread=1 should push high values to 1")
    }

    // MARK: - Task 8: BIAS as Probability Skew

    func testBiasHalfIsNearPassthrough() {
        // bias=0.5 should be close to identity (exponent = 1)
        let result = ScrambleEngine.skewedByBias(0.5, bias: 0.5)
        XCTAssertEqual(result, 0.5, accuracy: 0.01, "bias=0.5 should be near-identity")
    }

    func testBiasOneSkewsTowardHigh() {
        // bias=1.0 → exponent < 1 → values skew upward
        let result = ScrambleEngine.skewedByBias(0.5, bias: 1.0)
        XCTAssertGreaterThan(result, 0.5, "bias=1.0 should skew 0.5 upward")
    }

    func testBiasZeroSkewsTowardLow() {
        // bias=0.0 → exponent > 1 → values skew downward
        let result = ScrambleEngine.skewedByBias(0.5, bias: 0.0)
        XCTAssertLessThan(result, 0.5, "bias=0.0 should skew 0.5 downward")
    }

    func testBiasPreservesBoundaries() {
        XCTAssertEqual(ScrambleEngine.skewedByBias(0.0, bias: 0.3), 0.0, accuracy: 1e-10)
        XCTAssertEqual(ScrambleEngine.skewedByBias(1.0, bias: 0.7), 1.0, accuracy: 1e-10)
    }

    // MARK: - Task 9: STEPS Dual Behavior

    func testStepsHalfIsBypass() {
        let result = ScrambleEngine.applySteps(0.73, steps: 0.5, prev: 0.2)
        XCTAssertEqual(result, 0.73, accuracy: 1e-10, "steps=0.5 should bypass")
    }

    func testStepsZeroIsBypass() {
        // steps=0 → bypass → output = input value (no smoothing or quantization)
        let result = ScrambleEngine.applySteps(0.8, steps: 0.0, prev: 0.2)
        XCTAssertEqual(result, 0.8, accuracy: 1e-10, "steps=0 should bypass (return raw value)")
    }

    func testStepsLowIsSmoothing() {
        // steps=0.3 → smoothing: blend prev and value
        // smoothAmount = 0.3 / 0.45 ≈ 0.667
        // result = 0.2 * 0.667 + 0.8 * 0.333 ≈ 0.4
        let result = ScrambleEngine.applySteps(0.8, steps: 0.3, prev: 0.2)
        XCTAssertTrue(result > 0.2 && result < 0.8, "steps=0.3 should blend between prev and value")
        // Closer to prev than to value since smoothAmount > 0.5
        XCTAssertTrue(result < 0.5, "steps=0.3 should be closer to prev (heavy smoothing)")
    }

    func testStepsOneIsMaxQuantize() {
        // steps=1 → 16 discrete levels
        let result = ScrambleEngine.applySteps(0.73, steps: 1.0, prev: 0.5)
        // 0.73 * 16 = 11.68, floor = 11, 11/16 = 0.6875
        XCTAssertEqual(result, 0.6875, accuracy: 1e-10, "steps=1 should quantize to 16 levels")
    }

    func testStepsQuantizeProducesDiscreteValues() {
        // steps=0.8 → t = (0.8 - 0.55) / 0.45 ≈ 0.556, levels = round(0.556*14 + 2) = round(9.78) = 10
        var values: Set<Int> = []
        for i in 0..<100 {
            let raw = Double(i) / 100.0
            let result = ScrambleEngine.applySteps(raw, steps: 0.8, prev: 0.5)
            values.insert(Int((result * 1000).rounded()))
        }
        // With 10 discrete levels, we expect at most 10 unique values
        XCTAssertLessThanOrEqual(values.count, 11, "Quantized output should have discrete levels")
    }

    // MARK: - Mod Generator

    func testGenerateModValuesInRange() {
        var engine = ScrambleEngine()

        for _ in 0..<200 {
            let out = engine.generateMod()
            XCTAssertGreaterThanOrEqual(out.value, 0.0, "Mod value must be >= 0")
            XCTAssertLessThanOrEqual(out.value, 1.0, "Mod value must be <= 1")
        }
    }

    func testModDividerRatioTriggersCorrectly() {
        var engine = ScrambleEngine()
        engine.modSection.dividerRatio = 3

        var triggerCount = 0
        for _ in 0..<12 {
            let out = engine.generateMod()
            if out.triggered {
                triggerCount += 1
            }
        }
        // With ratio=3 over 12 steps, expect 4 triggers (steps 3, 6, 9, 12)
        XCTAssertEqual(triggerCount, 4, "Divider ratio 3 over 12 steps should produce 4 triggers")
    }

    func testModSpreadZeroProducesSameValue() {
        var engine = ScrambleEngine()
        engine.modSection.spread = 0.0
        engine.modSection.bias = 0.5
        engine.modSection.steps = 0.5  // bypass steps
        engine.modSection.dividerRatio = 1

        var values: Set<Int> = []
        for _ in 0..<100 {
            let out = engine.generateMod()
            if out.triggered {
                values.insert(Int((out.value * 10000).rounded()))
            }
        }
        // With spread=0, shapedBySpread returns 0.5 for all inputs
        // Then skewedByBias(0.5, bias: 0.5) ≈ 0.5
        XCTAssertEqual(values.count, 1, "With spread=0 and bias=0.5, Mod should produce a single value")
    }
}

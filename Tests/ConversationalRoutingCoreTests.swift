import XCTest
@testable import Grainulator

final class ConversationalRoutingCoreTests: XCTestCase {
    func testNormalizeActionTypeForRecordingFeedbackTargets() {
        let normalized = ConversationalRoutingCore.normalizeActionType(
            type: "set",
            target: "loop.voiceA.recording.feedback"
        )
        XCTAssertEqual(normalized, "setRecordingFeedback")
    }

    func testNormalizeActionTypeLeavesOtherTargetsUnchanged() {
        let normalized = ConversationalRoutingCore.normalizeActionType(
            type: "set",
            target: "fx.reverb.mix"
        )
        XCTAssertEqual(normalized, "set")
    }

    func testNormalizeActionTypeForRecordingModeTargets() {
        let normalized = ConversationalRoutingCore.normalizeActionType(
            type: "ramp",
            target: "loop.voiceB.recording.mode"
        )
        XCTAssertEqual(normalized, "setRecordingMode")
    }

    func testResolveTargetTransportNextBeat() {
        let current = ConversationalRoutingCore.TransportSnapshot(bar: 3, beat: 2.2, bpm: 120)
        let spec = ConversationalRoutingCore.TimeSpec(anchor: "next_beat", quantization: "off")
        let result = ConversationalRoutingCore.resolveTargetTransport(current: current, timeSpec: spec)

        XCTAssertEqual(result.bar, 3)
        XCTAssertEqual(result.beat, 3.0, accuracy: 0.0001)
        XCTAssertEqual(result.beatsDelta, 0.8, accuracy: 0.0001)
    }

    func testResolveTargetTransportNextBarQuantized() {
        let current = ConversationalRoutingCore.TransportSnapshot(bar: 5, beat: 3.75, bpm: 124)
        let spec = ConversationalRoutingCore.TimeSpec(anchor: "next_bar", quantization: "1/16")
        let result = ConversationalRoutingCore.resolveTargetTransport(current: current, timeSpec: spec)

        XCTAssertEqual(result.bar, 6)
        XCTAssertEqual(result.beat, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.beatsDelta, 1.25, accuracy: 0.0001)
    }

    func testResolveTargetTransportWithBarQuantization() {
        let current = ConversationalRoutingCore.TransportSnapshot(bar: 2, beat: 4.5, bpm: 100)
        let spec = ConversationalRoutingCore.TimeSpec(anchor: "next_beat", quantization: "1_bar")
        let result = ConversationalRoutingCore.resolveTargetTransport(current: current, timeSpec: spec)

        XCTAssertEqual(result.bar, 3)
        XCTAssertEqual(result.beat, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.beatsDelta, 0.5, accuracy: 0.0001)
    }

    func testResolveTargetTransportAtPositionWithQuarterQuantization() {
        let current = ConversationalRoutingCore.TransportSnapshot(bar: 1, beat: 1.3, bpm: 120)
        let spec = ConversationalRoutingCore.TimeSpec(anchor: "at_transport_position", quantization: "1/4")
        let result = ConversationalRoutingCore.resolveTargetTransport(current: current, timeSpec: spec)

        XCTAssertEqual(result.bar, 1)
        XCTAssertEqual(result.beat, 2.0, accuracy: 0.0001)
        XCTAssertEqual(result.beatsDelta, 0.7, accuracy: 0.0001)
    }

    func testQuantizationStepMapping() {
        XCTAssertNil(ConversationalRoutingCore.quantizationStepBeats("off"))
        XCTAssertEqual(ConversationalRoutingCore.quantizationStepBeats("1/16"), 0.25)
        XCTAssertEqual(ConversationalRoutingCore.quantizationStepBeats("1_bar"), 4.0)
    }

    func testQuantizationStepMapping3_4() {
        // In 3/4 time, 1 bar = 3 quarter notes
        XCTAssertEqual(ConversationalRoutingCore.quantizationStepBeats("1_bar", quarterNotesPerBar: 3.0), 3.0)
        // Sub-beat quantizations are unchanged
        XCTAssertEqual(ConversationalRoutingCore.quantizationStepBeats("1/4", quarterNotesPerBar: 3.0), 1.0)
        XCTAssertEqual(ConversationalRoutingCore.quantizationStepBeats("1/16", quarterNotesPerBar: 3.0), 0.25)
    }

    func testQuantizationStepMapping6_8() {
        // In 6/8 time, 1 bar = 3 quarter notes (same as 3/4)
        XCTAssertEqual(ConversationalRoutingCore.quantizationStepBeats("1_bar", quarterNotesPerBar: 3.0), 3.0)
    }

    func testQuantizationStepMapping7_8() {
        // In 7/8 time, 1 bar = 3.5 quarter notes
        XCTAssertEqual(ConversationalRoutingCore.quantizationStepBeats("1_bar", quarterNotesPerBar: 3.5), 3.5)
    }

    // MARK: - 3/4 Time Signature Tests

    func testResolveTargetTransport3_4NextBar() {
        // In 3/4 time, bars have 3 beats. Beat 2.5 of bar 2 → next bar = bar 3, beat 1
        let current = ConversationalRoutingCore.TransportSnapshot(bar: 2, beat: 2.5, bpm: 120, quarterNotesPerBar: 3.0)
        let spec = ConversationalRoutingCore.TimeSpec(anchor: "next_bar", quantization: "off")
        let result = ConversationalRoutingCore.resolveTargetTransport(current: current, timeSpec: spec)

        XCTAssertEqual(result.bar, 3)
        XCTAssertEqual(result.beat, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.beatsDelta, 1.5, accuracy: 0.0001)
    }

    func testResolveTargetTransport3_4NextBeat() {
        // In 3/4, beat 2.7 → next beat = 3.0
        let current = ConversationalRoutingCore.TransportSnapshot(bar: 1, beat: 2.7, bpm: 120, quarterNotesPerBar: 3.0)
        let spec = ConversationalRoutingCore.TimeSpec(anchor: "next_beat", quantization: "off")
        let result = ConversationalRoutingCore.resolveTargetTransport(current: current, timeSpec: spec)

        XCTAssertEqual(result.bar, 1)
        XCTAssertEqual(result.beat, 3.0, accuracy: 0.0001)
        XCTAssertEqual(result.beatsDelta, 0.3, accuracy: 0.0001)
    }

    func testResolveTargetTransport3_4NextBeatWrapsToNextBar() {
        // In 3/4, beat 3.5 is past the last beat (3 qn/bar) → next beat wraps to bar+1, beat 1
        // Actually beat 3.5 means: totalBeats = (bar-1)*3 + (beat-1) = 0*3 + 2.5 = 2.5
        // next beat = ceil(2.5) = 3.0, which is bar 2 beat 1 (3.0/3.0 = bar 1 + 1 = bar 2, beat 0 + 1 = 1)
        let current = ConversationalRoutingCore.TransportSnapshot(bar: 1, beat: 3.5, bpm: 120, quarterNotesPerBar: 3.0)
        let spec = ConversationalRoutingCore.TimeSpec(anchor: "next_beat", quantization: "off")
        let result = ConversationalRoutingCore.resolveTargetTransport(current: current, timeSpec: spec)

        // 3.5 → beat-1 = 2.5, totalBeats = 2.5, next beat = ceil(2.5) = 3.0
        // bar = floor(3.0/3.0) + 1 = 2, beat = 3.0 - 3.0 + 1 = 1.0
        XCTAssertEqual(result.bar, 2)
        XCTAssertEqual(result.beat, 1.0, accuracy: 0.0001)
    }

    func testResolveTargetTransport3_4BarQuantization() {
        // In 3/4, bar quantization snaps to 3-beat boundaries
        let current = ConversationalRoutingCore.TransportSnapshot(bar: 2, beat: 1.3, bpm: 120, quarterNotesPerBar: 3.0)
        let spec = ConversationalRoutingCore.TimeSpec(anchor: "next_beat", quantization: "1_bar")
        let result = ConversationalRoutingCore.resolveTargetTransport(current: current, timeSpec: spec)

        // totalBeats = (2-1)*3 + (1.3-1) = 3.3, next beat target = ceil(3.3) = 4.0
        // bar quantize (step=3): ceil(4.0/3.0)*3.0 = 6.0
        // bar = floor(6.0/3.0) + 1 = 3, beat = 6.0 - 6.0 + 1 = 1.0
        XCTAssertEqual(result.bar, 3)
        XCTAssertEqual(result.beat, 1.0, accuracy: 0.0001)
    }

    // MARK: - 6/8 Time Signature Tests

    func testResolveTargetTransport6_8NextBar() {
        // 6/8 has same qn/bar (3.0) as 3/4
        let current = ConversationalRoutingCore.TransportSnapshot(bar: 4, beat: 2.0, bpm: 140, quarterNotesPerBar: 3.0)
        let spec = ConversationalRoutingCore.TimeSpec(anchor: "next_bar", quantization: "off")
        let result = ConversationalRoutingCore.resolveTargetTransport(current: current, timeSpec: spec)

        XCTAssertEqual(result.bar, 5)
        XCTAssertEqual(result.beat, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.beatsDelta, 2.0, accuracy: 0.0001)
    }

    func testResolveTargetTransport6_8BarQuantization() {
        // 6/8: bar quantize → snap to 3-beat boundaries
        let current = ConversationalRoutingCore.TransportSnapshot(bar: 1, beat: 2.0, bpm: 100, quarterNotesPerBar: 3.0)
        let spec = ConversationalRoutingCore.TimeSpec(anchor: "at_transport_position", quantization: "1_bar")
        let result = ConversationalRoutingCore.resolveTargetTransport(current: current, timeSpec: spec)

        // totalBeats = 0*3 + 1.0 = 1.0, quantize to step 3: ceil(1.0/3.0)*3.0 = 3.0
        // bar = floor(3.0/3.0) + 1 = 2, beat = 1.0
        XCTAssertEqual(result.bar, 2)
        XCTAssertEqual(result.beat, 1.0, accuracy: 0.0001)
    }

    // MARK: - 7/8 Time Signature Test

    func testResolveTargetTransport7_8NextBar() {
        // 7/8: 3.5 qn/bar
        let current = ConversationalRoutingCore.TransportSnapshot(bar: 1, beat: 3.0, bpm: 120, quarterNotesPerBar: 3.5)
        let spec = ConversationalRoutingCore.TimeSpec(anchor: "next_bar", quantization: "off")
        let result = ConversationalRoutingCore.resolveTargetTransport(current: current, timeSpec: spec)

        // totalBeats = 0*3.5 + 2.0 = 2.0, next_bar → target bar 2, beat 1
        // target totalBeats = (2-1)*3.5 + 0 = 3.5
        XCTAssertEqual(result.bar, 2)
        XCTAssertEqual(result.beat, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.beatsDelta, 1.5, accuracy: 0.0001)
    }

    func testRiskRankingOrder() {
        XCTAssertLessThan(ConversationalRoutingCore.riskRank("low"), ConversationalRoutingCore.riskRank("medium"))
        XCTAssertLessThan(ConversationalRoutingCore.riskRank("medium"), ConversationalRoutingCore.riskRank("high"))
    }
}

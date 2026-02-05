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

    func testRiskRankingOrder() {
        XCTAssertLessThan(ConversationalRoutingCore.riskRank("low"), ConversationalRoutingCore.riskRank("medium"))
        XCTAssertLessThan(ConversationalRoutingCore.riskRank("medium"), ConversationalRoutingCore.riskRank("high"))
    }
}

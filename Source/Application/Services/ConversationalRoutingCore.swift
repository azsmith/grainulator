//
//  ConversationalRoutingCore.swift
//  Grainulator
//
//  Pure routing/scheduling helpers shared by bridge handlers and tests.
//

import Foundation

struct ConversationalRoutingCore {
    struct TransportSnapshot: Equatable {
        let bar: Int
        let beat: Double
        let bpm: Double
        let quarterNotesPerBar: Double

        init(bar: Int, beat: Double, bpm: Double, quarterNotesPerBar: Double = 4.0) {
            self.bar = bar
            self.beat = beat
            self.bpm = bpm
            self.quarterNotesPerBar = quarterNotesPerBar
        }
    }

    struct TimeSpec: Equatable {
        let anchor: String?
        let quantization: String?
    }

    static func normalizeActionType(type: String, target: String?) -> String {
        if type == "set" || type == "ramp" {
            if let target, target.hasSuffix(".recording.feedback") {
                return "setRecordingFeedback"
            }
            if let target, target.hasSuffix(".recording.mode") {
                return "setRecordingMode"
            }
        }
        return type
    }

    static func quantizationStepBeats(_ quantization: String?, quarterNotesPerBar: Double = 4.0) -> Double? {
        guard let quantization else { return nil }
        switch quantization {
        case "off":
            return nil
        case "1/16":
            return 0.25
        case "1/8":
            return 0.5
        case "1/4":
            return 1.0
        case "1_bar", "1 bar":
            return quarterNotesPerBar
        default:
            return nil
        }
    }

    static func riskRank(_ risk: String) -> Int {
        switch risk {
        case "high":
            return 2
        case "medium":
            return 1
        default:
            return 0
        }
    }

    static func resolveTargetTransport(
        current: TransportSnapshot,
        timeSpec: TimeSpec?
    ) -> (bar: Int, beat: Double, beatsDelta: Double) {
        let qnPerBar = current.quarterNotesPerBar
        let currentTotalBeats = (Double(max(1, current.bar) - 1) * qnPerBar) + (current.beat - 1.0)
        let anchor = timeSpec?.anchor ?? "now"

        var targetTotalBeats = currentTotalBeats
        switch anchor {
        case "next_beat":
            targetTotalBeats = floor(currentTotalBeats) + 1.0
        case "next_bar":
            targetTotalBeats = floor(currentTotalBeats / qnPerBar) * qnPerBar + qnPerBar
        case "at_transport_position":
            targetTotalBeats = currentTotalBeats
        default:
            targetTotalBeats = currentTotalBeats
        }

        if let step = quantizationStepBeats(timeSpec?.quantization, quarterNotesPerBar: qnPerBar), step > 0 {
            targetTotalBeats = ceil(targetTotalBeats / step) * step
        }

        let beatsDelta = max(0.0, targetTotalBeats - currentTotalBeats)
        let bar = Int(floor(targetTotalBeats / qnPerBar)) + 1
        let beat = targetTotalBeats.truncatingRemainder(dividingBy: qnPerBar) + 1.0
        return (max(1, bar), beat, beatsDelta)
    }
}

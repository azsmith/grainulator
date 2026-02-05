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

    static func quantizationStepBeats(_ quantization: String?) -> Double? {
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
            return 4.0
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
        let currentTotalBeats = (Double(max(1, current.bar) - 1) * 4.0) + (current.beat - 1.0)
        let anchor = timeSpec?.anchor ?? "now"

        var targetTotalBeats = currentTotalBeats
        switch anchor {
        case "next_beat":
            targetTotalBeats = floor(currentTotalBeats) + 1.0
        case "next_bar":
            targetTotalBeats = floor(currentTotalBeats / 4.0) * 4.0 + 4.0
        case "at_transport_position":
            targetTotalBeats = currentTotalBeats
        default:
            targetTotalBeats = currentTotalBeats
        }

        if let step = quantizationStepBeats(timeSpec?.quantization), step > 0 {
            targetTotalBeats = ceil(targetTotalBeats / step) * step
        }

        let beatsDelta = max(0.0, targetTotalBeats - currentTotalBeats)
        let bar = Int(floor(targetTotalBeats / 4.0)) + 1
        let beat = targetTotalBeats.truncatingRemainder(dividingBy: 4.0) + 1.0
        return (max(1, bar), beat, beatsDelta)
    }
}

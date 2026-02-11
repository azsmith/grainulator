//
//  PitchDetector.swift
//  Grainulator
//
//  YIN pitch detection algorithm — pure Swift, no dependencies.
//  Optimized for monophonic pitch detection of synthesizer voices.
//

import Foundation
import Accelerate

struct PitchResult {
    let frequency: Float
    let confidence: Float
}

struct PitchDetector {
    /// YIN absolute threshold — lower = stricter pitch detection.
    /// 0.15 is a good default for clean synth signals.
    private let threshold: Float = 0.15

    /// Minimum frequency to detect (~24 Hz = B0)
    private let minFrequency: Float = 24.0
    /// Maximum frequency to detect (~4186 Hz = C8)
    private let maxFrequency: Float = 4186.0

    /// Detect pitch using the YIN algorithm.
    /// - Parameters:
    ///   - samples: Audio samples (at least 2048, ideally 4096 for low notes)
    ///   - sampleRate: Sample rate in Hz (e.g. 48000)
    /// - Returns: Detected pitch and confidence, or nil if no clear pitch
    func detectPitch(samples: [Float], sampleRate: Float) -> PitchResult? {
        let n = samples.count
        let halfN = n / 2
        guard halfN > 0 else { return nil }

        // Check for silence — skip if RMS is very low
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(n))
        guard rms > 0.001 else { return nil }

        // Step 1 & 2: Difference function + cumulative mean normalized difference
        // Combined for efficiency
        var cmnd = [Float](repeating: 0, count: halfN)
        cmnd[0] = 1.0

        var runningSum: Float = 0

        for tau in 1..<halfN {
            var sum: Float = 0
            // Use vDSP for the difference function
            // d(tau) = sum((x[j] - x[j+tau])^2) for j in 0..<halfN
            for j in 0..<halfN {
                let diff = samples[j] - samples[j + tau]
                sum += diff * diff
            }

            runningSum += sum

            // Cumulative mean normalized difference
            if runningSum > 0 {
                cmnd[tau] = sum * Float(tau) / runningSum
            } else {
                cmnd[tau] = 1.0
            }
        }

        // Step 3: Absolute threshold — find first dip below threshold
        let minLag = max(1, Int(sampleRate / maxFrequency))
        let maxLag = min(halfN - 1, Int(sampleRate / minFrequency))
        guard minLag < maxLag else { return nil }

        var bestTau = -1

        for tau in minLag...maxLag {
            if cmnd[tau] < threshold {
                // Find the local minimum in this valley
                var localMin = tau
                while localMin + 1 <= maxLag && cmnd[localMin + 1] < cmnd[localMin] {
                    localMin += 1
                }
                bestTau = localMin
                break
            }
        }

        // If no dip found below threshold, find global minimum as fallback
        if bestTau < 0 {
            var globalMinVal: Float = .greatestFiniteMagnitude
            for tau in minLag...maxLag {
                if cmnd[tau] < globalMinVal {
                    globalMinVal = cmnd[tau]
                    bestTau = tau
                }
            }
            // Only use global min if it's reasonably low
            if globalMinVal > 0.5 {
                return nil
            }
        }

        guard bestTau > 0 else { return nil }

        // Step 4: Parabolic interpolation for sub-sample accuracy
        let refinedTau: Float
        if bestTau > 0 && bestTau < halfN - 1 {
            let s0 = cmnd[bestTau - 1]
            let s1 = cmnd[bestTau]
            let s2 = cmnd[bestTau + 1]
            let denom = 2.0 * s1 - s2 - s0
            if abs(denom) > 1e-10 {
                let shift = (s2 - s0) / (2.0 * denom)
                refinedTau = Float(bestTau) + shift
            } else {
                refinedTau = Float(bestTau)
            }
        } else {
            refinedTau = Float(bestTau)
        }

        guard refinedTau > 0 else { return nil }

        let frequency = sampleRate / refinedTau
        let confidence = 1.0 - cmnd[bestTau]

        // Sanity check frequency range
        guard frequency >= minFrequency && frequency <= maxFrequency else { return nil }

        return PitchResult(frequency: frequency, confidence: confidence)
    }
}

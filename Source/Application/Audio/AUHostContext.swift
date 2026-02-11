//
//  AUHostContext.swift
//  Grainulator
//
//  Provides musical context (tempo, time signature, transport state) to hosted
//  Audio Unit plugins so that tempo-synced effects (delays, modulation, etc.)
//  can lock to the host's BPM and transport.
//

import AudioToolbox
import Foundation

/// Thread-safe musical context that AU plugins can read from the audio thread.
/// Updated from the main thread whenever tempo or transport state changes.
final class AUHostContext: @unchecked Sendable {
    // All fields are read/written atomically. The audio thread only reads;
    // the main thread only writes. A lock-free approach using atomics would
    // be ideal, but for the low update frequency (UI-rate) a simple lock
    // with no contention on the audio thread in practice is acceptable.

    private let lock = NSLock()

    private var _tempo: Double = 120.0
    private var _timeSignatureNumerator: Int = 4
    private var _timeSignatureDenominator: Int = 4
    private var _currentBeatPosition: Double = 0.0
    private var _isPlaying: Bool = false
    private var _currentSamplePosition: Double = 0.0
    private var _cycleStartBeat: Double = 0.0
    private var _cycleEndBeat: Double = 0.0

    /// Update tempo (call from main thread when BPM changes)
    func setTempo(_ bpm: Double) {
        lock.lock()
        _tempo = bpm
        lock.unlock()
    }

    /// Update transport state (call from main thread on play/stop)
    func setTransportState(isPlaying: Bool) {
        lock.lock()
        _isPlaying = isPlaying
        lock.unlock()
    }

    /// Update beat position (call periodically from scheduler)
    func setBeatPosition(_ beat: Double) {
        lock.lock()
        _currentBeatPosition = beat
        lock.unlock()
    }

    /// Update sample position
    func setSamplePosition(_ sample: Double) {
        lock.lock()
        _currentSamplePosition = sample
        lock.unlock()
    }

    // MARK: - AU Callback Blocks

    /// Creates a `musicalContextBlock` that AU plugins use to query host tempo/time sig.
    func makeMusicalContextBlock() -> AUHostMusicalContextBlock {
        return { [weak self] outTempo, outTimeSignatureNumerator, outTimeSignatureDenominator, outCurrentBeatPosition, outSampleRate, outCurrentDownbeatPosition in
            guard let self else { return false }

            self.lock.lock()
            let tempo = self._tempo
            let tsNum = self._timeSignatureNumerator
            let tsDen = self._timeSignatureDenominator
            let beatPos = self._currentBeatPosition
            self.lock.unlock()

            outTempo?.pointee = tempo
            outTimeSignatureNumerator?.pointee = Double(tsNum)
            outTimeSignatureDenominator?.pointee = tsDen
            outCurrentBeatPosition?.pointee = beatPos
            // outSampleRate is expected as beats-per-bar for downbeat calc
            outCurrentDownbeatPosition?.pointee = floor(beatPos / Double(tsNum)) * Double(tsNum)

            return true
        }
    }

    /// Creates a `transportStateBlock` that AU plugins use to query host transport.
    func makeTransportStateBlock() -> AUHostTransportStateBlock {
        return { [weak self] outFlags, outCurrentSamplePosition, outCycleStartBeatPosition, outCycleEndBeatPosition in
            guard let self else { return false }

            self.lock.lock()
            let playing = self._isPlaying
            let samplePos = self._currentSamplePosition
            self.lock.unlock()

            if let flags = outFlags {
                var f = AUHostTransportStateFlags()
                if playing {
                    f.insert(.changed)
                    f.insert(.moving)
                }
                flags.pointee = f
            }
            outCurrentSamplePosition?.pointee = samplePos
            outCycleStartBeatPosition?.pointee = 0.0
            outCycleEndBeatPosition?.pointee = 0.0

            return true
        }
    }

    /// Attaches musical context and transport state blocks to an Audio Unit.
    /// Call this after instantiating/loading a plugin.
    func attachToAudioUnit(_ au: AUAudioUnit) {
        au.musicalContextBlock = makeMusicalContextBlock()
        au.transportStateBlock = makeTransportStateBlock()
    }
}

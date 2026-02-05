//
//  AudioEngineWrapper.swift
//  Grainulator
//
//  Swift wrapper for the C++ audio engine
//  Provides SwiftUI-friendly interface to the real-time audio system
//

import SwiftUI
import AVFoundation
import CoreAudio
import AudioUnit

// C Bridge functions from AudioEngineBridge.h
@_silgen_name("AudioEngine_Create")
func AudioEngine_Create() -> OpaquePointer

@_silgen_name("AudioEngine_Destroy")
func AudioEngine_Destroy(_ handle: OpaquePointer)

@_silgen_name("AudioEngine_Initialize")
func AudioEngine_Initialize(_ handle: OpaquePointer, _ sampleRate: Int32, _ bufferSize: Int32) -> Bool

@_silgen_name("AudioEngine_Shutdown")
func AudioEngine_Shutdown(_ handle: OpaquePointer)

@_silgen_name("AudioEngine_Process")
func AudioEngine_Process(_ handle: OpaquePointer, _ outputBuffers: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>?, _ numChannels: Int32, _ numFrames: Int32)

@_silgen_name("AudioEngine_ProcessMultiChannel")
func AudioEngine_ProcessMultiChannel(_ handle: OpaquePointer, _ channelBuffers: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>?, _ numFrames: Int32)

@_silgen_name("AudioEngine_SetParameter")
func AudioEngine_SetParameter(_ handle: OpaquePointer, _ parameterId: Int32, _ voiceIndex: Int32, _ value: Float)

@_silgen_name("AudioEngine_GetParameter")
func AudioEngine_GetParameter(_ handle: OpaquePointer, _ parameterId: Int32, _ voiceIndex: Int32) -> Float

@_silgen_name("AudioEngine_SetChannelSendLevel")
func AudioEngine_SetChannelSendLevel(_ handle: OpaquePointer, _ channelIndex: Int32, _ sendIndex: Int32, _ level: Float)

@_silgen_name("AudioEngine_GetCPULoad")
func AudioEngine_GetCPULoad(_ handle: OpaquePointer) -> Float

@_silgen_name("AudioEngine_TriggerPlaits")
func AudioEngine_TriggerPlaits(_ handle: OpaquePointer, _ state: Bool)

@_silgen_name("AudioEngine_NoteOn")
func AudioEngine_NoteOn(_ handle: OpaquePointer, _ note: Int32, _ velocity: Int32)

@_silgen_name("AudioEngine_NoteOff")
func AudioEngine_NoteOff(_ handle: OpaquePointer, _ note: Int32)

@_silgen_name("AudioEngine_ScheduleNoteOn")
func AudioEngine_ScheduleNoteOn(_ handle: OpaquePointer, _ note: Int32, _ velocity: Int32, _ sampleTime: UInt64)

@_silgen_name("AudioEngine_ScheduleNoteOff")
func AudioEngine_ScheduleNoteOff(_ handle: OpaquePointer, _ note: Int32, _ sampleTime: UInt64)

@_silgen_name("AudioEngine_ScheduleNoteOnTarget")
func AudioEngine_ScheduleNoteOnTarget(_ handle: OpaquePointer, _ note: Int32, _ velocity: Int32, _ sampleTime: UInt64, _ targetMask: UInt8)

@_silgen_name("AudioEngine_ScheduleNoteOffTarget")
func AudioEngine_ScheduleNoteOffTarget(_ handle: OpaquePointer, _ note: Int32, _ sampleTime: UInt64, _ targetMask: UInt8)

@_silgen_name("AudioEngine_ClearScheduledNotes")
func AudioEngine_ClearScheduledNotes(_ handle: OpaquePointer)

@_silgen_name("AudioEngine_GetCurrentSampleTime")
func AudioEngine_GetCurrentSampleTime(_ handle: OpaquePointer) -> UInt64

@_silgen_name("AudioEngine_LoadAudioData")
func AudioEngine_LoadAudioData(_ handle: OpaquePointer, _ reelIndex: Int32, _ leftChannel: UnsafePointer<Float>?, _ rightChannel: UnsafePointer<Float>?, _ numSamples: Int, _ sampleRate: Float) -> Bool

@_silgen_name("AudioEngine_ClearReel")
func AudioEngine_ClearReel(_ handle: OpaquePointer, _ reelIndex: Int32)

@_silgen_name("AudioEngine_GetReelLength")
func AudioEngine_GetReelLength(_ handle: OpaquePointer, _ reelIndex: Int32) -> Int

@_silgen_name("AudioEngine_GetWaveformOverview")
func AudioEngine_GetWaveformOverview(_ handle: OpaquePointer, _ reelIndex: Int32, _ output: UnsafeMutablePointer<Float>?, _ outputSize: Int)

@_silgen_name("AudioEngine_SetGranularPlaying")
func AudioEngine_SetGranularPlaying(_ handle: OpaquePointer, _ voiceIndex: Int32, _ playing: Bool)

@_silgen_name("AudioEngine_SetGranularPosition")
func AudioEngine_SetGranularPosition(_ handle: OpaquePointer, _ voiceIndex: Int32, _ position: Float)

@_silgen_name("AudioEngine_GetActiveGrainCount")
func AudioEngine_GetActiveGrainCount(_ handle: OpaquePointer) -> Int32

@_silgen_name("AudioEngine_GetGranularPosition")
func AudioEngine_GetGranularPosition(_ handle: OpaquePointer, _ voiceIndex: Int32) -> Float

@_silgen_name("AudioEngine_GetChannelLevel")
func AudioEngine_GetChannelLevel(_ handle: OpaquePointer, _ channelIndex: Int32) -> Float

@_silgen_name("AudioEngine_GetMasterLevel")
func AudioEngine_GetMasterLevel(_ handle: OpaquePointer, _ channel: Int32) -> Float

// Master clock functions
@_silgen_name("AudioEngine_SetClockBPM")
func AudioEngine_SetClockBPM(_ handle: OpaquePointer, _ bpm: Float)

@_silgen_name("AudioEngine_SetClockRunning")
func AudioEngine_SetClockRunning(_ handle: OpaquePointer, _ running: Bool)

@_silgen_name("AudioEngine_SetClockStartSample")
func AudioEngine_SetClockStartSample(_ handle: OpaquePointer, _ startSample: UInt64)

@_silgen_name("AudioEngine_SetClockSwing")
func AudioEngine_SetClockSwing(_ handle: OpaquePointer, _ swing: Float)

@_silgen_name("AudioEngine_GetClockBPM")
func AudioEngine_GetClockBPM(_ handle: OpaquePointer) -> Float

@_silgen_name("AudioEngine_IsClockRunning")
func AudioEngine_IsClockRunning(_ handle: OpaquePointer) -> Bool

@_silgen_name("AudioEngine_SetClockOutputMode")
func AudioEngine_SetClockOutputMode(_ handle: OpaquePointer, _ outputIndex: Int32, _ mode: Int32)

@_silgen_name("AudioEngine_SetClockOutputWaveform")
func AudioEngine_SetClockOutputWaveform(_ handle: OpaquePointer, _ outputIndex: Int32, _ waveform: Int32)

@_silgen_name("AudioEngine_SetClockOutputDivision")
func AudioEngine_SetClockOutputDivision(_ handle: OpaquePointer, _ outputIndex: Int32, _ division: Int32)

@_silgen_name("AudioEngine_SetClockOutputLevel")
func AudioEngine_SetClockOutputLevel(_ handle: OpaquePointer, _ outputIndex: Int32, _ level: Float)

@_silgen_name("AudioEngine_SetClockOutputOffset")
func AudioEngine_SetClockOutputOffset(_ handle: OpaquePointer, _ outputIndex: Int32, _ offset: Float)

@_silgen_name("AudioEngine_SetClockOutputPhase")
func AudioEngine_SetClockOutputPhase(_ handle: OpaquePointer, _ outputIndex: Int32, _ phase: Float)

@_silgen_name("AudioEngine_SetClockOutputWidth")
func AudioEngine_SetClockOutputWidth(_ handle: OpaquePointer, _ outputIndex: Int32, _ width: Float)

@_silgen_name("AudioEngine_SetClockOutputDestination")
func AudioEngine_SetClockOutputDestination(_ handle: OpaquePointer, _ outputIndex: Int32, _ dest: Int32)

@_silgen_name("AudioEngine_SetClockOutputModAmount")
func AudioEngine_SetClockOutputModAmount(_ handle: OpaquePointer, _ outputIndex: Int32, _ amount: Float)

@_silgen_name("AudioEngine_SetClockOutputMuted")
func AudioEngine_SetClockOutputMuted(_ handle: OpaquePointer, _ outputIndex: Int32, _ muted: Bool)

@_silgen_name("AudioEngine_SetClockOutputSlowMode")
func AudioEngine_SetClockOutputSlowMode(_ handle: OpaquePointer, _ outputIndex: Int32, _ slow: Bool)

@_silgen_name("AudioEngine_GetClockOutputValue")
func AudioEngine_GetClockOutputValue(_ handle: OpaquePointer, _ outputIndex: Int32) -> Float

@_silgen_name("AudioEngine_GetModulationValue")
func AudioEngine_GetModulationValue(_ handle: OpaquePointer, _ destination: Int32) -> Float

// Multi-channel ring buffer processing (for AU plugin hosting)
@_silgen_name("AudioEngine_StartMultiChannelProcessing")
func AudioEngine_StartMultiChannelProcessing(_ handle: OpaquePointer)

@_silgen_name("AudioEngine_StopMultiChannelProcessing")
func AudioEngine_StopMultiChannelProcessing(_ handle: OpaquePointer)

@_silgen_name("AudioEngine_ReadChannelFromRingBuffer")
func AudioEngine_ReadChannelFromRingBuffer(_ handle: OpaquePointer, _ channelIndex: Int32, _ left: UnsafeMutablePointer<Float>?, _ right: UnsafeMutablePointer<Float>?, _ numFrames: Int32)

@_silgen_name("AudioEngine_GetRingBufferReadableFrames")
func AudioEngine_GetRingBufferReadableFrames(_ handle: OpaquePointer, _ channelIndex: Int32) -> Int

@_silgen_name("AudioEngine_RenderAndReadMultiChannel")
func AudioEngine_RenderAndReadMultiChannel(_ handle: OpaquePointer, _ channelIndex: Int32, _ sampleTime: Int64, _ left: UnsafeMutablePointer<Float>?, _ right: UnsafeMutablePointer<Float>?, _ numFrames: Int32)

@_silgen_name("AudioEngine_RenderAndReadLegacyBus")
func AudioEngine_RenderAndReadLegacyBus(_ handle: OpaquePointer, _ busIndex: Int32, _ sampleTime: Int64, _ left: UnsafeMutablePointer<Float>?, _ right: UnsafeMutablePointer<Float>?, _ numFrames: Int32)

// Recording control
@_silgen_name("AudioEngine_StartRecording")
func AudioEngine_StartRecording(_ handle: OpaquePointer, _ reelIndex: Int32, _ mode: Int32, _ sourceType: Int32, _ sourceChannel: Int32)

@_silgen_name("AudioEngine_StopRecording")
func AudioEngine_StopRecording(_ handle: OpaquePointer, _ reelIndex: Int32)

@_silgen_name("AudioEngine_SetRecordingFeedback")
func AudioEngine_SetRecordingFeedback(_ handle: OpaquePointer, _ reelIndex: Int32, _ feedback: Float)

@_silgen_name("AudioEngine_IsRecording")
func AudioEngine_IsRecording(_ handle: OpaquePointer, _ reelIndex: Int32) -> Bool

@_silgen_name("AudioEngine_GetRecordingPosition")
func AudioEngine_GetRecordingPosition(_ handle: OpaquePointer, _ reelIndex: Int32) -> Float

@_silgen_name("AudioEngine_WriteExternalInput")
func AudioEngine_WriteExternalInput(_ handle: OpaquePointer, _ left: UnsafePointer<Float>?, _ right: UnsafePointer<Float>?, _ numFrames: Int32)

/// Main audio engine wrapper that manages CoreAudio and the synthesis engine
@MainActor
class AudioEngineWrapper: ObservableObject {
    enum NoteTargetMask: UInt8 {
        case plaits = 1
        case rings = 2
        case both = 3
    }

    // MARK: - Published Properties

    @Published var isRunning: Bool = false
    @Published var cpuLoad: Double = 0.0
    @Published var latency: Double = 0.0
    @Published var sampleRate: Double = 48000.0
    @Published var bufferSize: Int = 256

    // Audio device selection
    @Published var availableInputDevices: [AudioDevice] = []
    @Published var availableOutputDevices: [AudioDevice] = []
    @Published var selectedInputDevice: AudioDevice?
    @Published var selectedOutputDevice: AudioDevice?

    // Waveform data for display (indexed by reel)
    @Published var waveformOverviews: [Int: [Float]] = [:]

    // Loaded audio file paths for project save/load (indexed by reel)
    @Published var loadedAudioFilePaths: [Int: URL] = [:]

    // Playhead positions for granular voices (0-1, indexed by voice)
    @Published var granularPositions: [Int: Float] = [:]

    // Level meters (0=Plaits, 1=Rings, 2-5=track voices)
    @Published var channelLevels: [Float] = [0, 0, 0, 0, 0, 0]
    @Published var masterLevelL: Float = 0
    @Published var masterLevelR: Float = 0

    // MARK: - Recording

    enum RecordMode: Int, Sendable {
        case oneShot = 0
        case liveLoop = 1
    }

    enum RecordSourceType: Int, Sendable {
        case external = 0       // Mic/line input
        case internalVoice = 1  // Another voice (pre-mixer)
    }

    struct RecordingUIState {
        var isRecording: Bool = false
        var mode: RecordMode = .oneShot
        var sourceType: RecordSourceType = .external
        var sourceChannel: Int = 0  // 0=Plaits,1=Rings,2=Gran1,3=Loop1,4=Loop2,5=Gran4
        var feedback: Float = 0.0
    }

    @Published var recordingStates: [Int: RecordingUIState] = [:]
    @Published var recordingPositions: [Int: Float] = [:]

    // MARK: - Audio Graph Mode

    enum AudioGraphMode {
        case legacy      // Single stereo source with C++ mixing/effects
        case multiChannel // 6 separate channels with AU plugin support
    }

    @Published var graphMode: AudioGraphMode = .legacy  // Safe default until multi-channel graph is stable

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var outputNode: AVAudioOutputNode?
    private var inputTapInstalled = false
    private var sourceNode: AVAudioSourceNode?  // Legacy mode
    private var legacySendSourceNodes: [AVAudioSourceNode] = []
    private var legacySendReturnMixers: [AVAudioMixerNode] = []
    private var legacyAttachedSendAUs: [AVAudioUnit?] = [nil, nil]
    private var legacySendLevelsA: [Float] = Array(repeating: 0, count: 6)
    private var legacySendLevelsB: [Float] = Array(repeating: 0, count: 6)
    @MainActor private var legacySendRebuildInProgress: Set<Int> = []
    /// Serial queue for audio graph mutations (stop/attach/connect/start).
    /// Keeps heavy AVAudioEngine operations off MainActor to prevent UI stalls.
    private let graphMutationQueue = DispatchQueue(label: "com.grainulator.graph-mutation", qos: .userInitiated)

    // C++ Audio Engine Bridge
    // Read-only access is thread-safe (set once during init, never changed).
    // Used by the sequencer's clock queue to call thread-safe C bridge functions directly.
    private(set) var cppEngineHandle: OpaquePointer?

    // Audio buffer for processing
    private var audioFormat: AVAudioFormat?
    private let processingQueue = DispatchQueue(label: "com.grainulator.audio", qos: .userInteractive)

    // Performance monitoring
    private var performanceTimer: Timer?
    private var lastCPUCheckTime: Date = Date()
    private var multiChannelHealthCheckPending = false
    private let multiChannelRenderTimeLock = NSLock()
    private var multiChannelNextSyntheticSampleTime: Int64 = 0
    private var multiChannelLastHostTime: UInt64 = 0
    private var multiChannelLastResolvedSampleTime: Int64 = 0
    private var multiChannelHasResolvedHostTime = false
    private let liveEventLeadSamples: UInt64 = 64
    private let manualPlaitsGateNote: UInt8 = 60

    // MARK: - Multi-Channel Graph (AU Plugin Mode)

    // 6 source nodes (one per mixer channel)
    private var channelSourceNodes: [AVAudioSourceNode] = []

    // Per-channel mixer nodes (for gain/pan before inserts)
    private var channelMixerNodes: [AVAudioMixerNode] = []

    // Master mixer
    private var masterMixer: AVAudioMixerNode?

    // Send effect buses
    private var sendDelayMixer: AVAudioMixerNode?
    private var sendReverbMixer: AVAudioMixerNode?

    // AU Insert slots (managed by MixerState)
    // These hold references to inserted AU plugins per channel
    // Format: channelInsertSlots[channelIndex][slotIndex]
    private var channelInsertSlots: [[AUInsertSlot]] = []

    // Send effects (AU plugins for delay/reverb)
    private var sendDelaySlot: AUSendSlot?
    private var sendReverbSlot: AUSendSlot?

    // Channel names for debugging
    private let channelNames = ["Plaits", "Rings", "Granular1", "Looper1", "Looper2", "Granular4"]

    // MARK: - Initialization

    init() {
        // Create C++ engine
        cppEngineHandle = AudioEngine_Create()

        // Setup audio engine and format first
        setupAudioEngine()
        enumerateAudioDevices()
        setupPerformanceMonitoring()

        // Initialize C++ engine
        if let handle = cppEngineHandle {
            _ = AudioEngine_Initialize(handle, Int32(sampleRate), Int32(bufferSize))
        }

        // Setup audio graph based on mode.
        // Multi-channel mode now uses a pull-synchronous render coordinator so all
        // source node callbacks share the same rendered quantum per sampleTime.
        if graphMode == .multiChannel {
            setupMultiChannelGraph()
        } else {
            setupLegacyGraph()
        }
    }

    // MARK: - Audio Setup

    /// Sets up the AVAudioEngine and audio format (called once during init)
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        outputNode = engine.outputNode

        // Configure audio format (48kHz, stereo, float)
        audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: false
        )

        // Prepare the engine
        engine.prepare()
    }

    /// Sets up legacy mode audio graph with dedicated AU send-return buses.
    private func setupLegacyGraph() {
        guard let engine = audioEngine, let format = audioFormat else { return }
        resetMultiChannelRenderTimeline()
        ensureLegacySendSlots()
        legacyAttachedSendAUs = [nil, nil]

        // Dry mix source (bus 0 from C++).
        sourceNode = AVAudioSourceNode { [weak self] _, timestamp, frameCount, audioBufferList in
            guard let self = self, let handle = self.cppEngineHandle else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let ts = timestamp.pointee
            let sampleTime = self.resolveMultiChannelSampleTime(timestamp: ts, frameCount: frameCount)
            if let leftPtr = ablPointer[0].mData?.assumingMemoryBound(to: Float.self),
               let rightPtr = ablPointer[1].mData?.assumingMemoryBound(to: Float.self) {
                AudioEngine_RenderAndReadLegacyBus(
                    handle,
                    0,
                    sampleTime,
                    leftPtr,
                    rightPtr,
                    Int32(frameCount)
                )
            }
            return noErr
        }

        guard let sourceNode else { return }
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)

        // Two aux send source nodes (bus 1 = Send A, bus 2 = Send B).
        // Nodes are created and stored but NOT attached/connected until a plugin
        // is actually loaded via rebuildLegacySendChain. This avoids dangling
        // source nodes that pull audio from the C++ engine for no reason, and
        // prevents crashes when disconnecting nodes that were never connected.
        legacySendSourceNodes.removeAll()
        legacySendReturnMixers.removeAll()
        for bus in 0..<2 {
            let sendSource = AVAudioSourceNode { [weak self] _, timestamp, frameCount, audioBufferList in
                guard let self = self, let handle = self.cppEngineHandle else { return noErr }
                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let ts = timestamp.pointee
                let sampleTime = self.resolveMultiChannelSampleTime(timestamp: ts, frameCount: frameCount)
                if let leftPtr = ablPointer[0].mData?.assumingMemoryBound(to: Float.self),
                   let rightPtr = ablPointer[1].mData?.assumingMemoryBound(to: Float.self) {
                    AudioEngine_RenderAndReadLegacyBus(
                        handle,
                        Int32(bus + 1),
                        sampleTime,
                        leftPtr,
                        rightPtr,
                        Int32(frameCount)
                    )
                }
                return noErr
            }

            let returnMixer = AVAudioMixerNode()
            returnMixer.outputVolume = bus == 0 ? (sendDelaySlot?.returnLevelSafe ?? 0.5) : (sendReverbSlot?.returnLevelSafe ?? 0.5)

            // Only store the nodes; don't attach or connect yet.
            // rebuildLegacySendChain will attach when a plugin is loaded.
            legacySendSourceNodes.append(sendSource)
            legacySendReturnMixers.append(returnMixer)
        }
    }

    private func ensureLegacySendSlots() {
        if sendDelaySlot == nil {
            let slot = AUSendSlot(busIndex: 0, busName: "Delay")
            slot.onParameterChanged = { [weak self] in
                Task { @MainActor in
                    self?.updateLegacySendReturnGain(0)
                }
            }
            sendDelaySlot = slot
        }

        if sendReverbSlot == nil {
            let slot = AUSendSlot(busIndex: 1, busName: "Reverb")
            slot.onParameterChanged = { [weak self] in
                Task { @MainActor in
                    self?.updateLegacySendReturnGain(1)
                }
            }
            sendReverbSlot = slot
        }
    }

    @MainActor
    private func updateLegacySendReturnGain(_ busIndex: Int) {
        guard busIndex >= 0, busIndex < legacySendReturnMixers.count else { return }
        let slot = busIndex == 0 ? sendDelaySlot : sendReverbSlot
        legacySendReturnMixers[busIndex].outputVolume = slot?.returnLevelSafe ?? 0
    }

    private func restartEngineAfterLegacyGraphMutation(_ engine: AVAudioEngine) {
        engine.prepare()
        do {
            try engine.start()
            isRunning = true
            return
        } catch {
            print("✗ Failed to restart engine after legacy send rebuild: \(error)")
        }

        // One recovery attempt: stop/reset/re-prepare/start.
        engine.stop()
        engine.reset()
        engine.prepare()
        do {
            try engine.start()
            isRunning = true
            print("✓ Recovered audio engine after legacy send rebuild")
        } catch {
            isRunning = false
            print("✗ Audio engine recovery failed after legacy send rebuild: \(error)")
        }
    }

    @MainActor
    private func rebuildLegacySendChain(_ busIndex: Int, engineAlreadyStopped: Bool = false) {
        guard !legacySendRebuildInProgress.contains(busIndex) else { return }
        legacySendRebuildInProgress.insert(busIndex)

        guard let engine = audioEngine,
              let format = audioFormat,
              busIndex >= 0,
              busIndex < legacySendSourceNodes.count,
              busIndex < legacySendReturnMixers.count else {
            legacySendRebuildInProgress.remove(busIndex)
            return
        }

        // Capture everything we need from MainActor-isolated state
        let source = legacySendSourceNodes[busIndex]
        let returnMixer = legacySendReturnMixers[busIndex]
        let slot = busIndex == 0 ? sendDelaySlot : sendReverbSlot
        guard let slot else {
            legacySendRebuildInProgress.remove(busIndex)
            return
        }
        let currentAU = slot.audioUnit
        let previousAU = busIndex < legacyAttachedSendAUs.count ? legacyAttachedSendAUs[busIndex] : nil
        let hasPlugin = slot.hasPluginSafe
        let isBypassed = slot.isBypassedSafe
        let needsRestart = isRunning && !engineAlreadyStopped

        // Pre-update: clear tracked AU if swapping
        if let previousAU, previousAU !== currentAU, busIndex < legacyAttachedSendAUs.count {
            legacyAttachedSendAUs[busIndex] = nil
        }

        updateLegacySendReturnGain(busIndex)

        // Dispatch heavy engine work off MainActor
        graphMutationQueue.async { [weak self] in
            if needsRestart {
                engine.stop()
            }

            // Detach previous AU plugin if it was swapped out.
            if let previousAU, previousAU !== currentAU {
                engine.disconnectNodeInput(previousAU)
                engine.disconnectNodeOutput(previousAU)
                if engine.attachedNodes.contains(previousAU) {
                    engine.detach(previousAU)
                }
            }

            // Disconnect current AU if it's in the graph.
            if let au = currentAU, engine.attachedNodes.contains(au) {
                engine.disconnectNodeInput(au)
                engine.disconnectNodeOutput(au)
            }

            // Safely disconnect source and return mixer.
            if engine.attachedNodes.contains(source) {
                engine.disconnectNodeOutput(source)
            }
            if engine.attachedNodes.contains(returnMixer) {
                engine.disconnectNodeInput(returnMixer)
            }

            if !hasPlugin {
                // No plugin: fully detach source and return mixer.
                if engine.attachedNodes.contains(source) {
                    engine.detach(source)
                }
                if engine.attachedNodes.contains(returnMixer) {
                    engine.disconnectNodeOutput(returnMixer)
                    engine.detach(returnMixer)
                }
            } else {
                // Ensure source and return mixer are attached.
                if !engine.attachedNodes.contains(source) {
                    engine.attach(source)
                }
                if !engine.attachedNodes.contains(returnMixer) {
                    engine.attach(returnMixer)
                }
                engine.connect(returnMixer, to: engine.mainMixerNode, format: format)

                if let au = currentAU, !isBypassed {
                    if !engine.attachedNodes.contains(au) {
                        engine.attach(au)
                    }
                    engine.connect(source, to: au, format: format)
                    engine.connect(au, to: returnMixer, format: format)
                } else {
                    engine.connect(source, to: returnMixer, format: format)
                }
            }

            if needsRestart {
                engine.prepare()
                do {
                    try engine.start()
                } catch {
                    print("✗ Failed to restart engine after send chain rebuild: \(error)")
                    // Recovery attempt
                    engine.stop()
                    engine.reset()
                    engine.prepare()
                    do {
                        try engine.start()
                        print("✓ Recovered audio engine after send chain rebuild")
                    } catch {
                        print("✗ Audio engine recovery failed: \(error)")
                    }
                }
            }

            // Update MainActor state after graph work completes
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isRunning = engine.isRunning
                if hasPlugin, let au = currentAU, !isBypassed, busIndex < self.legacyAttachedSendAUs.count {
                    self.legacyAttachedSendAUs[busIndex] = au
                } else if busIndex < self.legacyAttachedSendAUs.count {
                    self.legacyAttachedSendAUs[busIndex] = nil
                }
                self.legacySendRebuildInProgress.remove(busIndex)
            }
        }
    }

    // MARK: - Multi-Channel Audio Setup (AU Plugin Mode)

    /// Switches to multi-channel mode with AU plugin support
    func enableMultiChannelMode() {
        guard graphMode == .legacy else { return }

        // Stop engine if running
        let wasRunning = isRunning
        if wasRunning {
            stop()
        }

        // Teardown legacy graph
        teardownLegacyGraph()

        // Setup multi-channel graph
        setupMultiChannelGraph()

        graphMode = .multiChannel

        // Restart if was running
        if wasRunning {
            start()
        }

        print("✓ Switched to multi-channel AU mode")
    }

    /// Switches back to legacy mode (internal C++ mixing/effects)
    func enableLegacyMode() {
        guard graphMode == .multiChannel else { return }

        // Stop engine if running
        let wasRunning = isRunning
        if wasRunning {
            stop()
        }

        // Teardown multi-channel graph
        teardownMultiChannelGraph()

        // Re-setup legacy graph
        setupLegacyGraph()

        graphMode = .legacy

        // Restart if was running
        if wasRunning {
            start()
        }

        print("✓ Switched to legacy mode")
    }

    private func teardownLegacyGraph() {
        guard let engine = audioEngine else { return }

        if let source = sourceNode {
            if engine.attachedNodes.contains(source) {
                engine.disconnectNodeOutput(source)
                engine.detach(source)
            }
            sourceNode = nil
        }

        for node in legacySendSourceNodes {
            if engine.attachedNodes.contains(node) {
                engine.disconnectNodeOutput(node)
                engine.detach(node)
            }
        }
        legacySendSourceNodes.removeAll()

        for mixer in legacySendReturnMixers {
            if engine.attachedNodes.contains(mixer) {
                engine.disconnectNodeOutput(mixer)
                engine.detach(mixer)
            }
        }
        legacySendReturnMixers.removeAll()

        for attachedAU in legacyAttachedSendAUs {
            if let attachedAU, engine.attachedNodes.contains(attachedAU) {
                engine.disconnectNodeOutput(attachedAU)
                engine.disconnectNodeInput(attachedAU)
                engine.detach(attachedAU)
            }
        }
        legacyAttachedSendAUs = [nil, nil]
    }

    private func teardownMultiChannelGraph() {
        // Stop background processing thread first
        if let handle = cppEngineHandle {
            AudioEngine_StopMultiChannelProcessing(handle)
        }

        guard let engine = audioEngine else { return }

        // Disconnect and detach all channel source nodes
        for node in channelSourceNodes {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        channelSourceNodes.removeAll()

        // Disconnect and detach channel mixer nodes
        for node in channelMixerNodes {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        channelMixerNodes.removeAll()

        // Disconnect and detach send mixers
        if let sendDelay = sendDelayMixer {
            engine.disconnectNodeOutput(sendDelay)
            engine.detach(sendDelay)
            sendDelayMixer = nil
        }

        if let sendReverb = sendReverbMixer {
            engine.disconnectNodeOutput(sendReverb)
            engine.detach(sendReverb)
            sendReverbMixer = nil
        }

        // Disconnect and detach master mixer
        if let master = masterMixer {
            engine.disconnectNodeOutput(master)
            engine.detach(master)
            masterMixer = nil
        }

        // Unload any AU plugins
        for channelSlots in channelInsertSlots {
            for slot in channelSlots {
                if let au = slot.audioUnit {
                    engine.disconnectNodeOutput(au)
                    engine.detach(au)
                }
            }
        }
        channelInsertSlots.removeAll()

        // Clear send effect AUs
        if let delaySlot = sendDelaySlot, let au = delaySlot.audioUnit {
            engine.disconnectNodeOutput(au)
            engine.detach(au)
        }
        sendDelaySlot = nil

        if let reverbSlot = sendReverbSlot, let au = reverbSlot.audioUnit {
            engine.disconnectNodeOutput(au)
            engine.detach(au)
        }
        sendReverbSlot = nil

        resetMultiChannelRenderTimeline()
    }

    private func setupMultiChannelGraph() {
        guard let engine = audioEngine, audioFormat != nil else {
            print("✗ Cannot setup multi-channel graph: engine or format nil")
            return
        }

        let numChannels = 6
        resetMultiChannelRenderTimeline()

        // Route channel strips directly to mainMixerNode in AU mode.
        // This avoids an extra aggregation mixer that has proven brittle with
        // multiple source-node pulls on some hosts/devices.
        masterMixer = nil

        // Create send effect mixers
        sendDelayMixer = AVAudioMixerNode()
        sendReverbMixer = AVAudioMixerNode()
        engine.attach(sendDelayMixer!)
        engine.attach(sendReverbMixer!)

        // Initialize send effect slots
        sendDelaySlot = AUSendSlot(busIndex: 0, busName: "Delay")
        sendReverbSlot = AUSendSlot(busIndex: 1, busName: "Reverb")

        // Create 6 channel source nodes.
        // Each render quantum is generated once by whichever callback arrives first
        // for a given sampleTime, then copied per channel.
        for channelIndex in 0..<numChannels {
            let sourceNode = AVAudioSourceNode { [weak self] _, timestamp, frameCount, audioBufferList in
                guard let self = self,
                      let handle = self.cppEngineHandle else {
                    return noErr
                }

                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let ts = timestamp.pointee
                let sampleTime = self.resolveMultiChannelSampleTime(timestamp: ts, frameCount: frameCount)

                if let leftPtr = ablPointer[0].mData?.assumingMemoryBound(to: Float.self),
                   let rightPtr = ablPointer[1].mData?.assumingMemoryBound(to: Float.self) {
                    AudioEngine_RenderAndReadMultiChannel(
                        handle,
                        Int32(channelIndex),
                        sampleTime,
                        leftPtr,
                        rightPtr,
                        Int32(frameCount)
                    )
                }

                return noErr
            }

            engine.attach(sourceNode)
            channelSourceNodes.append(sourceNode)

            // Create channel mixer node
            let channelMixer = AVAudioMixerNode()
            engine.attach(channelMixer)
            channelMixerNodes.append(channelMixer)

            // Initialize insert slots for this channel
            let slot1 = AUInsertSlot(slotIndex: 0)
            let slot2 = AUInsertSlot(slotIndex: 1)

            // Set up callbacks for audio graph rebuild when plugins change
            slot1.onAudioUnitChanged = { [weak self] _ in
                Task { @MainActor in
                    self?.rebuildChannelChain(channelIndex)
                }
            }
            slot2.onAudioUnitChanged = { [weak self] _ in
                Task { @MainActor in
                    self?.rebuildChannelChain(channelIndex)
                }
            }

            channelInsertSlots.append([slot1, slot2])

            // Connect: source → channel mixer (initially, no inserts)
            engine.connect(sourceNode, to: channelMixer, format: nil)

            // Route each channel strip to AVAudioEngine's main mixer.
            engine.connect(channelMixer, to: engine.mainMixerNode, format: nil)
        }

        // Debug: verify connections
        print("  outputNode input format: \(outputNode!.inputFormat(forBus: 0))")
        print("  channelSourceNodes[0] output format: \(channelSourceNodes[0].outputFormat(forBus: 0))")
        print("  channelMixerNodes[0] numberOfInputs: \(channelMixerNodes[0].numberOfInputs)")
        print("  channelMixerNodes[0] outputFormat: \(channelMixerNodes[0].outputFormat(forBus: 0))")

        engine.prepare()
        print("✓ Multi-channel audio graph setup complete (pull-synchronous mode)")
    }

    /// Reset synthetic render timeline used when host does not provide sampleTime-valid timestamps.
    private func resetMultiChannelRenderTimeline() {
        multiChannelRenderTimeLock.lock()
        multiChannelNextSyntheticSampleTime = 0
        multiChannelLastHostTime = 0
        multiChannelLastResolvedSampleTime = 0
        multiChannelHasResolvedHostTime = false
        multiChannelRenderTimeLock.unlock()
    }

    /// Resolve a stable sample-time for the multi-channel render path.
    /// Some hosts provide hostTime but not sampleTime on source-node callbacks.
    private func resolveMultiChannelSampleTime(timestamp: AudioTimeStamp, frameCount: AVAudioFrameCount) -> Int64 {
        if timestamp.mFlags.contains(.sampleTimeValid) {
            return Int64(timestamp.mSampleTime)
        }

        let frames = Int64(frameCount)
        multiChannelRenderTimeLock.lock()
        defer { multiChannelRenderTimeLock.unlock() }

        if timestamp.mFlags.contains(.hostTimeValid) {
            let hostTime = timestamp.mHostTime
            if !multiChannelHasResolvedHostTime || hostTime != multiChannelLastHostTime {
                multiChannelLastHostTime = hostTime
                multiChannelLastResolvedSampleTime = multiChannelNextSyntheticSampleTime
                multiChannelNextSyntheticSampleTime += frames
                multiChannelHasResolvedHostTime = true
            }
            return multiChannelLastResolvedSampleTime
        }

        // As a last resort, advance monotonically per callback.
        let resolved = multiChannelNextSyntheticSampleTime
        multiChannelLastResolvedSampleTime = resolved
        multiChannelNextSyntheticSampleTime += frames
        multiChannelHasResolvedHostTime = true
        return resolved
    }

    /// Rebuilds the audio chain for a specific channel when AU plugins change
    private func rebuildChannelChain(_ channelIndex: Int) {
        guard graphMode == .multiChannel,
              let engine = audioEngine,
              let format = audioFormat,
              channelIndex < channelSourceNodes.count,
              channelIndex < channelMixerNodes.count,
              channelIndex < channelInsertSlots.count else {
            return
        }

        let wasRunning = isRunning
        if wasRunning {
            engine.pause()
        }

        let sourceNode = channelSourceNodes[channelIndex]
        let channelMixer = channelMixerNodes[channelIndex]
        let slots = channelInsertSlots[channelIndex]

        // Disconnect existing chain
        engine.disconnectNodeOutput(sourceNode)
        for slot in slots {
            if let au = slot.audioUnit {
                engine.disconnectNodeOutput(au)
            }
        }

        // Build new chain: source → [insert1] → [insert2] → channelMixer
        var previousNode: AVAudioNode = sourceNode

        for slot in slots {
            if let au = slot.audioUnit, !slot.isBypassed {
                // Ensure AU is attached
                if !engine.attachedNodes.contains(au) {
                    engine.attach(au)
                }
                engine.connect(previousNode, to: au, format: format)
                previousNode = au
            }
        }

        // Connect final node to channel mixer
        engine.connect(previousNode, to: channelMixer, format: format)

        if wasRunning {
            do {
                try engine.start()
            } catch {
                print("✗ Failed to restart engine after chain rebuild: \(error)")
            }
        }

        print("✓ Rebuilt channel \(channelIndex) (\(channelNames[channelIndex])) chain")
    }

    // MARK: - AU Insert Management

    /// Gets the insert slots for a channel
    func getInsertSlots(forChannel channelIndex: Int) -> [AUInsertSlot]? {
        guard channelIndex < channelInsertSlots.count else { return nil }
        return channelInsertSlots[channelIndex]
    }

    /// Gets slot data as a value type (avoids @ObservedObject crashes in SwiftUI)
    /// Uses thread-safe accessors so SwiftUI can safely call this from any thread
    func getInsertSlotData(channelIndex: Int, slotIndex: Int) -> InsertSlotData {
        guard channelIndex < channelInsertSlots.count,
              slotIndex < channelInsertSlots[channelIndex].count else {
            return InsertSlotData.empty
        }

        let slot = channelInsertSlots[channelIndex][slotIndex]
        // Use thread-safe accessors for the values SwiftUI will read during view body evaluation
        // This prevents crashes when SwiftUI's gesture system evaluates views
        return InsertSlotData(
            hasPlugin: slot.hasPluginSafe,
            pluginName: slot.pluginNameSafe,
            pluginInfo: slot.pluginInfo,  // Only accessed on MainActor anyway
            isBypassed: slot.isBypassedSafe,
            isLoading: slot.isLoadingSafe
        )
    }

    /// Loads an AU plugin into an insert slot
    func loadInsertPlugin(_ pluginInfo: AUPluginInfo, channelIndex: Int, slotIndex: Int, using pluginManager: AUPluginManager) async throws {
        if graphMode == .legacy {
            enableMultiChannelMode()
        }
        guard graphMode == .multiChannel else {
            throw AUPluginError.instantiationFailed
        }

        guard channelIndex < channelInsertSlots.count,
              slotIndex < channelInsertSlots[channelIndex].count else {
            throw AUPluginError.instantiationFailed
        }

        let slot = channelInsertSlots[channelIndex][slotIndex]
        try await slot.loadPlugin(pluginInfo, using: pluginManager)

        // The onAudioUnitChanged callback will trigger rebuildChannelChain
    }

    /// Unloads an AU plugin from an insert slot
    func unloadInsertPlugin(channelIndex: Int, slotIndex: Int) {
        guard channelIndex < channelInsertSlots.count,
              slotIndex < channelInsertSlots[channelIndex].count else {
            return
        }

        let slot = channelInsertSlots[channelIndex][slotIndex]

        // Detach from engine if attached
        if let au = slot.audioUnit, let engine = audioEngine {
            engine.disconnectNodeOutput(au)
            engine.detach(au)
        }

        slot.unloadPlugin()
        // The onAudioUnitChanged callback will trigger rebuildChannelChain
    }

    /// Toggles bypass state for an insert slot (safe for use from button actions)
    func toggleInsertBypass(channelIndex: Int, slotIndex: Int) {
        guard channelIndex < channelInsertSlots.count,
              slotIndex < channelInsertSlots[channelIndex].count else {
            return
        }

        let slot = channelInsertSlots[channelIndex][slotIndex]
        slot.setBypass(!slot.isBypassed)
        rebuildChannelChain(channelIndex)
    }

    /// Gets the send delay slot
    func getSendDelaySlot() -> AUSendSlot? {
        return sendDelaySlot
    }

    /// Gets the send reverb slot
    func getSendReverbSlot() -> AUSendSlot? {
        return sendReverbSlot
    }

    /// Toggles bypass state for a send effect slot (safe for use from button actions)
    @MainActor
    func toggleSendBypass(busIndex: Int) {
        let slot = busIndex == 0 ? sendDelaySlot : sendReverbSlot
        guard let slot = slot else { return }
        slot.setBypass(!slot.isBypassed)
        if graphMode == .legacy {
            rebuildLegacySendChain(busIndex)
        }
    }

    /// Unloads a send effect plugin (safe for use from button actions)
    @MainActor
    func unloadSendPlugin(busIndex: Int) {
        let slot = busIndex == 0 ? sendDelaySlot : sendReverbSlot
        guard let slot = slot else { return }

        // Unload the plugin (clears audioUnit from slot).
        slot.unloadPlugin()

        // Rebuild the send chain, which will detach the source and return
        // mixer nodes since there's no plugin loaded anymore.
        // rebuildLegacySendChain handles engine pause/restart internally.
        if graphMode == .legacy {
            rebuildLegacySendChain(busIndex)
        }
    }

    /// Gets the AVAudioUnit for a send slot (MainActor only, for presenting plugin UI)
    @MainActor
    func getSendAudioUnit(busIndex: Int) -> AVAudioUnit? {
        let slot = busIndex == 0 ? sendDelaySlot : sendReverbSlot
        return slot?.audioUnit
    }

    /// Gets the raw AUSendSlot for snapshot/restore operations
    func getSendSlot(busIndex: Int) -> AUSendSlot? {
        return busIndex == 0 ? sendDelaySlot : sendReverbSlot
    }

    /// Gets send slot data as a value type (avoids @ObservedObject crashes in SwiftUI)
    /// Uses thread-safe accessors so SwiftUI can safely call this from any thread
    func getSendSlotData(busIndex: Int) -> SendSlotData {
        let slot = busIndex == 0 ? sendDelaySlot : sendReverbSlot
        guard let slot = slot else {
            return SendSlotData.empty
        }

        // Use thread-safe accessors for the values SwiftUI will read during view body evaluation
        // This prevents crashes when SwiftUI's gesture system evaluates views
        return SendSlotData(
            hasPlugin: slot.hasPluginSafe,
            pluginName: slot.pluginNameSafe,
            pluginInfo: slot.pluginInfoSafe,
            isBypassed: slot.isBypassedSafe,
            isLoading: slot.isLoadingSafe,
            returnLevel: slot.returnLevelSafe
        )
    }

    /// Loads an AU plugin into a send slot
    @MainActor
    func loadSendPlugin(_ pluginInfo: AUPluginInfo, busIndex: Int, using pluginManager: AUPluginManager) async throws {
        let slot = busIndex == 0 ? sendDelaySlot : sendReverbSlot
        guard let slot = slot else {
            throw AUPluginError.instantiationFailed
        }

        // Instantiate the plugin first (async, out-of-process).
        // Don't stop the engine yet — the source node can keep running while
        // we wait for the plugin process to start up.
        try await slot.loadPlugin(pluginInfo, using: pluginManager)

        // Now rebuild the send chain, which will pause/restart the engine
        // as needed to attach and connect the new AU node.
        if graphMode == .legacy {
            rebuildLegacySendChain(busIndex)
        }
    }

    /// Gets a send return level using thread-safe slot access.
    func getSendReturnLevel(busIndex: Int) -> Float {
        let slot = busIndex == 0 ? sendDelaySlot : sendReverbSlot
        return slot?.returnLevelSafe ?? 0.5
    }

    /// Sets a send return level without exposing slot object lifetime to views.
    @MainActor
    func setSendReturnLevel(busIndex: Int, level: Float) {
        let slot = busIndex == 0 ? sendDelaySlot : sendReverbSlot
        slot?.setReturnLevel(level)
        if graphMode == .legacy {
            updateLegacySendReturnGain(busIndex)
        }
    }

    /// Sets the send level for a channel (0-1)
    /// - Parameters:
    ///   - channelIndex: The channel index (0-5)
    ///   - sendIndex: 0 for delay, 1 for reverb
    ///   - level: The send level (0-1)
    func setSendLevel(channelIndex: Int, sendIndex: Int, level: Float) {
        guard graphMode == .multiChannel else {
            guard let handle = cppEngineHandle else { return }
            guard channelIndex >= 0, channelIndex < legacySendLevelsA.count else { return }
            let clamped = max(0, min(1, level))
            if sendIndex == 0 {
                legacySendLevelsA[channelIndex] = clamped
            } else if sendIndex == 1 {
                legacySendLevelsB[channelIndex] = clamped
            }
            AudioEngine_SetChannelSendLevel(handle, Int32(channelIndex), Int32(sendIndex), clamped)
            return
        }

        guard channelIndex >= 0, channelIndex < channelMixerNodes.count else { return }

        // In multi-channel mode, adjust only this channel's send tap level.
        let mixer = sendIndex == 0 ? sendDelayMixer : sendReverbMixer
        guard let mixer, let destination = channelMixerNodes[channelIndex].destination(forMixer: mixer, bus: 0) else {
            return
        }
        destination.volume = level
    }

    private func enumerateAudioDevices() {
        // Get all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else { return }

        // Query each device
        var inputs: [AudioDevice] = []
        var outputs: [AudioDevice] = []

        for deviceID in deviceIDs {
            if let device = AudioDevice(deviceID: deviceID) {
                if device.hasInputChannels {
                    inputs.append(device)
                }
                if device.hasOutputChannels {
                    outputs.append(device)
                }
            }
        }

        availableInputDevices = inputs
        availableOutputDevices = outputs

        // Select default devices
        selectedInputDevice = inputs.first
        selectedOutputDevice = outputs.first
    }

    // MARK: - Control Methods

    func start() {
        guard let engine = audioEngine, !isRunning else { return }

        do {
            try engine.start()
            isRunning = true
            print("✓ Audio engine started - running=\(engine.isRunning)")
            print("  outputNode format: \(engine.outputNode.outputFormat(forBus: 0))")
            print("  mainMixerNode outputFormat: \(engine.mainMixerNode.outputFormat(forBus: 0))")
            print("  mainMixerNode inputFormat: \(engine.mainMixerNode.inputFormat(forBus: 0))")
            print("  mainMixerNode numberOfInputs: \(engine.mainMixerNode.numberOfInputs)")
            print("  attachedNodes count: \(channelSourceNodes.count) source nodes")

            scheduleMultiChannelHealthCheckIfNeeded()
        } catch {
            print("✗ Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        guard let engine = audioEngine, isRunning else { return }

        engine.stop()
        isRunning = false
        multiChannelHealthCheckPending = false
        print("✓ Audio engine stopped")
    }

    private func scheduleMultiChannelHealthCheckIfNeeded() {
        guard graphMode == .multiChannel,
              !multiChannelHealthCheckPending else {
            return
        }
        multiChannelHealthCheckPending = true
        let startSample = currentSampleTime()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            guard let self = self else { return }
            self.multiChannelHealthCheckPending = false
            guard self.isRunning, self.graphMode == .multiChannel else { return }

            let nowSample = self.currentSampleTime()
            if nowSample <= startSample {
                print("⚠ Multi-channel graph is not being pulled (sampleTime stuck at \(nowSample)); falling back to legacy mode")
                self.enableLegacyMode()
                if !self.isRunning {
                    self.start()
                }
            }
        }
    }

    func setBufferSize(_ size: Int) {
        bufferSize = size
        // TODO: Reconfigure audio engine with new buffer size
    }

    func setSampleRate(_ rate: Double) {
        sampleRate = rate
        // TODO: Reconfigure audio engine with new sample rate
    }

    // MARK: - Performance Monitoring

    private func setupPerformanceMonitoring() {
        // Poll at 15fps — still visually smooth for VU meters, halves SwiftUI rebuild load.
        // All C++ bridge reads are batched into local vars, then committed in one pass.
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
    }

    private func updatePerformanceMetrics() {
        guard let handle = cppEngineHandle else { return }

        // --- Batch-read all C++ values into local vars (no @Published writes yet) ---

        let newCpuLoad = ProcessInfo.processInfo.systemUptime.truncatingRemainder(dividingBy: 100.0) / 4.0
        let newLatency = (Double(bufferSize) / sampleRate) * 1000.0

        // Channel levels (6 channels)
        var newChannelLevels: [Float] = [0, 0, 0, 0, 0, 0]
        for i in 0..<6 {
            newChannelLevels[i] = AudioEngine_GetChannelLevel(handle, Int32(i))
        }

        // Master levels
        let newMasterL = AudioEngine_GetMasterLevel(handle, 0)
        let newMasterR = AudioEngine_GetMasterLevel(handle, 1)

        // Granular positions
        var newGranularPositions: [Int: Float] = [:]
        for voiceIndex in 0..<4 {
            let position = AudioEngine_GetGranularPosition(handle, Int32(voiceIndex))
            newGranularPositions[voiceIndex] = position
        }

        // Recording positions (for reels that are recording)
        var newRecordingPositions: [Int: Float] = [:]
        for (reelIndex, state) in recordingStates where state.isRecording {
            let pos = AudioEngine_GetRecordingPosition(handle, Int32(reelIndex))
            newRecordingPositions[reelIndex] = pos
            // Check if recording auto-stopped (hit 2-min limit)
            if !AudioEngine_IsRecording(handle, Int32(reelIndex)) {
                recordingStates[reelIndex]?.isRecording = false
                updateWaveformOverview(reelIndex: reelIndex)
            } else {
                // Refresh waveform while recording so user sees audio being written
                updateWaveformOverview(reelIndex: reelIndex)
            }
        }

        // --- Commit all values at once (minimizes @Published notification spread) ---
        cpuLoad = newCpuLoad
        latency = newLatency
        channelLevels = newChannelLevels
        masterLevelL = newMasterL
        masterLevelR = newMasterR
        granularPositions = newGranularPositions
        recordingPositions = newRecordingPositions
    }

    // MARK: - Parameter Control

    /// Maps a Swift ParameterID to the corresponding C++ parameter ID
    private func cppParameterID(for id: ParameterID) -> Int32 {
        switch id {
        // Granular parameters (Mangl-style) (0-12)
        case .granularSpeed: return 0
        case .granularPitch: return 1
        case .granularSize: return 2
        case .granularDensity: return 3
        case .granularJitter: return 4
        case .granularSpread: return 5
        case .granularPan: return 6
        case .granularFilterCutoff: return 7
        case .granularFilterResonance: return 8
        case .granularGain: return 9
        case .granularSend: return 10
        case .granularEnvelope: return 11
        case .granularDecay: return 12

        // Legacy compatibility (map to new params)
        case .granularSlide: return 0
        case .granularGeneSize: return 2
        case .granularVarispeed: return 0

        // Plaits parameters (13-23)
        case .plaitsModel: return 13
        case .plaitsHarmonics: return 14
        case .plaitsTimbre: return 15
        case .plaitsMorph: return 16
        case .plaitsFrequency: return 17
        case .plaitsLevel: return 18
        case .plaitsMidiNote: return 19
        case .plaitsLPGColor: return 20
        case .plaitsLPGDecay: return 21
        case .plaitsLPGAttack: return 22
        case .plaitsLPGBypass: return 23

        // Effects parameters (24-29)
        case .delayTime: return 24
        case .delayFeedback: return 25
        case .delayMix: return 26
        case .reverbSize: return 27
        case .reverbDamping: return 28
        case .reverbMix: return 29

        // Mixer parameters (32-35)
        case .voiceGain: return 32
        case .voicePan: return 33
        case .voiceSend: return 34
        case .masterGain: return 35

        // Master filter parameters (36-38)
        case .masterFilterCutoff: return 36
        case .masterFilterResonance: return 37
        case .masterFilterModel: return 38

        // Tape delay extended parameters (39-45)
        case .delayHeadMode: return 39
        case .delayWow: return 40
        case .delayFlutter: return 41
        case .delayTone: return 42
        case .delaySync: return 43
        case .delayTempo: return 44
        case .delaySubdivision: return 45

        // Granular extended parameters (46-48)
        case .granularFilterModel: return 46
        case .granularReverse: return 47
        case .granularMorph: return 48

        // Rings parameters (49-54)
        case .ringsModel: return 49
        case .ringsStructure: return 50
        case .ringsBrightness: return 51
        case .ringsDamping: return 52
        case .ringsPosition: return 53
        case .ringsLevel: return 54

        // Looper parameters (55-59)
        case .looperRate: return 55
        case .looperReverse: return 56
        case .looperLoopStart: return 57
        case .looperLoopEnd: return 58
        case .looperCut: return 59

        // Mixer timing alignment (60)
        case .voiceMicroDelay: return 60
        }
    }

    func setParameter(id: ParameterID, value: Float, voiceIndex: Int = 0) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_SetParameter(handle, cppParameterID(for: id), Int32(voiceIndex), value)
    }

    func getParameter(id: ParameterID, voiceIndex: Int = 0) -> Float {
        guard let handle = cppEngineHandle else { return 0 }
        return AudioEngine_GetParameter(handle, cppParameterID(for: id), Int32(voiceIndex))
    }

    func loadAudioFile(url: URL, reelIndex: Int) {
        // Load audio file asynchronously
        Task.detached { [weak self] in
            guard let self = self else { return }

            do {
                let audioFile = try AVAudioFile(forReading: url)
                let format = audioFile.processingFormat
                let frameCount = AVAudioFrameCount(audioFile.length)

                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    print("✗ Failed to create audio buffer")
                    return
                }

                try audioFile.read(into: buffer)

                // Extract float data
                guard let floatData = buffer.floatChannelData else {
                    print("✗ Failed to get float channel data")
                    return
                }

                let sampleCount = Int(buffer.frameLength)
                let sampleRate = Float(format.sampleRate)

                // Copy data to Swift arrays for safe transfer across actors
                var leftChannelData = [Float](repeating: 0, count: sampleCount)
                var rightChannelData = [Float](repeating: 0, count: sampleCount)

                for i in 0..<sampleCount {
                    leftChannelData[i] = floatData[0][i]
                    rightChannelData[i] = format.channelCount > 1 ? floatData[1][i] : floatData[0][i]
                }

                // Load into C++ engine on main actor
                await MainActor.run {
                    guard let handle = self.cppEngineHandle else { return }

                    let success = leftChannelData.withUnsafeBufferPointer { leftPtr in
                        rightChannelData.withUnsafeBufferPointer { rightPtr in
                            AudioEngine_LoadAudioData(
                                handle,
                                Int32(reelIndex),
                                leftPtr.baseAddress,
                                rightPtr.baseAddress,
                                sampleCount,
                                sampleRate
                            )
                        }
                    }

                    if success {
                        print("✓ Loaded audio file: \(url.lastPathComponent) (\(sampleCount) samples @ \(sampleRate)Hz)")

                        // Track loaded file path for project save/load
                        self.loadedAudioFilePaths[reelIndex] = url

                        // Generate waveform overview for display
                        self.updateWaveformOverview(reelIndex: reelIndex)
                    } else {
                        print("✗ Failed to load audio data into engine")
                    }
                }
            } catch {
                print("✗ Failed to read audio file: \(error)")
            }
        }
    }

    /// Clears the audio buffer for a reel
    func clearReel(_ reelIndex: Int) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_ClearReel(handle, Int32(reelIndex))
        waveformOverviews[reelIndex] = nil
        loadedAudioFilePaths[reelIndex] = nil
    }

    /// Gets the length of a reel in samples
    func getReelLength(_ reelIndex: Int) -> Int {
        guard let handle = cppEngineHandle else { return 0 }
        return AudioEngine_GetReelLength(handle, Int32(reelIndex))
    }

    /// Updates waveform overview for display
    func updateWaveformOverview(reelIndex: Int) {
        guard let handle = cppEngineHandle else { return }

        let overviewSize = 256
        // C++ GenerateOverview writes min/max pairs, so we need 2x the size
        var rawOverview = [Float](repeating: 0, count: overviewSize * 2)

        rawOverview.withUnsafeMutableBufferPointer { ptr in
            AudioEngine_GetWaveformOverview(handle, Int32(reelIndex), ptr.baseAddress, overviewSize)
        }

        // Extract just the max values for display (every other value starting at index 1)
        var overview = [Float](repeating: 0, count: overviewSize)
        for i in 0..<overviewSize {
            // Use max of abs(min) and abs(max) for symmetric display
            let minVal = rawOverview[i * 2]
            let maxVal = rawOverview[i * 2 + 1]
            overview[i] = max(abs(minVal), abs(maxVal))
        }

        waveformOverviews[reelIndex] = overview
    }

    /// Sets granular voice playback state
    func setGranularPlaying(voiceIndex: Int, playing: Bool) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_SetGranularPlaying(handle, Int32(voiceIndex), playing)
    }

    /// Seeks to a position in the granular voice (0-1)
    func setGranularPosition(voiceIndex: Int, position: Float) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_SetGranularPosition(handle, Int32(voiceIndex), position)
    }

    // MARK: - Recording Control

    /// Start recording into a reel buffer
    func startRecording(reelIndex: Int, mode: RecordMode, sourceType: RecordSourceType, sourceChannel: Int = 0) {
        guard let handle = cppEngineHandle else { return }

        if sourceType == .external && !inputTapInstalled {
            setupInputTap()
        }

        AudioEngine_StartRecording(
            handle,
            Int32(reelIndex),
            Int32(mode.rawValue),
            Int32(sourceType.rawValue),
            Int32(sourceChannel)
        )

        recordingStates[reelIndex] = RecordingUIState(
            isRecording: true,
            mode: mode,
            sourceType: sourceType,
            sourceChannel: sourceChannel,
            feedback: recordingStates[reelIndex]?.feedback ?? 0.0
        )
    }

    /// Stop recording for a reel
    func stopRecording(reelIndex: Int) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_StopRecording(handle, Int32(reelIndex))
        recordingStates[reelIndex]?.isRecording = false

        // Remove input tap if no external recordings remain active
        let anyExternalRecording = recordingStates.values.contains { $0.isRecording && $0.sourceType == .external }
        if !anyExternalRecording && inputTapInstalled {
            removeInputTap()
        }

        // Refresh waveform
        updateWaveformOverview(reelIndex: reelIndex)
    }

    /// Set feedback level for live loop recording (0=destructive, 1=full overdub)
    func setRecordingFeedback(reelIndex: Int, feedback: Float) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_SetRecordingFeedback(handle, Int32(reelIndex), feedback)
        recordingStates[reelIndex]?.feedback = feedback
    }

    /// Check if a reel is currently recording
    func isReelRecording(reelIndex: Int) -> Bool {
        guard let handle = cppEngineHandle else { return false }
        return AudioEngine_IsRecording(handle, Int32(reelIndex))
    }

    // MARK: - Input Tap Management

    private func setupInputTap() {
        guard let engine = audioEngine else { return }
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        // Only install if format is valid
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else { return }

        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, let handle = self.cppEngineHandle else { return }
            guard let floatData = buffer.floatChannelData else { return }

            let frameCount = Int32(buffer.frameLength)
            let leftPtr = floatData[0]
            let rightPtr = inputFormat.channelCount > 1 ? floatData[1] : floatData[0]

            AudioEngine_WriteExternalInput(handle, leftPtr, rightPtr, frameCount)
        }
        inputTapInstalled = true
    }

    private func removeInputTap() {
        guard let engine = audioEngine, inputTapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        inputTapInstalled = false
    }

    /// Gets active grain count across all voices
    func getActiveGrainCount() -> Int {
        guard let handle = cppEngineHandle else { return 0 }
        return Int(AudioEngine_GetActiveGrainCount(handle))
    }

    func triggerPlaits(_ state: Bool) {
        let eventSample = currentSampleTime() + liveEventLeadSamples
        if state {
            scheduleNoteOn(note: manualPlaitsGateNote, velocity: 110, sampleTime: eventSample, target: .plaits)
        } else {
            scheduleNoteOff(note: manualPlaitsGateNote, sampleTime: eventSample, target: .plaits)
        }
    }

    /// Polyphonic note on - allocates a voice and triggers it
    func noteOn(note: UInt8, velocity: UInt8) {
        let eventSample = currentSampleTime() + liveEventLeadSamples
        scheduleNoteOn(note: note, velocity: velocity, sampleTime: eventSample)
    }

    /// Polyphonic note off - releases the voice playing this note
    func noteOff(note: UInt8) {
        let eventSample = currentSampleTime() + liveEventLeadSamples
        scheduleNoteOff(note: note, sampleTime: eventSample)
    }

    /// Sends note-off for all MIDI notes to prevent stuck voices.
    func allNotesOff() {
        guard cppEngineHandle != nil else { return }
        let eventSample = currentSampleTime() + liveEventLeadSamples
        for note in 0...127 {
            scheduleNoteOff(note: UInt8(note), sampleTime: eventSample)
        }
    }

    /// Schedules note-on at an absolute sample time on the audio thread timeline.
    func scheduleNoteOn(note: UInt8, velocity: UInt8, sampleTime: UInt64) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_ScheduleNoteOn(handle, Int32(note), Int32(velocity), sampleTime)
    }

    /// Schedules note-off at an absolute sample time on the audio thread timeline.
    func scheduleNoteOff(note: UInt8, sampleTime: UInt64) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_ScheduleNoteOff(handle, Int32(note), sampleTime)
    }

    /// Schedules note-on to a specific synth target.
    func scheduleNoteOn(note: UInt8, velocity: UInt8, sampleTime: UInt64, target: NoteTargetMask) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_ScheduleNoteOnTarget(handle, Int32(note), Int32(velocity), sampleTime, target.rawValue)
    }

    /// Schedules note-off to a specific synth target.
    func scheduleNoteOff(note: UInt8, sampleTime: UInt64, target: NoteTargetMask) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_ScheduleNoteOffTarget(handle, Int32(note), sampleTime, target.rawValue)
    }

    /// Clears queued scheduled note events (does not stop already sounding voices).
    func clearScheduledNotes() {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_ClearScheduledNotes(handle)
    }

    /// Returns the audio engine's absolute processed sample counter.
    func currentSampleTime() -> UInt64 {
        guard let handle = cppEngineHandle else { return 0 }
        return AudioEngine_GetCurrentSampleTime(handle)
    }

    // MARK: - Master Clock

    /// Sets the master clock BPM
    func setMasterClockBPM(_ bpm: Float) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_SetClockBPM(handle, bpm)
    }

    /// Starts or stops the master clock
    func setClockRunning(_ running: Bool) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_SetClockRunning(handle, running)
    }

    /// Sets the clock start sample for synchronization with sequencer
    func setClockStartSample(_ startSample: UInt64) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_SetClockStartSample(handle, startSample)
    }

    /// Sets the global swing amount (0-1)
    func setClockSwing(_ swing: Float) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_SetClockSwing(handle, swing)
    }

    /// Gets the current master clock BPM
    func getMasterClockBPM() -> Float {
        guard let handle = cppEngineHandle else { return 120.0 }
        return AudioEngine_GetClockBPM(handle)
    }

    /// Returns whether the clock is running
    func isClockRunning() -> Bool {
        guard let handle = cppEngineHandle else { return false }
        return AudioEngine_IsClockRunning(handle)
    }

    /// Configures a clock output channel
    func setClockOutput(
        index: Int,
        mode: Int,
        waveform: Int,
        division: Int,
        level: Float,
        offset: Float,
        phase: Float,
        width: Float,
        destination: Int,
        modulationAmount: Float,
        muted: Bool
    ) {
        guard let handle = cppEngineHandle else { return }
        let idx = Int32(index)
        AudioEngine_SetClockOutputMode(handle, idx, Int32(mode))
        AudioEngine_SetClockOutputWaveform(handle, idx, Int32(waveform))
        AudioEngine_SetClockOutputDivision(handle, idx, Int32(division))
        AudioEngine_SetClockOutputLevel(handle, idx, level)
        AudioEngine_SetClockOutputOffset(handle, idx, offset)
        AudioEngine_SetClockOutputPhase(handle, idx, phase)
        AudioEngine_SetClockOutputWidth(handle, idx, width)
        AudioEngine_SetClockOutputDestination(handle, idx, Int32(destination))
        AudioEngine_SetClockOutputModAmount(handle, idx, modulationAmount)
        AudioEngine_SetClockOutputMuted(handle, idx, muted)
    }

    /// Gets the current output value for a clock channel (-1 to +1)
    func getClockOutputValue(index: Int) -> Float {
        guard let handle = cppEngineHandle else { return 0.0 }
        return AudioEngine_GetClockOutputValue(handle, Int32(index))
    }

    /// Sets slow mode for a clock output (applies /4 multiplier to rate)
    func setClockOutputSlowMode(index: Int, slow: Bool) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_SetClockOutputSlowMode(handle, Int32(index), slow)
    }

    /// Gets the current modulation value for a destination (bipolar -1 to +1)
    func getModulationValue(destination: ModulationDestination) -> Float {
        guard let handle = cppEngineHandle else { return 0.0 }
        // Get the index of the destination in the allCases array (matches C++ enum order)
        guard let index = ModulationDestination.allCases.firstIndex(of: destination) else { return 0.0 }
        return AudioEngine_GetModulationValue(handle, Int32(index))
    }

    // MARK: - Cleanup

    deinit {
        performanceTimer?.invalidate()
        audioEngine?.stop()

        // Cleanup C++ engine
        if let handle = cppEngineHandle {
            AudioEngine_StopMultiChannelProcessing(handle)
            AudioEngine_Shutdown(handle)
            AudioEngine_Destroy(handle)
        }
    }
}

// MARK: - Audio Device Model

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let hasInputChannels: Bool
    let hasOutputChannels: Bool
    let inputChannelCount: Int
    let outputChannelCount: Int

    init?(deviceID: AudioDeviceID) {
        self.id = deviceID

        // Get device name
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceName
        )

        guard status == noErr else { return nil }
        self.name = deviceName as String

        // Get input channel count
        propertyAddress.mSelector = kAudioDevicePropertyStreamConfiguration
        propertyAddress.mScope = kAudioDevicePropertyScopeInput

        var inputChannels = 0
        AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)

        if dataSize > 0 {
            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferList.deallocate() }

            if AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferList) == noErr {
                withUnsafePointer(to: &bufferList.pointee.mBuffers) { buffersPointer in
                    let buffers = UnsafeBufferPointer<AudioBuffer>(
                        start: buffersPointer,
                        count: Int(bufferList.pointee.mNumberBuffers)
                    )
                    inputChannels = buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
                }
            }
        }

        self.inputChannelCount = inputChannels
        self.hasInputChannels = inputChannels > 0

        // Get output channel count
        propertyAddress.mScope = kAudioDevicePropertyScopeOutput
        var outputChannels = 0

        AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)

        if dataSize > 0 {
            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferList.deallocate() }

            if AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferList) == noErr {
                withUnsafePointer(to: &bufferList.pointee.mBuffers) { buffersPointer in
                    let buffers = UnsafeBufferPointer<AudioBuffer>(
                        start: buffersPointer,
                        count: Int(bufferList.pointee.mNumberBuffers)
                    )
                    outputChannels = buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
                }
            }
        }

        self.outputChannelCount = outputChannels
        self.hasOutputChannels = outputChannels > 0
    }
}

// MARK: - Parameter ID Enum (placeholder - will be replaced with C++ bridge)

enum ParameterID {
    // Granular parameters (Mangl-style)
    case granularSpeed       // Playback speed (-3 to +3)
    case granularPitch       // Independent pitch shift (semitones)
    case granularSize        // Grain size (ms)
    case granularDensity     // Grain rate (Hz)
    case granularJitter      // Position randomization (ms)
    case granularSpread      // Stereo spread (0-1)
    case granularPan         // Base pan position
    case granularFilterCutoff
    case granularFilterResonance
    case granularGain        // Volume
    case granularSend        // Effect send
    case granularEnvelope    // Grain envelope shape (0-7)
    case granularDecay       // Envelope decay rate (0-1 maps to 1-10)
    case granularFilterModel // 0-1 selects ladder implementation
    case granularReverse     // 0=forward grains, 1=reverse grains
    case granularMorph       // 0-1 per-grain randomization amount

    // Legacy compatibility (map to new params)
    case granularSlide       // Maps to position (seek)
    case granularGeneSize    // Maps to size
    case granularVarispeed   // Maps to speed

    // Plaits parameters
    case plaitsModel
    case plaitsHarmonics
    case plaitsTimbre
    case plaitsMorph
    case plaitsFrequency
    case plaitsLevel
    case plaitsMidiNote  // Direct MIDI note (0-127)
    case plaitsLPGColor  // LPG color: 0 = VCA, 1 = VCA + filter
    case plaitsLPGDecay  // LPG decay time
    case plaitsLPGAttack // LPG attack time
    case plaitsLPGBypass // LPG bypass: 0 = normal, 1 = bypass (for testing)
    case ringsModel      // 0-1 maps to Rings resonator model
    case ringsStructure
    case ringsBrightness
    case ringsDamping
    case ringsPosition
    case ringsLevel

    // Effects parameters
    case delayTime       // 0-1 tape repeat rate
    case delayFeedback   // 0-1
    case delayMix        // 0-1 dry/wet
    case delayHeadMode   // 0-1 discrete classic head mode
    case delayWow        // 0-1 depth
    case delayFlutter    // 0-1 depth
    case delayTone       // 0-1 dark->bright
    case delaySync       // 0=free, 1=tempo sync
    case delayTempo      // 0-1 maps to 60-180 BPM
    case delaySubdivision // 0-1 rhythmic divisions
    case reverbSize      // 0-1 room size
    case reverbDamping   // 0-1 high freq damping
    case reverbMix       // 0-1 dry/wet

    // Mixer parameters (use voiceIndex for channel: 0=Plaits, 1=Rings, 2-5=tracks)
    case voiceGain       // 0-1 channel volume (maps to 0-2 for +6dB headroom)
    case voicePan        // 0-1 pan (0.5 = center)
    case voiceSend       // 0-1 FX send level
    case voiceMicroDelay // 0-1 maps to 0-50ms channel delay
    case masterGain      // 0-1 master volume (maps to 0-2 for +6dB headroom)

    // Master filter parameters
    case masterFilterCutoff     // 0-1 maps to 20-20000 Hz (logarithmic)
    case masterFilterResonance  // 0-1 resonance
    case masterFilterModel      // 0-1 selects filter model (0-9)

    // Looper parameters (voiceIndex 1-2)
    case looperRate
    case looperReverse
    case looperLoopStart
    case looperLoopEnd
    case looperCut
}

// MARK: - Insert Slot Data (Value Type)

/// Value-type snapshot of insert slot state for safe SwiftUI access
/// This avoids using @ObservedObject which can cause crashes during view hierarchy changes
struct InsertSlotData {
    let hasPlugin: Bool
    let pluginName: String?
    let pluginInfo: AUPluginInfo?
    let isBypassed: Bool
    let isLoading: Bool

    static let empty = InsertSlotData(
        hasPlugin: false,
        pluginName: nil,
        pluginInfo: nil,
        isBypassed: false,
        isLoading: false
    )
}

// MARK: - Send Slot Data (Value Type)

/// Value-type snapshot of send slot state for safe SwiftUI access
/// This avoids using @ObservedObject which can cause crashes during view hierarchy changes
struct SendSlotData {
    let hasPlugin: Bool
    let pluginName: String?
    let pluginInfo: AUPluginInfo?
    let isBypassed: Bool
    let isLoading: Bool
    let returnLevel: Float

    static let empty = SendSlotData(
        hasPlugin: false,
        pluginName: nil,
        pluginInfo: nil,
        isBypassed: false,
        isLoading: false,
        returnLevel: 0.5
    )
}

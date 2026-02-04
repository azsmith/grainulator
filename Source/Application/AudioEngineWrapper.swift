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

@_silgen_name("AudioEngine_SetParameter")
func AudioEngine_SetParameter(_ handle: OpaquePointer, _ parameterId: Int32, _ voiceIndex: Int32, _ value: Float)

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

    // Playhead positions for granular voices (0-1, indexed by voice)
    @Published var granularPositions: [Int: Float] = [:]

    // Level meters (0=Plaits, 1=Rings, 2-5=track voices)
    @Published var channelLevels: [Float] = [0, 0, 0, 0, 0, 0]
    @Published var masterLevelL: Float = 0
    @Published var masterLevelR: Float = 0

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var outputNode: AVAudioOutputNode?
    private var sourceNode: AVAudioSourceNode?

    // C++ Audio Engine Bridge
    private var cppEngineHandle: OpaquePointer?

    // Audio buffer for processing
    private var audioFormat: AVAudioFormat?
    private let processingQueue = DispatchQueue(label: "com.grainulator.audio", qos: .userInteractive)

    // Performance monitoring
    private var performanceTimer: Timer?
    private var lastCPUCheckTime: Date = Date()

    // MARK: - Initialization

    init() {
        // Create C++ engine
        cppEngineHandle = AudioEngine_Create()

        setupAudio()
        enumerateAudioDevices()
        setupPerformanceMonitoring()

        // Initialize C++ engine
        if let handle = cppEngineHandle {
            _ = AudioEngine_Initialize(handle, Int32(sampleRate), Int32(bufferSize))
        }
    }

    // MARK: - Audio Setup

    private func setupAudio() {
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

        guard let format = audioFormat else { return }

        // Create source node that will generate audio
        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            // Create output buffer pointers for C++ engine
            var outputPtrs = [UnsafeMutablePointer<Float>?](repeating: nil, count: Int(format.channelCount))
            for i in 0..<Int(format.channelCount) {
                outputPtrs[i] = ablPointer[i].mData?.assumingMemoryBound(to: Float.self)
            }

            // Call C++ engine
            if let handle = self.cppEngineHandle {
                outputPtrs.withUnsafeMutableBufferPointer { ptrs in
                    AudioEngine_Process(handle, ptrs.baseAddress, Int32(format.channelCount), Int32(frameCount))
                }
            }

            return noErr
        }

        // Attach and connect source node to output
        engine.attach(sourceNode!)
        engine.connect(sourceNode!, to: outputNode!, format: format)

        // Prepare the engine
        engine.prepare()
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
            print("✓ Audio engine started")
        } catch {
            print("✗ Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        guard let engine = audioEngine, isRunning else { return }

        engine.stop()
        isRunning = false
        print("✓ Audio engine stopped")
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
        // Poll at 30fps for smooth playhead animation
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
    }

    private func updatePerformanceMetrics() {
        // Calculate CPU usage
        // This is a simplified version - real implementation would use more accurate metrics
        cpuLoad = ProcessInfo.processInfo.systemUptime.truncatingRemainder(dividingBy: 100.0) / 4.0

        // Calculate latency (buffer size / sample rate * 1000 for ms)
        latency = (Double(bufferSize) / sampleRate) * 1000.0

        // Update granular playhead positions
        updateGranularPositions()

        // Update level meters
        updateLevelMeters()
    }

    private func updateLevelMeters() {
        guard let handle = cppEngineHandle else { return }

        // Update channel levels (0=Plaits, 1=Rings, 2-5=track voices)
        for i in 0..<6 {
            channelLevels[i] = AudioEngine_GetChannelLevel(handle, Int32(i))
        }

        // Update master levels
        masterLevelL = AudioEngine_GetMasterLevel(handle, 0)
        masterLevelR = AudioEngine_GetMasterLevel(handle, 1)
    }

    private func updateGranularPositions() {
        guard let handle = cppEngineHandle else { return }

        for voiceIndex in 0..<4 {
            let position = AudioEngine_GetGranularPosition(handle, Int32(voiceIndex))
            granularPositions[voiceIndex] = position
        }
    }

    // MARK: - Parameter Control

    func setParameter(id: ParameterID, value: Float, voiceIndex: Int = 0) {
        guard let handle = cppEngineHandle else { return }

        // Map Swift ParameterID to C++ ParameterID
        let cppParamId: Int32
        switch id {
        // Granular parameters (Mangl-style) (0-11)
        case .granularSpeed: cppParamId = 0
        case .granularPitch: cppParamId = 1
        case .granularSize: cppParamId = 2
        case .granularDensity: cppParamId = 3
        case .granularJitter: cppParamId = 4
        case .granularSpread: cppParamId = 5
        case .granularPan: cppParamId = 6
        case .granularFilterCutoff: cppParamId = 7
        case .granularFilterResonance: cppParamId = 8
        case .granularGain: cppParamId = 9
        case .granularSend: cppParamId = 10
        case .granularEnvelope: cppParamId = 11
        case .granularDecay: cppParamId = 12
        case .granularFilterModel: cppParamId = 43
        case .granularReverse: cppParamId = 44
        case .granularMorph: cppParamId = 45

        // Legacy compatibility (map to new params)
        case .granularSlide: cppParamId = 0     // Maps to speed (position control via seek)
        case .granularGeneSize: cppParamId = 2  // Maps to size
        case .granularVarispeed: cppParamId = 0 // Maps to speed

        // Plaits parameters (13-23, shifted by 1 for GranularDecay)
        case .plaitsModel: cppParamId = 13
        case .plaitsHarmonics: cppParamId = 14
        case .plaitsTimbre: cppParamId = 15
        case .plaitsMorph: cppParamId = 16
        case .plaitsFrequency: cppParamId = 17
        case .plaitsLevel: cppParamId = 18
        case .plaitsMidiNote: cppParamId = 19
        case .plaitsLPGColor: cppParamId = 20
        case .plaitsLPGDecay: cppParamId = 21
        case .plaitsLPGAttack: cppParamId = 22
        case .plaitsLPGBypass: cppParamId = 23

        // Effects parameters (24-29)
        case .delayTime: cppParamId = 24
        case .delayFeedback: cppParamId = 25
        case .delayMix: cppParamId = 26
        case .reverbSize: cppParamId = 27
        case .reverbDamping: cppParamId = 28
        case .reverbMix: cppParamId = 29

        // Mixer parameters (32-35, after distortion params 30-31)
        case .voiceGain: cppParamId = 32
        case .voicePan: cppParamId = 33
        case .voiceSend: cppParamId = 34
        case .masterGain: cppParamId = 35

        // Tape delay extended parameters (36-42)
        case .delayHeadMode: cppParamId = 36
        case .delayWow: cppParamId = 37
        case .delayFlutter: cppParamId = 38
        case .delayTone: cppParamId = 39
        case .delaySync: cppParamId = 40
        case .delayTempo: cppParamId = 41
        case .delaySubdivision: cppParamId = 42
        case .ringsModel: cppParamId = 46
        case .ringsStructure: cppParamId = 47
        case .ringsBrightness: cppParamId = 48
        case .ringsDamping: cppParamId = 49
        case .ringsPosition: cppParamId = 50
        case .ringsLevel: cppParamId = 51
        case .looperRate: cppParamId = 52
        case .looperReverse: cppParamId = 53
        case .looperLoopStart: cppParamId = 54
        case .looperLoopEnd: cppParamId = 55
        case .looperCut: cppParamId = 56
        }

        AudioEngine_SetParameter(handle, cppParamId, Int32(voiceIndex), value)
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

    /// Gets active grain count across all voices
    func getActiveGrainCount() -> Int {
        guard let handle = cppEngineHandle else { return 0 }
        return Int(AudioEngine_GetActiveGrainCount(handle))
    }

    func triggerPlaits(_ state: Bool) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_TriggerPlaits(handle, state)
    }

    /// Polyphonic note on - allocates a voice and triggers it
    func noteOn(note: UInt8, velocity: UInt8) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_NoteOn(handle, Int32(note), Int32(velocity))
    }

    /// Polyphonic note off - releases the voice playing this note
    func noteOff(note: UInt8) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_NoteOff(handle, Int32(note))
    }

    /// Sends note-off for all MIDI notes to prevent stuck voices.
    func allNotesOff() {
        guard let handle = cppEngineHandle else { return }
        for note in 0...127 {
            AudioEngine_NoteOff(handle, Int32(note))
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

    // MARK: - Cleanup

    deinit {
        performanceTimer?.invalidate()
        audioEngine?.stop()

        // Cleanup C++ engine
        if let handle = cppEngineHandle {
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
    case masterGain      // 0-1 master volume (maps to 0-2 for +6dB headroom)

    // Looper parameters (voiceIndex 1-2)
    case looperRate
    case looperReverse
    case looperLoopStart
    case looperLoopEnd
    case looperCut
}

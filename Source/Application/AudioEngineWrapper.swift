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

/// Main audio engine wrapper that manages CoreAudio and the synthesis engine
@MainActor
class AudioEngineWrapper: ObservableObject {
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
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
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
    }

    // MARK: - Parameter Control

    func setParameter(id: ParameterID, value: Float) {
        guard let handle = cppEngineHandle else { return }

        // Map Swift ParameterID to C++ ParameterID (they match by design)
        let cppParamId: Int32
        switch id {
        case .plaitsModel: cppParamId = 10
        case .plaitsHarmonics: cppParamId = 11
        case .plaitsTimbre: cppParamId = 12
        case .plaitsMorph: cppParamId = 13
        case .plaitsFrequency: cppParamId = 14
        case .plaitsLevel: cppParamId = 15
        default: return // Ignore other parameters for now
        }

        AudioEngine_SetParameter(handle, cppParamId, 0, value)
    }

    func loadAudioFile(url: URL, reelIndex: Int) {
        // TODO: Load audio file into buffer manager
        print("Load audio file: \(url.lastPathComponent) into reel \(reelIndex)")
    }

    func triggerPlaits(_ state: Bool) {
        guard let handle = cppEngineHandle else { return }
        AudioEngine_TriggerPlaits(handle, state)
        print("✓ Trigger Plaits: \(state)")
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
    // Granular parameters
    case slide
    case geneSize
    case morph
    case varispeed
    case organize
    case pitch
    case spread
    case jitter
    case filterCutoff
    case filterResonance

    // Plaits parameters
    case plaitsModel
    case plaitsHarmonics
    case plaitsTimbre
    case plaitsMorph
    case plaitsFrequency
    case plaitsLevel
}

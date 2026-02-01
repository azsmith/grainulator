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
    private var mixerNode: AVAudioMixerNode?

    // Audio buffer for processing
    private var audioFormat: AVAudioFormat?
    private let processingQueue = DispatchQueue(label: "com.grainulator.audio", qos: .userInteractive)

    // Performance monitoring
    private var performanceTimer: Timer?
    private var lastCPUCheckTime: Date = Date()

    // MARK: - Initialization

    init() {
        setupAudio()
        enumerateAudioDevices()
        setupPerformanceMonitoring()
    }

    // MARK: - Audio Setup

    private func setupAudio() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        inputNode = engine.inputNode
        outputNode = engine.outputNode
        mixerNode = AVAudioMixerNode()

        engine.attach(mixerNode!)

        // Configure audio format (48kHz, stereo, float)
        audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: false
        )

        guard let format = audioFormat else { return }

        // Connect mixer to output
        engine.connect(mixerNode!, to: outputNode!, format: format)

        // Install tap on mixer for processing
        mixerNode?.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: format) { [weak self] buffer, time in
            self?.processAudio(buffer: buffer, time: time)
        }

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

    // MARK: - Audio Processing

    private func processAudio(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // This is where we'll call into the C++ audio engine
        // For now, this is a placeholder that passes audio through

        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // TODO: Call C++ audio engine processing here
        // engine.process(channelData, frameCount, channelCount)

        // For now, just pass through (silence)
        for channel in 0..<channelCount {
            let channelBuffer = channelData[channel]
            for frame in 0..<frameCount {
                channelBuffer[frame] = 0.0 // Silence for now
            }
        }
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
        // TODO: Send parameter change to C++ engine via command queue
        print("Set parameter \(id) to \(value)")
    }

    func loadAudioFile(url: URL, reelIndex: Int) {
        // TODO: Load audio file into buffer manager
        print("Load audio file: \(url.lastPathComponent) into reel \(reelIndex)")
    }

    // MARK: - Cleanup

    deinit {
        performanceTimer?.invalidate()
        audioEngine?.stop()
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
}

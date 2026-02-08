//
//  MonomeArcManager.swift
//  Grainulator
//
//  Monome Arc 4 controller integration via serialosc/OSC.
//  Provides 4 high-resolution encoders with LED ring feedback
//  for granular voice parameter control.
//

import Foundation
import Combine
import OSCKit

// MARK: - Arc Target

/// Defines what an encoder controls — either a named engine parameter or
/// the special-case granular playhead position.
enum ArcTarget {
    case parameter(ParameterID)
    case playheadPosition
    /// Semitone-stepped rate control for looper (range -24..+12 semitones)
    case steppedRate
}

/// Whether the current voice is a granular or looper voice.
private enum ArcVoiceMode {
    case granular
    case looper
}

// MARK: - MonomeArcManager

@MainActor
class MonomeArcManager: ObservableObject {

    // MARK: Published State

    @Published var isConnected: Bool = false
    @Published var deviceName: String = ""
    @Published var isShiftHeld: Bool = false
    @Published var encoderValues: [Float] = [0, 0, 0, 0]
    @Published var shiftEncoderValues: [Float] = [0, 0, 0, 0]

    // MARK: Encoder Mappings (voice-aware)

    /// Granular primary: Speed, Pitch, Size (length), Density
    private let granularPrimaryMappings: [ArcTarget] = [
        .parameter(.granularSpeed),
        .parameter(.granularPitch),
        .parameter(.granularSize),
        .parameter(.granularDensity),
    ]

    /// Granular shift: Jitter, Spread, Filter, Morph
    private let granularShiftMappings: [ArcTarget] = [
        .parameter(.granularJitter),
        .parameter(.granularSpread),
        .parameter(.granularFilterCutoff),
        .parameter(.granularMorph),
    ]

    /// Looper primary: Loop Start, Loop End, Pitch (semitone-stepped rate), Position
    private let looperPrimaryMappings: [ArcTarget] = [
        .parameter(.looperLoopStart),
        .parameter(.looperLoopEnd),
        .steppedRate,
        .playheadPosition,
    ]

    /// Looper shift: same as primary (few continuous looper params)
    private let looperShiftMappings: [ArcTarget] = [
        .parameter(.looperLoopStart),
        .parameter(.looperLoopEnd),
        .steppedRate,
        .playheadPosition,
    ]

    /// Current voice mode based on selected voice.
    private var voiceMode: ArcVoiceMode {
        let voice = appState?.selectedGranularVoice ?? 0
        return (voice == 1 || voice == 2) ? .looper : .granular
    }

    /// Active primary mappings for the current voice mode.
    private var primaryMappings: [ArcTarget] {
        voiceMode == .looper ? looperPrimaryMappings : granularPrimaryMappings
    }

    /// Active shift mappings for the current voice mode.
    private var shiftMappings: [ArcTarget] {
        voiceMode == .looper ? looperShiftMappings : granularShiftMappings
    }

    // MARK: Configuration

    /// Ticks-to-value sensitivity. ~2048 ticks (two full revolutions) for full 0→1 sweep.
    private let sensitivity: Float = 0.0005

    /// Our UDP listening port for OSC messages from serialosc and Arc.
    private let localReceivePort: UInt16 = 17_842

    /// serialosc discovery daemon port.
    private let serialoscPort: UInt16 = 12_002

    /// OSC address prefix for the Arc device.
    private let oscPrefix = "/arc"

    // MARK: Internal State

    private var oscServer: OSCUDPServer?
    private var oscClient: OSCUDPClient?
    private var arcDevicePort: UInt16 = 0
    private var arcDeviceId: String = ""

    private var primaryValues: [Float] = [0, 0, 0, 0]
    private var shiftValues: [Float] = [0, 0, 0, 0]
    private var shiftActive: Bool = false

    private var ledDirty: [Bool] = [false, false, false, false]
    private var ledUpdateTimer: Timer?
    private var paramSyncTimer: Timer?
    private var reconnectTimer: Timer?
    private var uiNotifyTimer: Timer?

    /// Throttle UI refresh notifications to ~30 Hz to avoid overwhelming SwiftUI.
    private var uiNotifyPending: Bool = false

    /// Stepped rate: current semitone offset (-24..+12). 0 = 1x speed.
    private var rateSemitone: Int = 0
    /// Stepped rate: accumulates encoder delta ticks between semitone steps.
    private var rateTickAccumulator: Int = 0
    /// Ticks per semitone step (~1/10 revolution).
    private let ticksPerSemitone: Int = 24

    /// Tap-to-record: timestamp when encoder was pressed (nil if not pressed).
    private var encoderPressTime: Date?
    /// Tap-to-record: which encoder was pressed.
    private var pressedEncoder: Int = -1
    /// Tap-to-record: whether the encoder was rotated while pressed (disqualifies tap).
    private var encoderMovedDuringPress: Bool = false
    /// Tap threshold: press+release under this duration = tap (record toggle).
    private let tapThreshold: TimeInterval = 0.3

    private weak var audioEngine: AudioEngineWrapper?
    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    /// Connect the Arc manager to the audio engine and app state.
    /// Call from GrainulatorApp.onAppear after all other subsystems are wired.
    func connect(audioEngine: AudioEngineWrapper, appState: AppState) {
        self.audioEngine = audioEngine
        self.appState = appState

        // Seed encoder values from current engine state
        syncFromEngine()

        // Observe voice selection changes
        observeVoiceSelection()

        // Start serialosc discovery
        startDiscovery()
    }

    deinit {
        ledUpdateTimer?.invalidate()
        paramSyncTimer?.invalidate()
        reconnectTimer?.invalidate()
        uiNotifyTimer?.invalidate()
        oscServer?.stop()
        oscClient?.stop()
    }

    // MARK: - serialosc Discovery

    private func startDiscovery() {
        // Create a UDP server to receive messages from serialosc and Arc
        let server = OSCUDPServer(port: localReceivePort, timeTagMode: .ignore)

        // Set the receive handler (called on background thread)
        server.setReceiveHandler { [weak self] message, timeTag, host, port in
            Task { @MainActor [weak self] in
                self?.handleOSCMessage(message, fromHost: host, fromPort: port)
            }
        }

        do {
            try server.start()
            self.oscServer = server
            NSLog("[Arc] OSC server listening on port %d", localReceivePort)
        } catch {
            NSLog("[Arc] Failed to start OSC server on port %d: %@", localReceivePort, error.localizedDescription)
            // Try again in 5 seconds
            scheduleReconnect()
            return
        }

        // Create a client for sending messages
        let client = OSCUDPClient()
        do {
            try client.start()
            self.oscClient = client
        } catch {
            NSLog("[Arc] Failed to start OSC client: %@", error.localizedDescription)
            return
        }

        // Query serialosc for connected devices
        querySerialoscDevices()

        // Subscribe to connect/disconnect notifications
        subscribeToNotifications()

        // Start reconnect polling (in case serialosc isn't running yet)
        scheduleReconnect()
    }

    private func querySerialoscDevices() {
        guard let client = oscClient else { return }
        let message = OSCMessage("/serialosc/list", values: [
            "127.0.0.1" as String,
            Int32(localReceivePort),
        ])
        do {
            try client.send(message, to: "127.0.0.1", port: serialoscPort)
            NSLog("[Arc] Sent /serialosc/list query to port %d", serialoscPort)
        } catch {
            NSLog("[Arc] Failed to query serialosc: %@", error.localizedDescription)
        }
    }

    private func subscribeToNotifications() {
        guard let client = oscClient else { return }
        let message = OSCMessage("/serialosc/notify", values: [
            "127.0.0.1" as String,
            Int32(localReceivePort),
        ])
        do {
            try client.send(message, to: "127.0.0.1", port: serialoscPort)
        } catch {
            NSLog("[Arc] Failed to subscribe to serialosc notifications: %@", error.localizedDescription)
        }
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.isConnected else { return }
                self.querySerialoscDevices()
                self.subscribeToNotifications()
            }
        }
    }

    // MARK: - OSC Message Handling

    private func handleOSCMessage(_ message: OSCMessage, fromHost host: String, fromPort port: UInt16) {
        let address = message.addressPattern.stringValue

        switch address {
        // serialosc device advertisement
        case "/serialosc/device":
            handleDeviceResponse(message)

        // serialosc device connected notification
        case "/serialosc/add":
            NSLog("[Arc] Device added notification")
            querySerialoscDevices()

        // serialosc device removed notification
        case "/serialosc/remove":
            NSLog("[Arc] Device removed notification")
            disconnect()

        // Arc encoder rotation
        case "\(oscPrefix)/enc/delta":
            handleEncoderDelta(message)

        // Arc encoder key press/release
        case "\(oscPrefix)/enc/key":
            handleEncoderKey(message)

        default:
            break // Ignore /sys echoes and other unhandled messages
        }
    }

    // MARK: - Device Connection

    private func handleDeviceResponse(_ message: OSCMessage) {
        // /serialosc/device ssi <device_id> <device_type> <port>
        guard message.values.count >= 3,
              let deviceId = message.values[0] as? String,
              let deviceType = message.values[1] as? String,
              let devicePort = message.values[2] as? Int32 else {
            NSLog("[Arc] Malformed /serialosc/device response: %d values", message.values.count)
            return
        }

        // Only connect to Arc devices
        let typeLower = deviceType.lowercased()
        guard typeLower.contains("arc") else {
            NSLog("[Arc] Ignoring non-arc device: %@ (%@)", deviceType, deviceId)
            return
        }

        NSLog("[Arc] Discovered Arc: %@ (%@) on port %d", deviceId, deviceType, devicePort)

        arcDeviceId = deviceId
        arcDevicePort = UInt16(devicePort)

        // Send handshake to the Arc's assigned port
        performHandshake()
    }

    private func performHandshake() {
        guard let client = oscClient, arcDevicePort > 0 else { return }

        do {
            // Tell the Arc where to send its messages
            let hostMsg = OSCMessage("/sys/host", values: ["127.0.0.1" as String])
            try client.send(hostMsg, to: "127.0.0.1", port: arcDevicePort)

            let portMsg = OSCMessage("/sys/port", values: [Int32(localReceivePort)])
            try client.send(portMsg, to: "127.0.0.1", port: arcDevicePort)

            // Set the OSC prefix
            let prefixMsg = OSCMessage("/sys/prefix", values: [oscPrefix as String])
            try client.send(prefixMsg, to: "127.0.0.1", port: arcDevicePort)

            NSLog("[Arc] Handshake complete with %@ on port %d", arcDeviceId, arcDevicePort)

            isConnected = true
            deviceName = arcDeviceId

            // Stop reconnect polling
            reconnectTimer?.invalidate()
            reconnectTimer = nil

            // Seed values from engine and start feedback
            syncFromEngine()
            startLEDFeedback()
            startParamSync()
            startUINotifyTimer()

            // Send initial LED state
            for i in 0..<4 { ledDirty[i] = true }

        } catch {
            NSLog("[Arc] Handshake failed: %@", error.localizedDescription)
        }
    }

    func disconnect() {
        guard isConnected else { return }

        // Clear all LED rings
        clearAllLEDs()

        isConnected = false
        deviceName = ""
        arcDevicePort = 0
        arcDeviceId = ""

        ledUpdateTimer?.invalidate()
        ledUpdateTimer = nil
        paramSyncTimer?.invalidate()
        paramSyncTimer = nil
        uiNotifyTimer?.invalidate()
        uiNotifyTimer = nil

        NSLog("[Arc] Disconnected")

        // Resume reconnect polling
        scheduleReconnect()
    }

    // MARK: - Encoder Delta Handling

    private func handleEncoderDelta(_ message: OSCMessage) {
        // /arc/enc/delta ii <encoder> <delta>
        guard message.values.count >= 2,
              let encoderRaw = message.values[0] as? Int32,
              let deltaRaw = message.values[1] as? Int32 else { return }

        let encoder = Int(encoderRaw)
        let delta = Int(deltaRaw)
        guard encoder >= 0, encoder < 4 else { return }

        // If encoder is pressed and rotated, it's not a tap — it's a shift gesture
        if encoderPressTime != nil {
            encoderMovedDuringPress = true
        }

        let isShift = shiftActive
        let mappings = isShift ? shiftMappings : primaryMappings
        let mapping = mappings[encoder]

        // Stepped rate: accumulate ticks and step by semitones
        if case .steppedRate = mapping {
            NSLog("[Arc] steppedRate: delta=%d accum=%d semitone=%d", delta, rateTickAccumulator, rateSemitone)
            rateTickAccumulator += delta
            let steps = rateTickAccumulator / ticksPerSemitone
            if steps != 0 {
                rateTickAccumulator -= steps * ticksPerSemitone
                rateSemitone = max(-24, min(12, rateSemitone + steps))
                // Convert semitone to rate: rate = 2^(semitone/12)
                let rate = powf(2.0, Float(rateSemitone) / 12.0)
                // Normalize to 0..1: (rate - 0.25) / 1.75
                let normalized = max(0.0, min(1.0, (rate - 0.25) / 1.75))
                primaryValues[encoder] = normalized
                encoderValues[encoder] = normalized
                let voiceIndex = appState?.selectedGranularVoice ?? 0
                audioEngine?.setParameter(id: .looperRate, value: normalized, voiceIndex: voiceIndex)
            }
            ledDirty[encoder] = true
            uiNotifyPending = true
            return
        }

        // Get current value
        let currentValue = isShift ? shiftValues[encoder] : primaryValues[encoder]

        // Apply delta with clamping
        let newValue = max(0.0, min(1.0, currentValue + Float(delta) * sensitivity))

        // Store
        if isShift {
            shiftValues[encoder] = newValue
            shiftEncoderValues[encoder] = newValue
        } else {
            primaryValues[encoder] = newValue
            encoderValues[encoder] = newValue
        }

        // Apply to engine
        let voiceIndex = appState?.selectedGranularVoice ?? 0
        switch mapping {
        case .parameter(let paramId):
            audioEngine?.setParameter(id: paramId, value: newValue, voiceIndex: voiceIndex)
        case .steppedRate:
            break // handled above
        case .playheadPosition:
            audioEngine?.setGranularPosition(voiceIndex: voiceIndex, position: newValue)
        }

        // Mark LED dirty
        ledDirty[encoder] = true

        // Notify the audio engine's objectWillChange so SwiftUI refreshes knobs in real time.
        // Throttled: we set a flag and the uiNotifyTimer fires it at ~30 Hz.
        uiNotifyPending = true
    }

    // MARK: - Encoder Key Handling (Shift + Tap-to-Record)

    private func handleEncoderKey(_ message: OSCMessage) {
        // /arc/enc/key ii <encoder> <state>  (state: 1=pressed, 0=released)
        guard message.values.count >= 2,
              let encoderRaw = message.values[0] as? Int32,
              let stateRaw = message.values[1] as? Int32 else { return }

        let encoder = Int(encoderRaw)
        let pressed = (stateRaw == 1)

        if pressed {
            // Key down: record timestamp and activate shift
            encoderPressTime = Date()
            pressedEncoder = encoder
            encoderMovedDuringPress = false
            shiftActive = true
            isShiftHeld = true
            for i in 0..<4 { ledDirty[i] = true }
        } else {
            // Key up: check if this was a short tap (no rotation, under threshold)
            let wasTap: Bool
            if let pressTime = encoderPressTime,
               !encoderMovedDuringPress,
               Date().timeIntervalSince(pressTime) < tapThreshold {
                wasTap = true
            } else {
                wasTap = false
            }

            // Deactivate shift
            encoderPressTime = nil
            pressedEncoder = -1
            shiftActive = false
            isShiftHeld = false
            for i in 0..<4 { ledDirty[i] = true }

            // If it was a tap, toggle recording for the current voice
            if wasTap {
                toggleRecording()
            }
        }
    }

    /// Toggle recording for the currently selected voice.
    /// If the voice was previously recording (has stored state), re-use those settings.
    /// Otherwise fall back to sensible defaults per voice type.
    private func toggleRecording() {
        guard let engine = audioEngine else { return }
        let voiceIndex = appState?.selectedGranularVoice ?? 0

        let isCurrentlyRecording = engine.recordingStates[voiceIndex]?.isRecording ?? false
        if isCurrentlyRecording {
            engine.stopRecording(reelIndex: voiceIndex)
            NSLog("[Arc] Tap: stopped recording for voice %d", voiceIndex)
        } else {
            // Re-use previous recording settings if available
            if let prev = engine.recordingStates[voiceIndex] {
                engine.startRecording(
                    reelIndex: voiceIndex,
                    mode: prev.mode,
                    sourceType: prev.sourceType,
                    sourceChannel: prev.sourceChannel
                )
                NSLog("[Arc] Tap: resumed recording for voice %d (prev settings)", voiceIndex)
            } else {
                // First time defaults: always use internal source (Plaits) to avoid mic permission prompts.
                // User can select mic from the UI menu if desired.
                let isLooper = (voiceIndex == 1 || voiceIndex == 2)
                let mode: AudioEngineWrapper.RecordMode = isLooper ? .liveLoop : .oneShot
                engine.startRecording(reelIndex: voiceIndex, mode: mode, sourceType: .internalVoice, sourceChannel: 0)
                NSLog("[Arc] Tap: started recording for voice %d (defaults, Plaits)", voiceIndex)
            }
        }
    }

    // MARK: - LED Ring Feedback

    private func startLEDFeedback() {
        ledUpdateTimer?.invalidate()
        ledUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLEDs()
            }
        }
    }

    private func updateLEDs() {
        guard isConnected else { return }

        for enc in 0..<4 {
            guard ledDirty[enc] else { continue }
            ledDirty[enc] = false

            let value = shiftActive ? shiftValues[enc] : primaryValues[enc]
            let ring = buildRadialMeter(value: value, isShift: shiftActive)
            sendRingMap(encoder: enc, ring: ring)
        }
    }

    /// Convert a 0-1 value into a 64-element LED brightness array.
    /// Filled arc from LED 0 (12 o'clock) clockwise.
    private func buildRadialMeter(value: Float, isShift: Bool) -> [Int32] {
        var ring = [Int32](repeating: 0, count: 64)
        let maxBright: Int32 = isShift ? 10 : 15
        let fillCount = value * 64.0

        let fullLEDs = Int(fillCount)
        let fractional = fillCount - Float(fullLEDs)

        for i in 0..<min(fullLEDs, 64) {
            ring[i] = maxBright
        }
        if fullLEDs < 64 {
            ring[fullLEDs] = Int32(fractional * Float(maxBright))
        }

        return ring
    }

    /// Send a full ring map update to a single encoder.
    private func sendRingMap(encoder: Int, ring: [Int32]) {
        guard let client = oscClient, arcDevicePort > 0 else { return }

        // /arc/ring/map i [64 ints]  (LED output addresses omit /enc/)
        var values: [any OSCValue] = [Int32(encoder)]
        values.append(contentsOf: ring)

        let message = OSCMessage("\(oscPrefix)/ring/map", values: values)
        do {
            try client.send(message, to: "127.0.0.1", port: arcDevicePort)
        } catch {
            // Silently ignore send failures (device may have disconnected)
        }
    }

    /// Clear all LED rings (set all to brightness 0).
    private func clearAllLEDs() {
        guard let client = oscClient, arcDevicePort > 0 else { return }
        for enc in 0..<4 {
            let message = OSCMessage("\(oscPrefix)/ring/all", values: [
                Int32(enc), Int32(0),
            ])
            try? client.send(message, to: "127.0.0.1", port: arcDevicePort)
        }
    }

    // MARK: - Bidirectional Parameter Sync

    private func startParamSync() {
        paramSyncTimer?.invalidate()
        paramSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncFromEngine()
            }
        }
    }

    /// Throttled UI notification at ~30 Hz. When Arc encoder deltas change engine parameters,
    /// this fires `audioEngine.objectWillChange` so SwiftUI refreshes knobs in real time.
    private func startUINotifyTimer() {
        uiNotifyTimer?.invalidate()
        uiNotifyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.uiNotifyPending else { return }
                self.uiNotifyPending = false
                self.audioEngine?.objectWillChange.send()
            }
        }
    }

    /// Read current parameter values from the engine and update tracked positions.
    /// Called on initial connect, voice change, and periodically at 4 Hz.
    private func syncFromEngine() {
        guard let engine = audioEngine else { return }
        let voice = appState?.selectedGranularVoice ?? 0
        let epsilon: Float = 0.005

        // Sync primary layer
        for (i, target) in primaryMappings.enumerated() {
            let engineValue: Float
            switch target {
            case .parameter(let paramId):
                engineValue = engine.getParameter(id: paramId, voiceIndex: voice)
            case .playheadPosition:
                engineValue = engine.granularPositions[voice] ?? 0
            case .steppedRate:
                // Read normalized rate from engine, convert back to semitone
                let normalized = engine.getParameter(id: .looperRate, voiceIndex: voice)
                let rate = normalized * 1.75 + 0.25
                let semitone = Int(round(12.0 * log2f(rate)))
                rateSemitone = max(-24, min(12, semitone))
                engineValue = normalized
            }
            if abs(engineValue - primaryValues[i]) > epsilon {
                primaryValues[i] = engineValue
                encoderValues[i] = engineValue
                if !shiftActive { ledDirty[i] = true }
            }
        }

        // Sync shift layer
        for (i, target) in shiftMappings.enumerated() {
            let engineValue: Float
            switch target {
            case .parameter(let paramId):
                engineValue = engine.getParameter(id: paramId, voiceIndex: voice)
            case .steppedRate:
                engineValue = engine.getParameter(id: .looperRate, voiceIndex: voice)
            case .playheadPosition:
                continue
            }
            if abs(engineValue - shiftValues[i]) > epsilon {
                shiftValues[i] = engineValue
                shiftEncoderValues[i] = engineValue
                if shiftActive { ledDirty[i] = true }
            }
        }
    }

    // MARK: - Voice Selection Tracking

    private func observeVoiceSelection() {
        appState?.$selectedGranularVoice
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.onVoiceChanged()
                }
            }
            .store(in: &cancellables)
    }

    private func onVoiceChanged() {
        syncFromEngine()
        for i in 0..<4 { ledDirty[i] = true }
    }
}

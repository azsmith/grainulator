//
//  MIDIManager.swift
//  Grainulator
//
//  MIDI input manager for keyboard and controller support
//  Uses CoreMIDI for low-latency MIDI processing
//

import Foundation
import CoreMIDI
import Combine

/// MIDI message types
enum MIDIMessageType {
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    case noteOff(channel: UInt8, note: UInt8, velocity: UInt8)
    case controlChange(channel: UInt8, controller: UInt8, value: UInt8)
    case pitchBend(channel: UInt8, value: Int16)
    case aftertouch(channel: UInt8, pressure: UInt8)
    case programChange(channel: UInt8, program: UInt8)
}

/// Represents a connected MIDI device
struct MIDIDevice: Identifiable, Hashable {
    let id: MIDIEndpointRef
    let name: String
    let manufacturer: String
    let isOnline: Bool

    static func == (lhs: MIDIDevice, rhs: MIDIDevice) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Manages MIDI input from keyboards and controllers
@MainActor
class MIDIManager: ObservableObject {
    // MARK: - Published Properties

    @Published var availableDevices: [MIDIDevice] = []
    @Published var connectedDevices: Set<MIDIDevice> = []
    @Published var isEnabled: Bool = false
    @Published var lastNote: UInt8 = 0
    @Published var lastVelocity: UInt8 = 0

    // MARK: - Callbacks

    var onNoteOn: ((UInt8, UInt8) -> Void)?  // (note, velocity)
    var onNoteOff: ((UInt8) -> Void)?         // (note)
    var onControlChange: ((UInt8, UInt8) -> Void)?  // (controller, value)
    var onPitchBend: ((Int16) -> Void)?       // (value: -8192 to 8191)

    // MARK: - Private Properties

    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var notificationPort: MIDIPortRef = 0

    // Currently held notes for polyphony tracking
    private var heldNotes: Set<UInt8> = []

    // MARK: - Initialization

    init() {
        setupMIDI()
    }

    deinit {
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
        }
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
        }
    }

    // MARK: - Setup

    private func setupMIDI() {
        // Create MIDI client
        let clientName = "Grainulator" as CFString
        var status = MIDIClientCreateWithBlock(clientName, &midiClient) { [weak self] notification in
            Task { @MainActor in
                self?.handleMIDINotification(notification)
            }
        }

        guard status == noErr else {
            print("✗ Failed to create MIDI client: \(status)")
            return
        }

        // Create input port
        let portName = "Grainulator Input" as CFString
        status = MIDIInputPortCreateWithProtocol(
            midiClient,
            portName,
            ._1_0,
            &inputPort
        ) { [weak self] eventList, _ in
            self?.handleMIDIEventList(eventList)
        }

        guard status == noErr else {
            print("✗ Failed to create MIDI input port: \(status)")
            return
        }

        print("✓ MIDI system initialized")

        // Enumerate existing devices
        refreshDevices()

        isEnabled = true
    }

    // MARK: - Device Management

    func refreshDevices() {
        var devices: [MIDIDevice] = []

        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if let device = createMIDIDevice(from: source) {
                devices.append(device)
            }
        }

        availableDevices = devices
        print("✓ Found \(devices.count) MIDI source(s)")

        // Auto-connect to all devices if none connected
        if connectedDevices.isEmpty && !devices.isEmpty {
            connectToAllDevices()
        }
    }

    private func createMIDIDevice(from endpoint: MIDIEndpointRef) -> MIDIDevice? {
        var name: Unmanaged<CFString>?
        var manufacturer: Unmanaged<CFString>?
        var isOffline: Int32 = 0

        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyManufacturer, &manufacturer)
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyOffline, &isOffline)

        let deviceName = (name?.takeRetainedValue() as String?) ?? "Unknown Device"
        let deviceManufacturer = (manufacturer?.takeRetainedValue() as String?) ?? "Unknown"

        return MIDIDevice(
            id: endpoint,
            name: deviceName,
            manufacturer: deviceManufacturer,
            isOnline: isOffline == 0
        )
    }

    func connectToDevice(_ device: MIDIDevice) {
        let status = MIDIPortConnectSource(inputPort, device.id, nil)

        if status == noErr {
            connectedDevices.insert(device)
            print("✓ Connected to MIDI device: \(device.name)")
        } else {
            print("✗ Failed to connect to \(device.name): \(status)")
        }
    }

    func disconnectFromDevice(_ device: MIDIDevice) {
        let status = MIDIPortDisconnectSource(inputPort, device.id)

        if status == noErr {
            connectedDevices.remove(device)
            print("✓ Disconnected from MIDI device: \(device.name)")
        } else {
            print("✗ Failed to disconnect from \(device.name): \(status)")
        }
    }

    func connectToAllDevices() {
        for device in availableDevices {
            connectToDevice(device)
        }
    }

    func disconnectFromAllDevices() {
        for device in connectedDevices {
            disconnectFromDevice(device)
        }
    }

    // MARK: - MIDI Event Handling

    private func handleMIDIEventList(_ eventListPtr: UnsafePointer<MIDIEventList>) {
        let eventList = eventListPtr.pointee

        var packet = eventList.packet
        for _ in 0..<eventList.numPackets {
            handleMIDIPacket(&packet)
            packet = MIDIEventPacketNext(&packet).pointee
        }
    }

    private func handleMIDIPacket(_ packet: inout MIDIEventPacket) {
        // Get the word count and process MIDI 1.0 Universal MIDI Packet
        let wordCount = packet.wordCount
        guard wordCount > 0 else { return }

        // Access the words through the tuple
        let words = withUnsafeBytes(of: packet.words) { ptr in
            ptr.bindMemory(to: UInt32.self)
        }

        guard let firstWord = words.first else { return }

        // Parse MIDI 1.0 Channel Voice Message (Message Type 0x2)
        let messageType = (firstWord >> 28) & 0xF

        if messageType == 0x2 {
            // MIDI 1.0 Channel Voice Message
            let status = UInt8((firstWord >> 16) & 0xFF)
            let data1 = UInt8((firstWord >> 8) & 0xFF)
            let data2 = UInt8(firstWord & 0xFF)

            processMIDIMessage(status: status, data1: data1, data2: data2)
        }
    }

    private func processMIDIMessage(status: UInt8, data1: UInt8, data2: UInt8) {
        let messageType = status & 0xF0
        let channel = status & 0x0F

        switch messageType {
        case 0x90: // Note On
            if data2 > 0 {
                handleNoteOn(channel: channel, note: data1, velocity: data2)
            } else {
                // Note On with velocity 0 = Note Off
                handleNoteOff(channel: channel, note: data1)
            }

        case 0x80: // Note Off
            handleNoteOff(channel: channel, note: data1)

        case 0xB0: // Control Change
            handleControlChange(channel: channel, controller: data1, value: data2)

        case 0xE0: // Pitch Bend
            let bendValue = Int16(data1) | (Int16(data2) << 7) - 8192
            handlePitchBend(channel: channel, value: bendValue)

        case 0xD0: // Channel Aftertouch
            handleAftertouch(channel: channel, pressure: data1)

        case 0xC0: // Program Change
            handleProgramChange(channel: channel, program: data1)

        default:
            break
        }
    }

    private func handleNoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
        heldNotes.insert(note)

        Task { @MainActor in
            self.lastNote = note
            self.lastVelocity = velocity
            self.onNoteOn?(note, velocity)
        }

        // Debug output
        let noteName = noteNumberToName(note)
        print("♪ Note On: \(noteName) (vel: \(velocity))")
    }

    private func handleNoteOff(channel: UInt8, note: UInt8) {
        heldNotes.remove(note)

        Task { @MainActor in
            self.onNoteOff?(note)
        }

        let noteName = noteNumberToName(note)
        print("♪ Note Off: \(noteName)")
    }

    private func handleControlChange(channel: UInt8, controller: UInt8, value: UInt8) {
        Task { @MainActor in
            self.onControlChange?(controller, value)
        }

        // Common CC names for debugging
        let ccName: String
        switch controller {
        case 1: ccName = "Mod Wheel"
        case 7: ccName = "Volume"
        case 10: ccName = "Pan"
        case 11: ccName = "Expression"
        case 64: ccName = "Sustain"
        case 74: ccName = "Filter Cutoff"
        case 71: ccName = "Resonance"
        default: ccName = "CC\(controller)"
        }

        print("⚙ \(ccName): \(value)")
    }

    private func handlePitchBend(channel: UInt8, value: Int16) {
        Task { @MainActor in
            self.onPitchBend?(value)
        }
    }

    private func handleAftertouch(channel: UInt8, pressure: UInt8) {
        // Can be used for modulation
    }

    private func handleProgramChange(channel: UInt8, program: UInt8) {
        // Can be used for preset switching
        print("⚙ Program Change: \(program)")
    }

    // MARK: - MIDI Notifications

    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        switch notification.pointee.messageID {
        case .msgSetupChanged:
            print("♪ MIDI setup changed")
            refreshDevices()

        case .msgObjectAdded:
            print("♪ MIDI device added")
            refreshDevices()

        case .msgObjectRemoved:
            print("♪ MIDI device removed")
            refreshDevices()

        default:
            break
        }
    }

    // MARK: - Utility

    private func noteNumberToName(_ note: UInt8) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(note) / 12 - 1
        let noteName = noteNames[Int(note) % 12]
        return "\(noteName)\(octave)"
    }

    /// Get all currently held notes (for polyphony)
    func getHeldNotes() -> Set<UInt8> {
        return heldNotes
    }

    /// Check if any notes are currently held
    var hasHeldNotes: Bool {
        return !heldNotes.isEmpty
    }
}

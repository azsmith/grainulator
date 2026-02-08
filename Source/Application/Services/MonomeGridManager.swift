//
//  MonomeGridManager.swift
//  Grainulator
//
//  Monome Grid 128 (16×8) controller integration via serialosc/OSC.
//  Provides hands-on sequencer control: step matrix for note entry,
//  track switching, step parameter editing, and transport control.
//

import Foundation
import Combine
import OSCKit

// MARK: - Grid Track

/// Which sequencer track the grid is currently showing/editing.
enum GridTrack: Int, CaseIterable {
    case track1 = 0
    case track2 = 1
    case chords = 2
}

// MARK: - Loop Edit State

/// Tracks whether the next loop row press sets the start or end position.
private enum LoopEditState {
    case settingStart
    case settingEnd
}

// MARK: - MonomeGridManager

@MainActor
class MonomeGridManager: ObservableObject {

    // MARK: Published State

    @Published var isConnected: Bool = false
    @Published var deviceName: String = ""
    @Published var activeTrack: GridTrack = .track1

    // MARK: Configuration

    /// Our UDP listening port (different from Arc's 17842).
    private let localReceivePort: UInt16 = 17_843

    /// serialosc discovery daemon port.
    private let serialoscPort: UInt16 = 12_002

    /// OSC prefix registered with serialosc for this device.
    private let devicePrefix = "/monome"

    // MARK: Internal State

    private var oscServer: OSCUDPServer?
    private var oscClient: OSCUDPClient?
    private var gridDevicePort: UInt16 = 0
    private var gridDeviceId: String = ""

    /// LED buffer: 8 rows × 16 cols, brightness 0-15.
    private var ledBuffer: [[UInt8]] = Array(repeating: Array(repeating: 0, count: 16), count: 8)
    private var ledDirty: Bool = false
    private var ledUpdateTimer: Timer?
    private var reconnectTimer: Timer?

    /// Currently selected step for control panel editing.
    private var selectedStep: Int = 0

    /// Held step columns for multi-press gestures.
    private var heldStepColumns: Set<Int> = []

    /// Loop row edit state: alternates between setting start and end.
    private var loopEditState: LoopEditState = .settingStart

    /// Chord degree page (0 = Page A: I–V, 1 = Page B: bV–vii).
    private var chordDegreePage: Int = 0

    /// Chord degree IDs for each page. Row 7 is the page toggle, rows 0-6 are degrees.
    private let chordDegreePageA: [String?] = ["V", "IV", "iii", "bIII", "ii", "bII", "I"]
    private let chordDegreePageB: [String?] = ["vii", "bVII", "vi", "bVI", "V", "bV", nil]

    /// Chord quality IDs by row in chord mode control panel.
    /// Row 2 (cols 8-14): triads
    private let chordTriadQualities = ["maj", "min", "dim", "aug", "sus2", "sus4", "pow"]
    /// Row 3 (cols 8-12): sevenths
    private let chordSeventhQualities = ["maj7", "min7", "dom7", "hdim7", "fdim7"]
    /// Row 4 (cols 8-12): extensions
    private let chordExtendedQualities = ["dom9", "maj9", "min9", "dom11", "dom13"]

    /// Step type mapping for row 4 of control panel.
    private let stepTypes: [SequencerStepType] = [.play, .rest, .tie, .skip, .elide]

    /// Gate mode mapping for row 5 of control panel.
    private let gateModes: [SequencerGateMode] = [.every, .first, .last, .tie, .rest]

    private weak var sequencer: StepSequencer?
    private weak var chordSequencer: ChordSequencer?
    private weak var masterClock: MasterClock?
    private weak var audioEngine: AudioEngineWrapper?
    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    /// Voice indices for the 4 granular/looper voices in grid row order.
    private let voiceIndices: [Int] = [0, 3, 1, 2]  // G1, G2, L1, L2

    /// Local tracking of per-voice playing state (toggled by grid buttons).
    private var voicePlaying: [Int: Bool] = [:]

    // MARK: - Lifecycle

    /// Connect the Grid manager to sequencer subsystems.
    func connect(sequencer: StepSequencer, chordSequencer: ChordSequencer, masterClock: MasterClock, audioEngine: AudioEngineWrapper? = nil, appState: AppState? = nil) {
        self.sequencer = sequencer
        self.chordSequencer = chordSequencer
        self.masterClock = masterClock
        self.audioEngine = audioEngine
        self.appState = appState

        observeStateChanges()
        startDiscovery()
    }

    deinit {
        ledUpdateTimer?.invalidate()
        reconnectTimer?.invalidate()
        oscServer?.stop()
        oscClient?.stop()
    }

    // MARK: - serialosc Discovery

    private func startDiscovery() {
        let server = OSCUDPServer(port: localReceivePort, timeTagMode: .ignore)

        server.setReceiveHandler { [weak self] message, timeTag, host, port in
            Task { @MainActor [weak self] in
                self?.handleOSCMessage(message, fromHost: host, fromPort: port)
            }
        }

        do {
            try server.start()
            self.oscServer = server
            NSLog("[Grid] OSC server listening on port %d", localReceivePort)
        } catch {
            NSLog("[Grid] Failed to start OSC server on port %d: %@", localReceivePort, error.localizedDescription)
            scheduleReconnect()
            return
        }

        let client = OSCUDPClient()
        do {
            try client.start()
            self.oscClient = client
        } catch {
            NSLog("[Grid] Failed to start OSC client: %@", error.localizedDescription)
            return
        }

        querySerialoscDevices()
        subscribeToNotifications()
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
            NSLog("[Grid] Sent /serialosc/list query to port %d", serialoscPort)
        } catch {
            NSLog("[Grid] Failed to query serialosc: %@", error.localizedDescription)
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
            NSLog("[Grid] Failed to subscribe to serialosc notifications: %@", error.localizedDescription)
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
        case "/serialosc/device":
            handleDeviceResponse(message)

        case "/serialosc/add":
            NSLog("[Grid] Device added notification")
            querySerialoscDevices()

        case "/serialosc/remove":
            NSLog("[Grid] Device removed notification")
            disconnect()

        case "\(devicePrefix)/grid/key":
            handleGridKey(message)

        default:
            break
        }
    }

    // MARK: - Device Connection

    private func handleDeviceResponse(_ message: OSCMessage) {
        guard message.values.count >= 3,
              let deviceId = message.values[0] as? String,
              let deviceType = message.values[1] as? String,
              let devicePort = message.values[2] as? Int32 else {
            NSLog("[Grid] Malformed /serialosc/device response")
            return
        }

        // Only connect to Grid devices (not Arc)
        let typeLower = deviceType.lowercased()
        guard !typeLower.contains("arc") else {
            return // Silently ignore Arc — ArcManager handles those
        }
        guard typeLower.contains("monome") || typeLower.contains("grid") ||
              typeLower.contains("128") || typeLower.contains("256") ||
              typeLower.contains("64") else {
            NSLog("[Grid] Ignoring non-grid device: %@ (%@)", deviceType, deviceId)
            return
        }

        NSLog("[Grid] Discovered Grid: %@ (%@) on port %d", deviceId, deviceType, devicePort)

        gridDeviceId = deviceId
        gridDevicePort = UInt16(devicePort)

        performHandshake()
    }

    private func performHandshake() {
        guard let client = oscClient, gridDevicePort > 0 else { return }

        do {
            let hostMsg = OSCMessage("/sys/host", values: ["127.0.0.1" as String])
            try client.send(hostMsg, to: "127.0.0.1", port: gridDevicePort)

            let portMsg = OSCMessage("/sys/port", values: [Int32(localReceivePort)])
            try client.send(portMsg, to: "127.0.0.1", port: gridDevicePort)

            let prefixMsg = OSCMessage("/sys/prefix", values: [devicePrefix as String])
            try client.send(prefixMsg, to: "127.0.0.1", port: gridDevicePort)

            NSLog("[Grid] Handshake complete with %@ on port %d", gridDeviceId, gridDevicePort)

            isConnected = true
            deviceName = gridDeviceId

            reconnectTimer?.invalidate()
            reconnectTimer = nil

            // Render initial state and start LED feedback
            ledDirty = true
            startLEDFeedback()

        } catch {
            NSLog("[Grid] Handshake failed: %@", error.localizedDescription)
        }
    }

    func disconnect() {
        guard isConnected else { return }

        clearAllLEDs()

        isConnected = false
        deviceName = ""
        gridDevicePort = 0
        gridDeviceId = ""

        ledUpdateTimer?.invalidate()
        ledUpdateTimer = nil

        NSLog("[Grid] Disconnected")

        scheduleReconnect()
    }

    // MARK: - Grid Key Input

    private func handleGridKey(_ message: OSCMessage) {
        // /grid/key iii <x> <y> <state>
        guard message.values.count >= 3,
              let x = message.values[0] as? Int32,
              let y = message.values[1] as? Int32,
              let s = message.values[2] as? Int32 else { return }

        let col = Int(x)
        let row = Int(y)
        let pressed = (s == 1)

        // Track held step columns for multi-press
        if col < 8 {
            if pressed {
                heldStepColumns.insert(col)
            } else {
                heldStepColumns.remove(col)
            }
        }

        // Only act on key-down
        guard pressed else { return }

        if col < 8 {
            handleStepMatrixPress(col: col, row: row)
        } else {
            handleControlPanelPress(col: col, row: row)
        }
    }

    // MARK: - Step Matrix Press Handling

    private func handleStepMatrixPress(col: Int, row: Int) {
        let step = col
        guard step >= 0, step < 8 else { return }

        switch activeTrack {
        case .track1, .track2:
            handleNoteSlotPress(step: step, row: row)
        case .chords:
            handleChordDegreePress(step: step, row: row)
        }

        // Select this step for control panel editing
        selectedStep = step
        if activeTrack != .chords {
            sequencer?.selectStage(activeTrack.rawValue, step)
        } else {
            chordSequencer?.selectedStep = step
        }

        ledDirty = true
    }

    private func handleNoteSlotPress(step: Int, row: Int) {
        guard let seq = sequencer else { return }
        let trackIdx = activeTrack.rawValue
        let noteSlot = 8 - row  // row 0 = noteSlot 8, row 7 = noteSlot 1

        // If pressing the already-active noteSlot, toggle to 0 (root)
        let currentSlot = seq.tracks[trackIdx].stages[step].noteSlot
        let newSlot = (currentSlot == noteSlot) ? 0 : noteSlot

        seq.setStageNoteSlot(track: trackIdx, stage: step, value: newSlot)
    }

    private func handleChordDegreePress(step: Int, row: Int) {
        guard let chordSeq = chordSequencer else { return }

        // Row 7 = page toggle
        if row == 7 {
            chordDegreePage = (chordDegreePage == 0) ? 1 : 0
            ledDirty = true
            return
        }

        let degrees = chordDegreePage == 0 ? chordDegreePageA : chordDegreePageB
        guard row < degrees.count, let degreeId = degrees[row] else { return }

        chordSeq.setDegree(step, degreeId)

        // If the step doesn't have a quality yet, default to "maj"
        if chordSeq.steps[step].qualityId == nil {
            chordSeq.setQuality(step, "maj")
        }
    }

    // MARK: - Control Panel Press Handling

    private func handleControlPanelPress(col: Int, row: Int) {
        let panelCol = col - 8  // 0-7 within control panel

        switch row {
        case 0:
            handleRow0Press(panelCol: panelCol)
        case 1:
            handleRow1Press(panelCol: panelCol)
        case 2:
            handleRow2Press(panelCol: panelCol)
        case 3:
            handleRow3Press(panelCol: panelCol)
        case 4:
            handleRow4Press(panelCol: panelCol)
        case 5:
            handleRow5Press(panelCol: panelCol)
        case 6:
            handleRow6Press(panelCol: panelCol)
        case 7:
            handleRow7Press(panelCol: panelCol)
        default:
            break
        }

        ledDirty = true
    }

    /// Row 0: Track selection + Transport
    private func handleRow0Press(panelCol: Int) {
        switch panelCol {
        case 0: // Track 1
            activeTrack = .track1
        case 1: // Track 2
            activeTrack = .track2
        case 2: // Chords
            activeTrack = .chords
        case 4: // Play/Stop toggle
            if sequencer?.isPlaying == true {
                sequencer?.stop()
            } else {
                sequencer?.start()
            }
        case 5: // Reset
            sequencer?.reset()
        case 6: // G1 Record toggle
            toggleRecording(voiceIndex: voiceIndices[0])
        case 7: // G1 Play toggle
            togglePlaying(voiceIndex: voiceIndices[0])
        default:
            break
        }
    }

    /// Row 1: Track mutes + Octave up/down + G2 Rec/Play
    private func handleRow1Press(panelCol: Int) {
        switch panelCol {
        case 0: // Mute Track 1
            guard let seq = sequencer else { return }
            seq.setTrackMuted(0, !seq.tracks[0].muted)
        case 1: // Mute Track 2
            guard let seq = sequencer else { return }
            seq.setTrackMuted(1, !seq.tracks[1].muted)
        case 2: // Mute Chords
            guard let chordSeq = chordSequencer else { return }
            chordSeq.isEnabled = !chordSeq.isEnabled
        case 4: // Octave Up
            adjustOctave(direction: 1)
        case 5: // Octave Down
            adjustOctave(direction: -1)
        case 6: // G2 Record toggle
            toggleRecording(voiceIndex: voiceIndices[1])
        case 7: // G2 Play toggle
            togglePlaying(voiceIndex: voiceIndices[1])
        default:
            break
        }
    }

    /// Row 2: Ratchets (Track 1/2) or Triad qualities (Chords) + L1 Rec/Play
    private func handleRow2Press(panelCol: Int) {
        if panelCol == 6 { toggleRecording(voiceIndex: voiceIndices[2]); return }
        if panelCol == 7 { togglePlaying(voiceIndex: voiceIndices[2]); return }

        switch activeTrack {
        case .track1, .track2:
            if panelCol >= 0, panelCol <= 3 {
                let targetStep = heldStepColumns.first ?? selectedStep
                sequencer?.setStageRatchets(track: activeTrack.rawValue, stage: targetStep, value: panelCol + 1)
            }
        case .chords:
            if panelCol < chordTriadQualities.count {
                let targetStep = heldStepColumns.first ?? selectedStep
                chordSequencer?.setQuality(targetStep, chordTriadQualities[panelCol])
            }
        }
    }

    /// Row 3: L2 Rec/Play + Seventh qualities (Chords only)
    private func handleRow3Press(panelCol: Int) {
        if panelCol == 6 { toggleRecording(voiceIndex: voiceIndices[3]); return }
        if panelCol == 7 { togglePlaying(voiceIndex: voiceIndices[3]); return }

        if case .chords = activeTrack {
            if panelCol < chordSeventhQualities.count {
                let targetStep = heldStepColumns.first ?? selectedStep
                chordSequencer?.setQuality(targetStep, chordSeventhQualities[panelCol])
            }
        }
    }

    /// Row 4: Step type (Track 1/2) or Extended qualities (Chords)
    private func handleRow4Press(panelCol: Int) {
        switch activeTrack {
        case .track1, .track2:
            if panelCol < stepTypes.count {
                let targetStep = heldStepColumns.first ?? selectedStep
                sequencer?.setStageStepType(track: activeTrack.rawValue, stage: targetStep, value: stepTypes[panelCol])
            }
        case .chords:
            if panelCol < chordExtendedQualities.count {
                let targetStep = heldStepColumns.first ?? selectedStep
                chordSequencer?.setQuality(targetStep, chordExtendedQualities[panelCol])
            }
        }
    }

    /// Row 5: Gate mode (Track 1/2) or Step active toggles (Chords)
    private func handleRow5Press(panelCol: Int) {
        switch activeTrack {
        case .track1, .track2:
            if panelCol < gateModes.count {
                let targetStep = heldStepColumns.first ?? selectedStep
                sequencer?.setStageGateMode(track: activeTrack.rawValue, stage: targetStep, value: gateModes[panelCol])
            }
        case .chords:
            // Step active/mute toggles (panelCol 0-7 = chord steps 0-7)
            if panelCol < 8, let chordSeq = chordSequencer {
                chordSeq.setStepActive(panelCol, !chordSeq.steps[panelCol].active)
            }
        }
    }

    /// Row 6: Combined loop range (first press = start, second press = end)
    private func handleRow6Press(panelCol: Int) {
        guard panelCol < 8, activeTrack != .chords else { return }

        switch loopEditState {
        case .settingStart:
            sequencer?.setTrackLoopStart(activeTrack.rawValue, panelCol)
            // If the new start is past the current end, also move end
            if let seq = sequencer {
                let trackIdx = activeTrack.rawValue
                if panelCol > seq.tracks[trackIdx].loopEnd {
                    seq.setTrackLoopEnd(trackIdx, panelCol)
                }
            }
            loopEditState = .settingEnd
        case .settingEnd:
            sequencer?.setTrackLoopEnd(activeTrack.rawValue, panelCol)
            // If the new end is before the current start, also move start
            if let seq = sequencer {
                let trackIdx = activeTrack.rawValue
                if panelCol < seq.tracks[trackIdx].loopStart {
                    seq.setTrackLoopStart(trackIdx, panelCol)
                }
            }
            loopEditState = .settingStart
        }
    }

    /// Row 7: Step selector (all modes)
    private func handleRow7Press(panelCol: Int) {
        guard panelCol < 8 else { return }
        selectedStep = panelCol

        if activeTrack != .chords {
            sequencer?.selectStage(activeTrack.rawValue, panelCol)
        } else {
            chordSequencer?.selectedStep = panelCol
        }
    }

    /// Adjust octave offset for the active track.
    private func adjustOctave(direction: Int) {
        guard let seq = sequencer, activeTrack != .chords else { return }
        let trackIdx = activeTrack.rawValue
        let current = seq.trackOctaveOffset(trackIdx)
        seq.setTrackOctaveOffset(trackIdx, current + direction)
    }

    /// Toggle recording for a granular/looper voice.
    private func toggleRecording(voiceIndex: Int) {
        guard let engine = audioEngine else { return }
        let isRec = engine.recordingStates[voiceIndex]?.isRecording ?? false
        if isRec {
            engine.stopRecording(reelIndex: voiceIndex)
        } else {
            // Reuse previous recording settings if available
            if let prev = engine.recordingStates[voiceIndex] {
                engine.startRecording(
                    reelIndex: voiceIndex,
                    mode: prev.mode,
                    sourceType: prev.sourceType,
                    sourceChannel: prev.sourceChannel
                )
            } else {
                // First time: default to Plaits internal source
                let isLooper = (voiceIndex == 1 || voiceIndex == 2)
                let mode: AudioEngineWrapper.RecordMode = isLooper ? .liveLoop : .oneShot
                engine.startRecording(reelIndex: voiceIndex, mode: mode, sourceType: .internalVoice, sourceChannel: 0)
            }
        }
    }

    /// Toggle playback for a granular/looper voice.
    private func togglePlaying(voiceIndex: Int) {
        guard let engine = audioEngine else { return }
        let isPlaying = voicePlaying[voiceIndex] ?? false
        let newState = !isPlaying
        voicePlaying[voiceIndex] = newState
        engine.setGranularPlaying(voiceIndex: voiceIndex, playing: newState)
        // Also switch to this voice tab in the UI
        appState?.focusVoice(voiceIndex)
    }

    // MARK: - LED Rendering

    private func startLEDFeedback() {
        ledUpdateTimer?.invalidate()
        ledUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLEDs()
            }
        }
    }

    private func updateLEDs() {
        guard isConnected, ledDirty else { return }
        ledDirty = false

        renderFullGrid()
        sendLEDUpdate()
    }

    private func renderFullGrid() {
        // Clear buffer
        for row in 0..<8 {
            for col in 0..<16 {
                ledBuffer[row][col] = 0
            }
        }

        renderStepMatrix()
        renderControlPanel()
    }

    // MARK: Step Matrix Rendering

    private func renderStepMatrix() {
        switch activeTrack {
        case .track1, .track2:
            renderTrackStepMatrix()
        case .chords:
            renderChordStepMatrix()
        }
    }

    private func renderTrackStepMatrix() {
        guard let seq = sequencer else { return }
        let trackIdx = activeTrack.rawValue
        guard trackIdx < seq.tracks.count else { return }
        let track = seq.tracks[trackIdx]
        let playhead = seq.playheadStagePerTrack[trackIdx]

        for step in 0..<8 {
            let stage = track.stages[step]
            let noteSlot = stage.noteSlot
            let isPlayhead = seq.isPlaying && (step == playhead)
            let isSelected = (step == selectedStep)

            let isInactive = (stage.stepType == .rest || stage.stepType == .skip)

            for row in 0..<8 {
                let rowSlot = 8 - row  // row 0 = slot 8, row 7 = slot 1
                var brightness: UInt8 = 0

                if isInactive {
                    // REST/SKIP: ghost LED at the noteSlot position only
                    if rowSlot == noteSlot && noteSlot > 0 {
                        brightness = 2
                    }
                } else if noteSlot > 0 {
                    if rowSlot == noteSlot {
                        // Active noteSlot position
                        brightness = 15
                    } else if rowSlot < noteSlot {
                        // Fill bar below noteSlot
                        brightness = 4
                    }
                }

                // Playhead overlay
                if isPlayhead {
                    brightness = min(brightness + 6, 15)
                }

                // Selected step boost
                if isSelected && !isPlayhead {
                    brightness = min(brightness + 2, 15)
                }

                ledBuffer[row][step] = brightness
            }
        }
    }

    private func renderChordStepMatrix() {
        guard let chordSeq = chordSequencer else { return }
        let degrees = chordDegreePage == 0 ? chordDegreePageA : chordDegreePageB
        let playhead = chordSeq.playheadStep

        for step in 0..<8 {
            let chordStep = chordSeq.steps[step]
            let isPlayhead = (sequencer?.isPlaying ?? false) && (step == playhead)
            let isSelected = (step == selectedStep)

            for row in 0..<7 {
                guard let degreeId = degrees[row] else { continue }
                var brightness: UInt8 = 0

                if chordStep.degreeId == degreeId {
                    brightness = chordStep.active ? 15 : 6
                } else {
                    brightness = 2  // Dim available positions
                }

                if isPlayhead {
                    brightness = min(brightness + 6, 15)
                }
                if isSelected && !isPlayhead {
                    brightness = min(brightness + 2, 15)
                }

                ledBuffer[row][step] = brightness
            }

            // Row 7 = page toggle indicator
            ledBuffer[7][step] = isPlayhead ? 6 : (isSelected ? 4 : 0)
        }

        // Page toggle button: show on first column only (or all to indicate page)
        ledBuffer[7][0] = UInt8(chordDegreePage == 0 ? 8 : 15)
    }

    // MARK: Control Panel Rendering

    private func renderControlPanel() {
        renderRow0()
        renderRow1()

        switch activeTrack {
        case .track1, .track2:
            renderRow2Track()
            renderRow3Track()
            renderRow4Track()
            renderRow5Track()
        case .chords:
            renderRow2Chords()
            renderRow3Chords()
            renderRow4Chords()
            renderRow5Chords()
        }

        renderRow6()
        renderRow7()
    }

    /// Row 0: Track selection + Transport
    /// Render Rec (col 14) and Play (col 15) LEDs for a voice on the given row.
    private func renderVoiceRecPlay(row: Int, voiceIndex: Int) {
        let isRec = audioEngine?.recordingStates[voiceIndex]?.isRecording ?? false
        let isPlay = voicePlaying[voiceIndex] ?? false
        ledBuffer[row][14] = isRec ? 15 : 4     // Rec: bright when recording
        ledBuffer[row][15] = isPlay ? 15 : 4    // Play: bright when playing
    }

    private func renderRow0() {
        let isPlaying = sequencer?.isPlaying ?? false

        // Track selection
        ledBuffer[0][8]  = (activeTrack == .track1) ? 15 : 4
        ledBuffer[0][9]  = (activeTrack == .track2) ? 15 : 4
        ledBuffer[0][10] = (activeTrack == .chords) ? 15 : 4

        // Transport
        ledBuffer[0][12] = isPlaying ? 15 : 4    // Play toggle
        ledBuffer[0][13] = 4                      // Reset

        // G1 Rec / Play
        renderVoiceRecPlay(row: 0, voiceIndex: voiceIndices[0])
    }

    /// Row 1: Mutes + Octave up/down + G2 Rec/Play
    private func renderRow1() {
        // Track mutes
        ledBuffer[1][8]  = (sequencer?.tracks[0].muted ?? false) ? 15 : 0
        ledBuffer[1][9]  = (sequencer?.tracks[1].muted ?? false) ? 15 : 0
        ledBuffer[1][10] = (chordSequencer?.isEnabled ?? true) ? 0 : 15  // Inverted: enabled=unmuted

        // Octave up + down
        if activeTrack != .chords, let seq = sequencer {
            let oct = seq.trackOctaveOffset(activeTrack.rawValue)
            ledBuffer[1][12] = oct > 0 ? 15 : 4
            ledBuffer[1][13] = oct < 0 ? 15 : 4
        } else {
            ledBuffer[1][12] = 0
            ledBuffer[1][13] = 0
        }

        // G2 Rec / Play
        renderVoiceRecPlay(row: 1, voiceIndex: voiceIndices[1])
    }

    /// Row 2 (Track mode): Ratchets + L1 Rec/Play
    private func renderRow2Track() {
        guard let seq = sequencer else { return }
        let trackIdx = activeTrack.rawValue
        let step = heldStepColumns.first ?? selectedStep
        guard trackIdx < seq.tracks.count, step < seq.tracks[trackIdx].stages.count else { return }

        let ratchets = seq.tracks[trackIdx].stages[step].ratchets

        // Ratchets fill bar (cols 8-11)
        for i in 0..<4 {
            ledBuffer[2][8 + i] = (i < ratchets) ? 15 : 4
        }

        // L1 Rec / Play
        renderVoiceRecPlay(row: 2, voiceIndex: voiceIndices[2])
    }

    /// Row 3 (Track mode): L2 Rec/Play (probability removed)
    private func renderRow3Track() {
        // Clear cols 8-13 (probability removed)
        for i in 8..<14 {
            ledBuffer[3][i] = 0
        }
        // L2 Rec / Play
        renderVoiceRecPlay(row: 3, voiceIndex: voiceIndices[3])
    }

    /// Row 4 (Track mode): Step type
    private func renderRow4Track() {
        guard let seq = sequencer else { return }
        let trackIdx = activeTrack.rawValue
        let step = heldStepColumns.first ?? selectedStep
        guard trackIdx < seq.tracks.count, step < seq.tracks[trackIdx].stages.count else { return }

        let currentType = seq.tracks[trackIdx].stages[step].stepType

        for (i, sType) in stepTypes.enumerated() {
            ledBuffer[4][8 + i] = (sType == currentType) ? 15 : 4
        }
    }

    /// Row 5 (Track mode): Gate mode
    private func renderRow5Track() {
        guard let seq = sequencer else { return }
        let trackIdx = activeTrack.rawValue
        let step = heldStepColumns.first ?? selectedStep
        guard trackIdx < seq.tracks.count, step < seq.tracks[trackIdx].stages.count else { return }

        let currentMode = seq.tracks[trackIdx].stages[step].gateMode

        for (i, mode) in gateModes.enumerated() {
            ledBuffer[5][8 + i] = (mode == currentMode) ? 15 : 4
        }
    }

    /// Row 2 (Chord mode): Triad qualities + L1 Rec/Play
    private func renderRow2Chords() {
        guard let chordSeq = chordSequencer else { return }
        let step = heldStepColumns.first ?? selectedStep
        guard step < chordSeq.steps.count else { return }

        let currentQuality = chordSeq.steps[step].qualityId

        for (i, qId) in chordTriadQualities.enumerated() {
            ledBuffer[2][8 + i] = (qId == currentQuality) ? 15 : 4
        }

        // L1 Rec / Play
        renderVoiceRecPlay(row: 2, voiceIndex: voiceIndices[2])
    }

    /// Row 3 (Chord mode): Seventh qualities + L2 Rec/Play
    private func renderRow3Chords() {
        guard let chordSeq = chordSequencer else { return }
        let step = heldStepColumns.first ?? selectedStep
        guard step < chordSeq.steps.count else { return }

        let currentQuality = chordSeq.steps[step].qualityId

        for (i, qId) in chordSeventhQualities.enumerated() {
            ledBuffer[3][8 + i] = (qId == currentQuality) ? 15 : 4
        }

        // L2 Rec / Play
        renderVoiceRecPlay(row: 3, voiceIndex: voiceIndices[3])
    }

    /// Row 4 (Chord mode): Extended qualities
    private func renderRow4Chords() {
        guard let chordSeq = chordSequencer else { return }
        let step = heldStepColumns.first ?? selectedStep
        guard step < chordSeq.steps.count else { return }

        let currentQuality = chordSeq.steps[step].qualityId

        for (i, qId) in chordExtendedQualities.enumerated() {
            ledBuffer[4][8 + i] = (qId == currentQuality) ? 15 : 4
        }
    }

    /// Row 5 (Chord mode): Step active/mute toggles
    private func renderRow5Chords() {
        guard let chordSeq = chordSequencer else { return }

        for i in 0..<8 {
            guard i < chordSeq.steps.count else { continue }
            let step = chordSeq.steps[i]
            if step.isEmpty {
                ledBuffer[5][8 + i] = 0
            } else {
                ledBuffer[5][8 + i] = step.active ? 12 : 4
            }
        }
    }

    /// Row 6: Combined loop range (start + end on one row)
    private func renderRow6() {
        guard activeTrack != .chords, let seq = sequencer else {
            // No loop controls for chord track
            return
        }
        let trackIdx = activeTrack.rawValue
        guard trackIdx < seq.tracks.count else { return }
        let loopStart = seq.tracks[trackIdx].loopStart
        let loopEnd = seq.tracks[trackIdx].loopEnd

        for i in 0..<8 {
            if i == loopStart || i == loopEnd {
                ledBuffer[6][8 + i] = 15  // Start and end = full bright
            } else if i > loopStart, i < loopEnd {
                ledBuffer[6][8 + i] = 8   // In-range = medium
            } else {
                ledBuffer[6][8 + i] = 0   // Outside = off
            }
        }
    }

    /// Row 7: Step selector (all modes)
    private func renderRow7() {
        // Determine playhead position based on active track
        let playhead: Int
        let isPlaying: Bool
        if activeTrack == .chords {
            playhead = chordSequencer?.playheadStep ?? -1
            isPlaying = sequencer?.isPlaying ?? false
        } else {
            let trackIdx = activeTrack.rawValue
            playhead = sequencer?.playheadStagePerTrack[trackIdx] ?? -1
            isPlaying = sequencer?.isPlaying ?? false
        }

        for i in 0..<8 {
            if i == selectedStep {
                ledBuffer[7][8 + i] = 15  // Selected step = full bright
            } else if isPlaying && i == playhead {
                ledBuffer[7][8 + i] = 8   // Playhead = medium
            } else {
                ledBuffer[7][8 + i] = 3   // Others = dim
            }
        }
    }

    // MARK: - LED Output

    /// Send the full LED buffer to the grid using two /grid/led/level/map messages.
    private func sendLEDUpdate() {
        guard let client = oscClient, gridDevicePort > 0 else { return }

        // Left quadrant: cols 0-7 (x_offset=0, y_offset=0)
        sendLevelMap(client: client, xOffset: 0, yOffset: 0)

        // Right quadrant: cols 8-15 (x_offset=8, y_offset=0)
        sendLevelMap(client: client, xOffset: 8, yOffset: 0)
    }

    /// Send a single 8×8 quadrant level map.
    private func sendLevelMap(client: OSCUDPClient, xOffset: Int, yOffset: Int) {
        // /grid/led/level/map x_offset y_offset d[64]
        // d is row-major: data[row * 8 + col]
        var values: [any OSCValue] = [Int32(xOffset), Int32(yOffset)]

        for row in 0..<8 {
            for col in 0..<8 {
                values.append(Int32(ledBuffer[row + yOffset][col + xOffset]))
            }
        }

        let message = OSCMessage("\(devicePrefix)/grid/led/level/map", values: values)
        try? client.send(message, to: "127.0.0.1", port: gridDevicePort)
    }

    /// Clear all LEDs.
    private func clearAllLEDs() {
        guard let client = oscClient, gridDevicePort > 0 else { return }
        let message = OSCMessage("\(devicePrefix)/grid/led/all", values: [Int32(0)])
        try? client.send(message, to: "127.0.0.1", port: gridDevicePort)
    }

    // MARK: - State Observation

    private func observeStateChanges() {
        // Observe step sequencer track data changes
        sequencer?.$tracks
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.ledDirty = true
                }
            }
            .store(in: &cancellables)

        // Observe playhead changes (high frequency)
        sequencer?.$playheadStagePerTrack
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.ledDirty = true
                }
            }
            .store(in: &cancellables)

        // Observe transport state
        sequencer?.$isPlaying
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.ledDirty = true
                }
            }
            .store(in: &cancellables)

        // Observe chord sequencer changes
        chordSequencer?.$steps
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard self?.activeTrack == .chords else { return }
                    self?.ledDirty = true
                }
            }
            .store(in: &cancellables)

        chordSequencer?.$playheadStep
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard self?.activeTrack == .chords else { return }
                    self?.ledDirty = true
                }
            }
            .store(in: &cancellables)

        chordSequencer?.$isEnabled
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.ledDirty = true
                }
            }
            .store(in: &cancellables)
    }
}

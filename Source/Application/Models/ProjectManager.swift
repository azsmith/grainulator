//
//  ProjectManager.swift
//  Grainulator
//
//  UI-facing manager for project save/load with file dialogs
//  Connects menu commands to ProjectSerializer
//

import SwiftUI
import UniformTypeIdentifiers

@MainActor
class ProjectManager: ObservableObject {
    @Published var currentProjectURL: URL?
    @Published var currentProjectName: String = "Untitled"
    @Published var hasUnsavedChanges: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    // References to subsystems (set during app startup)
    weak var audioEngine: AudioEngineWrapper?
    weak var mixerState: MixerState?
    weak var sequencer: StepSequencer?
    weak var masterClock: MasterClock?
    weak var appState: AppState?
    weak var pluginManager: AUPluginManager?
    weak var drumSequencer: DrumSequencer?
    weak var chordSequencer: ChordSequencer?
    weak var scrambleManager: ScrambleManager?

    /// Connect all subsystems (call from GrainulatorApp.onAppear)
    func connect(
        audioEngine: AudioEngineWrapper,
        mixerState: MixerState,
        sequencer: StepSequencer,
        masterClock: MasterClock,
        appState: AppState,
        pluginManager: AUPluginManager,
        drumSequencer: DrumSequencer? = nil,
        chordSequencer: ChordSequencer? = nil,
        scrambleManager: ScrambleManager? = nil
    ) {
        self.audioEngine = audioEngine
        self.mixerState = mixerState
        self.sequencer = sequencer
        self.masterClock = masterClock
        self.appState = appState
        self.pluginManager = pluginManager
        self.drumSequencer = drumSequencer
        self.chordSequencer = chordSequencer
        self.scrambleManager = scrambleManager
    }

    // MARK: - File Type

    static let projectFileType = UTType(exportedAs: "com.grainulator.project", conformingTo: .json)

    // MARK: - New Project

    func newProject() {
        guard let audioEngine, let mixerState, let sequencer, let masterClock, let appState else { return }

        // Reset all state to defaults
        mixerState.resetAll()

        // Reset sequencer
        sequencer.stop()
        sequencer.tempoBPM = 120.0
        sequencer.rootNote = 0
        sequencer.sequenceOctave = 0
        sequencer.scaleIndex = 0

        // Reset drum sequencer
        if let drumSeq = drumSequencer {
            drumSeq.stop()
            drumSeq.clearAll()
            drumSeq.stepDivision = .x4
            drumSeq.syncToTransport = true
            for i in 0..<drumSeq.lanes.count {
                drumSeq.lanes[i].isMuted = false
                drumSeq.lanes[i].level = 0.8
                drumSeq.lanes[i].harmonics = 0.5
                drumSeq.lanes[i].timbre = 0.5
                drumSeq.lanes[i].morph = 0.5
                drumSeq.lanes[i].note = 60
                audioEngine.setDrumSeqLaneLevel(i, value: 0.8)
                audioEngine.setDrumSeqLaneHarmonics(i, value: 0.5)
                audioEngine.setDrumSeqLaneTimbre(i, value: 0.5)
                audioEngine.setDrumSeqLaneMorph(i, value: 0.5)
            }
        }

        // Reset chord sequencer
        if let chordSeq = chordSequencer {
            chordSeq.clearAll()
            chordSeq.division = .div4
            chordSeq.isEnabled = true
        }

        // Reset scramble manager
        if let scrambleMgr = scrambleManager {
            scrambleMgr.stop()
            scrambleMgr.enabled = false
            scrambleMgr.reset()
            scrambleMgr.division = .x1
            scrambleMgr.gate1Destination = .plaitsGate
            scrambleMgr.gate2Destination = .ringsGate
            scrambleMgr.gate3Destination = .daisyDrumGate
            scrambleMgr.note1Destination = .plaits
            scrambleMgr.note2Destination = .rings
            scrambleMgr.note3Destination = .none
            scrambleMgr.modDestination = .plaitsTimbre
            scrambleMgr.modAmount = 0.5
        }

        // Reset master clock
        masterClock.stop()
        masterClock.bpm = 120.0
        masterClock.swing = 0.0

        // Reset UI
        appState.focusedVoice = 0

        // Sync to engine
        mixerState.syncToAudioEngine(audioEngine)

        currentProjectURL = nil
        currentProjectName = "Untitled"
        hasUnsavedChanges = false
        lastError = nil
    }

    // MARK: - Save

    func saveProject() {
        if let url = currentProjectURL {
            saveToURL(url)
        } else {
            saveProjectAs()
        }
    }

    func saveProjectAs() {
        let panel = NSSavePanel()
        panel.title = "Save Grainulator Project"
        panel.nameFieldStringValue = currentProjectName
        panel.allowedContentTypes = [UTType.json]
        panel.allowsOtherFileTypes = false
        panel.canCreateDirectories = true

        if let ext = panel.allowedContentTypes.first?.preferredFilenameExtension {
            panel.nameFieldStringValue = "\(currentProjectName).\(ext)"
        }

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.saveToURL(url)
            }
        }
    }

    private func saveToURL(_ url: URL) {
        guard let audioEngine, let mixerState, let sequencer, let masterClock, let appState else {
            lastError = "Cannot save: subsystems not connected"
            return
        }

        let projectName = url.deletingPathExtension().lastPathComponent

        var snapshot = ProjectSerializer.captureSnapshot(
            name: projectName,
            audioEngine: audioEngine,
            mixerState: mixerState,
            sequencer: sequencer,
            masterClock: masterClock,
            appState: appState,
            drumSequencer: drumSequencer,
            chordSequencer: chordSequencer,
            scrambleManager: scrambleManager
        )

        // Update timestamps if overwriting
        if currentProjectURL == url {
            snapshot.modifiedAt = Date()
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: .atomic)

            currentProjectURL = url
            currentProjectName = projectName
            hasUnsavedChanges = false
            lastError = nil
            print("[ProjectManager] Saved project to \(url.path)")
        } catch {
            lastError = "Save failed: \(error.localizedDescription)"
            print("[ProjectManager] Save error: \(error)")
        }
    }

    // MARK: - Load

    func openProject() {
        let panel = NSOpenPanel()
        panel.title = "Open Grainulator Project"
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                await self?.loadFromURL(url)
            }
        }
    }

    func loadFromURL(_ url: URL) async {
        guard let audioEngine, let mixerState, let sequencer,
              let masterClock, let appState, let pluginManager else {
            lastError = "Cannot load: subsystems not connected"
            return
        }

        isLoading = true
        lastError = nil

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(ProjectSnapshot.self, from: data)

            // Validate version
            guard snapshot.version <= ProjectSnapshot.currentVersion else {
                lastError = "Project version \(snapshot.version) is newer than supported (\(ProjectSnapshot.currentVersion))"
                isLoading = false
                return
            }

            await ProjectSerializer.restoreSnapshot(
                snapshot,
                audioEngine: audioEngine,
                mixerState: mixerState,
                sequencer: sequencer,
                masterClock: masterClock,
                appState: appState,
                pluginManager: pluginManager,
                drumSequencer: drumSequencer,
                chordSequencer: chordSequencer,
                scrambleManager: scrambleManager
            )

            currentProjectURL = url
            currentProjectName = snapshot.name
            hasUnsavedChanges = false
            print("[ProjectManager] Loaded project from \(url.path)")
        } catch {
            lastError = "Load failed: \(error.localizedDescription)"
            print("[ProjectManager] Load error: \(error)")
        }

        isLoading = false
    }
}

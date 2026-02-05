//
//  ProjectSerializer.swift
//  Grainulator
//
//  Captures and restores project state from/to live objects
//  Acts as the bridge between runtime state and the Codable snapshot
//

import Foundation

@MainActor
struct ProjectSerializer {

    // MARK: - Capture Current State

    static func captureSnapshot(
        name: String,
        audioEngine: AudioEngineWrapper,
        mixerState: MixerState,
        sequencer: MetropolixSequencer,
        masterClock: MasterClock,
        appState: AppState
    ) -> ProjectSnapshot {
        let now = Date()
        return ProjectSnapshot(
            version: ProjectSnapshot.currentVersion,
            name: name,
            createdAt: now,
            modifiedAt: now,
            engineParameters: captureEngineParameters(audioEngine),
            mixer: captureMixer(mixerState),
            sequencer: captureSequencer(sequencer),
            masterClock: captureMasterClock(masterClock),
            auPlugins: captureAUPlugins(audioEngine),
            audioFiles: captureAudioFiles(audioEngine),
            uiPreferences: captureUIPreferences(appState)
        )
    }

    // MARK: - Engine Parameters

    private static func captureEngineParameters(_ engine: AudioEngineWrapper) -> EngineParametersSnapshot {
        // Capture 4 granular voices
        var granularVoices: [GranularVoiceSnapshot] = []
        for i in 0..<4 {
            granularVoices.append(GranularVoiceSnapshot(
                voiceIndex: i,
                speed: engine.getParameter(id: .granularSpeed, voiceIndex: i),
                pitch: engine.getParameter(id: .granularPitch, voiceIndex: i),
                size: engine.getParameter(id: .granularSize, voiceIndex: i),
                density: engine.getParameter(id: .granularDensity, voiceIndex: i),
                jitter: engine.getParameter(id: .granularJitter, voiceIndex: i),
                spread: engine.getParameter(id: .granularSpread, voiceIndex: i),
                pan: engine.getParameter(id: .granularPan, voiceIndex: i),
                filterCutoff: engine.getParameter(id: .granularFilterCutoff, voiceIndex: i),
                filterResonance: engine.getParameter(id: .granularFilterResonance, voiceIndex: i),
                gain: engine.getParameter(id: .granularGain, voiceIndex: i),
                send: engine.getParameter(id: .granularSend, voiceIndex: i),
                envelope: engine.getParameter(id: .granularEnvelope, voiceIndex: i),
                decay: engine.getParameter(id: .granularDecay, voiceIndex: i),
                filterModel: engine.getParameter(id: .granularFilterModel, voiceIndex: i),
                reverse: engine.getParameter(id: .granularReverse, voiceIndex: i),
                morph: engine.getParameter(id: .granularMorph, voiceIndex: i)
            ))
        }

        let plaits = PlaitsSnapshot(
            model: engine.getParameter(id: .plaitsModel),
            harmonics: engine.getParameter(id: .plaitsHarmonics),
            timbre: engine.getParameter(id: .plaitsTimbre),
            morph: engine.getParameter(id: .plaitsMorph),
            frequency: engine.getParameter(id: .plaitsFrequency),
            level: engine.getParameter(id: .plaitsLevel),
            lpgColor: engine.getParameter(id: .plaitsLPGColor),
            lpgDecay: engine.getParameter(id: .plaitsLPGDecay),
            lpgAttack: engine.getParameter(id: .plaitsLPGAttack),
            lpgBypass: engine.getParameter(id: .plaitsLPGBypass)
        )

        let rings = RingsSnapshot(
            model: engine.getParameter(id: .ringsModel),
            structure: engine.getParameter(id: .ringsStructure),
            brightness: engine.getParameter(id: .ringsBrightness),
            damping: engine.getParameter(id: .ringsDamping),
            position: engine.getParameter(id: .ringsPosition),
            level: engine.getParameter(id: .ringsLevel)
        )

        let delay = DelaySnapshot(
            time: engine.getParameter(id: .delayTime),
            feedback: engine.getParameter(id: .delayFeedback),
            mix: engine.getParameter(id: .delayMix),
            headMode: engine.getParameter(id: .delayHeadMode),
            wow: engine.getParameter(id: .delayWow),
            flutter: engine.getParameter(id: .delayFlutter),
            tone: engine.getParameter(id: .delayTone),
            sync: engine.getParameter(id: .delaySync),
            tempo: engine.getParameter(id: .delayTempo),
            subdivision: engine.getParameter(id: .delaySubdivision)
        )

        let reverb = ReverbSnapshot(
            size: engine.getParameter(id: .reverbSize),
            damping: engine.getParameter(id: .reverbDamping),
            mix: engine.getParameter(id: .reverbMix)
        )

        let masterFilter = MasterFilterSnapshot(
            cutoff: engine.getParameter(id: .masterFilterCutoff),
            resonance: engine.getParameter(id: .masterFilterResonance),
            model: engine.getParameter(id: .masterFilterModel)
        )

        // Capture 2 loopers (voice indices 1, 2)
        var loopers: [LooperSnapshot] = []
        for i in 1...2 {
            loopers.append(LooperSnapshot(
                voiceIndex: i,
                rate: engine.getParameter(id: .looperRate, voiceIndex: i),
                reverse: engine.getParameter(id: .looperReverse, voiceIndex: i),
                loopStart: engine.getParameter(id: .looperLoopStart, voiceIndex: i),
                loopEnd: engine.getParameter(id: .looperLoopEnd, voiceIndex: i),
                cut: engine.getParameter(id: .looperCut, voiceIndex: i)
            ))
        }

        return EngineParametersSnapshot(
            granularVoices: granularVoices,
            plaits: plaits,
            rings: rings,
            delay: delay,
            reverb: reverb,
            masterFilter: masterFilter,
            loopers: loopers
        )
    }

    // MARK: - Mixer

    private static func captureMixer(_ mixerState: MixerState) -> MixerSnapshot {
        let channels = mixerState.channels.map { ch in
            MixerChannelSnapshot(
                channelIndex: ch.channelType.rawValue,
                gain: ch.gain,
                pan: ch.pan,
                isMuted: ch.isMuted,
                isSolo: ch.isSolo,
                sendA: SendStateSnapshot(
                    level: ch.sendA.level,
                    mode: ch.sendA.mode.rawValue,
                    isEnabled: ch.sendA.isEnabled
                ),
                sendB: SendStateSnapshot(
                    level: ch.sendB.level,
                    mode: ch.sendB.mode.rawValue,
                    isEnabled: ch.sendB.isEnabled
                ),
                insert1: captureInsertEffect(ch.insert1),
                insert2: captureInsertEffect(ch.insert2),
                microDelay: ch.microDelay,
                isPhaseInverted: ch.isPhaseInverted
            )
        }

        let master = MasterChannelSnapshot(
            gain: mixerState.master.gain,
            isMuted: mixerState.master.isMuted,
            delayReturnLevel: mixerState.master.delayReturnLevel,
            reverbReturnLevel: mixerState.master.reverbReturnLevel,
            filterCutoff: mixerState.master.filterCutoff,
            filterResonance: mixerState.master.filterResonance,
            filterModel: mixerState.master.filterModel
        )

        return MixerSnapshot(channels: channels, master: master)
    }

    private static func captureInsertEffect(_ insert: InsertEffectState) -> InsertEffectSnapshot {
        InsertEffectSnapshot(
            effectType: insert.effectType.rawValue,
            isBypassed: insert.isBypassed,
            parameters: insert.parameters
        )
    }

    // MARK: - Sequencer

    private static func captureSequencer(_ sequencer: MetropolixSequencer) -> SequencerSnapshot {
        let tracks = sequencer.tracks.map { track in
            SequencerTrackSnapshot(
                id: track.id,
                name: track.name,
                muted: track.muted,
                direction: track.direction.rawValue,
                division: track.division.rawValue,
                loopStart: track.loopStart,
                loopEnd: track.loopEnd,
                transpose: track.transpose,
                baseOctave: track.baseOctave,
                velocity: track.velocity,
                output: track.output.rawValue,
                stages: track.stages.map { stage in
                    SequencerStageSnapshot(
                        id: stage.id,
                        pulses: stage.pulses,
                        gateMode: stage.gateMode.rawValue,
                        ratchets: stage.ratchets,
                        probability: stage.probability,
                        noteSlot: stage.noteSlot,
                        octave: stage.octave,
                        stepType: stage.stepType.rawValue,
                        slide: stage.slide
                    )
                }
            )
        }

        return SequencerSnapshot(
            tempoBPM: sequencer.tempoBPM,
            rootNote: sequencer.rootNote,
            sequenceOctave: sequencer.sequenceOctave,
            scaleIndex: sequencer.scaleIndex,
            interEngineCompensationSamples: sequencer.interEngineCompensationSamples,
            plaitsTriggerOffsetMs: sequencer.plaitsTriggerOffsetMs,
            ringsTriggerOffsetMs: sequencer.ringsTriggerOffsetMs,
            tracks: tracks
        )
    }

    // MARK: - Master Clock

    private static func captureMasterClock(_ clock: MasterClock) -> MasterClockSnapshot {
        let outputs = clock.outputs.map { output in
            ClockOutputSnapshot(
                id: output.id,
                mode: output.mode.rawValue,
                waveform: output.waveform.rawValue,
                division: output.division.rawValue,
                slowMode: output.slowMode,
                level: output.level,
                offset: output.offset,
                phase: output.phase,
                width: output.width,
                destination: output.destination.rawValue,
                modulationAmount: output.modulationAmount,
                muted: output.muted
            )
        }

        return MasterClockSnapshot(
            bpm: clock.bpm,
            swing: clock.swing,
            externalSync: clock.externalSync,
            outputs: outputs
        )
    }

    // MARK: - AU Plugins

    private static func captureAUPlugins(_ engine: AudioEngineWrapper) -> AUPluginsSnapshot {
        // Send slots
        var sendSnapshots: [AUSendSnapshot] = []
        for busIndex in 0..<2 {
            if let slot = engine.getSendSlot(busIndex: busIndex),
               let snapshot = slot.createSnapshot() {
                sendSnapshots.append(snapshot)
            }
        }

        // Insert slots (6 channels x 2 slots)
        var insertSnapshots: [[AUSlotSnapshot?]] = []
        for channelIndex in 0..<6 {
            var channelSlots: [AUSlotSnapshot?] = []
            if let slots = engine.getInsertSlots(forChannel: channelIndex) {
                for slot in slots {
                    channelSlots.append(slot.createSnapshot())
                }
            }
            insertSnapshots.append(channelSlots)
        }

        return AUPluginsSnapshot(
            sendSlots: sendSnapshots,
            insertSlots: insertSnapshots
        )
    }

    // MARK: - Audio Files

    private static func captureAudioFiles(_ engine: AudioEngineWrapper) -> AudioFilesSnapshot {
        let reels = engine.loadedAudioFilePaths.map { (index, url) in
            AudioReelReference(reelIndex: index, filePath: url.path)
        }.sorted { $0.reelIndex < $1.reelIndex }

        return AudioFilesSnapshot(reels: reels)
    }

    // MARK: - UI Preferences

    private static func captureUIPreferences(_ appState: AppState) -> UIPreferencesSnapshot {
        let viewMode: String
        switch appState.currentView {
        case .multiVoice: viewMode = "multiVoice"
        case .focus: viewMode = "focus"
        case .performance: viewMode = "performance"
        }

        return UIPreferencesSnapshot(
            useTabLayout: appState.useTabLayout,
            useNewMixer: appState.useNewMixer,
            currentView: viewMode,
            focusedVoice: appState.focusedVoice,
            selectedGranularVoice: appState.selectedGranularVoice
        )
    }

    // MARK: - Restore State

    static func restoreSnapshot(
        _ snapshot: ProjectSnapshot,
        audioEngine: AudioEngineWrapper,
        mixerState: MixerState,
        sequencer: MetropolixSequencer,
        masterClock: MasterClock,
        appState: AppState,
        pluginManager: AUPluginManager
    ) async {
        // 1. Stop playback
        if sequencer.isPlaying {
            sequencer.stop()
        }
        if masterClock.isRunning {
            masterClock.stop()
        }

        // 2. Restore UI preferences
        restoreUIPreferences(snapshot.uiPreferences, appState: appState)

        // 3. Restore mixer state (Swift side)
        restoreMixer(snapshot.mixer, mixerState: mixerState)

        // 4. Restore sequencer state
        restoreSequencer(snapshot.sequencer, sequencer: sequencer)

        // 5. Restore master clock state
        restoreMasterClock(snapshot.masterClock, masterClock: masterClock)

        // 6. Push all C++ engine parameters
        restoreEngineParameters(snapshot.engineParameters, engine: audioEngine)

        // 7. Sync mixer to C++ engine
        mixerState.syncToAudioEngine(audioEngine)

        // 8. Sync clock outputs to engine
        masterClock.syncAllOutputsToEngine()

        // 9. Restore AU plugins (async)
        await restoreAUPlugins(snapshot.auPlugins, engine: audioEngine, pluginManager: pluginManager)

        // 10. Reload audio files
        restoreAudioFiles(snapshot.audioFiles, engine: audioEngine)
    }

    // MARK: - Restore Helpers

    private static func restoreUIPreferences(_ prefs: UIPreferencesSnapshot, appState: AppState) {
        appState.useTabLayout = prefs.useTabLayout
        appState.useNewMixer = prefs.useNewMixer
        appState.focusedVoice = prefs.focusedVoice
        appState.selectedGranularVoice = prefs.selectedGranularVoice

        switch prefs.currentView {
        case "focus": appState.currentView = .focus
        case "performance": appState.currentView = .performance
        default: appState.currentView = .multiVoice
        }
    }

    private static func restoreMixer(_ snapshot: MixerSnapshot, mixerState: MixerState) {
        // Restore channel states
        for channelSnap in snapshot.channels {
            guard channelSnap.channelIndex < mixerState.channels.count else { continue }
            let ch = mixerState.channels[channelSnap.channelIndex]

            ch.gain = channelSnap.gain
            ch.pan = channelSnap.pan
            ch.isMuted = channelSnap.isMuted
            ch.isSolo = channelSnap.isSolo
            ch.microDelay = channelSnap.microDelay
            ch.isPhaseInverted = channelSnap.isPhaseInverted

            // Send states
            ch.sendA.level = channelSnap.sendA.level
            ch.sendA.mode = SendMode(rawValue: channelSnap.sendA.mode) ?? .postFader
            ch.sendA.isEnabled = channelSnap.sendA.isEnabled
            ch.sendB.level = channelSnap.sendB.level
            ch.sendB.mode = SendMode(rawValue: channelSnap.sendB.mode) ?? .postFader
            ch.sendB.isEnabled = channelSnap.sendB.isEnabled

            // Insert effects
            restoreInsertEffect(channelSnap.insert1, to: ch.insert1)
            restoreInsertEffect(channelSnap.insert2, to: ch.insert2)
        }

        // Restore master state
        let m = mixerState.master
        m.gain = snapshot.master.gain
        m.isMuted = snapshot.master.isMuted
        m.delayReturnLevel = snapshot.master.delayReturnLevel
        m.reverbReturnLevel = snapshot.master.reverbReturnLevel
        m.filterCutoff = snapshot.master.filterCutoff
        m.filterResonance = snapshot.master.filterResonance
        m.filterModel = snapshot.master.filterModel
    }

    private static func restoreInsertEffect(_ snapshot: InsertEffectSnapshot, to insert: InsertEffectState) {
        insert.effectType = InsertEffectType(rawValue: snapshot.effectType) ?? .none
        insert.isBypassed = snapshot.isBypassed
        // Restore parameters array, padding if needed
        let count = max(snapshot.parameters.count, 6)
        var params = snapshot.parameters
        while params.count < count {
            params.append(0.5)
        }
        insert.parameters = params
    }

    private static func restoreSequencer(_ snapshot: SequencerSnapshot, sequencer: MetropolixSequencer) {
        sequencer.tempoBPM = snapshot.tempoBPM
        sequencer.rootNote = snapshot.rootNote
        sequencer.sequenceOctave = snapshot.sequenceOctave
        sequencer.scaleIndex = snapshot.scaleIndex
        sequencer.interEngineCompensationSamples = snapshot.interEngineCompensationSamples
        sequencer.plaitsTriggerOffsetMs = snapshot.plaitsTriggerOffsetMs
        sequencer.ringsTriggerOffsetMs = snapshot.ringsTriggerOffsetMs

        // Restore tracks
        for (i, trackSnap) in snapshot.tracks.enumerated() {
            guard i < sequencer.tracks.count else { continue }

            sequencer.tracks[i].name = trackSnap.name
            sequencer.tracks[i].muted = trackSnap.muted
            sequencer.tracks[i].direction = SequencerDirection(rawValue: trackSnap.direction) ?? .forward
            sequencer.tracks[i].division = SequencerClockDivision(rawValue: trackSnap.division) ?? .x1
            sequencer.tracks[i].loopStart = trackSnap.loopStart
            sequencer.tracks[i].loopEnd = trackSnap.loopEnd
            sequencer.tracks[i].transpose = trackSnap.transpose
            sequencer.tracks[i].baseOctave = trackSnap.baseOctave
            sequencer.tracks[i].velocity = trackSnap.velocity
            sequencer.tracks[i].output = SequencerTrackOutput(rawValue: trackSnap.output) ?? .plaits

            // Restore stages
            for (j, stageSnap) in trackSnap.stages.enumerated() {
                guard j < sequencer.tracks[i].stages.count else { continue }
                sequencer.tracks[i].stages[j].pulses = stageSnap.pulses
                sequencer.tracks[i].stages[j].gateMode = SequencerGateMode(rawValue: stageSnap.gateMode) ?? .every
                sequencer.tracks[i].stages[j].ratchets = stageSnap.ratchets
                sequencer.tracks[i].stages[j].probability = stageSnap.probability
                sequencer.tracks[i].stages[j].noteSlot = stageSnap.noteSlot
                sequencer.tracks[i].stages[j].octave = stageSnap.octave
                sequencer.tracks[i].stages[j].stepType = SequencerStepType(rawValue: stageSnap.stepType) ?? .play
                sequencer.tracks[i].stages[j].slide = stageSnap.slide
            }
        }
    }

    private static func restoreMasterClock(_ snapshot: MasterClockSnapshot, masterClock: MasterClock) {
        masterClock.bpm = snapshot.bpm
        masterClock.swing = snapshot.swing
        masterClock.externalSync = snapshot.externalSync

        for (i, outputSnap) in snapshot.outputs.enumerated() {
            guard i < masterClock.outputs.count else { continue }
            let output = masterClock.outputs[i]

            output.mode = ClockOutputMode(rawValue: outputSnap.mode) ?? .clock
            output.waveform = ClockWaveform(rawValue: outputSnap.waveform) ?? .gate
            output.division = SequencerClockDivision(rawValue: outputSnap.division) ?? .x1
            output.slowMode = outputSnap.slowMode
            output.level = outputSnap.level
            output.offset = outputSnap.offset
            output.phase = outputSnap.phase
            output.width = outputSnap.width
            output.destination = ModulationDestination(rawValue: outputSnap.destination) ?? .none
            output.modulationAmount = outputSnap.modulationAmount
            output.muted = outputSnap.muted
        }
    }

    private static func restoreEngineParameters(_ snapshot: EngineParametersSnapshot, engine: AudioEngineWrapper) {
        // Granular voices
        for voice in snapshot.granularVoices {
            let vi = voice.voiceIndex
            engine.setParameter(id: .granularSpeed, value: voice.speed, voiceIndex: vi)
            engine.setParameter(id: .granularPitch, value: voice.pitch, voiceIndex: vi)
            engine.setParameter(id: .granularSize, value: voice.size, voiceIndex: vi)
            engine.setParameter(id: .granularDensity, value: voice.density, voiceIndex: vi)
            engine.setParameter(id: .granularJitter, value: voice.jitter, voiceIndex: vi)
            engine.setParameter(id: .granularSpread, value: voice.spread, voiceIndex: vi)
            engine.setParameter(id: .granularPan, value: voice.pan, voiceIndex: vi)
            engine.setParameter(id: .granularFilterCutoff, value: voice.filterCutoff, voiceIndex: vi)
            engine.setParameter(id: .granularFilterResonance, value: voice.filterResonance, voiceIndex: vi)
            engine.setParameter(id: .granularGain, value: voice.gain, voiceIndex: vi)
            engine.setParameter(id: .granularSend, value: voice.send, voiceIndex: vi)
            engine.setParameter(id: .granularEnvelope, value: voice.envelope, voiceIndex: vi)
            engine.setParameter(id: .granularDecay, value: voice.decay, voiceIndex: vi)
            engine.setParameter(id: .granularFilterModel, value: voice.filterModel, voiceIndex: vi)
            engine.setParameter(id: .granularReverse, value: voice.reverse, voiceIndex: vi)
            engine.setParameter(id: .granularMorph, value: voice.morph, voiceIndex: vi)
        }

        // Plaits
        let p = snapshot.plaits
        engine.setParameter(id: .plaitsModel, value: p.model)
        engine.setParameter(id: .plaitsHarmonics, value: p.harmonics)
        engine.setParameter(id: .plaitsTimbre, value: p.timbre)
        engine.setParameter(id: .plaitsMorph, value: p.morph)
        engine.setParameter(id: .plaitsFrequency, value: p.frequency)
        engine.setParameter(id: .plaitsLevel, value: p.level)
        engine.setParameter(id: .plaitsLPGColor, value: p.lpgColor)
        engine.setParameter(id: .plaitsLPGDecay, value: p.lpgDecay)
        engine.setParameter(id: .plaitsLPGAttack, value: p.lpgAttack)
        engine.setParameter(id: .plaitsLPGBypass, value: p.lpgBypass)

        // Rings
        let r = snapshot.rings
        engine.setParameter(id: .ringsModel, value: r.model)
        engine.setParameter(id: .ringsStructure, value: r.structure)
        engine.setParameter(id: .ringsBrightness, value: r.brightness)
        engine.setParameter(id: .ringsDamping, value: r.damping)
        engine.setParameter(id: .ringsPosition, value: r.position)
        engine.setParameter(id: .ringsLevel, value: r.level)

        // Delay
        let d = snapshot.delay
        engine.setParameter(id: .delayTime, value: d.time)
        engine.setParameter(id: .delayFeedback, value: d.feedback)
        engine.setParameter(id: .delayMix, value: d.mix)
        engine.setParameter(id: .delayHeadMode, value: d.headMode)
        engine.setParameter(id: .delayWow, value: d.wow)
        engine.setParameter(id: .delayFlutter, value: d.flutter)
        engine.setParameter(id: .delayTone, value: d.tone)
        engine.setParameter(id: .delaySync, value: d.sync)
        engine.setParameter(id: .delayTempo, value: d.tempo)
        engine.setParameter(id: .delaySubdivision, value: d.subdivision)

        // Reverb
        let rv = snapshot.reverb
        engine.setParameter(id: .reverbSize, value: rv.size)
        engine.setParameter(id: .reverbDamping, value: rv.damping)
        engine.setParameter(id: .reverbMix, value: rv.mix)

        // Master filter
        let mf = snapshot.masterFilter
        engine.setParameter(id: .masterFilterCutoff, value: mf.cutoff)
        engine.setParameter(id: .masterFilterResonance, value: mf.resonance)
        engine.setParameter(id: .masterFilterModel, value: mf.model)

        // Loopers
        for looper in snapshot.loopers {
            let vi = looper.voiceIndex
            engine.setParameter(id: .looperRate, value: looper.rate, voiceIndex: vi)
            engine.setParameter(id: .looperReverse, value: looper.reverse, voiceIndex: vi)
            engine.setParameter(id: .looperLoopStart, value: looper.loopStart, voiceIndex: vi)
            engine.setParameter(id: .looperLoopEnd, value: looper.loopEnd, voiceIndex: vi)
            engine.setParameter(id: .looperCut, value: looper.cut, voiceIndex: vi)
        }
    }

    private static func restoreAUPlugins(
        _ snapshot: AUPluginsSnapshot,
        engine: AudioEngineWrapper,
        pluginManager: AUPluginManager
    ) async {
        // Restore send plugins
        for sendSnap in snapshot.sendSlots {
            do {
                if let slot = engine.getSendSlot(busIndex: sendSnap.busIndex) {
                    try await slot.restoreFromSnapshot(sendSnap, using: pluginManager)
                }
            } catch {
                print("[ProjectSerializer] Failed to restore send plugin bus \(sendSnap.busIndex): \(error)")
            }
        }

        // Restore insert plugins
        for (channelIndex, channelSlots) in snapshot.insertSlots.enumerated() {
            guard let slots = engine.getInsertSlots(forChannel: channelIndex) else { continue }
            for (slotIndex, slotSnap) in channelSlots.enumerated() {
                guard slotIndex < slots.count, let snap = slotSnap else { continue }
                do {
                    try await slots[slotIndex].restoreFromSnapshot(snap, using: pluginManager)
                } catch {
                    print("[ProjectSerializer] Failed to restore insert plugin ch\(channelIndex) slot\(slotIndex): \(error)")
                }
            }
        }
    }

    private static func restoreAudioFiles(_ snapshot: AudioFilesSnapshot, engine: AudioEngineWrapper) {
        for reel in snapshot.reels {
            let url = URL(fileURLWithPath: reel.filePath)
            if FileManager.default.fileExists(atPath: reel.filePath) {
                engine.loadAudioFile(url: url, reelIndex: reel.reelIndex)
            } else {
                print("[ProjectSerializer] Audio file not found: \(reel.filePath)")
            }
        }
    }
}

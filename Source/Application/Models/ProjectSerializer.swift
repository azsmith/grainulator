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
        sequencer: StepSequencer,
        masterClock: MasterClock,
        appState: AppState,
        drumSequencer: DrumSequencer? = nil,
        chordSequencer: ChordSequencer? = nil
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
            uiPreferences: captureUIPreferences(appState),
            drumSequencer: drumSequencer.map { captureDrumSequencer($0) },
            daisyDrum: captureDaisyDrum(audioEngine),
            sampler: captureSampler(audioEngine),
            chordSequencer: chordSequencer.map { captureChordSequencer($0) }
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

    private static func captureSequencer(_ sequencer: StepSequencer) -> SequencerSnapshot {
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
                        gateLength: stage.gateLength,
                        slide: stage.slide,
                        accumTranspose: stage.accumTranspose,
                        accumTrigger: stage.accumTrigger.rawValue,
                        accumRange: stage.accumRange,
                        accumMode: stage.accumMode.rawValue
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
        return UIPreferencesSnapshot(
            focusedVoice: appState.focusedVoice,
            selectedGranularVoice: appState.selectedGranularVoice
        )
    }

    // MARK: - Drum Sequencer

    private static func captureDrumSequencer(_ drumSeq: DrumSequencer) -> DrumSequencerSnapshot {
        let lanes = drumSeq.lanes.map { lane in
            DrumLaneSnapshot(
                laneIndex: lane.id,
                steps: lane.steps.map { step in
                    DrumStepSnapshot(
                        index: step.id,
                        isActive: step.isActive,
                        velocity: step.velocity
                    )
                },
                isMuted: lane.isMuted,
                level: lane.level,
                harmonics: lane.harmonics,
                timbre: lane.timbre,
                morph: lane.morph,
                note: Int(lane.note)
            )
        }
        return DrumSequencerSnapshot(
            lanes: lanes,
            stepDivision: drumSeq.stepDivision.rawValue,
            syncToTransport: drumSeq.syncToTransport
        )
    }

    // MARK: - Chord Sequencer

    private static func captureChordSequencer(_ chordSeq: ChordSequencer) -> ChordSequencerSnapshot {
        let steps = chordSeq.steps.map { step in
            ChordStepSnapshot(
                index: step.id,
                degreeId: step.degreeId,
                qualityId: step.qualityId,
                active: step.active
            )
        }
        return ChordSequencerSnapshot(
            steps: steps,
            division: chordSeq.division.rawValue,
            isEnabled: chordSeq.isEnabled
        )
    }

    // MARK: - DaisyDrum Voice (manual/synth tab)

    private static func captureDaisyDrum(_ engine: AudioEngineWrapper) -> DaisyDrumVoiceSnapshot {
        return DaisyDrumVoiceSnapshot(
            engine: engine.getParameter(id: .daisyDrumEngine),
            harmonics: engine.getParameter(id: .daisyDrumHarmonics),
            timbre: engine.getParameter(id: .daisyDrumTimbre),
            morph: engine.getParameter(id: .daisyDrumMorph),
            level: engine.getParameter(id: .daisyDrumLevel)
        )
    }

    // MARK: - SoundFont Sampler Voice

    private static func captureSampler(_ engine: AudioEngineWrapper) -> SamplerVoiceSnapshot {
        let modeStr = engine.activeSamplerMode == .wavSampler ? "wavsampler" : "soundfont"
        // Derive instrument ID from directory path (last path component)
        var wavId: String? = nil
        if let dirPath = engine.wavSamplerDirectoryPath {
            wavId = dirPath.lastPathComponent
        }
        return SamplerVoiceSnapshot(
            samplerMode: modeStr,
            soundFontPath: engine.soundFontFilePath?.path,
            presetIndex: engine.soundFontCurrentPreset,
            wavInstrumentId: wavId,
            attack: engine.getParameter(id: .samplerAttack),
            decay: engine.getParameter(id: .samplerDecay),
            sustain: engine.getParameter(id: .samplerSustain),
            release: engine.getParameter(id: .samplerRelease),
            filterCutoff: engine.getParameter(id: .samplerFilterCutoff),
            filterResonance: engine.getParameter(id: .samplerFilterResonance),
            tuning: engine.getParameter(id: .samplerTuning),
            level: engine.getParameter(id: .samplerLevel)
        )
    }

    // MARK: - Restore State

    static func restoreSnapshot(
        _ snapshot: ProjectSnapshot,
        audioEngine: AudioEngineWrapper,
        mixerState: MixerState,
        sequencer: StepSequencer,
        masterClock: MasterClock,
        appState: AppState,
        pluginManager: AUPluginManager,
        drumSequencer: DrumSequencer? = nil,
        chordSequencer: ChordSequencer? = nil
    ) async {
        // 1. Stop playback
        if sequencer.isPlaying {
            sequencer.stop()
        }
        if masterClock.isRunning {
            masterClock.stop()
        }
        if let drumSeq = drumSequencer, drumSeq.isPlaying {
            drumSeq.stop()
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

        // 7. Restore drum sequencer state (if present in project)
        if let drumSeq = drumSequencer {
            if let drumSnapshot = snapshot.drumSequencer {
                restoreDrumSequencer(drumSnapshot, drumSequencer: drumSeq, audioEngine: audioEngine)
            } else {
                // Version 1 project — reset drum sequencer to defaults
                resetDrumSequencerToDefaults(drumSeq, audioEngine: audioEngine)
            }
        }

        // 7b. Restore chord sequencer state (if present in project)
        if let chordSeq = chordSequencer {
            if let chordSnapshot = snapshot.chordSequencer {
                restoreChordSequencer(chordSnapshot, chordSequencer: chordSeq)
            } else {
                // Older project — reset chord sequencer to defaults
                chordSeq.clearAll()
                chordSeq.division = .div4
                chordSeq.isEnabled = true
            }
        }

        // 8. Restore DaisyDrum voice parameters (if present in project)
        if let daisyDrumSnapshot = snapshot.daisyDrum {
            restoreDaisyDrum(daisyDrumSnapshot, engine: audioEngine)
        }

        // 8b. Restore SoundFont sampler voice (if present in project)
        if let samplerSnapshot = snapshot.sampler {
            restoreSampler(samplerSnapshot, engine: audioEngine)
        }

        // 9. Sync mixer to C++ engine
        mixerState.syncToAudioEngine(audioEngine)

        // 10. Sync clock outputs to engine
        masterClock.syncAllOutputsToEngine()

        // 11. Restore AU plugins (async)
        await restoreAUPlugins(snapshot.auPlugins, engine: audioEngine, pluginManager: pluginManager)

        // 12. Reload audio files
        restoreAudioFiles(snapshot.audioFiles, engine: audioEngine)
    }

    // MARK: - Restore Helpers

    private static func restoreUIPreferences(_ prefs: UIPreferencesSnapshot, appState: AppState) {
        appState.focusedVoice = prefs.focusedVoice
        appState.selectedGranularVoice = prefs.selectedGranularVoice
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

    private static func restoreSequencer(_ snapshot: SequencerSnapshot, sequencer: StepSequencer) {
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
                sequencer.tracks[i].stages[j].gateLength = stageSnap.gateLength ?? 1.0
                sequencer.tracks[i].stages[j].slide = stageSnap.slide
                sequencer.tracks[i].stages[j].accumTranspose = stageSnap.accumTranspose ?? 0
                sequencer.tracks[i].stages[j].accumTrigger = AccumulatorTrigger(rawValue: stageSnap.accumTrigger ?? "") ?? .stage
                sequencer.tracks[i].stages[j].accumRange = stageSnap.accumRange ?? 7
                sequencer.tracks[i].stages[j].accumMode = AccumulatorMode(rawValue: stageSnap.accumMode ?? "") ?? .stage
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

    // MARK: - Restore Drum Sequencer

    private static func restoreDrumSequencer(_ snapshot: DrumSequencerSnapshot, drumSequencer: DrumSequencer, audioEngine: AudioEngineWrapper) {
        drumSequencer.stepDivision = SequencerClockDivision(rawValue: snapshot.stepDivision) ?? .x4
        drumSequencer.syncToTransport = snapshot.syncToTransport

        for laneSnap in snapshot.lanes {
            let laneIndex = laneSnap.laneIndex
            guard laneIndex < drumSequencer.lanes.count else { continue }

            drumSequencer.lanes[laneIndex].isMuted = laneSnap.isMuted
            drumSequencer.lanes[laneIndex].level = laneSnap.level
            drumSequencer.lanes[laneIndex].harmonics = laneSnap.harmonics
            drumSequencer.lanes[laneIndex].timbre = laneSnap.timbre
            drumSequencer.lanes[laneIndex].morph = laneSnap.morph
            drumSequencer.lanes[laneIndex].note = UInt8(min(max(laneSnap.note, 24), 96))

            // Restore steps
            for stepSnap in laneSnap.steps {
                let stepIndex = stepSnap.index
                guard stepIndex < DrumSequencer.numSteps else { continue }
                drumSequencer.lanes[laneIndex].steps[stepIndex].isActive = stepSnap.isActive
                drumSequencer.lanes[laneIndex].steps[stepIndex].velocity = stepSnap.velocity
            }

            // Sync lane parameters to C++ engine
            audioEngine.setDrumSeqLaneLevel(laneIndex, value: laneSnap.level)
            audioEngine.setDrumSeqLaneHarmonics(laneIndex, value: laneSnap.harmonics)
            audioEngine.setDrumSeqLaneTimbre(laneIndex, value: laneSnap.timbre)
            audioEngine.setDrumSeqLaneMorph(laneIndex, value: laneSnap.morph)
        }
    }

    private static func resetDrumSequencerToDefaults(_ drumSequencer: DrumSequencer, audioEngine: AudioEngineWrapper) {
        drumSequencer.stepDivision = .x4
        drumSequencer.syncToTransport = true
        drumSequencer.clearAll()

        for i in 0..<drumSequencer.lanes.count {
            drumSequencer.lanes[i].isMuted = false
            drumSequencer.lanes[i].level = 0.8
            drumSequencer.lanes[i].harmonics = 0.5
            drumSequencer.lanes[i].timbre = 0.5
            drumSequencer.lanes[i].morph = 0.5
            drumSequencer.lanes[i].note = 60

            audioEngine.setDrumSeqLaneLevel(i, value: 0.8)
            audioEngine.setDrumSeqLaneHarmonics(i, value: 0.5)
            audioEngine.setDrumSeqLaneTimbre(i, value: 0.5)
            audioEngine.setDrumSeqLaneMorph(i, value: 0.5)
        }
    }

    // MARK: - Restore Chord Sequencer

    private static func restoreChordSequencer(_ snapshot: ChordSequencerSnapshot, chordSequencer: ChordSequencer) {
        chordSequencer.division = SequencerClockDivision(rawValue: snapshot.division) ?? .div4
        chordSequencer.isEnabled = snapshot.isEnabled

        for stepSnap in snapshot.steps {
            let stepIndex = stepSnap.index
            guard stepIndex < chordSequencer.steps.count else { continue }
            chordSequencer.steps[stepIndex].degreeId = stepSnap.degreeId
            chordSequencer.steps[stepIndex].qualityId = stepSnap.qualityId
            chordSequencer.steps[stepIndex].active = stepSnap.active
        }
    }

    // MARK: - Restore DaisyDrum Voice

    private static func restoreDaisyDrum(_ snapshot: DaisyDrumVoiceSnapshot, engine: AudioEngineWrapper) {
        engine.setParameter(id: .daisyDrumEngine, value: snapshot.engine)
        engine.setParameter(id: .daisyDrumHarmonics, value: snapshot.harmonics)
        engine.setParameter(id: .daisyDrumTimbre, value: snapshot.timbre)
        engine.setParameter(id: .daisyDrumMorph, value: snapshot.morph)
        engine.setParameter(id: .daisyDrumLevel, value: snapshot.level)
    }

    // MARK: - Restore SoundFont Sampler Voice

    private static func restoreSampler(_ snapshot: SamplerVoiceSnapshot, engine: AudioEngineWrapper) {
        let mode: AudioEngineWrapper.SamplerMode = (snapshot.samplerMode == "wavsampler") ? .wavSampler : .soundFont

        // Load the SoundFont file if a path was saved
        if let sfPath = snapshot.soundFontPath {
            let url = URL(fileURLWithPath: sfPath)
            if FileManager.default.fileExists(atPath: sfPath) {
                engine.loadSoundFont(url: url)
                // Set preset after a delay to allow SF2 loading to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    engine.setSamplerPreset(snapshot.presetIndex)
                }
            }
        }

        // Load WAV sampler instrument if saved
        if let wavId = snapshot.wavInstrumentId {
            let library = SampleLibraryManager.shared
            if let localDir = library.localPath(for: wavId) {
                engine.loadWavSampler(directory: localDir)
            }
        }

        // Set mode after a brief delay to ensure loaders have started
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            engine.setSamplerMode(mode)
        }

        // Restore parameters immediately (they'll be applied once sources load)
        engine.setParameter(id: .samplerAttack, value: snapshot.attack)
        engine.setParameter(id: .samplerDecay, value: snapshot.decay)
        engine.setParameter(id: .samplerSustain, value: snapshot.sustain)
        engine.setParameter(id: .samplerRelease, value: snapshot.release)
        engine.setParameter(id: .samplerFilterCutoff, value: snapshot.filterCutoff)
        engine.setParameter(id: .samplerFilterResonance, value: snapshot.filterResonance)
        engine.setParameter(id: .samplerTuning, value: snapshot.tuning)
        engine.setParameter(id: .samplerLevel, value: snapshot.level)
    }
}

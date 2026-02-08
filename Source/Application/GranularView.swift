//
//  GranularView.swift
//  Grainulator
//
//  Granular synthesis voice UI (Mangl-style)
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct GranularView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var arcManager: MonomeArcManager
    let voiceIndex: Int

    // Core Mangl parameters
    @State private var speed: Float = 0.75        // 0-1 maps to -200% to +200%; 0.75 = 100% (normal speed)
    @State private var pitch: Float = 0.5        // 0-1 maps to -24 to +24 semitones
    @State private var size: Float = 0.3         // 0-1 maps to 1-500ms (logarithmic)
    @State private var density: Float = 0.3      // 0-1 maps to 0-512 Hz (logarithmic)

    // Extended parameters
    @State private var jitter: Float = 0.0       // 0-1 maps to 0-500ms
    @State private var spread: Float = 0.0       // 0-1 stereo spread
    @State private var morph: Float = 0.0        // 0-1 per-grain randomization probability
    @State private var filterCutoff: Float = 1.0 // 0-1 maps to 20-20kHz
    @State private var filterResonance: Float = 0.5 // 0-1 filter resonance
    @State private var filterModel: Int = 2 // default: Stilson
    @State private var reverseGrains: Bool = false
    @State private var envelope: Int = 0          // 0-7 envelope type
    @State private var decay: Float = 0.3        // 0-1: 0=short release, 1=long release

    // State
    @State private var isPlaying: Bool = false
    @State private var isDragOver: Bool = false
    @State private var loadedFileName: String?

    // Recording state
    @State private var isRecording: Bool = false
    @State private var recordMode: AudioEngineWrapper.RecordMode = .oneShot
    @State private var recordSourceType: AudioEngineWrapper.RecordSourceType = .internalVoice
    @State private var recordSourceChannel: Int = 0
    @State private var recordFeedback: Float = 0.0

    // Voice colors from design system
    let voiceColors: [Color] = [
        ColorPalette.accentGranular1,  // Voice 1: Blue
        ColorPalette.accentLooper1,    // Voice 2: Purple
        ColorPalette.accentLooper2,    // Voice 3: Orange
        ColorPalette.accentGranular4   // Voice 4: Teal
    ]

    // Envelope type names
    let envelopeNames = ["Hann", "Gauss", "Trap", "Tri", "Tukey", "Pluck", "Soft", "Decay"]
    let filterModelNames = [
        "Simplified",
        "Huovilainen",
        "Stilson",
        "Microtracker",
        "Krajeski",
        "MusicDSP",
        "Oberheim",
        "Improved",
        "RKSimulation",
        "Hyperion"
    ]

    let stateSyncTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var voiceColor: Color {
        voiceColors[voiceIndex % voiceColors.count]
    }

    var body: some View {
        ConsoleModuleView(
            title: "GRANULAR \(voiceIndex + 1)",
            accentColor: voiceColor
        ) {
        VStack(spacing: 16) {
            // Transport controls
            HStack {
                // Recording source & mode controls
                Menu {
                    Section("Input Source") {
                        Button(action: { recordSourceType = .external; recordSourceChannel = 0 }) {
                            Label("Mic / Line In", systemImage: "mic")
                        }
                        Divider()
                        Button("Plaits") { recordSourceType = .internalVoice; recordSourceChannel = 0 }
                        Button("Rings") { recordSourceType = .internalVoice; recordSourceChannel = 1 }
                        if voiceIndex != 0 {
                            Button("Granular 1") { recordSourceType = .internalVoice; recordSourceChannel = 2 }
                        }
                        Button("Looper 1") { recordSourceType = .internalVoice; recordSourceChannel = 3 }
                        Button("Looper 2") { recordSourceType = .internalVoice; recordSourceChannel = 4 }
                        if voiceIndex != 3 {
                            Button("Granular 2") { recordSourceType = .internalVoice; recordSourceChannel = 5 }
                        }
                    }
                    Section("Sampler") {
                        Button("Sampler") { recordSourceType = .internalVoice; recordSourceChannel = 11 }
                    }
                    Section("Drums") {
                        Button("Drums (All)") { recordSourceType = .internalVoice; recordSourceChannel = 6 }
                        Button("Kick") { recordSourceType = .internalVoice; recordSourceChannel = 7 }
                        Button("Synth Kick") { recordSourceType = .internalVoice; recordSourceChannel = 8 }
                        Button("Snare") { recordSourceType = .internalVoice; recordSourceChannel = 9 }
                        Button("Hi-Hat") { recordSourceType = .internalVoice; recordSourceChannel = 10 }
                    }
                    Section("Mode") {
                        Button(action: { recordMode = .oneShot }) {
                            Label("One Shot", systemImage: recordMode == .oneShot ? "checkmark" : "")
                        }
                        Button(action: { recordMode = .liveLoop }) {
                            Label("Live Loop", systemImage: recordMode == .liveLoop ? "checkmark" : "")
                        }
                    }
                } label: {
                    Text(recordSourceType == .external ? "MIC" : channelShortName(recordSourceChannel))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.textMuted)
                        .frame(width: 40, height: 32)
                        .background(RoundedRectangle(cornerRadius: 4).fill(ColorPalette.backgroundTertiary))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                if recordMode == .liveLoop {
                    VStack(spacing: 1) {
                        Text("FB")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(ColorPalette.textDimmed)
                        Text("\(Int(recordFeedback * 100))%")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(voiceColor)
                    }
                    .frame(width: 30)
                    Slider(value: $recordFeedback, in: 0...1)
                        .frame(width: 60)
                        .onChange(of: recordFeedback) { newValue in
                            audioEngine.setRecordingFeedback(reelIndex: voiceIndex, feedback: newValue)
                        }
                }

                Spacer()

                // Load file button
                Button(action: {
                    openFilePicker()
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(ColorPalette.textMuted)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ColorPalette.backgroundTertiary)
                        )
                }
                .buttonStyle(.plain)
                .help("Load audio file")

                // Record button
                Button(action: {
                    isRecording.toggle()
                    if isRecording {
                        audioEngine.startRecording(
                            reelIndex: voiceIndex,
                            mode: recordMode,
                            sourceType: recordSourceType,
                            sourceChannel: recordSourceChannel
                        )
                    } else {
                        audioEngine.stopRecording(reelIndex: voiceIndex)
                    }
                }) {
                    Circle()
                        .fill(isRecording ? Color.red : Color.red.opacity(0.4))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.6), lineWidth: 1)
                        )
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ColorPalette.backgroundTertiary)
                        )
                }
                .buttonStyle(.plain)
                .help(isRecording ? "Stop recording" : "Start recording")

                // Play button (gate)
                Button(action: {
                    isPlaying.toggle()
                    audioEngine.setGranularPlaying(voiceIndex: voiceIndex, playing: isPlaying)
                }) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isPlaying ? ColorPalette.accentPlaits : voiceColor)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ColorPalette.backgroundTertiary)
                        )
                }
                .buttonStyle(.plain)
            }

            // Waveform display with drag-and-drop and tap-to-seek
            WaveformView(
                waveformData: audioEngine.waveformOverviews[voiceIndex],
                playheadPosition: audioEngine.granularPositions[voiceIndex] ?? 0,
                isPlaying: isPlaying,
                color: voiceColor,
                fileName: loadedFileName,
                isDragOver: isDragOver,
                onSeek: { position in
                    audioEngine.setGranularPosition(voiceIndex: voiceIndex, position: position)
                },
                recordPosition: isRecording ? audioEngine.recordingPositions[voiceIndex] : nil
            )
            .frame(height: 80)
            .onDrop(of: [.audio, .fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
            }

            // Core parameters row — knobs
            HStack(spacing: 14) {
                ProKnobView(
                    value: $speed,
                    label: "SPEED",
                    accentColor: voiceColor,
                    size: .large,
                    style: .minimoog,
                    defaultValue: 0.75,
                    isBipolar: true,
                    valueFormatter: { value in
                        let speed = (Double(value) - 0.5) * 4.0
                        let percent = Int(speed * 100)
                        if percent == 0 { return "0%" }
                        return percent > 0 ? "+\(percent)%" : "\(percent)%"
                    }
                )
                .onChange(of: speed) { newValue in
                    audioEngine.setParameter(id: .granularSpeed, value: newValue, voiceIndex: voiceIndex)
                }

                ProKnobView(
                    value: $pitch,
                    label: "PITCH",
                    accentColor: ColorPalette.ledBlue,
                    size: .large,
                    style: .minimoog,
                    defaultValue: 0.5,
                    isBipolar: true,
                    valueFormatter: { value in
                        let semitones = Int((Double(value) - 0.5) * 48)
                        if semitones == 0 { return "0st" }
                        return semitones > 0 ? "+\(semitones)st" : "\(semitones)st"
                    }
                )
                .onChange(of: pitch) { newValue in
                    audioEngine.setParameter(id: .granularPitch, value: newValue, voiceIndex: voiceIndex)
                }

                ProKnobView(
                    value: $size,
                    label: "SIZE",
                    accentColor: voiceColor,
                    size: .large,
                    style: .minimoog,
                    valueFormatter: { value in
                        let ms = Double(value) * 2500.0
                        return ms < 1 ? "0ms" : String(format: "%.0fms", ms)
                    }
                )
                .onChange(of: size) { newValue in
                    audioEngine.setParameter(id: .granularSize, value: newValue, voiceIndex: voiceIndex)
                }

                ProKnobView(
                    value: $density,
                    label: "DENSITY",
                    accentColor: voiceColor,
                    size: .large,
                    style: .minimoog,
                    valueFormatter: { value in
                        let hz = 1.0 * pow(512.0, Double(value))
                        return hz < 10 ? String(format: "%.1fHz", hz) : String(format: "%.0fHz", hz)
                    }
                )
                .onChange(of: density) { newValue in
                    audioEngine.setParameter(id: .granularDensity, value: newValue, voiceIndex: voiceIndex)
                }
            }

            ConsoleSectionDivider(accentColor: ColorPalette.dividerSubtle)

                HStack(spacing: 10) {
                    ProKnobView(
                        value: $jitter,
                        label: "JITTER",
                        accentColor: ColorPalette.ledAmber,
                        size: .medium,
                        style: .minimoog,
                        valueFormatter: { value in
                            String(format: "%.0fms", Double(value) * 500.0)
                        }
                    )
                    .onChange(of: jitter) { newValue in
                        audioEngine.setParameter(id: .granularJitter, value: newValue, voiceIndex: voiceIndex)
                    }

                    ProKnobView.normalized(
                        value: $spread,
                        label: "SPREAD",
                        accentColor: ColorPalette.accentPlaits,
                        size: .medium,
                        style: .minimoog
                    )
                    .onChange(of: spread) { newValue in
                        audioEngine.setParameter(id: .granularSpread, value: newValue, voiceIndex: voiceIndex)
                    }

                    ProKnobView.normalized(
                        value: $morph,
                        label: "MORPH",
                        accentColor: ColorPalette.ledGreen,
                        size: .medium,
                        style: .minimoog
                    )
                    .onChange(of: morph) { newValue in
                        audioEngine.setParameter(id: .granularMorph, value: newValue, voiceIndex: voiceIndex)
                    }

                    ProKnobView.frequency(
                        value: $filterCutoff,
                        label: "FILTER",
                        accentColor: ColorPalette.accentLooper2,
                        size: .medium,
                        style: .minimoog
                    )
                    .onChange(of: filterCutoff) { newValue in
                        audioEngine.setParameter(id: .granularFilterCutoff, value: newValue, voiceIndex: voiceIndex)
                    }

                    ProKnobView.normalized(
                        value: $filterResonance,
                        label: "RES",
                        accentColor: ColorPalette.ledAmber,
                        size: .medium,
                        style: .minimoog
                    )
                    .onChange(of: filterResonance) { newValue in
                        audioEngine.setParameter(id: .granularFilterResonance, value: newValue, voiceIndex: voiceIndex)
                    }
                }

                // Envelope picker row
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ENVELOPE")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorPalette.textMuted)

                        HStack(spacing: 4) {
                            ForEach(Array(envelopeNames.enumerated()), id: \.offset) { index, name in
                                Button(action: {
                                    envelope = index
                                    audioEngine.setParameter(id: .granularEnvelope, value: Float(index) / 7.0, voiceIndex: voiceIndex)
                                }) {
                                    Text(name)
                                        .font(.system(size: 9, weight: envelope == index ? .bold : .regular, design: .monospaced))
                                        .foregroundColor(envelope == index ? .white : ColorPalette.textPanelLabel)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(envelope == index ? voiceColor.opacity(0.6) : ColorPalette.backgroundTertiary)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("FILTER MODEL")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorPalette.textMuted)

                        Menu {
                            ForEach(Array(filterModelNames.enumerated()), id: \.offset) { index, name in
                                Button(name) {
                                    filterModel = index
                                    let normalized = Float(index) / Float(max(filterModelNames.count - 1, 1))
                                    audioEngine.setParameter(id: .granularFilterModel, value: normalized, voiceIndex: voiceIndex)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(filterModelNames[filterModel])
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(voiceColor)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(ColorPalette.backgroundTertiary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(voiceColor.opacity(0.45), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("DIRECTION")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorPalette.textMuted)

                        Button(action: {
                            reverseGrains.toggle()
                            audioEngine.setParameter(
                                id: .granularReverse,
                                value: reverseGrains ? 1.0 : 0.0,
                                voiceIndex: voiceIndex
                            )
                        }) {
                            Text(reverseGrains ? "REVERSE" : "FORWARD")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(reverseGrains ? voiceColor.opacity(0.75) : ColorPalette.backgroundTertiary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(voiceColor.opacity(0.45), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // Decay control (only visible for pluck/decay envelopes)
                    if envelope >= 5 {  // Pluck, PluckSoft, ExpDecay
                        ProKnobView(
                            value: $decay,
                            label: "DECAY",
                            accentColor: ColorPalette.ledAmber,
                            size: .medium,
                            style: .minimoog,
                            valueFormatter: { value in
                                if value < 0.25 { return "Short" }
                                else if value < 0.5 { return "Med" }
                                else if value < 0.75 { return "Long" }
                                else { return "V.Long" }
                            }
                        )
                        .onChange(of: decay) { newValue in
                            audioEngine.setParameter(id: .granularDecay, value: newValue, voiceIndex: voiceIndex)
                        }
                    }
                }
        }
        .padding(16)
        } // end ConsoleModuleView
        .onAppear {
            syncFromEngine()
        }
        .onReceive(stateSyncTimer) { _ in
            syncFromEngine()
        }
        .onChange(of: arcManager.encoderValues) { _ in
            syncFromEngine()
        }
        .onChange(of: arcManager.shiftEncoderValues) { _ in
            syncFromEngine()
        }
        .onChange(of: recordSourceType) { _ in
            audioEngine.setRecordingSource(reelIndex: voiceIndex, mode: recordMode, sourceType: recordSourceType, sourceChannel: recordSourceChannel)
        }
        .onChange(of: recordSourceChannel) { _ in
            audioEngine.setRecordingSource(reelIndex: voiceIndex, mode: recordMode, sourceType: recordSourceType, sourceChannel: recordSourceChannel)
        }
        .onChange(of: recordMode) { _ in
            audioEngine.setRecordingSource(reelIndex: voiceIndex, mode: recordMode, sourceType: recordSourceType, sourceChannel: recordSourceChannel)
        }
    }

    // MARK: - File Handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // Try to load as file URL
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in
                            loadAudioFile(url: url)
                        }
                    }
                }
                return true
            }

            // Try to load as audio
            if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.audio.identifier, options: nil) { item, error in
                    if let url = item as? URL {
                        Task { @MainActor in
                            loadAudioFile(url: url)
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    private func loadAudioFile(url: URL) {
        loadedFileName = url.lastPathComponent
        audioEngine.loadAudioFile(url: url, reelIndex: voiceIndex)
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select an audio file to load into granular voice \(voiceIndex + 1)"

        if panel.runModal() == .OK, let url = panel.url {
            loadAudioFile(url: url)
        }
    }

    private func channelShortName(_ channel: Int) -> String {
        switch channel {
        case 0: return "PLT"
        case 1: return "RNG"
        case 2: return "GR1"
        case 3: return "LP1"
        case 4: return "LP2"
        case 5: return "GR4"
        case 6: return "DRM"
        case 7: return "KCK"
        case 8: return "SK"
        case 9: return "SNR"
        case 10: return "HH"
        case 11: return "SMP"
        default: return "???"
        }
    }

    private func syncFromEngine() {
        // Keep UI in sync with engine values when parameters are changed externally (API/chat, MIDI, recalls).
        let epsilon: Float = 0.0001

        let engineSpeed = audioEngine.getParameter(id: .granularSpeed, voiceIndex: voiceIndex)
        if abs(engineSpeed - speed) > epsilon { speed = engineSpeed }

        let enginePitch = audioEngine.getParameter(id: .granularPitch, voiceIndex: voiceIndex)
        if abs(enginePitch - pitch) > epsilon { pitch = enginePitch }

        let engineSize = audioEngine.getParameter(id: .granularSize, voiceIndex: voiceIndex)
        if abs(engineSize - size) > epsilon { size = engineSize }

        let engineDensity = audioEngine.getParameter(id: .granularDensity, voiceIndex: voiceIndex)
        if abs(engineDensity - density) > epsilon { density = engineDensity }

        let engineJitter = audioEngine.getParameter(id: .granularJitter, voiceIndex: voiceIndex)
        if abs(engineJitter - jitter) > epsilon { jitter = engineJitter }

        let engineSpread = audioEngine.getParameter(id: .granularSpread, voiceIndex: voiceIndex)
        if abs(engineSpread - spread) > epsilon { spread = engineSpread }

        let engineMorph = audioEngine.getParameter(id: .granularMorph, voiceIndex: voiceIndex)
        if abs(engineMorph - morph) > epsilon { morph = engineMorph }

        let engineCutoff = audioEngine.getParameter(id: .granularFilterCutoff, voiceIndex: voiceIndex)
        if abs(engineCutoff - filterCutoff) > epsilon { filterCutoff = engineCutoff }

        let engineResonance = audioEngine.getParameter(id: .granularFilterResonance, voiceIndex: voiceIndex)
        if abs(engineResonance - filterResonance) > epsilon { filterResonance = engineResonance }

        let engineDecay = audioEngine.getParameter(id: .granularDecay, voiceIndex: voiceIndex)
        if abs(engineDecay - decay) > epsilon { decay = engineDecay }

        let envelopeNormalized = audioEngine.getParameter(id: .granularEnvelope, voiceIndex: voiceIndex)
        let envelopeIndex = min(max(Int((envelopeNormalized * 7.0).rounded()), 0), envelopeNames.count - 1)
        if envelopeIndex != envelope { envelope = envelopeIndex }

        let modelNormalized = audioEngine.getParameter(id: .granularFilterModel, voiceIndex: voiceIndex)
        let maxModel = max(filterModelNames.count - 1, 1)
        let modelIndex = min(max(Int((modelNormalized * Float(maxModel)).rounded()), 0), filterModelNames.count - 1)
        if modelIndex != filterModel { filterModel = modelIndex }

        let engineReverse = audioEngine.getParameter(id: .granularReverse, voiceIndex: voiceIndex) >= 0.5
        if engineReverse != reverseGrains { reverseGrains = engineReverse }

        // Sync playing state from engine
        let enginePlaying = audioEngine.playingStates[voiceIndex] ?? false
        if enginePlaying != isPlaying { isPlaying = enginePlaying }

        // Sync recording state from engine (may have been toggled by Arc tap or API)
        if let recState = audioEngine.recordingStates[voiceIndex] {
            if recState.isRecording != isRecording { isRecording = recState.isRecording }
            if recState.mode != recordMode { recordMode = recState.mode }
            if recState.sourceType != recordSourceType { recordSourceType = recState.sourceType }
            if recState.sourceChannel != recordSourceChannel { recordSourceChannel = recState.sourceChannel }
            if abs(recState.feedback - recordFeedback) > 0.001 { recordFeedback = recState.feedback }
        } else if isRecording {
            isRecording = false
        }
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let waveformData: [Float]?
    let playheadPosition: Float  // 0-1 normalized position
    let isPlaying: Bool
    let color: Color
    let fileName: String?
    let isDragOver: Bool
    let onSeek: ((Float) -> Void)?
    let loopStart: Float?
    let loopEnd: Float?
    let onLoopRangeChange: ((Float, Float) -> Void)?
    let recordPosition: Float?  // 0-1 normalized record head position (nil = not recording)

    init(
        waveformData: [Float]?,
        playheadPosition: Float,
        isPlaying: Bool,
        color: Color,
        fileName: String?,
        isDragOver: Bool,
        onSeek: ((Float) -> Void)? = nil,
        loopStart: Float? = nil,
        loopEnd: Float? = nil,
        onLoopRangeChange: ((Float, Float) -> Void)? = nil,
        recordPosition: Float? = nil
    ) {
        self.waveformData = waveformData
        self.playheadPosition = playheadPosition
        self.isPlaying = isPlaying
        self.color = color
        self.fileName = fileName
        self.isDragOver = isDragOver
        self.onSeek = onSeek
        self.loopStart = loopStart
        self.loopEnd = loopEnd
        self.onLoopRangeChange = onLoopRangeChange
        self.recordPosition = recordPosition
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(ColorPalette.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isDragOver ? color : Color.clear, lineWidth: 2)
                )

            if let data = waveformData, !data.isEmpty {
                // Real waveform display with playhead
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height

                    ZStack {
                        // Waveform bars
                        Path { path in
                            let midY = height / 2
                            let barWidth = width / CGFloat(data.count)

                            for (index, value) in data.enumerated() {
                                let x = CGFloat(index) * barWidth
                                let amplitude = CGFloat(abs(value)) * (height / 2) * 0.9
                                path.addRect(CGRect(
                                    x: x,
                                    y: midY - amplitude,
                                    width: max(barWidth - 1, 1),
                                    height: amplitude * 2
                                ))
                            }
                        }
                        .fill(color.opacity(0.5))

                        if let loopStart, let loopEnd {
                            let clampedStart = min(max(CGFloat(loopStart), 0), 1)
                            let clampedEnd = min(max(CGFloat(loopEnd), 0), 1)
                            let startX = clampedStart * width
                            let endX = clampedEnd * width

                            HStack(spacing: 0) {
                                Color.black.opacity(0.42)
                                    .frame(width: max(0, startX))
                                Color.clear
                                Color.black.opacity(0.42)
                                    .frame(width: max(0, width - endX))
                            }

                            Rectangle()
                                .fill(color.opacity(0.9))
                                .frame(width: 2, height: height)
                                .position(x: startX, y: height / 2)

                            Rectangle()
                                .fill(color.opacity(0.9))
                                .frame(width: 2, height: height)
                                .position(x: endX, y: height / 2)

                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                                .position(x: startX, y: 8)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { gesture in
                                            let pos = min(max(gesture.location.x / width, 0), 1)
                                            let newStart = Float(min(pos, CGFloat(loopEnd) - 0.005))
                                            onLoopRangeChange?(newStart, loopEnd)
                                        }
                                )

                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                                .position(x: endX, y: 8)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { gesture in
                                            let pos = min(max(gesture.location.x / width, 0), 1)
                                            let newEnd = Float(max(pos, CGFloat(loopStart) + 0.005))
                                            onLoopRangeChange?(loopStart, newEnd)
                                        }
                                )
                        }

                        // Playhead line
                        if isPlaying || playheadPosition > 0 {
                            let playheadX = CGFloat(playheadPosition) * width

                            // Playhead glow
                            Rectangle()
                                .fill(color.opacity(0.3))
                                .frame(width: 8)
                                .blur(radius: 4)
                                .position(x: playheadX, y: height / 2)

                            // Playhead line
                            Rectangle()
                                .fill(color)
                                .frame(width: 2)
                                .position(x: playheadX, y: height / 2)

                            // Position indicator dot
                            Circle()
                                .fill(color)
                                .frame(width: 6, height: 6)
                                .position(x: playheadX, y: 4)
                        }

                        // Record head (red line when recording)
                        if let recPos = recordPosition {
                            let recX = CGFloat(recPos) * width

                            Rectangle()
                                .fill(Color.red.opacity(0.4))
                                .frame(width: 8)
                                .blur(radius: 4)
                                .position(x: recX, y: height / 2)

                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2)
                                .position(x: recX, y: height / 2)

                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .position(x: recX, y: height - 4)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let position = Float(gesture.location.x / width)
                                let clampedPosition = max(0, min(1, position))
                                onSeek?(clampedPosition)
                            }
                    )
                }
                .padding(.horizontal, 4)

                // File name overlay
                if let fileName = fileName {
                    VStack {
                        Spacer()
                        HStack {
                            Text(fileName)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(ColorPalette.textMuted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(ColorPalette.backgroundSecondary.opacity(0.8))
                                .cornerRadius(2)
                            Spacer()
                        }
                        .padding(4)
                    }
                }
            } else {
                // Placeholder when no audio loaded
                VStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 24))
                        .foregroundColor(isDragOver ? color : ColorPalette.textDimmed)
                    Text(isDragOver ? "Drop to load" : "Drop audio file or use folder button")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(isDragOver ? color : ColorPalette.textDimmed)
                }
            }
        }
    }
}

// MARK: - Granular Slider

struct GranularSlider: View {
    let label: String
    @Binding var value: Float
    let color: Color
    var detents: [Float]
    var stepCount: Int?
    var formatter: ((Float) -> String)?

    /// Threshold in normalized space for snapping to a detent
    private let detentThreshold: Float = 0.02

    init(label: String, value: Binding<Float>, color: Color, detents: [Float] = [], stepCount: Int? = nil, formatter: ((Float) -> String)? = nil) {
        self.label = label
        self._value = value
        self.color = color
        self.detents = detents
        self.stepCount = stepCount
        self.formatter = formatter
    }

    var displayValue: String {
        if let formatter = formatter {
            return formatter(value)
        }
        return String(format: "%.0f%%", value * 100)
    }

    /// Apply detent snapping and/or step quantization to a raw value
    private func quantize(_ raw: Float) -> Float {
        var v = raw
        // Step quantization (e.g., 48 steps for semitones)
        if let steps = stepCount, steps > 0 {
            let stepSize = 1.0 / Float(steps)
            v = (v / stepSize).rounded() * stepSize
        }
        // Detent snapping — snap to nearest detent if within threshold
        for detent in detents {
            if abs(v - detent) <= detentThreshold {
                v = detent
                break
            }
        }
        return max(0, min(1, v))
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(Typography.valueSmall)
                .foregroundColor(ColorPalette.textMuted)

            // Vertical slider
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorPalette.backgroundTertiary)

                    // Value fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.6))
                        .frame(height: geometry.size.height * CGFloat(value))
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let raw = 1.0 - Float(gesture.location.y / geometry.size.height)
                            value = quantize(raw)
                        }
                )
            }
            .frame(width: 50, height: 60)

            Text(displayValue)
                .font(Typography.channelLabel)
                .foregroundColor(color)
        }
    }
}

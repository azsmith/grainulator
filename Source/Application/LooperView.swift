//
//  LooperView.swift
//  Grainulator
//
//  MLRE-inspired looper UI for track voices.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct LooperView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    let voiceIndex: Int
    let title: String

    @State private var isPlaying: Bool = false
    @State private var isReverse: Bool = false
    @State private var rate: Float = 1.0
    @State private var loopStart: Float = 0.0
    @State private var loopEnd: Float = 1.0
    @State private var isDragOver: Bool = false
    @State private var loadedFileName: String?

    // Recording state
    @State private var isRecording: Bool = false
    @State private var recordMode: AudioEngineWrapper.RecordMode = .liveLoop  // Default to LiveLoop for looper
    @State private var recordSourceType: AudioEngineWrapper.RecordSourceType = .external
    @State private var recordSourceChannel: Int = 0
    @State private var recordFeedback: Float = 0.5  // Default 50% feedback for looper

    /// Periodic sync from engine (recording state, loop bounds changed externally).
    private let stateSyncTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private let rateOptions: [Float] = [0.25, 0.5, 1.0, 1.5, 2.0]
    private let cutCount = 8

    private var accentColor: Color {
        voiceIndex == 1 ? ColorPalette.accentLooper1 : ColorPalette.accentLooper2
    }

    var body: some View {
        ConsoleModuleView(
            title: title,
            accentColor: accentColor
        ) {
        VStack(spacing: 14) {
            HStack {
                // Recording source & mode controls
                Menu {
                    Section("Input Source") {
                        Button(action: { recordSourceType = .external; recordSourceChannel = 0 }) {
                            if isSourceSelected(.external, 0) {
                                Label("Mic / Line In", systemImage: "checkmark")
                            } else {
                                Label("Mic / Line In", systemImage: "mic")
                            }
                        }
                        Divider()
                        inputSourceButton("Macro Osc", channel: 0)
                        inputSourceButton("Resonator", channel: 1)
                        inputSourceButton("Granular 1", channel: 2)
                        if voiceIndex != 1 {
                            inputSourceButton("Looper 1", channel: 3)
                        }
                        if voiceIndex != 2 {
                            inputSourceButton("Looper 2", channel: 4)
                        }
                        inputSourceButton("Granular 2", channel: 5)
                    }
                    Section("Sampler") {
                        inputSourceButton("Sampler", channel: 11)
                    }
                    Section("Drums") {
                        inputSourceButton("Drums (All)", channel: 6)
                        inputSourceButton("Kick", channel: 7)
                        inputSourceButton("Synth Kick", channel: 8)
                        inputSourceButton("Snare", channel: 9)
                        inputSourceButton("Hi-Hat", channel: 10)
                    }
                    Section("Mode") {
                        Button(action: { recordMode = .oneShot }) {
                            if recordMode == .oneShot {
                                Label("One Shot", systemImage: "checkmark")
                            } else {
                                Text("One Shot")
                            }
                        }
                        Button(action: { recordMode = .liveLoop }) {
                            if recordMode == .liveLoop {
                                Label("Live Loop", systemImage: "checkmark")
                            } else {
                                Text("Live Loop")
                            }
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("INPUT")
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorPalette.textDimmed)
                        HStack(spacing: 3) {
                            Text(recordSourceType == .external ? "Mic" : channelDisplayName(recordSourceChannel))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(accentColor)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(accentColor.opacity(0.6))
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: 32)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 4).fill(ColorPalette.backgroundTertiary))
                }
                .buttonStyle(.plain)
                .fixedSize()

                if recordMode == .liveLoop {
                    VStack(spacing: 1) {
                        Text("FB")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(ColorPalette.textDimmed)
                        Text("\(Int(recordFeedback * 100))%")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(accentColor)
                    }
                    .frame(width: 30)
                    Slider(value: $recordFeedback, in: 0...1)
                        .frame(width: 60)
                        .onChange(of: recordFeedback) { newValue in
                            audioEngine.setRecordingFeedback(reelIndex: voiceIndex, feedback: newValue)
                        }
                }

                Spacer()

                Button(action: openFilePicker) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
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
                        .background(RoundedRectangle(cornerRadius: 4).fill(ColorPalette.backgroundTertiary))
                }
                .buttonStyle(.plain)
                .help(isRecording ? "Stop recording" : "Start recording")

                Button(action: {
                    isPlaying.toggle()
                    audioEngine.setGranularPlaying(voiceIndex: voiceIndex, playing: isPlaying)
                }) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isPlaying ? ColorPalette.accentPlaits : accentColor)
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 4).fill(ColorPalette.backgroundTertiary))
                }
                .buttonStyle(.plain)
            }

            WaveformView(
                waveformData: audioEngine.waveformOverviews[voiceIndex],
                playheadPosition: audioEngine.granularPositions[voiceIndex] ?? 0,
                isPlaying: isPlaying,
                color: accentColor,
                fileName: loadedFileName,
                isDragOver: isDragOver,
                onSeek: { audioEngine.setGranularPosition(voiceIndex: voiceIndex, position: $0) },
                loopStart: loopStart,
                loopEnd: loopEnd,
                onLoopRangeChange: { newStart, newEnd in
                    loopStart = min(max(newStart, 0), newEnd)
                    loopEnd = max(min(newEnd, 1), loopStart)
                    sendLoopBounds()
                },
                recordPosition: isRecording ? audioEngine.recordingPositions[voiceIndex] : nil
            )
            .frame(height: 78)
            .onDrop(of: [.audio, .fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RATE")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textMuted)

                    Menu {
                        ForEach(rateOptions, id: \.self) { option in
                            Button(rateText(option)) {
                                rate = option
                                sendRate()
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(rateText(rate))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(accentColor)
                        }
                        .frame(width: 78, height: 24)
                        .background(ColorPalette.backgroundTertiary)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                Toggle(isOn: $isReverse) {
                    Text("REV")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .toggleStyle(SwitchToggleStyle(tint: accentColor))
                .frame(width: 84)
                .onChange(of: isReverse) { _ in sendReverse() }

                VStack(alignment: .leading, spacing: 2) {
                    Text("LOOP START")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                    Slider(
                        value: Binding(
                            get: { Double(loopStart) },
                            set: { newValue in
                                loopStart = min(Float(newValue), loopEnd)
                                sendLoopBounds()
                            }
                        ),
                        in: 0...1
                    )
                    .tint(accentColor)
                    .frame(width: 190)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("LOOP END")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                    Slider(
                        value: Binding(
                            get: { Double(loopEnd) },
                            set: { newValue in
                                loopEnd = max(Float(newValue), loopStart)
                                sendLoopBounds()
                            }
                        ),
                        in: 0...1
                    )
                    .tint(accentColor)
                    .frame(width: 190)
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<cutCount, id: \.self) { cut in
                    Button(action: { triggerCut(cut) }) {
                        Text("\(cut + 1)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(ColorPalette.textPrimary)
                            .frame(width: 34, height: 24)
                            .background(ColorPalette.backgroundTertiary)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(accentColor.opacity(0.45), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
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
        .onReceive(audioEngine.objectWillChange) { _ in
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

    private func rateText(_ value: Float) -> String {
        if value == floor(value) {
            return String(format: "x%.0f", value)
        }
        return String(format: "x%.2g", value)
    }

    private func syncFromEngine() {
        let engineStart = audioEngine.getParameter(id: .looperLoopStart, voiceIndex: voiceIndex)
        let engineEnd = audioEngine.getParameter(id: .looperLoopEnd, voiceIndex: voiceIndex)
        loopStart = engineStart
        loopEnd = max(engineEnd, engineStart)

        let engineRate = audioEngine.getParameter(id: .looperRate, voiceIndex: voiceIndex)
        // Denormalize: normalized = (rate - 0.25) / 1.75
        let denormalized = engineRate * 1.75 + 0.25
        rate = denormalized

        let engineReverse = audioEngine.getParameter(id: .looperReverse, voiceIndex: voiceIndex)
        isReverse = engineReverse > 0.5

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

    private func sendRate() {
        let normalized = (rate - 0.25) / 1.75
        audioEngine.setParameter(id: .looperRate, value: max(0, min(1, normalized)), voiceIndex: voiceIndex)
    }

    private func sendReverse() {
        audioEngine.setParameter(id: .looperReverse, value: isReverse ? 1.0 : 0.0, voiceIndex: voiceIndex)
    }

    private func sendLoopBounds() {
        audioEngine.setParameter(id: .looperLoopStart, value: loopStart, voiceIndex: voiceIndex)
        audioEngine.setParameter(id: .looperLoopEnd, value: loopEnd, voiceIndex: voiceIndex)
    }

    private func triggerCut(_ cut: Int) {
        let normalized = Float(cut) / Float(max(cutCount - 1, 1))
        audioEngine.setParameter(id: .looperCut, value: normalized, voiceIndex: voiceIndex)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }

            DispatchQueue.main.async {
                audioEngine.loadAudioFile(url: url, reelIndex: voiceIndex)
                loadedFileName = url.lastPathComponent
            }
        }

        return true
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            audioEngine.loadAudioFile(url: url, reelIndex: voiceIndex)
            loadedFileName = url.lastPathComponent
        }
    }

    private func channelShortName(_ channel: Int) -> String {
        MixerChannel.shortName(channel)
    }

    private func channelDisplayName(_ channel: Int) -> String {
        MixerChannel.displayName(channel)
    }

    private func isSourceSelected(_ type: AudioEngineWrapper.RecordSourceType, _ channel: Int) -> Bool {
        recordSourceType == type && recordSourceChannel == channel
    }

    @ViewBuilder
    private func inputSourceButton(_ name: String, channel: Int) -> some View {
        Button(action: { recordSourceType = .internalVoice; recordSourceChannel = channel }) {
            if isSourceSelected(.internalVoice, channel) {
                Label(name, systemImage: "checkmark")
            } else {
                Text(name)
            }
        }
    }
}

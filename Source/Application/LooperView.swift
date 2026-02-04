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

    private let rateOptions: [Float] = [0.25, 0.5, 1.0, 1.5, 2.0]
    private let cutCount = 8

    private var accentColor: Color {
        voiceIndex == 1 ? Color(hex: "#9B59B6") : Color(hex: "#E67E22")
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)

                Spacer()

                Button(action: openFilePicker) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#888888"))
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#252528")))
                }
                .buttonStyle(.plain)

                Button(action: {
                    isPlaying.toggle()
                    audioEngine.setGranularPlaying(voiceIndex: voiceIndex, playing: isPlaying)
                }) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isPlaying ? Color(hex: "#FF6B6B") : accentColor)
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#252528")))
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
                }
            )
            .frame(height: 78)
            .onDrop(of: [.audio, .fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RATE")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#888888"))

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
                        .background(Color(hex: "#252528"))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                Toggle(isOn: $isReverse) {
                    Text("REV")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#DDDDDD"))
                }
                .toggleStyle(SwitchToggleStyle(tint: accentColor))
                .frame(width: 84)
                .onChange(of: isReverse) { _ in sendReverse() }

                VStack(alignment: .leading, spacing: 2) {
                    Text("LOOP START")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#777777"))
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
                        .foregroundColor(Color(hex: "#777777"))
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
                            .foregroundColor(Color(hex: "#EEEEEE"))
                            .frame(width: 34, height: 24)
                            .background(Color(hex: "#252528"))
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
        .background(Color(hex: "#0F0F11"))
        .cornerRadius(8)
        .onAppear {
            sendRate()
            sendReverse()
            sendLoopBounds()
        }
    }

    private func rateText(_ value: Float) -> String {
        if value == floor(value) {
            return String(format: "x%.0f", value)
        }
        return String(format: "x%.2g", value)
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
}

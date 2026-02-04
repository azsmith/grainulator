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
    let voiceIndex: Int

    // Core Mangl parameters
    @State private var speed: Float = 0.5        // 0-1 maps to -3 to +3
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
    @State private var showAdvanced: Bool = false
    @State private var isDragOver: Bool = false
    @State private var loadedFileName: String?

    // Voice colors
    let voiceColors: [Color] = [
        Color(hex: "#4A9EFF"),  // Voice 1: Blue
        Color(hex: "#9B59B6"),  // Voice 2: Purple
        Color(hex: "#E67E22"),  // Voice 3: Orange
        Color(hex: "#1ABC9C")   // Voice 4: Teal
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

    var voiceColor: Color {
        voiceColors[voiceIndex % voiceColors.count]
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("GRANULAR \(voiceIndex + 1)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(voiceColor)

                Spacer()

                // Load file button
                Button(action: {
                    openFilePicker()
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#888888"))
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "#252528"))
                        )
                }
                .buttonStyle(.plain)
                .help("Load audio file")

                // Play button (gate)
                Button(action: {
                    isPlaying.toggle()
                    audioEngine.setGranularPlaying(voiceIndex: voiceIndex, playing: isPlaying)
                }) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isPlaying ? Color(hex: "#FF6B6B") : voiceColor)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "#252528"))
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
                }
            )
            .frame(height: 80)
            .onDrop(of: [.audio, .fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
            }

            // Core parameters row
            HStack(spacing: 16) {
                // SPEED (displayed as percentage: 100% = normal, -100% = reverse)
                GranularSlider(
                    label: "SPEED",
                    value: $speed,
                    color: voiceColor,
                    formatter: { value in
                        let spd = (Double(value) - 0.5) * 4.0  // -2 to +2
                        let percent = Int(spd * 100)
                        if percent == 0 {
                            return "0%"
                        } else if percent > 0 {
                            return "+\(percent)%"
                        } else {
                            return "\(percent)%"
                        }
                    }
                )
                .onChange(of: speed) { newValue in
                    audioEngine.setParameter(id: .granularSpeed, value: newValue, voiceIndex: voiceIndex)
                }

                // PITCH
                GranularSlider(
                    label: "PITCH",
                    value: $pitch,
                    color: Color(hex: "#7B68EE"),
                    formatter: { value in
                        let semitones = Int((Double(value) - 0.5) * 48)  // -24 to +24
                        if semitones == 0 {
                            return "0st"
                        } else if semitones > 0 {
                            return "+\(semitones)st"
                        } else {
                            return "\(semitones)st"
                        }
                    }
                )
                .onChange(of: pitch) { newValue in
                    audioEngine.setParameter(id: .granularPitch, value: newValue, voiceIndex: voiceIndex)
                }

                // SIZE (grain duration)
                GranularSlider(
                    label: "SIZE",
                    value: $size,
                    color: voiceColor,
                    formatter: { value in
                        // 1ms to 1000ms logarithmic
                        let ms = 1.0 * pow(1000.0, Double(value))
                        if ms < 100 {
                            return String(format: "%.0fms", ms)
                        } else {
                            return String(format: "%.0fms", ms)
                        }
                    }
                )
                .onChange(of: size) { newValue in
                    audioEngine.setParameter(id: .granularSize, value: newValue, voiceIndex: voiceIndex)
                }

                // DENSITY (grain rate)
                GranularSlider(
                    label: "DENSITY",
                    value: $density,
                    color: voiceColor,
                    formatter: { value in
                        // 1Hz to 512Hz logarithmic
                        let hz = 1.0 * pow(512.0, Double(value))
                        if hz < 10 {
                            return String(format: "%.1fHz", hz)
                        } else {
                            return String(format: "%.0fHz", hz)
                        }
                    }
                )
                .onChange(of: density) { newValue in
                    audioEngine.setParameter(id: .granularDensity, value: newValue, voiceIndex: voiceIndex)
                }
            }

            // Advanced toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAdvanced.toggle()
                }
            }) {
                HStack {
                    Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                    Text("ADVANCED")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundColor(Color(hex: "#666666"))
            }
            .buttonStyle(.plain)

            // Extended parameters (collapsible)
            if showAdvanced {
                HStack(spacing: 16) {
                    // JITTER (position randomization)
                    GranularSlider(
                        label: "JITTER",
                        value: $jitter,
                        color: Color(hex: "#FFD93D"),
                        formatter: { value in
                            // 0ms to 500ms
                            let ms = Double(value) * 500.0
                            return String(format: "%.0fms", ms)
                        }
                    )
                    .onChange(of: jitter) { newValue in
                        audioEngine.setParameter(id: .granularJitter, value: newValue, voiceIndex: voiceIndex)
                    }

                    // SPREAD (stereo spread)
                    GranularSlider(
                        label: "SPREAD",
                        value: $spread,
                        color: Color(hex: "#FF6B6B")
                    )
                    .onChange(of: spread) { newValue in
                        audioEngine.setParameter(id: .granularSpread, value: newValue, voiceIndex: voiceIndex)
                    }

                    // MORPH (probability of extra per-grain randomization)
                    GranularSlider(
                        label: "MORPH",
                        value: $morph,
                        color: Color(hex: "#6BCB77"),
                        formatter: { value in
                            String(format: "%.0f%%", value * 100)
                        }
                    )
                    .onChange(of: morph) { newValue in
                        audioEngine.setParameter(id: .granularMorph, value: newValue, voiceIndex: voiceIndex)
                    }

                    // FILTER
                    GranularSlider(
                        label: "FILTER",
                        value: $filterCutoff,
                        color: Color(hex: "#E67E22"),
                        formatter: { value in
                            let hz = 20.0 * pow(1000.0, Double(value))
                            if hz < 1000 {
                                return String(format: "%.0fHz", hz)
                            } else {
                                return String(format: "%.1fkHz", hz / 1000)
                            }
                        }
                    )
                    .onChange(of: filterCutoff) { newValue in
                        audioEngine.setParameter(id: .granularFilterCutoff, value: newValue, voiceIndex: voiceIndex)
                    }

                    // RESONANCE
                    GranularSlider(
                        label: "RES",
                        value: $filterResonance,
                        color: Color(hex: "#FF8C42"),
                        formatter: { value in
                            String(format: "%.0f%%", value * 100)
                        }
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
                            .foregroundColor(Color(hex: "#888888"))

                        HStack(spacing: 4) {
                            ForEach(Array(envelopeNames.enumerated()), id: \.offset) { index, name in
                                Button(action: {
                                    envelope = index
                                    audioEngine.setParameter(id: .granularEnvelope, value: Float(index) / 7.0, voiceIndex: voiceIndex)
                                }) {
                                    Text(name)
                                        .font(.system(size: 9, weight: envelope == index ? .bold : .regular, design: .monospaced))
                                        .foregroundColor(envelope == index ? .white : Color(hex: "#AAAAAA"))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(envelope == index ? voiceColor.opacity(0.6) : Color(hex: "#252528"))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("FILTER MODEL")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#888888"))

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
                                    .fill(Color(hex: "#252528"))
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
                            .foregroundColor(Color(hex: "#888888"))

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
                                        .fill(reverseGrains ? voiceColor.opacity(0.75) : Color(hex: "#252528"))
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
                        GranularSlider(
                            label: "DECAY",
                            value: $decay,
                            color: Color(hex: "#FF9500"),
                            formatter: { value in
                                // Higher value = longer decay
                                if value < 0.25 {
                                    return "Short"
                                } else if value < 0.5 {
                                    return "Med"
                                } else if value < 0.75 {
                                    return "Long"
                                } else {
                                    return "V.Long"
                                }
                            }
                        )
                        .onChange(of: decay) { newValue in
                            audioEngine.setParameter(id: .granularDecay, value: newValue, voiceIndex: voiceIndex)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color(hex: "#0F0F11"))
        .cornerRadius(8)
        .onAppear {
            let normalized = Float(filterModel) / Float(max(filterModelNames.count - 1, 1))
            audioEngine.setParameter(id: .granularFilterModel, value: normalized, voiceIndex: voiceIndex)
            audioEngine.setParameter(id: .granularReverse, value: reverseGrains ? 1.0 : 0.0, voiceIndex: voiceIndex)
            audioEngine.setParameter(id: .granularMorph, value: morph, voiceIndex: voiceIndex)
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

    init(waveformData: [Float]?, playheadPosition: Float, isPlaying: Bool, color: Color, fileName: String?, isDragOver: Bool, onSeek: ((Float) -> Void)? = nil) {
        self.waveformData = waveformData
        self.playheadPosition = playheadPosition
        self.isPlaying = isPlaying
        self.color = color
        self.fileName = fileName
        self.isDragOver = isDragOver
        self.onSeek = onSeek
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: "#1A1A1D"))
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
                                .foregroundColor(Color(hex: "#888888"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#1A1A1D").opacity(0.8))
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
                        .foregroundColor(isDragOver ? color : Color(hex: "#666666"))
                    Text(isDragOver ? "Drop to load" : "Drop audio file or use folder button")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(isDragOver ? color : Color(hex: "#666666"))
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
    var formatter: ((Float) -> String)?

    init(label: String, value: Binding<Float>, color: Color, formatter: ((Float) -> String)? = nil) {
        self.label = label
        self._value = value
        self.color = color
        self.formatter = formatter
    }

    var displayValue: String {
        if let formatter = formatter {
            return formatter(value)
        }
        return String(format: "%.0f%%", value * 100)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#888888"))

            // Vertical slider
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#252528"))

                    // Value fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.6))
                        .frame(height: geometry.size.height * CGFloat(value))
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let newValue = 1.0 - Float(gesture.location.y / geometry.size.height)
                            value = max(0, min(1, newValue))
                        }
                )
            }
            .frame(width: 50, height: 60)

            Text(displayValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

//
//  ContentView.swift
//  Grainulator
//
//  Main content view that switches between different view modes
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    var body: some View {
        ZStack {
            Color(hex: "#1A1A1D")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Status bar
                StatusBarView()
                    .frame(height: 40)

                Divider()
                    .background(Color(hex: "#333333"))

                // Main content area - switches based on view mode
                Group {
                    switch appState.currentView {
                    case .multiVoice:
                        MultiVoiceView()
                    case .focus:
                        FocusView()
                    case .performance:
                        PerformanceView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                    .background(Color(hex: "#333333"))

                // Mixer and Effects at the bottom
                HStack(spacing: 0) {
                    MixerView()

                    Rectangle()
                        .fill(Color(hex: "#333333"))
                        .frame(width: 1)

                    EffectsView()
                        .frame(width: 520)
                }
                .frame(height: 200)
            }
        }
        .onAppear {
            audioEngine.start()
        }
        .onDisappear {
            audioEngine.stop()
        }
    }
}

// MARK: - Status Bar

struct StatusBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    var body: some View {
        HStack(spacing: 20) {
            // App title
            Text("GRAINULATOR")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#4A9EFF"))

            Spacer()

            // View mode selector
            HStack(spacing: 8) {
                ViewModeButton(mode: .multiVoice, label: "Multi")
                ViewModeButton(mode: .focus, label: "Focus")
                ViewModeButton(mode: .performance, label: "Perform")
            }

            Spacer()

            // CPU and latency monitoring
            HStack(spacing: 20) {
                StatusLabel(label: "CPU", value: String(format: "%.1f%%", appState.cpuUsage))
                StatusLabel(label: "Latency", value: String(format: "%.1fms", appState.latency))
            }
        }
        .padding(.horizontal, 20)
        .background(Color(hex: "#0F0F11"))
    }
}

struct ViewModeButton: View {
    @EnvironmentObject var appState: AppState
    let mode: AppState.ViewMode
    let label: String

    var isActive: Bool {
        appState.currentView == mode
    }

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                appState.switchToView(mode)
            }
        }) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? Color(hex: "#1A1A1D") : Color(hex: "#CCCCCC"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? Color(hex: "#4A9EFF") : Color.clear)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(hex: "#4A9EFF"), lineWidth: 1)
                        .opacity(isActive ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct StatusLabel: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#888888"))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#4A9EFF"))
        }
    }
}

// MARK: - Placeholder Views (to be implemented)

struct MultiVoiceView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Plaits synthesizer
                PlaitsView()
                RingsView()

                // Metropolix-inspired sequencer
                SequencerView()

                GranularView(voiceIndex: 0)
                LooperView(voiceIndex: 1, title: "LOOPER 1")
                LooperView(voiceIndex: 2, title: "LOOPER 2")
                GranularView(voiceIndex: 3)
            }
            .padding(20)
        }
    }
}

struct FocusView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("FOCUS VIEW")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#4A9EFF"))

                // Show Plaits in focus view too
                PlaitsView()

                Text("Full-width voice controls coming soon")
                    .foregroundColor(Color(hex: "#888888"))
            }
            .padding(20)
        }
    }
}

struct PerformanceView: View {
    var body: some View {
        Text("Performance View")
            .foregroundColor(.white)
    }
}

// MARK: - Mixer View

struct MixerView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    // Channel gains (0-1 maps to 0-2 gain, 0.5 = unity)
    @State private var channelGains: [Float] = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]

    // Channel pans (0-1, 0.5 = center)
    @State private var channelPans: [Float] = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]

    // Channel sends (0-1)
    @State private var channelSends: [Float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

    // Mute/Solo states
    @State private var channelMuted: [Bool] = [false, false, false, false, false, false]
    @State private var channelSoloed: [Bool] = [false, false, false, false, false, false]

    // Master (0-1 maps to 0-2 gain, 0.5 = unity)
    @State private var masterLevel: Float = 0.5

    // Channel names
    let channelNames: [String] = ["PLAITS", "RINGS", "GRAN 1", "LOOP 1", "LOOP 2", "GRAN 4"]

    // Channel colors
    let channelColors: [Color] = [
        Color(hex: "#FF6B6B"),  // Plaits: Red
        Color(hex: "#00D1B2"),  // Rings: Mint
        Color(hex: "#4A9EFF"),  // Granular 1: Blue
        Color(hex: "#9B59B6"),  // Granular 2: Purple
        Color(hex: "#E67E22"),  // Granular 3: Orange
        Color(hex: "#1ABC9C")   // Granular 4: Teal
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Channel strips
            HStack(spacing: 2) {
                ForEach(0..<6, id: \.self) { index in
                    ChannelStripView(
                        label: channelNames[index],
                        color: channelColors[index],
                        level: $channelGains[index],
                        pan: $channelPans[index],
                        send: $channelSends[index],
                        isMuted: $channelMuted[index],
                        isSoloed: $channelSoloed[index],
                        meterLevel: audioEngine.channelLevels[index],
                        onLevelChange: { value in
                            audioEngine.setParameter(id: .voiceGain, value: value, voiceIndex: index)
                        },
                        onPanChange: { value in
                            audioEngine.setParameter(id: .voicePan, value: value, voiceIndex: index)
                        },
                        onSendChange: { value in
                            audioEngine.setParameter(id: .voiceSend, value: value, voiceIndex: index)
                        }
                    )
                }
            }

            // Divider before master
            Rectangle()
                .fill(Color(hex: "#333333"))
                .frame(width: 2)
                .padding(.vertical, 8)

            // Master section
            MasterStripView(
                level: $masterLevel,
                meterL: audioEngine.masterLevelL,
                meterR: audioEngine.masterLevelR,
                onLevelChange: { value in
                    audioEngine.setParameter(id: .masterGain, value: value)
                }
            )

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "#0F0F11"))
    }
}

// MARK: - Channel Strip

struct ChannelStripView: View {
    let label: String
    let color: Color
    @Binding var level: Float
    @Binding var pan: Float
    @Binding var send: Float
    @Binding var isMuted: Bool
    @Binding var isSoloed: Bool
    let meterLevel: Float
    let onLevelChange: (Float) -> Void
    let onPanChange: (Float) -> Void
    let onSendChange: (Float) -> Void

    var body: some View {
        VStack(spacing: 4) {
            // Channel label
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isMuted ? Color(hex: "#555555") : color)
                .frame(width: 56)

            // Pan knob
            MiniKnobView(value: $pan, label: "PAN", color: color)
                .frame(width: 32, height: 32)
                .onChange(of: pan) { newValue in
                    onPanChange(newValue)
                }

            // Send knob
            MiniKnobView(value: $send, label: "SND", color: Color(hex: "#4ECDC4"))
                .frame(width: 32, height: 32)
                .onChange(of: send) { newValue in
                    onSendChange(newValue)
                }

            // Fader + Meter
            HStack(spacing: 2) {
                // Level meter
                MeterView(level: meterLevel)
                    .frame(width: 6, height: 80)

                // Fader
                FaderView(value: $level, color: color, isMuted: isMuted)
                    .frame(width: 24, height: 80)
                    .onChange(of: level) { newValue in
                        if !isMuted {
                            onLevelChange(newValue)
                        }
                    }
            }

            // Level display
            Text(levelToDb(level))
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(isMuted ? Color(hex: "#555555") : Color(hex: "#AAAAAA"))
                .frame(width: 48)

            // Mute/Solo buttons
            HStack(spacing: 2) {
                Button(action: { isMuted.toggle() }) {
                    Text("M")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(isMuted ? .white : Color(hex: "#888888"))
                        .frame(width: 18, height: 16)
                        .background(isMuted ? Color(hex: "#FF4444") : Color(hex: "#252528"))
                        .cornerRadius(2)
                }
                .buttonStyle(.plain)

                Button(action: { isSoloed.toggle() }) {
                    Text("S")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(isSoloed ? .black : Color(hex: "#888888"))
                        .frame(width: 18, height: 16)
                        .background(isSoloed ? Color(hex: "#FFDD44") : Color(hex: "#252528"))
                        .cornerRadius(2)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 56)
        .padding(.vertical, 4)
    }

    func levelToDb(_ level: Float) -> String {
        // level 0-1 maps to gain 0-2, so 0.5 = unity (0dB)
        let gain = level * 2.0
        if gain <= 0.001 {
            return "-inf"
        }
        let db = 20 * log10(gain)
        if db >= 0 {
            return String(format: "+%.1f", db)
        } else {
            return String(format: "%.1f", db)
        }
    }
}

// MARK: - Mini Knob View (for channel strip)

struct MiniKnobView: View {
    @Binding var value: Float
    let label: String
    let color: Color

    @State private var dragStartValue: Float = 0
    @State private var isDragging: Bool = false

    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                // Background circle
                Circle()
                    .fill(Color(hex: "#252528"))
                    .frame(width: 24, height: 24)

                // Arc indicator
                Circle()
                    .trim(from: 0.15, to: 0.15 + 0.7 * CGFloat(value))
                    .stroke(color, lineWidth: 2)
                    .rotationEffect(.degrees(90))
                    .frame(width: 20, height: 20)

                // Pointer line
                Rectangle()
                    .fill(isDragging ? color : color.opacity(0.8))
                    .frame(width: 1, height: 6)
                    .offset(y: -6)
                    .rotationEffect(.degrees(Double(value - 0.5) * 270))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            dragStartValue = value
                        }
                        // Shift key = fine control (4x slower)
                        let sensitivity: Float = NSEvent.modifierFlags.contains(.shift) ? 400.0 : 100.0
                        let delta = -Float(gesture.translation.height) / sensitivity
                        value = max(0, min(1, dragStartValue + delta))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            Text(label)
                .font(.system(size: 6, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#666666"))
        }
    }
}

// MARK: - Fader View

struct FaderView: View {
    @Binding var value: Float
    let color: Color
    let isMuted: Bool

    @State private var dragStartValue: Float = 0
    @State private var isDragging: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Track background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#1A1A1D"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color(hex: "#333333"), lineWidth: 1)
                    )

                // Level fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                isMuted ? Color(hex: "#333333") : color.opacity(0.3),
                                isMuted ? Color(hex: "#444444") : color.opacity(0.6)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: geometry.size.height * CGFloat(value))

                // Fader cap
                RoundedRectangle(cornerRadius: 2)
                    .fill(isMuted ? Color(hex: "#555555") : (isDragging ? color : color.opacity(0.9)))
                    .frame(width: geometry.size.width - 4, height: 8)
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height * CGFloat(1 - value)
                    )
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            dragStartValue = value
                        }
                        // Shift key = fine control (4x slower)
                        let sensitivity: Float = NSEvent.modifierFlags.contains(.shift) ? 4.0 : 1.0
                        let delta = -Float(gesture.translation.height / geometry.size.height) / sensitivity
                        value = max(0, min(1, dragStartValue + delta))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            // Double-click to reset to unity (0.5 = 1.0 gain)
            .onTapGesture(count: 2) {
                value = 0.5
            }
        }
    }
}

// MARK: - Pan Control

struct PanControlView: View {
    @Binding var value: Float  // 0 = left, 0.5 = center, 1 = right
    let color: Color

    @State private var dragStartValue: Float = 0
    @State private var isDragging: Bool = false

    var displayValue: String {
        let pan = (value - 0.5) * 2  // Convert to -1 to +1
        if abs(pan) < 0.05 {
            return "C"
        } else if pan < 0 {
            return String(format: "L%d", Int(abs(pan) * 100))
        } else {
            return String(format: "R%d", Int(pan * 100))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#252528"))

                // Center line
                Rectangle()
                    .fill(Color(hex: "#444444"))
                    .frame(width: 1)

                // Pan indicator
                Circle()
                    .fill(isDragging ? color : color.opacity(0.8))
                    .frame(width: 10, height: 10)
                    .position(
                        x: CGFloat(value) * geometry.size.width,
                        y: geometry.size.height / 2
                    )
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            dragStartValue = value
                        }
                        // Horizontal drag, shift = fine control
                        let sensitivity: Float = NSEvent.modifierFlags.contains(.shift) ? 4.0 : 1.0
                        let delta = Float(gesture.translation.width / geometry.size.width) / sensitivity
                        value = max(0, min(1, dragStartValue + delta))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            // Double-click to center
            .onTapGesture(count: 2) {
                value = 0.5
            }
        }
    }
}

// MARK: - Master Strip

struct MasterStripView: View {
    @Binding var level: Float
    let meterL: Float
    let meterR: Float
    let onLevelChange: (Float) -> Void

    var body: some View {
        VStack(spacing: 4) {
            // Label
            Text("MASTER")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#FFFFFF"))
                .frame(width: 70)

            // Stereo meter
            HStack(spacing: 2) {
                MeterView(level: meterL)
                MeterView(level: meterR)
            }
            .frame(width: 20, height: 80)

            // Fader
            FaderView(value: $level, color: Color(hex: "#FFFFFF"), isMuted: false)
                .frame(width: 32, height: 80)
                .onChange(of: level) { newValue in
                    onLevelChange(newValue)
                }

            // Level display
            Text(levelToDb(level))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#FFFFFF"))
                .frame(width: 48)
        }
        .frame(width: 70)
        .padding(.vertical, 4)
    }

    func levelToDb(_ level: Float) -> String {
        // level 0-1 maps to gain 0-2, so 0.5 = unity (0dB)
        let gain = level * 2.0
        if gain <= 0.001 {
            return "-inf"
        }
        let db = 20 * log10(gain)
        if db >= 0 {
            return String(format: "+%.1f", db)
        } else {
            return String(format: "%.1f", db)
        }
    }
}

// MARK: - Meter View

struct MeterView: View {
    let level: Float  // 0-1

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background
                Rectangle()
                    .fill(Color(hex: "#1A1A1D"))

                // Level
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#00AA00"),
                                Color(hex: "#AAAA00"),
                                Color(hex: "#FF4444")
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: geometry.size.height * CGFloat(level))
            }
        }
        .frame(width: 8)
        .cornerRadius(1)
    }
}

// MARK: - Effects View

struct EffectsView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    // Delay parameters
    @State private var delayTime: Float = 0.3
    @State private var delayFeedback: Float = 0.4
    @State private var delayMix: Float = 0.0
    @State private var delayHeadMode: Float = 0.86
    @State private var delaySync: Float = 0.0
    @State private var delayTempo: Float = 0.5
    @State private var delaySubdivision: Float = 0.375
    @State private var delayWow: Float = 0.5
    @State private var delayFlutter: Float = 0.5
    @State private var delayTone: Float = 0.45

    // Reverb parameters
    @State private var reverbSize: Float = 0.5
    @State private var reverbDamping: Float = 0.5
    @State private var reverbMix: Float = 0.0

    private func delayModeLabel(_ value: Float) -> String {
        let modes = ["H1", "H2", "H3", "H12", "H23", "H13", "H123", "STACK"]
        let index = min(max(Int((value * 7.0).rounded()), 0), modes.count - 1)
        return modes[index]
    }

    private func delaySubdivisionLabel(_ value: Float) -> String {
        let labels = ["1/2", "1/2T", "1/4.", "1/4", "1/4T", "1/8.", "1/8", "1/8T", "1/16"]
        let index = min(max(Int((value * 8.0).rounded()), 0), labels.count - 1)
        return labels[index]
    }

    var body: some View {
        HStack(spacing: 16) {
            // Delay Section
            EffectUnitView(
                title: "DELAY",
                color: Color(hex: "#4ECDC4"),
                parameters: [
                    EffectParameter(name: "TIME", value: $delayTime, formatter: { v in
                        let head1Seconds: Double
                        if delaySync > 0.5 {
                            let divisions: [Double] = [2.0, 1.333333, 1.5, 1.0, 0.666667, 0.75, 0.5, 0.333333, 0.25]
                            let divisionIndex = min(max(Int((delaySubdivision * 8.0).rounded()), 0), divisions.count - 1)
                            let bpm = 60.0 + Double(delayTempo) * 120.0
                            head1Seconds = (60.0 / bpm) * divisions[divisionIndex]
                        } else {
                            head1Seconds = 0.06 + (Double(v) * Double(v)) * 0.39
                        }
                        let maxHeadMilliseconds = head1Seconds * 1.95 * 1000.0
                        return String(format: "%.0fms", maxHeadMilliseconds)
                    }),
                    EffectParameter(name: "FDBK", value: $delayFeedback, formatter: { v in
                        String(format: "%.0f%%", v * 100)
                    }),
                    EffectParameter(name: "MIX", value: $delayMix, formatter: { v in
                        String(format: "%.0f%%", v * 100)
                    }),
                    EffectParameter(name: "MODE", value: $delayHeadMode, formatter: { v in
                        delayModeLabel(v)
                    }),
                    EffectParameter(name: "SYNC", value: $delaySync, formatter: { v in
                        v > 0.5 ? "ON" : "OFF"
                    }),
                    EffectParameter(name: "BPM", value: $delayTempo, formatter: { v in
                        String(format: "%.0f", 60.0 + v * 120.0)
                    }),
                    EffectParameter(name: "DIV", value: $delaySubdivision, formatter: { v in
                        delaySubdivisionLabel(v)
                    }),
                    EffectParameter(name: "WOW", value: $delayWow, formatter: { v in
                        String(format: "%.0f%%", v * 100)
                    }),
                    EffectParameter(name: "FLUT", value: $delayFlutter, formatter: { v in
                        String(format: "%.0f%%", v * 100)
                    }),
                    EffectParameter(name: "TONE", value: $delayTone, formatter: { v in
                        String(format: "%.0f%%", v * 100)
                    })
                ],
                onParameterChange: { index, value in
                    switch index {
                    case 0: audioEngine.setParameter(id: .delayTime, value: value)
                    case 1: audioEngine.setParameter(id: .delayFeedback, value: value)
                    case 2: audioEngine.setParameter(id: .delayMix, value: value)
                    case 3: audioEngine.setParameter(id: .delayHeadMode, value: value)
                    case 4: audioEngine.setParameter(id: .delaySync, value: value > 0.5 ? 1.0 : 0.0)
                    case 5: audioEngine.setParameter(id: .delayTempo, value: value)
                    case 6: audioEngine.setParameter(id: .delaySubdivision, value: value)
                    case 7: audioEngine.setParameter(id: .delayWow, value: value)
                    case 8: audioEngine.setParameter(id: .delayFlutter, value: value)
                    case 9: audioEngine.setParameter(id: .delayTone, value: value)
                    default: break
                    }
                }
            )

            // Reverb Section
            EffectUnitView(
                title: "REVERB",
                color: Color(hex: "#9B59B6"),
                parameters: [
                    EffectParameter(name: "SIZE", value: $reverbSize, formatter: { v in
                        String(format: "%.0f%%", v * 100)
                    }),
                    EffectParameter(name: "DAMP", value: $reverbDamping, formatter: { v in
                        String(format: "%.0f%%", v * 100)
                    }),
                    EffectParameter(name: "MIX", value: $reverbMix, formatter: { v in
                        String(format: "%.0f%%", v * 100)
                    })
                ],
                onParameterChange: { index, value in
                    switch index {
                    case 0: audioEngine.setParameter(id: .reverbSize, value: value)
                    case 1: audioEngine.setParameter(id: .reverbDamping, value: value)
                    case 2: audioEngine.setParameter(id: .reverbMix, value: value)
                    default: break
                    }
                }
            )
        }
        .padding(12)
        .background(Color(hex: "#0F0F11"))
    }
}

struct EffectParameter {
    let name: String
    @Binding var value: Float
    let formatter: (Float) -> String

    init(name: String, value: Binding<Float>, formatter: @escaping (Float) -> String = { v in String(format: "%.0f%%", v * 100) }) {
        self.name = name
        self._value = value
        self.formatter = formatter
    }
}

struct EffectUnitView: View {
    let title: String
    let color: Color
    let parameters: [EffectParameter]
    let onParameterChange: (Int, Float) -> Void

    var body: some View {
        let columnCount = max(1, min(4, parameters.count))
        let columns = Array(repeating: GridItem(.fixed(44), spacing: 12), count: columnCount)

        VStack(spacing: 8) {
            // Title
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)

            LazyVGrid(columns: columns, alignment: .center, spacing: 8) {
                ForEach(Array(parameters.enumerated()), id: \.offset) { index, param in
                    EffectKnobView(
                        label: param.name,
                        value: param.$value,
                        color: color,
                        formatter: param.formatter
                    )
                    .onChange(of: param.value) { newValue in
                        onParameterChange(index, newValue)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#1A1A1D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct EffectKnobView: View {
    let label: String
    @Binding var value: Float
    let color: Color
    let formatter: (Float) -> String

    @State private var isDragging: Bool = false
    @State private var dragStartValue: Float = 0

    var body: some View {
        VStack(spacing: 4) {
            // Label
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#888888"))

            // Knob
            ZStack {
                // Background circle
                Circle()
                    .fill(Color(hex: "#252528"))
                    .frame(width: 40, height: 40)

                // Arc indicator
                Circle()
                    .trim(from: 0.15, to: 0.15 + 0.7 * CGFloat(value))
                    .stroke(color, lineWidth: 3)
                    .rotationEffect(.degrees(90))
                    .frame(width: 34, height: 34)

                // Pointer line
                Rectangle()
                    .fill(isDragging ? color : color.opacity(0.8))
                    .frame(width: 2, height: 10)
                    .offset(y: -10)
                    .rotationEffect(.degrees(Double(value - 0.5) * 270))

                // Center dot
                Circle()
                    .fill(isDragging ? color : Color(hex: "#444444"))
                    .frame(width: 6, height: 6)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            dragStartValue = value
                        }
                        // Shift key = fine control (4x slower)
                        let sensitivity: Float = NSEvent.modifierFlags.contains(.shift) ? 600.0 : 150.0
                        let delta = -Float(gesture.translation.height) / sensitivity
                        value = max(0, min(1, dragStartValue + delta))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            // Value display
            Text(formatter(value))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(width: 44)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

//
//  OscilloscopeView.swift
//  Grainulator
//
//  Oscilloscope waveform display with source selection,
//  continuous timescale/sensitivity sliders, and dual-source overlay.
//

import SwiftUI

struct OscilloscopeView: View {
    @ObservedObject var audioEngine: AudioEngineWrapper

    private let scopeGreen = Color(red: 0.2, green: 1.0, blue: 0.3)
    private let scopeCyan = Color(red: 0.2, green: 0.8, blue: 1.0)
    private let gridColor = Color.white.opacity(0.08)
    private let bgColor = Color(red: 0.04, green: 0.04, blue: 0.06)

    var body: some View {
        HStack(spacing: 0) {
            // Waveform area
            VStack(spacing: 0) {
                ZStack {
                    bgColor
                    gridOverlay
                    waveformCanvas
                }

                infoBar
                    .frame(height: 22)
                    .background(ColorPalette.backgroundSecondary)
            }

            // Right control panel
            Rectangle()
                .fill(ColorPalette.divider)
                .frame(width: 1)

            controlPanel
                .frame(width: 160)
                .background(ColorPalette.backgroundSecondary)
        }
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Source A
            controlSection {
                HStack(spacing: 4) {
                    Circle().fill(scopeGreen).frame(width: 6, height: 6)
                    Text("Source A")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(scopeGreen)
                }
                sourcePicker(selection: $audioEngine.scopeSource, includeOff: false)
            }

            controlDivider

            // Source B
            controlSection {
                HStack(spacing: 4) {
                    Circle().fill(scopeCyan).frame(width: 6, height: 6)
                    Text("Source B")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(scopeCyan)
                }
                sourcePicker(selection: $audioEngine.scopeSourceB, includeOff: true)
            }

            controlDivider

            // Time/div slider
            controlSection {
                HStack {
                    Text("Time")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                    Spacer()
                    Text(timescaleLabel(audioEngine.scopeTimeScale))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                        .monospacedDigit()
                }
                Slider(value: $audioEngine.scopeTimeNorm, in: 0...1)
                    .controlSize(.small)
            }

            controlDivider

            // Sensitivity slider
            controlSection {
                HStack {
                    Text("Gain")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                    Spacer()
                    Text(gainLabel(audioEngine.scopeGain))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                        .monospacedDigit()
                }
                Slider(value: $audioEngine.scopeGain, in: 0.25...8.0)
                    .controlSize(.small)
            }

            Spacer()
        }
    }

    private func controlSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var controlDivider: some View {
        Rectangle()
            .fill(ColorPalette.divider)
            .frame(height: 1)
    }

    private func sourcePicker(selection: Binding<Int>, includeOff: Bool) -> some View {
        Picker("", selection: selection) {
            if includeOff {
                Text("Off").tag(-1)
            }
            Section(header: Text("Voices")) {
                ForEach(0..<8, id: \.self) { i in
                    Text(AudioEngineWrapper.scopeSourceNames[i]).tag(i)
                }
            }
            Section(header: Text("Master")) {
                Text(AudioEngineWrapper.scopeSourceNames[8]).tag(8)
            }
            Section(header: Text("Clock Outputs")) {
                ForEach(9..<17, id: \.self) { i in
                    Text(AudioEngineWrapper.scopeSourceNames[i]).tag(i)
                }
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private func timescaleLabel(_ samples: Int) -> String {
        let ms = Double(samples) / 48.0
        if ms < 1.0 {
            return String(format: "%.0f us", ms * 1000)
        }
        return String(format: "%.1f ms", ms)
    }

    private func gainLabel(_ gain: Double) -> String {
        if gain >= 1.0 {
            return String(format: "%.1fx", gain)
        }
        return String(format: "%.2fx", gain)
    }

    // MARK: - Grid

    private var gridOverlay: some View {
        Canvas { context, size in
            let centerY = size.height / 2
            context.stroke(
                Path { p in
                    p.move(to: CGPoint(x: 0, y: centerY))
                    p.addLine(to: CGPoint(x: size.width, y: centerY))
                },
                with: .color(.white.opacity(0.15)),
                lineWidth: 0.5
            )

            for frac in [0.25, 0.75] {
                let y = size.height * frac
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(gridColor),
                    lineWidth: 0.5
                )
            }

            let divCount = 8
            for i in 1..<divCount {
                let x = size.width * CGFloat(i) / CGFloat(divCount)
                context.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(gridColor),
                    lineWidth: 0.5
                )
            }
        }
    }

    // MARK: - Waveform Canvas

    private var waveformCanvas: some View {
        let gain = CGFloat(audioEngine.scopeGain)
        return Canvas { context, size in
            let centerY = size.height / 2

            // Draw Source B first (underneath)
            let samplesB = audioEngine.scopeWaveformB
            if samplesB.count > 1 {
                let pathB = buildWaveformPath(samples: samplesB, size: size, centerY: centerY, gain: gain)
                context.stroke(pathB, with: .color(scopeCyan.opacity(0.2)), lineWidth: 4)
                context.stroke(pathB, with: .color(scopeCyan), lineWidth: 1.5)
            }

            // Draw Source A on top
            let samplesA = audioEngine.scopeWaveform
            if samplesA.count > 1 {
                let pathA = buildWaveformPath(samples: samplesA, size: size, centerY: centerY, gain: gain)
                context.stroke(pathA, with: .color(scopeGreen.opacity(0.3)), lineWidth: 4)
                context.stroke(pathA, with: .color(scopeGreen), lineWidth: 1.5)
            }
        }
    }

    private func buildWaveformPath(samples: [Float], size: CGSize, centerY: CGFloat, gain: CGFloat) -> Path {
        let stepX = size.width / CGFloat(samples.count - 1)
        var path = Path()
        for i in 0..<samples.count {
            let x = CGFloat(i) * stepX
            let y = centerY - CGFloat(samples[i]) * gain * centerY
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }

    // MARK: - Info Bar

    private var infoBar: some View {
        HStack(spacing: 12) {
            let nameA = sourceName(audioEngine.scopeSource)
            let peakA = audioEngine.scopeWaveform.reduce(Float(0)) { max($0, abs($1)) }
            HStack(spacing: 4) {
                Circle().fill(scopeGreen).frame(width: 6, height: 6)
                Text("\(nameA)  \(String(format: "%.2f", peakA))")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textMuted)
                    .monospacedDigit()
            }

            if audioEngine.scopeSourceB >= 0 {
                let nameB = sourceName(audioEngine.scopeSourceB)
                let peakB = audioEngine.scopeWaveformB.reduce(Float(0)) { max($0, abs($1)) }
                HStack(spacing: 4) {
                    Circle().fill(scopeCyan).frame(width: 6, height: 6)
                    Text("\(nameB)  \(String(format: "%.2f", peakB))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textMuted)
                        .monospacedDigit()
                }
            }

            Spacer()

            Text("\(timescaleLabel(audioEngine.scopeTimeScale)) / \(gainLabel(audioEngine.scopeGain))")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
    }

    private func sourceName(_ index: Int) -> String {
        guard index >= 0, index < AudioEngineWrapper.scopeSourceNames.count else { return "Off" }
        return AudioEngineWrapper.scopeSourceNames[index]
    }
}

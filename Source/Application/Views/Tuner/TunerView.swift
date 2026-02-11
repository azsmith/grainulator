//
//  TunerView.swift
//  Grainulator
//
//  Chromatic tuner view — displays detected pitch as note name with cents meter.
//  Hosted in a small floating NSPanel.
//

import SwiftUI

// MARK: - Note Utilities

private enum NoteUtils {
    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    static let referenceA4: Float = 440.0

    struct NoteInfo {
        let name: String
        let octave: Int
        let cents: Float
    }

    static func noteFromFrequency(_ freq: Float) -> NoteInfo {
        let semitones = 12.0 * log2(freq / referenceA4)
        let roundedSemitones = roundf(semitones)
        let cents = (semitones - roundedSemitones) * 100.0

        // A4 = MIDI note 69, note index 9 (A) in octave 4
        let midiNote = Int(roundedSemitones) + 69
        let noteIndex = ((midiNote % 12) + 12) % 12
        let octave = (midiNote / 12) - 1

        return NoteInfo(
            name: noteNames[noteIndex],
            octave: octave,
            cents: cents
        )
    }
}

// MARK: - Tuner View

struct TunerView: View {
    @ObservedObject var audioEngine: AudioEngineWrapper

    private let bgColor = Color(red: 0.04, green: 0.04, blue: 0.06)

    var body: some View {
        VStack(spacing: 0) {
            // Source picker
            sourcePickerBar
                .frame(height: 28)
                .background(ColorPalette.backgroundSecondary)

            Rectangle()
                .fill(ColorPalette.divider)
                .frame(height: 1)

            // Main tuner display
            ZStack {
                bgColor

                if audioEngine.tunerFrequency > 0 {
                    activeTunerDisplay
                } else {
                    noSignalDisplay
                }
            }
        }
    }

    // MARK: - Source Picker

    private var sourcePickerBar: some View {
        HStack(spacing: 6) {
            Text("SOURCE")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed)

            Picker("", selection: $audioEngine.tunerSource) {
                Section(header: Text("Voices")) {
                    ForEach(0..<8, id: \.self) { i in
                        Text(AudioEngineWrapper.scopeSourceNames[i]).tag(i)
                    }
                }
                Section(header: Text("Master")) {
                    Text(AudioEngineWrapper.scopeSourceNames[8]).tag(8)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .colorScheme(.dark)
            .frame(maxWidth: 140)

            Spacer()
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Active Tuner Display

    private var activeTunerDisplay: some View {
        let note = NoteUtils.noteFromFrequency(audioEngine.tunerFrequency)
        let absCents = abs(note.cents)
        let deviationColor = absCents <= 5 ? ColorPalette.ledGreen
            : absCents <= 15 ? ColorPalette.ledAmber
            : ColorPalette.ledRed

        return VStack(spacing: 6) {
            Spacer(minLength: 4)

            // Note name
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(note.name)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundColor(deviationColor)
                Text("\(note.octave)")
                    .font(.system(size: 22, weight: .medium, design: .monospaced))
                    .foregroundColor(deviationColor.opacity(0.7))
            }

            // Frequency
            Text(String(format: "%.1f Hz", audioEngine.tunerFrequency))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textSecondary)

            // Cents meter
            CentsMeterView(cents: note.cents)
                .frame(height: 36)
                .padding(.horizontal, 16)

            // Cents readout
            Text(centsString(note.cents))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(deviationColor)

            Spacer(minLength: 4)
        }
    }

    // MARK: - No Signal

    private var noSignalDisplay: some View {
        VStack(spacing: 8) {
            Text("—")
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed.opacity(0.4))
            Text("No pitch detected")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(ColorPalette.textDimmed.opacity(0.5))
        }
    }

    private func centsString(_ cents: Float) -> String {
        if abs(cents) < 1 {
            return "in tune"
        }
        let sign = cents > 0 ? "+" : ""
        return String(format: "%@%.0f cents", sign, cents)
    }
}

// MARK: - Cents Meter View

private struct CentsMeterView: View {
    let cents: Float

    private let meterRange: Float = 50.0
    private let greenZone: Float = 2.0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let centerX = width / 2.0

            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 8)

                // Green center zone
                let greenWidth = max(4, width * CGFloat(greenZone / meterRange))
                RoundedRectangle(cornerRadius: 2)
                    .fill(ColorPalette.ledGreen.opacity(0.2))
                    .frame(width: greenWidth, height: 8)

                // Tick marks
                ForEach([-50, -25, 0, 25, 50], id: \.self) { tick in
                    let x = centerX + CGFloat(Float(tick) / meterRange) * (width / 2.0)
                    Rectangle()
                        .fill(tick == 0 ? Color.white.opacity(0.5) : Color.white.opacity(0.15))
                        .frame(width: tick == 0 ? 1.5 : 1, height: tick == 0 ? 16 : 10)
                        .position(x: x, y: height / 2.0)
                }

                // Tick labels
                ForEach([-50, -25, 25, 50], id: \.self) { tick in
                    let x = centerX + CGFloat(Float(tick) / meterRange) * (width / 2.0)
                    Text("\(tick)")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.2))
                        .position(x: x, y: height - 2)
                }

                // Indicator needle
                let clampedCents = max(-meterRange, min(meterRange, cents))
                let indicatorX = centerX + CGFloat(clampedCents / meterRange) * (width / 2.0)
                let absCents = abs(cents)
                let indicatorColor = absCents <= 5 ? ColorPalette.ledGreen
                    : absCents <= 15 ? ColorPalette.ledAmber
                    : ColorPalette.ledRed

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(indicatorColor)
                    .frame(width: 3, height: 18)
                    .shadow(color: indicatorColor.opacity(0.6), radius: 4)
                    .position(x: indicatorX, y: height / 2.0 - 2)
                    .animation(.easeOut(duration: 0.08), value: clampedCents)
            }
        }
    }
}

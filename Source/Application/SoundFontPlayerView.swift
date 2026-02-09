//
//  SoundFontPlayerView.swift
//  Grainulator
//
//  Sample player UI component supporting both SoundFont (.sf2) and
//  mx.samples WAV instruments. Minimoog-inspired knob-focused panel
//  with source picker, library browser, preset selector, and synth controls.
//

import SwiftUI
import AppKit

struct SoundFontPlayerView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @Binding var showLibraryBrowser: Bool

    @State private var attack: Float = 0.0
    @State private var decay: Float = 0.0
    @State private var sustain: Float = 1.0
    @State private var release: Float = 0.1
    @State private var filterCutoff: Float = 1.0
    @State private var filterResonance: Float = 0.0
    @State private var tuning: Float = 0.5  // 0.5 = center = 0 semitones
    @State private var level: Float = 0.8

    var body: some View {
        SynthPanelView(
            title: "SAMPLER",
            accentColor: ColorPalette.accentSampler,
            width: 300
        ) {
            VStack(spacing: 6) {
                modeToggle
                sourcePickerSection
                presetOrInstrumentSection

                SynthPanelSectionLabel("ENVELOPE", accentColor: ColorPalette.accentSampler)

                envelopeKnobs

                SynthPanelSectionLabel("FILTER", accentColor: ColorPalette.synthPanelLabelDim)

                filterKnobs

                SynthPanelSectionLabel("OUTPUT", accentColor: ColorPalette.synthPanelLabelDim)

                outputKnobs
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton("SF2", mode: .soundFont)
            modeButton("SFZ", mode: .sfz)
            modeButton("WAV", mode: .wavSampler)
        }
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.black.opacity(0.3))
        )
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .padding(.horizontal, 4)
    }

    private func modeButton(_ label: String, mode: AudioEngineWrapper.SamplerMode) -> some View {
        let isActive = audioEngine.activeSamplerMode == mode
        return Button(action: { audioEngine.setSamplerMode(mode) }) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(isActive ? ColorPalette.synthPanelSurface : ColorPalette.synthPanelLabel)
                .tracking(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(isActive ? ColorPalette.accentSampler : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Source Picker

    private var sourcePickerSection: some View {
        VStack(spacing: 4) {
            switch audioEngine.activeSamplerMode {
            case .soundFont:
                Button(action: openSoundFontFile) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 9))
                            .foregroundColor(ColorPalette.accentSampler)
                        Text(audioEngine.soundFontLoaded
                             ? (audioEngine.soundFontFilePath?.lastPathComponent ?? "Loaded")
                             : "Load SF2...")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(ColorPalette.synthPanelLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(ColorPalette.synthPanelDivider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

            case .sfz:
                Button(action: openSfzFile) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 9))
                            .foregroundColor(ColorPalette.accentSampler)
                        Text(audioEngine.sfzLoaded
                             ? (audioEngine.sfzFilePath?.lastPathComponent ?? "Loaded")
                             : "Open SFZ...")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(ColorPalette.synthPanelLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(ColorPalette.synthPanelDivider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

            case .wavSampler:
                Button(action: { showLibraryBrowser = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 9))
                            .foregroundColor(ColorPalette.accentSampler)
                        Text(audioEngine.wavSamplerLoaded
                             ? audioEngine.wavSamplerInstrumentName
                             : "Browse Library...")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(ColorPalette.synthPanelLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(ColorPalette.synthPanelDivider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Preset / Instrument Display

    private var presetOrInstrumentSection: some View {
        Group {
            switch audioEngine.activeSamplerMode {
            case .soundFont:
                presetSelector
            case .sfz:
                sfzInstrumentDisplay
            case .wavSampler:
                wavInstrumentDisplay
            }
        }
        .padding(.horizontal, 4)
    }

    private var presetSelector: some View {
        Group {
            if audioEngine.soundFontLoaded && !audioEngine.soundFontPresetNames.isEmpty {
                Menu {
                    ForEach(0..<audioEngine.soundFontPresetNames.count, id: \.self) { index in
                        Button(action: {
                            audioEngine.setSamplerPreset(index)
                        }) {
                            HStack {
                                Text("\(index): \(audioEngine.soundFontPresetNames[index])")
                                if audioEngine.soundFontCurrentPreset == index {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(presetDisplayName)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(ColorPalette.synthPanelLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(ColorPalette.accentSampler)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(ColorPalette.synthPanelDivider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Text("No SoundFont loaded")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.synthPanelLabelDim)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var sfzInstrumentDisplay: some View {
        VStack(spacing: 2) {
            if audioEngine.sfzLoaded {
                Text(audioEngine.sfzInstrumentName)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.synthPanelLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.3))
                    )
                Text("Per-region envelopes from SFZ take priority")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundColor(ColorPalette.synthPanelLabelDim)
            } else {
                Text("No SFZ loaded")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.synthPanelLabelDim)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var wavInstrumentDisplay: some View {
        Group {
            if audioEngine.wavSamplerLoaded {
                Text(audioEngine.wavSamplerInstrumentName)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorPalette.synthPanelLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.3))
                    )
            } else {
                Text("No instrument loaded")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.synthPanelLabelDim)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Envelope Knobs (ADSR)

    private var envelopeKnobs: some View {
        HStack(spacing: 10) {
            ProKnobView(
                value: $attack,
                label: "ATTACK",
                accentColor: ColorPalette.accentSampler,
                size: .medium,
                style: .minimoog
            )
            ProKnobView(
                value: $decay,
                label: "DECAY",
                accentColor: ColorPalette.accentSampler,
                size: .medium,
                style: .minimoog
            )
            ProKnobView(
                value: $sustain,
                label: "SUSTN",
                accentColor: ColorPalette.accentSampler,
                size: .medium,
                style: .minimoog
            )
            ProKnobView(
                value: $release,
                label: "RELEASE",
                accentColor: ColorPalette.accentSampler,
                size: .medium,
                style: .minimoog
            )
        }
        .onChange(of: attack) { audioEngine.setParameter(id: .samplerAttack, value: $0) }
        .onChange(of: decay) { audioEngine.setParameter(id: .samplerDecay, value: $0) }
        .onChange(of: sustain) { audioEngine.setParameter(id: .samplerSustain, value: $0) }
        .onChange(of: release) { audioEngine.setParameter(id: .samplerRelease, value: $0) }
    }

    // MARK: - Filter Knobs

    private var filterKnobs: some View {
        HStack(spacing: 16) {
            ProKnobView.frequency(
                value: $filterCutoff,
                label: "CUTOFF",
                accentColor: ColorPalette.accentSampler,
                size: .medium,
                style: .minimoog
            )
            ProKnobView(
                value: $filterResonance,
                label: "RESON",
                accentColor: ColorPalette.accentSampler,
                size: .medium,
                style: .minimoog,
                valueFormatter: { String(format: "%.0f%%", $0 * 100) }
            )
        }
        .onChange(of: filterCutoff) { audioEngine.setParameter(id: .samplerFilterCutoff, value: $0) }
        .onChange(of: filterResonance) { audioEngine.setParameter(id: .samplerFilterResonance, value: $0) }
    }

    // MARK: - Output Knobs

    private var outputKnobs: some View {
        HStack(spacing: 16) {
            ProKnobView.bipolar(
                value: $tuning,
                label: "TUNE",
                accentColor: ColorPalette.accentSampler,
                size: .medium,
                style: .minimoog
            )
            ProKnobView(
                value: $level,
                label: "LEVEL",
                accentColor: ColorPalette.accentSampler,
                size: .medium,
                style: .minimoog,
                valueFormatter: { String(format: "%.0f%%", $0 * 100) }
            )
        }
        .onChange(of: tuning) { audioEngine.setParameter(id: .samplerTuning, value: $0) }
        .onChange(of: level) { audioEngine.setParameter(id: .samplerLevel, value: $0) }
    }

    // MARK: - Helpers

    private var presetDisplayName: String {
        let idx = audioEngine.soundFontCurrentPreset
        if idx < audioEngine.soundFontPresetNames.count {
            return "\(idx): \(audioEngine.soundFontPresetNames[idx])"
        }
        return "—"
    }

    private func openSoundFontFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "sf2")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open SoundFont File"

        if panel.runModal() == .OK, let url = panel.url {
            audioEngine.loadSoundFont(url: url)
        }
    }

    private func openSfzFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "sfz")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open SFZ Instrument"

        if panel.runModal() == .OK, let url = panel.url {
            audioEngine.loadSfzFile(url: url)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SoundFontPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        SoundFontPlayerView(showLibraryBrowser: .constant(false))
            .environmentObject(AudioEngineWrapper())
            .padding(20)
            .background(ColorPalette.backgroundPrimary)
    }
}
#endif

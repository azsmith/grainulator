//
//  SoundFontPlayerView.swift
//  Grainulator
//
//  Sample player UI component supporting both SoundFont (.sf2) and
//  mx.samples WAV instruments. Vertical eurorack-style module with
//  source picker, library browser, preset selector, and synth controls.
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
        EurorackModuleView(
            title: "SAMPLER",
            accentColor: ColorPalette.accentSampler,
            width: 220
        ) {
            samplerContent
        }
    }

    private var samplerContent: some View {
        VStack(spacing: 10) {
            modeToggle
            sourcePickerSection
            presetOrInstrumentSection
            envelopeSliders
            filterSliders
            outputSliders
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton("SF2", mode: .soundFont)
            modeButton("WAV", mode: .wavSampler)
        }
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(ColorPalette.backgroundTertiary)
        )
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func modeButton(_ label: String, mode: AudioEngineWrapper.SamplerMode) -> some View {
        let isActive = audioEngine.activeSamplerMode == mode
        return Button(action: { audioEngine.setSamplerMode(mode) }) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(isActive ? .black : ColorPalette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(isActive ? ColorPalette.accentSampler : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Source Picker

    private var sourcePickerSection: some View {
        VStack(spacing: 4) {
            if audioEngine.activeSamplerMode == .soundFont {
                // SF2 file picker
                Button(action: openSoundFontFile) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 9))
                            .foregroundColor(ColorPalette.accentSampler)
                        Text(audioEngine.soundFontLoaded
                             ? (audioEngine.soundFontFilePath?.lastPathComponent ?? "Loaded")
                             : "Load SF2...")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.backgroundTertiary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(ColorPalette.accentSampler.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                // WAV library browser
                Button(action: { showLibraryBrowser = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 9))
                            .foregroundColor(ColorPalette.accentSampler)
                        Text(audioEngine.wavSamplerLoaded
                             ? audioEngine.wavSamplerInstrumentName
                             : "Browse Library...")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.backgroundTertiary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(ColorPalette.accentSampler.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Preset / Instrument Display

    private var presetOrInstrumentSection: some View {
        Group {
            if audioEngine.activeSamplerMode == .soundFont {
                presetSelector
            } else {
                wavInstrumentDisplay
            }
        }
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
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                            .foregroundColor(ColorPalette.accentSampler)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.backgroundTertiary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(ColorPalette.accentSampler.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Text("No SoundFont loaded")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var wavInstrumentDisplay: some View {
        Group {
            if audioEngine.wavSamplerLoaded {
                Text(audioEngine.wavSamplerInstrumentName)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.backgroundTertiary)
                    )
            } else {
                Text("No instrument loaded")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Envelope Sliders

    private var envelopeSliders: some View {
        SliderBankView(
                parameters: [
                    SliderParameter(
                        label: "ATK",
                        value: $attack,
                        accentColor: ColorPalette.accentSampler
                    ),
                    SliderParameter(
                        label: "DCY",
                        value: $decay,
                        accentColor: ColorPalette.accentSampler
                    ),
                    SliderParameter(
                        label: "SUS",
                        value: $sustain,
                        accentColor: ColorPalette.accentSampler
                    ),
                    SliderParameter(
                        label: "REL",
                        value: $release,
                        accentColor: ColorPalette.accentSampler
                    )
                ],
                sliderHeight: 70,
                sliderWidth: 20
            )
            .onChange(of: attack) { audioEngine.setParameter(id: .samplerAttack, value: $0) }
        .onChange(of: decay) { audioEngine.setParameter(id: .samplerDecay, value: $0) }
        .onChange(of: sustain) { audioEngine.setParameter(id: .samplerSustain, value: $0) }
        .onChange(of: release) { audioEngine.setParameter(id: .samplerRelease, value: $0) }
    }

    // MARK: - Filter Sliders

    private var filterSliders: some View {
        SliderBankView(
            parameters: [
                SliderParameter(
                    label: "CUT",
                    value: $filterCutoff,
                    accentColor: ColorPalette.accentSampler
                ),
                SliderParameter(
                    label: "RES",
                    value: $filterResonance,
                    accentColor: ColorPalette.accentSampler
                )
            ],
            sliderHeight: 70,
            sliderWidth: 20
        )
        .onChange(of: filterCutoff) { audioEngine.setParameter(id: .samplerFilterCutoff, value: $0) }
        .onChange(of: filterResonance) { audioEngine.setParameter(id: .samplerFilterResonance, value: $0) }
    }

    // MARK: - Output Sliders

    private var outputSliders: some View {
        SliderBankView(
            parameters: [
                SliderParameter(
                    label: "TUNE",
                    value: $tuning,
                    accentColor: ColorPalette.accentSampler
                ),
                SliderParameter(
                    label: "LVL",
                    value: $level,
                    accentColor: ColorPalette.accentSampler
                )
            ],
            sliderHeight: 70,
            sliderWidth: 20
        )
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

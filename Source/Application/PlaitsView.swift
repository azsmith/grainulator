//
//  PlaitsView.swift
//  Grainulator
//
//  Plaits synthesizer UI component
//  Minimoog-inspired knob-focused panel layout.
//

import SwiftUI
import UniformTypeIdentifiers

struct PlaitsView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @EnvironmentObject var midiManager: MIDIManager

    @State private var selectedEngine: Int = 0  // Virtual Analog
    @State private var harmonics: Float = 0.35
    @State private var timbre: Float = 0.31
    @State private var morph: Float = 0.51
    @State private var level: Float = 0.8
    @State private var isTriggered: Bool = false

    // LPG parameters
    @State private var lpgColor: Float = 0.0
    @State private var lpgAttack: Float = 0.0
    @State private var lpgDecay: Float = 0.5
    @State private var lpgBypass: Bool = false

    // Modulation amounts (updated via timer)
    @State private var harmonicsMod: Float = 0.0
    @State private var timbreMod: Float = 0.0
    @State private var morphMod: Float = 0.0
    @State private var showWavetableFilePicker = false
    @State private var showSixOpBankFilePicker = false

    // Timer for polling modulation values
    let modulationTimer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()

    private struct EngineDescriptor {
        let name: String
        let internalIndex: Int
        let labels: [String]
        let usesLPG: Bool
        let isSixOpCustom: Bool
    }

    // Hardware-first ordering in the UI:
    // classic synth voices, then percussion, then alternate firmware engines.
    private let engines: [EngineDescriptor] = [
        EngineDescriptor(name: "Virtual Analog", internalIndex: 8, labels: ["DETUNE", "PULSE", "SAW"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "Waveshaper", internalIndex: 9, labels: ["SHAPE", "FOLD", "ASYM"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "Two-Op FM", internalIndex: 10, labels: ["RATIO", "MOD", "FDBK"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "Granular Formant", internalIndex: 11, labels: ["FORMANT", "FREQ", "WIDTH"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "Harmonic", internalIndex: 12, labels: ["BUMPS", "BRIGHT", "WIDTH"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "Wavetable", internalIndex: 13, labels: ["BANK", "ROW", "COLUMN"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "Chords", internalIndex: 14, labels: ["CHORD", "INVERT", "WAVE"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "Speech", internalIndex: 15, labels: ["TYPE", "SPEC", "PHONEM"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "Granular Cloud", internalIndex: 16, labels: ["PITCH", "DENS", "DUR"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "Filtered Noise", internalIndex: 17, labels: ["FILTER", "CLOCK", "RES"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "Particle Noise", internalIndex: 18, labels: ["FREQ", "DENS", "FILTER"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "String", internalIndex: 19, labels: ["INHARM", "BRIGHT", "DECAY"], usesLPG: false, isSixOpCustom: false),
        EngineDescriptor(name: "Modal", internalIndex: 20, labels: ["INHARM", "BRIGHT", "DECAY"], usesLPG: false, isSixOpCustom: false),
        EngineDescriptor(name: "Bass Drum", internalIndex: 21, labels: ["PUNCH", "TONE", "DECAY"], usesLPG: false, isSixOpCustom: false),
        EngineDescriptor(name: "Snare Drum", internalIndex: 22, labels: ["SNARE", "TONE", "DECAY"], usesLPG: false, isSixOpCustom: false),
        EngineDescriptor(name: "Hi-Hat", internalIndex: 23, labels: ["METAL", "OPEN", "DECAY"], usesLPG: false, isSixOpCustom: false),
        EngineDescriptor(name: "VA VCF", internalIndex: 0, labels: ["COLOR", "CUTOFF", "SHAPE"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "Phase Dist", internalIndex: 1, labels: ["INDEX", "AMOUNT", "PW"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "Six-Op FM A", internalIndex: 2, labels: ["PATCH", "BRIGHT", "ENV"], usesLPG: false, isSixOpCustom: false),
        EngineDescriptor(name: "Six-Op FM B", internalIndex: 3, labels: ["PATCH", "BRIGHT", "ENV"], usesLPG: false, isSixOpCustom: false),
        EngineDescriptor(name: "Six-Op FM C", internalIndex: 4, labels: ["PATCH", "BRIGHT", "ENV"], usesLPG: false, isSixOpCustom: false),
        EngineDescriptor(name: "Six-Op FM Custom", internalIndex: 2, labels: ["PATCH", "BRIGHT", "ENV"], usesLPG: false, isSixOpCustom: true),
        EngineDescriptor(name: "Wave Terrain", internalIndex: 5, labels: ["TERRAIN", "RADIUS", "OFFSET"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "String Machine", internalIndex: 6, labels: ["CHORD", "TONE", "REG"], usesLPG: true, isSixOpCustom: false),
        EngineDescriptor(name: "Chiptune", internalIndex: 7, labels: ["CHORD", "ARP", "SHAPE"], usesLPG: true, isSixOpCustom: false),
    ]

    private var selectedEngineDescriptor: EngineDescriptor {
        engines.indices.contains(selectedEngine) ? engines[selectedEngine] : engines[0]
    }

    var usesLPG: Bool {
        selectedEngineDescriptor.usesLPG
    }

    var body: some View {
        SynthPanelView(
            title: "MACRO OSC",
            accentColor: ColorPalette.accentPlaits,
            width: 300
        ) {
            VStack(spacing: 6) {
                // Engine selector + MIDI indicator
                headerSection

                SynthPanelSectionLabel("OSCILLATOR", accentColor: ColorPalette.accentPlaits)

                // Main parameter knobs: 2x2 grid
                oscillatorKnobs

                SynthPanelSectionLabel(
                    "LPG",
                    accentColor: usesLPG ? ColorPalette.synthPanelLabelDim : ColorPalette.textDimmed
                )

                // LPG knobs + bypass
                lpgSection
                    .opacity(usesLPG ? 1.0 : 0.35)

                // Load wavetable button (only shown for Wavetable engine)
                if selectedEngineDescriptor.internalIndex == 13 {
                    loadWavetableButton
                        .padding(.horizontal, 16)
                }

                if selectedEngineDescriptor.isSixOpCustom {
                    sixOpCustomSection
                        .padding(.horizontal, 16)
                }

                // Trigger button
                triggerButton
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            syncToEngine()
        }
        .onReceive(modulationTimer) { _ in
            // Poll modulation values from audio engine
            harmonicsMod = audioEngine.getModulationValue(destination: .plaitsHarmonics)
            timbreMod = audioEngine.getModulationValue(destination: .plaitsTimbre)
            morphMod = audioEngine.getModulationValue(destination: .plaitsMorph)

            // Sync engine mode (may be changed externally via API)
            let rawModel = audioEngine.getParameter(id: .plaitsModel)
            guard rawModel.isFinite else { return }
            let internalEngineIndex = Int(round(rawModel * 23.0))
            if internalEngineIndex == 2 && audioEngine.plaitsSixOpCustomEnabled {
                if let customIndex = engines.firstIndex(where: { $0.isSixOpCustom }),
                   customIndex != selectedEngine {
                    selectedEngine = customIndex
                }
            } else if let orderedIndex = engines.firstIndex(where: {
                $0.internalIndex == internalEngineIndex && !$0.isSixOpCustom
            }), orderedIndex != selectedEngine {
                selectedEngine = orderedIndex
            }
        }
        .onChange(of: audioEngine.plaitsSixOpCustomSelectedPatch) { patch in
            if selectedEngineDescriptor.isSixOpCustom {
                harmonics = Float(max(0, min(31, patch))) / 31.0
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 8) {
            // Engine selector
            Menu {
                ForEach(0..<engines.count, id: \.self) { index in
                    Button(action: {
                        selectEngine(index)
                    }) {
                        HStack {
                            Text(engines[index].name)
                            if selectedEngine == index {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedEngineDescriptor.name)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.synthPanelLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(ColorPalette.accentPlaits)
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

            // MIDI indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(midiManager.isEnabled ? ColorPalette.ledGreen : ColorPalette.ledOff)
                    .frame(width: 6, height: 6)
                    .shadow(color: midiManager.isEnabled ? ColorPalette.ledGreenGlow.opacity(0.5) : .clear, radius: 3)

                if midiManager.lastNote > 0 {
                    Text(noteToName(Int(midiManager.lastNote)))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.accentPlaits)
                } else {
                    Text("MIDI")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorPalette.textDimmed)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Oscillator Knobs (2x2 grid)

    private var oscillatorKnobs: some View {
        VStack(spacing: 4) {
            // Top row: param1 + param2
            HStack(spacing: 16) {
                ProKnobView(
                    value: $harmonics,
                    label: selectedEngineDescriptor.labels[0],
                    accentColor: ColorPalette.accentPlaits,
                    size: .large,
                    style: .minimoog,
                    modulationValue: harmonicsMod > 0.001 ? harmonics + harmonicsMod : nil
                )
                ProKnobView(
                    value: $timbre,
                    label: selectedEngineDescriptor.labels[1],
                    accentColor: ColorPalette.accentPlaits,
                    size: .large,
                    style: .minimoog,
                    modulationValue: timbreMod > 0.001 ? timbre + timbreMod : nil
                )
            }

            // Bottom row: param3 + level
            HStack(spacing: 16) {
                ProKnobView(
                    value: $morph,
                    label: selectedEngineDescriptor.labels[2],
                    accentColor: ColorPalette.accentPlaits,
                    size: .large,
                    style: .minimoog,
                    modulationValue: morphMod > 0.001 ? morph + morphMod : nil
                )
                ProKnobView(
                    value: $level,
                    label: "LEVEL",
                    accentColor: ColorPalette.accentPlaits,
                    size: .large,
                    style: .minimoog,
                    valueFormatter: { String(format: "%.0f%%", $0 * 100) }
                )
            }
        }
        .padding(.horizontal, 12)
        .onChange(of: harmonics) { applyHarmonics($0) }
        .onChange(of: timbre) { audioEngine.setParameter(id: .plaitsTimbre, value: $0) }
        .onChange(of: morph) { audioEngine.setParameter(id: .plaitsMorph, value: $0) }
        .onChange(of: level) { audioEngine.setParameter(id: .plaitsLevel, value: $0) }
    }

    // MARK: - LPG Section

    private var lpgSection: some View {
        HStack(spacing: 12) {
            ProKnobView(
                value: $lpgAttack,
                label: "ATTACK",
                accentColor: ColorPalette.accentLooper1,
                size: .medium,
                style: .minimoog
            )
            ProKnobView(
                value: $lpgDecay,
                label: "DECAY",
                accentColor: ColorPalette.accentLooper1,
                size: .medium,
                style: .minimoog
            )
            ProKnobView(
                value: $lpgColor,
                label: "COLOR",
                accentColor: ColorPalette.ledAmber,
                size: .medium,
                style: .minimoog
            )

            // Bypass toggle
            VStack(spacing: 4) {
                Button(action: {
                    lpgBypass.toggle()
                    audioEngine.setParameter(id: .plaitsLPGBypass, value: lpgBypass ? 1.0 : 0.0)
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(lpgBypass ? ColorPalette.ledAmber : ColorPalette.ledOff)
                            .frame(width: 24, height: 24)

                        if lpgBypass {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(ColorPalette.backgroundPrimary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .shadow(color: lpgBypass ? ColorPalette.ledAmberGlow.opacity(0.4) : .clear, radius: 4)

                Text("BYP")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(lpgBypass ? ColorPalette.ledAmber : ColorPalette.textDimmed)
                    .tracking(1)
            }
        }
        .padding(.horizontal, 14)
        .onChange(of: lpgAttack) { audioEngine.setParameter(id: .plaitsLPGAttack, value: $0) }
        .onChange(of: lpgDecay) { audioEngine.setParameter(id: .plaitsLPGDecay, value: $0) }
        .onChange(of: lpgColor) { audioEngine.setParameter(id: .plaitsLPGColor, value: $0) }
    }

    // MARK: - Load Wavetable Button

    private var loadWavetableButton: some View {
        Button(action: {
            showWavetableFilePicker = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 10, weight: .bold))
                Text("LOAD WAVETABLE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundColor(ColorPalette.synthPanelLabel)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
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
        .fileImporter(
            isPresented: $showWavetableFilePicker,
            allowedContentTypes: [.wav, .aiff, .audio],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                audioEngine.loadUserWavetable(url: url)
                // Switch to user bank (harmonics ~0.9)
                harmonics = 0.9
                audioEngine.setParameter(id: .plaitsHarmonics, value: 0.9)
            }
        }
    }

    // MARK: - Six-Op Custom Controls

    private var sixOpPatchNames: [String] {
        if audioEngine.plaitsSixOpCustomPatchNames.isEmpty {
            return (1...32).map { "Patch \($0)" }
        }
        return audioEngine.plaitsSixOpCustomPatchNames
    }

    private var sixOpCustomSection: some View {
        VStack(spacing: 6) {
            Button(action: {
                showSixOpBankFilePicker = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(audioEngine.plaitsSixOpCustomLoaded ? "RELOAD DX7 BANK" : "LOAD DX7 BANK")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundColor(ColorPalette.synthPanelLabel)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
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
            .fileImporter(
                isPresented: $showSixOpBankFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "syx") ?? .data, .data],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    audioEngine.loadPlaitsSixOpCustomBank(url: url)
                }
            }

            Menu {
                ForEach(Array(sixOpPatchNames.enumerated()), id: \.offset) { index, name in
                    Button(action: {
                        audioEngine.setPlaitsSixOpCustomPatch(index)
                        harmonics = Float(index) / 31.0
                    }) {
                        HStack {
                            Text("\(index + 1). \(name)")
                            if audioEngine.plaitsSixOpCustomSelectedPatch == index {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                let safePatchIndex = max(0, min(sixOpPatchNames.count - 1, audioEngine.plaitsSixOpCustomSelectedPatch))
                HStack(spacing: 6) {
                    Text("PATCH \(safePatchIndex + 1): \(sixOpPatchNames[safePatchIndex])")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.synthPanelLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(ColorPalette.accentPlaits)
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
            .disabled(!audioEngine.plaitsSixOpCustomLoaded)
            .opacity(audioEngine.plaitsSixOpCustomLoaded ? 1.0 : 0.5)
        }
    }

    // MARK: - Trigger Button

    private var triggerButton: some View {
        Button(action: {
            isTriggered = true
            audioEngine.triggerPlaits(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                isTriggered = false
                audioEngine.triggerPlaits(false)
            }
        }) {
            Text(isTriggered ? "TRIG" : "TRIGGER")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(isTriggered ? ColorPalette.synthPanelSurface : ColorPalette.synthPanelLabel)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isTriggered ? ColorPalette.accentPlaits : Color.black.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isTriggered ? ColorPalette.accentPlaits : ColorPalette.synthPanelDivider,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .shadow(color: isTriggered ? ColorPalette.accentPlaits.opacity(0.4) : .clear, radius: 6)
    }

    // MARK: - Helpers

    private func noteToName(_ midiNote: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midiNote / 12) - 1
        let noteName = noteNames[midiNote % 12]
        return "\(noteName)\(octave)"
    }

    private func applyHarmonics(_ value: Float) {
        if selectedEngineDescriptor.isSixOpCustom {
            let patchIndex = max(0, min(31, Int(value * 31.0 + 0.5)))
            let snapped = Float(patchIndex) / 31.0
            if abs(snapped - harmonics) > 0.0001 {
                harmonics = snapped
                return
            }
            audioEngine.setPlaitsSixOpCustomPatch(patchIndex)
            return
        }
        audioEngine.setParameter(id: .plaitsHarmonics, value: value)
    }

    private func selectEngine(_ index: Int) {
        guard engines.indices.contains(index) else { return }
        selectedEngine = index
        let descriptor = engines[index]
        if descriptor.isSixOpCustom {
            audioEngine.setPlaitsSixOpCustomMode(true)
            audioEngine.setParameter(id: .plaitsModel, value: Float(descriptor.internalIndex) / 23.0)
            audioEngine.setPlaitsSixOpCustomPatch(audioEngine.plaitsSixOpCustomSelectedPatch)
            harmonics = Float(audioEngine.plaitsSixOpCustomSelectedPatch) / 31.0
        } else {
            if audioEngine.plaitsSixOpCustomEnabled {
                audioEngine.setPlaitsSixOpCustomMode(false)
            }
            audioEngine.setParameter(id: .plaitsModel, value: Float(descriptor.internalIndex) / 23.0)
        }
    }

    private func syncToEngine() {
        if !engines.indices.contains(selectedEngine) {
            selectedEngine = 0
        }
        selectEngine(selectedEngine)
        applyHarmonics(harmonics)
        audioEngine.setParameter(id: .plaitsTimbre, value: timbre)
        audioEngine.setParameter(id: .plaitsMorph, value: morph)
        audioEngine.setParameter(id: .plaitsLevel, value: level)
        audioEngine.setParameter(id: .plaitsLPGAttack, value: lpgAttack)
        audioEngine.setParameter(id: .plaitsLPGDecay, value: lpgDecay)
        audioEngine.setParameter(id: .plaitsLPGColor, value: lpgColor)
        audioEngine.setParameter(id: .plaitsLPGBypass, value: lpgBypass ? 1.0 : 0.0)
    }
}

// MARK: - Preview

#if DEBUG
struct PlaitsView_Previews: PreviewProvider {
    static var previews: some View {
        PlaitsView()
            .environmentObject(AudioEngineWrapper())
            .environmentObject(MIDIManager())
            .padding(20)
            .background(ColorPalette.backgroundPrimary)
    }
}
#endif

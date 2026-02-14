//
//  MasterCompressorView.swift
//  Grainulator
//
//  Popover UI for the master bus compressor/limiter
//

import SwiftUI

struct MasterCompressorView: View {
    @ObservedObject var master: MasterChannelState
    let audioEngine: AudioEngineWrapper

    var body: some View {
        VStack(spacing: 12) {
            header
            Divider().background(ColorPalette.divider)
            knobsRow1
            knobsRow2
            Divider().background(ColorPalette.divider)
            gainReductionMeter
            togglesRow
        }
        .padding(14)
        .background(ColorPalette.backgroundSecondary)
        .onChange(of: master.compThreshold) { v in
            audioEngine.setParameter(id: .masterCompThreshold, value: v)
        }
        .onChange(of: master.compRatio) { v in
            audioEngine.setParameter(id: .masterCompRatio, value: v)
        }
        .onChange(of: master.compAttack) { v in
            audioEngine.setParameter(id: .masterCompAttack, value: v)
        }
        .onChange(of: master.compRelease) { v in
            audioEngine.setParameter(id: .masterCompRelease, value: v)
        }
        .onChange(of: master.compKnee) { v in
            audioEngine.setParameter(id: .masterCompKnee, value: v)
        }
        .onChange(of: master.compMakeup) { v in
            audioEngine.setParameter(id: .masterCompMakeup, value: v)
        }
        .onChange(of: master.compMix) { v in
            audioEngine.setParameter(id: .masterCompMix, value: v)
        }
        .onChange(of: master.compEnabled) { v in
            audioEngine.setParameter(id: .masterCompEnabled, value: v ? 1.0 : 0.0)
        }
        .onChange(of: master.compLimiter) { v in
            audioEngine.setParameter(id: .masterCompLimiter, value: v ? 1.0 : 0.0)
        }
        .onChange(of: master.compAutoMakeup) { v in
            audioEngine.setParameter(id: .masterCompAutoMakeup, value: v ? 1.0 : 0.0)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("COMPRESSOR")
                .font(Typography.sectionHeader.weight(.bold))
                .foregroundColor(ColorPalette.accentMaster)

            Spacer()

            // Enable/bypass toggle
            Button(action: { master.compEnabled.toggle() }) {
                Text(master.compEnabled ? "ON" : "OFF")
                    .font(Typography.buttonSmall)
                    .foregroundColor(master.compEnabled ? .black : ColorPalette.textMuted)
                    .frame(width: 36, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(master.compEnabled ? ColorPalette.accentMaster : ColorPalette.ledOff)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Knobs Row 1: Threshold, Ratio, Attack

    private var knobsRow1: some View {
        HStack(spacing: 16) {
            // Threshold: 0-1 → -60..0 dB
            ProKnobView(
                value: $master.compThreshold,
                label: "THRESH",
                accentColor: ColorPalette.accentMaster,
                size: .medium,
                valueFormatter: { v in
                    let db = -60.0 + Double(v) * 60.0
                    return String(format: "%.0f", db)
                }
            )

            // Ratio: 0-1 → 1:1..20:1
            ProKnobView(
                value: $master.compRatio,
                label: "RATIO",
                accentColor: ColorPalette.accentMaster,
                size: .medium,
                valueFormatter: { v in
                    let ratio = 1.0 + Double(v) * 19.0
                    if ratio >= 19.5 { return "∞:1" }
                    if ratio >= 10.0 { return String(format: "%.0f:1", ratio) }
                    return String(format: "%.1f:1", ratio)
                }
            )

            // Attack: 0-1 → 0.1..100 ms (log)
            ProKnobView(
                value: $master.compAttack,
                label: "ATK",
                accentColor: ColorPalette.accentMaster,
                size: .medium,
                valueFormatter: { v in
                    let ms = 0.1 * pow(1000.0, Double(v))
                    if ms >= 10.0 { return String(format: "%.0f", ms) }
                    return String(format: "%.1f", ms)
                }
            )
        }
    }

    // MARK: - Knobs Row 2: Release, Knee, Makeup, Mix

    private var knobsRow2: some View {
        HStack(spacing: 16) {
            // Release: 0-1 → 10..1000 ms (log)
            ProKnobView(
                value: $master.compRelease,
                label: "REL",
                accentColor: ColorPalette.accentMaster,
                size: .medium,
                valueFormatter: { v in
                    let ms = 10.0 * pow(100.0, Double(v))
                    if ms >= 100.0 { return String(format: "%.0f", ms) }
                    return String(format: "%.0f", ms)
                }
            )

            // Knee: 0-1 → 0..12 dB
            ProKnobView(
                value: $master.compKnee,
                label: "KNEE",
                accentColor: ColorPalette.accentMaster,
                size: .medium,
                valueFormatter: { v in
                    let db = Double(v) * 12.0
                    return String(format: "%.0f", db)
                }
            )

            // Makeup gain: 0-1 → 0..40 dB
            ProKnobView(
                value: $master.compMakeup,
                label: "GAIN",
                accentColor: ColorPalette.accentMaster,
                size: .medium,
                valueFormatter: { v in
                    let db = Double(v) * 40.0
                    if db < 0.5 { return "0" }
                    return String(format: "+%.0f", db)
                }
            )

            // Mix (parallel compression): 0-1 → 0..100%
            ProKnobView(
                value: $master.compMix,
                label: "MIX",
                accentColor: ColorPalette.accentMaster,
                size: .medium,
                valueFormatter: { v in
                    String(format: "%.0f%%", Double(v) * 100.0)
                }
            )
        }
    }

    // MARK: - Gain Reduction Meter

    private var gainReductionMeter: some View {
        VStack(spacing: 3) {
            Text("GR")
                .font(Typography.parameterLabel)
                .foregroundColor(ColorPalette.textMuted)

            GeometryReader { geo in
                ZStack(alignment: .trailing) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorPalette.backgroundPrimary)

                    // GR bar (grows from right to left)
                    let grNorm = min(master.compGainReduction / 24.0, 1.0)
                    if grNorm > 0.005 {
                        HStack(spacing: 0) {
                            Spacer()
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [ColorPalette.ledAmber, ColorPalette.ledRed],
                                        startPoint: .trailing,
                                        endPoint: .leading
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(grNorm))
                        }
                    }

                    // Value readout
                    Text(String(format: "-%.1f dB", master.compGainReduction))
                        .font(Typography.valueTiny)
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(height: 18)
        }
    }

    // MARK: - Toggles Row

    private var togglesRow: some View {
        HStack(spacing: 12) {
            compactToggle(label: "LIMIT", isOn: $master.compLimiter)
            compactToggle(label: "AUTO", isOn: $master.compAutoMakeup)
        }
    }

    private func compactToggle(label: String, isOn: Binding<Bool>) -> some View {
        Button(action: { isOn.wrappedValue.toggle() }) {
            Text(label)
                .font(Typography.buttonSmall)
                .foregroundColor(isOn.wrappedValue ? .black : ColorPalette.textMuted)
                .frame(width: 44, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isOn.wrappedValue ? ColorPalette.ledGreen : ColorPalette.ledOff)
                )
        }
        .buttonStyle(.plain)
    }
}

//
//  ProMasterStripView.swift
//  Grainulator
//
//  Master channel strip with stereo VU meters and effects returns
//

import SwiftUI

// MARK: - Master Strip View

struct ProMasterStripView: View {
    @ObservedObject var master: MasterChannelState
    let showNeedleMeter: Bool

    init(master: MasterChannelState, showNeedleMeter: Bool = true) {
        self.master = master
        self.showNeedleMeter = showNeedleMeter
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            masterHeader

            Divider()
                .background(ColorPalette.divider)

            // Effects returns
            effectsReturnsSection

            Divider()
                .background(ColorPalette.divider)

            // Master fader with stereo bar meters
            faderSection

            // Master controls
            controlsSection
        }
        .frame(width: showNeedleMeter ? 140 : 80)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorPalette.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ColorPalette.accentMaster.opacity(0.3), lineWidth: 1)
        )
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    // MARK: - Header

    private var masterHeader: some View {
        VStack(spacing: 2) {
            // Peak LEDs
            HStack(spacing: 8) {
                PeakLEDView(level: $master.meterLevelL)
                Text("MASTER")
                    .font(Typography.channelLabel)
                    .foregroundColor(ColorPalette.accentMaster)
                PeakLEDView(level: $master.meterLevelR)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(ColorPalette.backgroundPrimary)
    }

    // MARK: - Meter Section

    private var meterSection: some View {
        Group {
            if showNeedleMeter {
                // Needle-style stereo VU meter
                StereoVUMeterNeedleView(
                    levelL: Binding(
                        get: { master.isMuted ? 0 : master.meterLevelL },
                        set: { _ in }
                    ),
                    levelR: Binding(
                        get: { master.isMuted ? 0 : master.meterLevelR },
                        set: { _ in }
                    ),
                    width: 120,
                    height: 60
                )
                .padding(.vertical, 8)
            } else {
                // LED bar stereo meter
                StereoVUMeterBarView(
                    levelL: Binding(
                        get: { master.isMuted ? 0 : master.meterLevelL },
                        set: { _ in }
                    ),
                    levelR: Binding(
                        get: { master.isMuted ? 0 : master.meterLevelR },
                        set: { _ in }
                    ),
                    segments: 16,
                    width: 28,
                    height: 80
                )
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Effects Returns Section

    private var effectsReturnsSection: some View {
        VStack(spacing: 8) {
            Text("RETURNS")
                .font(Typography.parameterLabelSmall)
                .foregroundColor(ColorPalette.textDimmed)

            HStack(spacing: showNeedleMeter ? 20 : 8) {
                // Delay return (Send A)
                VStack(spacing: 2) {
                    ProKnobView(
                        value: $master.delayReturnLevel,
                        label: "DLY",
                        accentColor: ColorPalette.ledAmber,
                        size: .small
                    )
                }

                // Reverb return (Send B)
                VStack(spacing: 2) {
                    ProKnobView(
                        value: $master.reverbReturnLevel,
                        label: "REV",
                        accentColor: ColorPalette.ledGreen,
                        size: .small
                    )
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Fader Section

    private var faderSection: some View {
        VStack(spacing: 4) {
            // Fader with stereo VU meters alongside
            HStack(spacing: showNeedleMeter ? 4 : 2) {
                // Left VU meter bar
                VUMeterBarView(
                    level: Binding(
                        get: { master.isMuted ? 0 : master.meterLevelL },
                        set: { _ in }
                    ),
                    segments: 12,
                    width: 5,
                    height: showNeedleMeter ? 100 : 80
                )

                if showNeedleMeter {
                    // dB scale on left
                    dBScaleView
                }

                ProFaderView(
                    value: $master.gain,
                    accentColor: ColorPalette.accentMaster,
                    size: .large,
                    showScale: false,
                    isMuted: master.isMuted
                )

                if showNeedleMeter {
                    // dB scale on right
                    dBScaleView
                }

                // Right VU meter bar
                VUMeterBarView(
                    level: Binding(
                        get: { master.isMuted ? 0 : master.meterLevelR },
                        set: { _ in }
                    ),
                    segments: 12,
                    width: 5,
                    height: showNeedleMeter ? 100 : 80
                )
            }

            // dB display
            Text(master.gainDB)
                .font(Typography.valueMedium)
                .foregroundColor(master.isMuted ? ColorPalette.textDimmed : ColorPalette.accentMaster)
                .monospacedDigit()
                .frame(width: 50)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorPalette.backgroundPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(ColorPalette.accentMaster.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .padding(.vertical, 8)
    }

    // MARK: - dB Scale

    private var dBScaleView: some View {
        VStack(spacing: 0) {
            ForEach(["+10", "+6", "0", "-6", "-12", "-20", "-∞"], id: \.self) { label in
                Text(label)
                    .font(Typography.vuScale)
                    .foregroundColor(label == "0" ? ColorPalette.accentMaster : ColorPalette.textDimmed)
                    .frame(height: 100 / 7)
            }
        }
        .frame(width: 24)
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 8) {
            // Mute button (larger for master)
            Button(action: { master.isMuted.toggle() }) {
                Text("MUTE")
                    .font(Typography.buttonSmall)
                    .foregroundColor(master.isMuted ? .white : ColorPalette.textMuted)
                    .frame(width: 50, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(master.isMuted ? ColorPalette.ledRed : ColorPalette.ledOff)
                    )
                    .shadow(color: master.isMuted ? ColorPalette.ledRedGlow.opacity(0.5) : .clear, radius: 4)
            }
            .buttonStyle(.plain)

            // Master filter quick access
            HStack(spacing: 4) {
                ProKnobView.frequency(
                    value: $master.filterCutoff,
                    label: "FILT",
                    accentColor: ColorPalette.accentRings,
                    size: .small
                )

                ProKnobView(
                    value: $master.filterResonance,
                    label: "RES",
                    accentColor: ColorPalette.accentRings,
                    size: .small,
                    showValue: false
                )
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#if DEBUG
struct ProMasterStripView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @StateObject private var master = MasterChannelState()

        var body: some View {
            HStack(spacing: 20) {
                // With needle meter
                ProMasterStripView(master: master, showNeedleMeter: true)
                    .onAppear {
                        master.meterLevelL = 0.6
                        master.meterLevelR = 0.5
                        master.gain = 0.5
                    }

                // Without needle meter (compact)
                ProMasterStripView(master: master, showNeedleMeter: false)
            }
            .padding(20)
            .background(ColorPalette.backgroundPrimary)
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
#endif

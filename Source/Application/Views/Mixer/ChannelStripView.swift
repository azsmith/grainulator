//
//  ProChannelStripView.swift
//  Grainulator
//
//  Modular channel strip component with vintage analog styling
//  Includes VU meter, pan, sends, fader, and mute/solo
//

import SwiftUI

// MARK: - Pro Channel Strip View (New Modular Version)

struct ProChannelStripView: View {
    @ObservedObject var channel: MixerChannelState
    let isCompact: Bool
    let showInserts: Bool

    @State private var showInsertPopover: Bool = false

    init(
        channel: MixerChannelState,
        isCompact: Bool = false,
        showInserts: Bool = true
    ) {
        self.channel = channel
        self.isCompact = isCompact
        self.showInserts = showInserts
    }

    var body: some View {
        VStack(spacing: 0) {
            if isCompact {
                compactLayout
            } else {
                fullLayout
            }
        }
        .frame(width: isCompact ? 50 : 70)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorPalette.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    channel.isSolo ? ColorPalette.ledAmber.opacity(0.5) : ColorPalette.divider,
                    lineWidth: channel.isSolo ? 2 : 1
                )
        )
    }

    // MARK: - Full Layout

    private var fullLayout: some View {
        VStack(spacing: 6) {
            // Channel name (scribble strip)
            channelHeader

            // Insert effects (collapsible)
            if showInserts {
                insertSection
            }

            Divider()
                .background(ColorPalette.divider)

            // Pan control
            panSection

            // Send knobs
            sendSection

            Divider()
                .background(ColorPalette.divider)

            // Fader with VU meter alongside
            faderSection

            // Mute/Solo buttons
            buttonSection
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    // MARK: - Compact Layout

    private var compactLayout: some View {
        VStack(spacing: 4) {
            // Mini channel name
            Text(channel.channelType.shortName)
                .font(Typography.parameterLabelSmall)
                .foregroundColor(channel.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .background(ColorPalette.backgroundPrimary)

            // Compact fader with meter alongside
            HStack(spacing: 1) {
                VUMeterBarView(
                    level: Binding(
                        get: { channel.isMuted ? 0 : channel.meterLevel },
                        set: { _ in }
                    ),
                    segments: 8,
                    width: 4,
                    height: 60
                )

                ProFaderView(
                    value: $channel.gain,
                    accentColor: channel.accentColor,
                    size: .small,
                    showScale: false,
                    isMuted: channel.isMuted
                )
            }

            // Mini mute/solo
            HStack(spacing: 2) {
                MuteButton(isMuted: $channel.isMuted, size: .small)
                SoloButton(isSolo: $channel.isSolo, size: .small)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }

    // MARK: - Channel Header

    private var channelHeader: some View {
        VStack(spacing: 2) {
            // Peak LED + activity LED
            HStack(spacing: 4) {
                Circle()
                    .fill(channel.meterLevel > 0.01 ? channel.accentColor : ColorPalette.ledOff)
                    .frame(width: 6, height: 6)
                    .shadow(color: channel.meterLevel > 0.01 ? channel.accentColor.opacity(0.5) : .clear, radius: 3)

                PeakLEDView(level: $channel.meterLevel, threshold: 0.9)
            }

            // Channel name
            Text(channel.name)
                .font(Typography.channelLabel)
                .foregroundColor(channel.isMuted ? ColorPalette.textDimmed : channel.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(ColorPalette.backgroundPrimary)
    }

    // MARK: - Meter Section

    private var meterSection: some View {
        HStack(spacing: 4) {
            // Peak LED
            PeakLEDView(level: $channel.meterLevel, threshold: 0.9)

            // VU meter bar - use binding for real-time updates
            VUMeterBarView(
                level: Binding(
                    get: { channel.isMuted ? 0 : channel.meterLevel },
                    set: { _ in }  // Read-only from audio engine
                ),
                segments: 12,
                width: 10,
                height: 60
            )
        }
        .frame(height: 65)
    }

    // MARK: - Insert Section

    private var insertSection: some View {
        AUInsertSectionView(
            channelIndex: channel.channelIndex,
            accentColor: channel.accentColor
        )
    }

    // MARK: - Pan Section

    private var panSection: some View {
        VStack(spacing: 2) {
            ProKnobView.pan(
                value: $channel.pan,
                accentColor: channel.accentColor,
                size: .small
            )
        }
    }

    // MARK: - Send Section

    private var sendSection: some View {
        HStack(spacing: 4) {
            // Send A (Delay)
            VStack(spacing: 1) {
                ProKnobView(
                    value: $channel.sendA.level,
                    label: "A",
                    accentColor: ColorPalette.ledAmber,
                    size: .small,
                    showValue: false
                )

                // Pre/Post indicator
                Text(channel.sendA.mode.rawValue)
                    .font(Typography.parameterLabelSmall)
                    .foregroundColor(ColorPalette.textDimmed)
            }

            // Send B (Reverb)
            VStack(spacing: 1) {
                ProKnobView(
                    value: $channel.sendB.level,
                    label: "B",
                    accentColor: ColorPalette.ledGreen,
                    size: .small,
                    showValue: false
                )

                Text(channel.sendB.mode.rawValue)
                    .font(Typography.parameterLabelSmall)
                    .foregroundColor(ColorPalette.textDimmed)
            }
        }
    }

    // MARK: - Fader Section

    private var faderSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                // VU meter alongside fader
                VUMeterBarView(
                    level: Binding(
                        get: { channel.isMuted ? 0 : channel.meterLevel },
                        set: { _ in }
                    ),
                    segments: 10,
                    width: 5,
                    height: 80
                )

                ProFaderView(
                    value: $channel.gain,
                    accentColor: channel.accentColor,
                    size: .medium,
                    showScale: false,
                    isMuted: channel.isMuted
                )
            }

            // dB display
            Text(channel.gainDB)
                .font(Typography.valueSmall)
                .foregroundColor(channel.isMuted ? ColorPalette.textDimmed : channel.accentColor)
                .monospacedDigit()
                .frame(width: 40)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ColorPalette.backgroundPrimary)
                )
        }
    }

    // MARK: - Button Section

    private var buttonSection: some View {
        HStack(spacing: 4) {
            MuteButton(isMuted: $channel.isMuted, size: .medium)
            SoloButton(isSolo: $channel.isSolo, size: .medium)
        }
        .padding(.top, 4)
    }
}

// MARK: - Insert Indicator (Compact)

struct InsertIndicator: View {
    @ObservedObject var insert: InsertEffectState
    let accentColor: Color

    var body: some View {
        ZStack {
            // LED indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(insert.effectType == .none ? ColorPalette.ledOff : (insert.isBypassed ? ColorPalette.ledAmber : accentColor))
                .frame(width: 24, height: 16)

            // Effect abbreviation
            Text(insert.effectType.abbreviation)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(insert.effectType == .none ? ColorPalette.textDimmed : .white)
        }
        .shadow(color: (insert.effectType != .none && !insert.isBypassed) ? accentColor.opacity(0.3) : .clear, radius: 2)
    }
}

// MARK: - Insert Effects Popover

struct InsertEffectsPopover: View {
    @ObservedObject var insert1: InsertEffectState
    @ObservedObject var insert2: InsertEffectState
    let channelName: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("\(channelName) INSERTS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)

                Spacer()
            }

            Divider()
                .background(ColorPalette.divider)

            // Insert 1
            InsertSlotEditor(insert: insert1, slotNumber: 1, accentColor: accentColor)

            // Insert 2
            InsertSlotEditor(insert: insert2, slotNumber: 2, accentColor: accentColor)
        }
        .padding(16)
        .frame(width: 280)
        .background(ColorPalette.backgroundSecondary)
    }
}

// MARK: - Insert Slot Editor

struct InsertSlotEditor: View {
    @ObservedObject var insert: InsertEffectState
    let slotNumber: Int
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Slot header
            HStack {
                Text("INSERT \(slotNumber)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textMuted)

                Spacer()

                // Bypass toggle
                if insert.effectType != .none {
                    Button(action: { insert.isBypassed.toggle() }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(insert.isBypassed ? ColorPalette.ledAmber : ColorPalette.ledGreen)
                                .frame(width: 8, height: 8)
                            Text(insert.isBypassed ? "BYPASSED" : "ACTIVE")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(insert.isBypassed ? ColorPalette.ledAmber : ColorPalette.ledGreen)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Effect type selector
            HStack(spacing: 8) {
                ForEach(InsertEffectType.allCases) { effectType in
                    Button(action: { insert.setEffect(effectType) }) {
                        Text(effectType.displayName)
                            .font(.system(size: 10, weight: insert.effectType == effectType ? .bold : .medium, design: .monospaced))
                            .foregroundColor(insert.effectType == effectType ? .white : ColorPalette.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(insert.effectType == effectType ? accentColor : ColorPalette.backgroundTertiary)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Effect parameters (when effect is active)
            if insert.effectType != .none {
                effectParameters
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorPalette.backgroundPrimary)
        )
    }

    @ViewBuilder
    private var effectParameters: some View {
        HStack(spacing: 12) {
            switch insert.effectType {
            case .none:
                EmptyView()
            case .eq:
                // EQ: Low, Mid, High
                ParameterKnob(value: $insert.param1, label: "LOW", accentColor: accentColor)
                ParameterKnob(value: $insert.param2, label: "MID", accentColor: accentColor)
                ParameterKnob(value: $insert.param3, label: "HIGH", accentColor: accentColor)
            case .compressor:
                // Compressor: Threshold, Ratio, Makeup
                ParameterKnob(value: $insert.param1, label: "THRS", accentColor: accentColor)
                ParameterKnob(value: $insert.param2, label: "RATIO", accentColor: accentColor)
                ParameterKnob(value: $insert.param3, label: "GAIN", accentColor: accentColor)
            case .filter:
                // Filter: Cutoff, Resonance, Type
                ParameterKnob(value: $insert.param1, label: "FREQ", accentColor: accentColor)
                ParameterKnob(value: $insert.param2, label: "RES", accentColor: accentColor)
                ParameterKnob(value: $insert.param3, label: "TYPE", accentColor: accentColor)
            case .saturator:
                // Saturator: Drive, Tone, Mix
                ParameterKnob(value: $insert.param1, label: "DRIVE", accentColor: accentColor)
                ParameterKnob(value: $insert.param2, label: "TONE", accentColor: accentColor)
                ParameterKnob(value: $insert.param3, label: "MIX", accentColor: accentColor)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Parameter Knob (for popover)

struct ParameterKnob: View {
    @Binding var value: Float
    let label: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 4) {
            ProKnobView(
                value: $value,
                label: label,
                accentColor: accentColor,
                size: .small,
                showValue: false
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProChannelStripView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @StateObject private var channel1 = MixerChannelState(channelType: .plaits)
        @StateObject private var channel2 = MixerChannelState(channelType: .rings)
        @StateObject private var channel3 = MixerChannelState(channelType: .granular1)

        var body: some View {
            HStack(spacing: 8) {
                // Full layout
                ProChannelStripView(channel: channel1)
                    .onAppear {
                        channel1.meterLevel = 0.6
                        channel1.gain = 0.7
                    }

                ProChannelStripView(channel: channel2)
                    .onAppear {
                        channel2.meterLevel = 0.4
                        channel2.isSolo = true
                    }

                ProChannelStripView(channel: channel3)
                    .onAppear {
                        channel3.meterLevel = 0.8
                        channel3.isMuted = true
                    }

                Divider()

                // Compact layout
                ProChannelStripView(channel: channel1, isCompact: true)
                ProChannelStripView(channel: channel2, isCompact: true)
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

//
//  EffectsRackView.swift
//  Grainulator
//
//  Modular effects rack view with send/return effects
//  Classic outboard gear styling with vintage knobs and VU meters
//

import SwiftUI

// MARK: - Effects State Models

/// Individual effect unit state
class EffectUnitState: ObservableObject, Identifiable {
    let id = UUID()
    let effectType: EffectUnitType

    @Published var isBypassed: Bool = false
    @Published var mix: Float = 1.0
    @Published var parameters: [Float]

    init(effectType: EffectUnitType) {
        self.effectType = effectType
        self.parameters = Array(repeating: 0.5, count: effectType.parameterCount)

        // Set default parameter values
        switch effectType {
        case .delay:
            parameters = [0.3, 0.4, 0.86, 0.5, 0.5, 0.45]  // time, feedback, mode, wow, flutter, tone
        case .reverb:
            parameters = [0.5, 0.5, 0.0, 1.0]  // size, damping, predelay, width
        case .none:
            break
        }
    }
}

/// Types of available effects
enum EffectUnitType: String, CaseIterable, Identifiable {
    case none = "NONE"
    case delay = "DELAY"
    case reverb = "REVERB"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "—"
        case .delay: return "TAPE DELAY"
        case .reverb: return "PLATE REVERB"
        }
    }

    var parameterCount: Int {
        switch self {
        case .none: return 0
        case .delay: return 6
        case .reverb: return 4
        }
    }

    var accentColor: Color {
        switch self {
        case .none: return ColorPalette.textDimmed
        case .delay: return ColorPalette.ledAmber
        case .reverb: return ColorPalette.ledGreen
        }
    }
}

/// Send/return bus state
class SendBusState: ObservableObject, Identifiable {
    let id: String
    let name: String

    @Published var effectUnit: EffectUnitState
    @Published var returnLevel: Float = 1.0
    @Published var meterLevel: Float = 0.0

    init(id: String, name: String, effectType: EffectUnitType) {
        self.id = id
        self.name = name
        self.effectUnit = EffectUnitState(effectType: effectType)
    }
}

/// Master effects rack state
class EffectsRackState: ObservableObject {
    @Published var sendA: SendBusState  // Delay send
    @Published var sendB: SendBusState  // Reverb send

    init() {
        self.sendA = SendBusState(id: "sendA", name: "SEND A", effectType: .delay)
        self.sendB = SendBusState(id: "sendB", name: "SEND B", effectType: .reverb)
    }
}

// MARK: - Effects Rack View

struct EffectsRackView: View {
    @ObservedObject var rackState: EffectsRackState
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    var body: some View {
        HStack(spacing: 16) {
            // Send A - Delay
            SendEffectUnitView(
                sendBus: rackState.sendA,
                audioEngine: audioEngine
            )

            // Divider
            Rectangle()
                .fill(ColorPalette.divider)
                .frame(width: 1)

            // Send B - Reverb
            SendEffectUnitView(
                sendBus: rackState.sendB,
                audioEngine: audioEngine
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorPalette.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorPalette.divider, lineWidth: 1)
        )
    }
}

// MARK: - Send Effect Unit View

struct SendEffectUnitView: View {
    @ObservedObject var sendBus: SendBusState
    @ObservedObject var audioEngine: AudioEngineWrapper

    var body: some View {
        VStack(spacing: 8) {
            // Header with name and bypass
            effectHeader

            // Effect-specific controls
            if sendBus.effectUnit.effectType != .none {
                effectControls
            } else {
                emptySlot
            }

            // Return level and meter
            returnSection
        }
        .frame(width: 240)
    }

    // MARK: - Header

    private var effectHeader: some View {
        HStack {
            // Send label with LED
            HStack(spacing: 6) {
                Circle()
                    .fill(sendBus.meterLevel > 0.01 ?
                          sendBus.effectUnit.effectType.accentColor :
                          ColorPalette.ledOff)
                    .frame(width: 8, height: 8)
                    .shadow(color: sendBus.meterLevel > 0.01 ?
                            sendBus.effectUnit.effectType.accentColor.opacity(0.5) : .clear,
                            radius: 3)

                Text(sendBus.name)
                    .font(Typography.panelTitle)
                    .foregroundColor(sendBus.effectUnit.effectType.accentColor)
            }

            Spacer()

            // Effect type display
            Text(sendBus.effectUnit.effectType.displayName)
                .font(Typography.valueSmall)
                .foregroundColor(ColorPalette.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorPalette.backgroundTertiary)
                )

            // Bypass button
            Button(action: {
                sendBus.effectUnit.isBypassed.toggle()
            }) {
                Text("BYP")
                    .font(Typography.buttonSmall)
                    .foregroundColor(sendBus.effectUnit.isBypassed ?
                                     ColorPalette.ledRed : ColorPalette.textDimmed)
                    .frame(width: 32, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(sendBus.effectUnit.isBypassed ?
                                  ColorPalette.ledRed.opacity(0.2) :
                                  ColorPalette.backgroundTertiary)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(ColorPalette.backgroundPrimary)
    }

    // MARK: - Effect Controls

    @ViewBuilder
    private var effectControls: some View {
        switch sendBus.effectUnit.effectType {
        case .delay:
            DelayEffectControlsView(effect: sendBus.effectUnit, audioEngine: audioEngine)
        case .reverb:
            ReverbEffectControlsView(effect: sendBus.effectUnit, audioEngine: audioEngine)
        case .none:
            emptySlot
        }
    }

    private var emptySlot: some View {
        VStack {
            Text("No Effect")
                .font(Typography.parameterLabel)
                .foregroundColor(ColorPalette.textDimmed)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorPalette.backgroundPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(ColorPalette.divider.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
        )
    }

    // MARK: - Return Section

    private var returnSection: some View {
        HStack(spacing: 8) {
            // Return level knob
            VStack(spacing: 2) {
                ProKnobView(
                    value: $sendBus.returnLevel,
                    label: "RETURN",
                    accentColor: sendBus.effectUnit.effectType.accentColor,
                    size: .small,
                    showValue: true
                )
            }

            Spacer()

            // Mini VU meter
            VStack(spacing: 2) {
                Text("LEVEL")
                    .font(Typography.parameterLabelSmall)
                    .foregroundColor(ColorPalette.textDimmed)

                VUMeterBarView(
                    level: .constant(sendBus.meterLevel),
                    segments: 8,
                    width: 12,
                    height: 40
                )
            }

            // Mix control
            VStack(spacing: 2) {
                ProKnobView(
                    value: $sendBus.effectUnit.mix,
                    label: "MIX",
                    accentColor: sendBus.effectUnit.effectType.accentColor,
                    size: .small,
                    showValue: true
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Delay Effect Controls

struct DelayEffectControlsView: View {
    @ObservedObject var effect: EffectUnitState
    @ObservedObject var audioEngine: AudioEngineWrapper

    var body: some View {
        VStack(spacing: 8) {
            // Top row: Time, Feedback, Mode
            HStack(spacing: 12) {
                ProKnobView(
                    value: $effect.parameters[0],
                    label: "TIME",
                    accentColor: ColorPalette.ledAmber,
                    size: .medium,
                    showValue: true
                )
                .onChange(of: effect.parameters[0]) { newValue in
                    audioEngine.setParameter(id: .delayTime, value: newValue)
                }

                ProKnobView(
                    value: $effect.parameters[1],
                    label: "FDBK",
                    accentColor: ColorPalette.ledAmber,
                    size: .medium,
                    showValue: true
                )
                .onChange(of: effect.parameters[1]) { newValue in
                    audioEngine.setParameter(id: .delayFeedback, value: newValue)
                }

                // Head mode selector
                VStack(spacing: 4) {
                    Text("MODE")
                        .font(Typography.parameterLabelSmall)
                        .foregroundColor(ColorPalette.textDimmed)

                    DelayModeSelector(value: $effect.parameters[2])
                        .onChange(of: effect.parameters[2]) { newValue in
                            audioEngine.setParameter(id: .delayHeadMode, value: newValue)
                        }
                }
            }

            // Bottom row: Wow, Flutter, Tone
            HStack(spacing: 12) {
                ProKnobView(
                    value: $effect.parameters[3],
                    label: "WOW",
                    accentColor: ColorPalette.ledAmber.opacity(0.8),
                    size: .small,
                    showValue: false
                )
                .onChange(of: effect.parameters[3]) { newValue in
                    audioEngine.setParameter(id: .delayWow, value: newValue)
                }

                ProKnobView(
                    value: $effect.parameters[4],
                    label: "FLTR",
                    accentColor: ColorPalette.ledAmber.opacity(0.8),
                    size: .small,
                    showValue: false
                )
                .onChange(of: effect.parameters[4]) { newValue in
                    audioEngine.setParameter(id: .delayFlutter, value: newValue)
                }

                ProKnobView(
                    value: $effect.parameters[5],
                    label: "TONE",
                    accentColor: ColorPalette.ledAmber.opacity(0.8),
                    size: .small,
                    showValue: false
                )
                .onChange(of: effect.parameters[5]) { newValue in
                    audioEngine.setParameter(id: .delayTone, value: newValue)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorPalette.backgroundPrimary)
        )
    }
}

// MARK: - Delay Mode Selector

struct DelayModeSelector: View {
    @Binding var value: Float

    private let modes = ["1", "2", "3", "1+2", "2+3", "1+3", "ALL", "DNZ"]

    private var selectedIndex: Int {
        Int(value * Float(modes.count - 1) + 0.5)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<modes.count, id: \.self) { index in
                Button(action: {
                    value = Float(index) / Float(modes.count - 1)
                }) {
                    Text(modes[index])
                        .font(Typography.parameterLabelSmall)
                        .foregroundColor(index == selectedIndex ? .white : ColorPalette.textDimmed)
                        .frame(width: 22, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(index == selectedIndex ?
                                      ColorPalette.ledAmber : ColorPalette.backgroundTertiary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Reverb Effect Controls

struct ReverbEffectControlsView: View {
    @ObservedObject var effect: EffectUnitState
    @ObservedObject var audioEngine: AudioEngineWrapper

    var body: some View {
        VStack(spacing: 8) {
            // Main controls: Size, Damping
            HStack(spacing: 16) {
                ProKnobView(
                    value: $effect.parameters[0],
                    label: "SIZE",
                    accentColor: ColorPalette.ledGreen,
                    size: .medium,
                    showValue: true
                )
                .onChange(of: effect.parameters[0]) { newValue in
                    audioEngine.setParameter(id: .reverbSize, value: newValue)
                }

                ProKnobView(
                    value: $effect.parameters[1],
                    label: "DAMP",
                    accentColor: ColorPalette.ledGreen,
                    size: .medium,
                    showValue: true
                )
                .onChange(of: effect.parameters[1]) { newValue in
                    audioEngine.setParameter(id: .reverbDamping, value: newValue)
                }
            }

            // Secondary controls: Pre-delay, Width
            HStack(spacing: 16) {
                ProKnobView(
                    value: $effect.parameters[2],
                    label: "PRE",
                    accentColor: ColorPalette.ledGreen.opacity(0.8),
                    size: .small,
                    showValue: false
                )

                ProKnobView(
                    value: $effect.parameters[3],
                    label: "WIDTH",
                    accentColor: ColorPalette.ledGreen.opacity(0.8),
                    size: .small,
                    showValue: false
                )
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ColorPalette.backgroundPrimary)
        )
    }
}

// MARK: - Compact Effects Strip

/// A compact horizontal strip version for use in the mixer area
struct CompactEffectsStripView: View {
    @ObservedObject var rackState: EffectsRackState

    var body: some View {
        HStack(spacing: 12) {
            // Send A mini
            CompactSendView(sendBus: rackState.sendA)

            Rectangle()
                .fill(ColorPalette.divider)
                .frame(width: 1, height: 40)

            // Send B mini
            CompactSendView(sendBus: rackState.sendB)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ColorPalette.backgroundSecondary)
    }
}

struct CompactSendView: View {
    @ObservedObject var sendBus: SendBusState

    var body: some View {
        HStack(spacing: 8) {
            // LED and name
            Circle()
                .fill(sendBus.meterLevel > 0.01 ?
                      sendBus.effectUnit.effectType.accentColor : ColorPalette.ledOff)
                .frame(width: 6, height: 6)

            Text(sendBus.name)
                .font(Typography.parameterLabelSmall)
                .foregroundColor(sendBus.effectUnit.effectType.accentColor)

            // Mini meter
            VUMeterBarView(
                level: .constant(sendBus.meterLevel),
                segments: 6,
                width: 4,
                height: 24
            )

            // Return level display
            Text(String(format: "%.0f%%", sendBus.returnLevel * 100))
                .font(Typography.valueSmall)
                .foregroundColor(ColorPalette.textMuted)
                .monospacedDigit()
                .frame(width: 36)

            // Bypass indicator
            if sendBus.effectUnit.isBypassed {
                Text("BYP")
                    .font(Typography.parameterLabelSmall)
                    .foregroundColor(ColorPalette.ledRed)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct EffectsRackView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @StateObject private var rackState = EffectsRackState()
        @StateObject private var audioEngine = AudioEngineWrapper()

        var body: some View {
            VStack(spacing: 20) {
                // Full rack view
                EffectsRackView(rackState: rackState)
                    .environmentObject(audioEngine)

                // Compact strip
                CompactEffectsStripView(rackState: rackState)
            }
            .padding(20)
            .background(ColorPalette.backgroundPrimary)
            .onAppear {
                rackState.sendA.meterLevel = 0.4
                rackState.sendB.meterLevel = 0.6
            }
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
#endif

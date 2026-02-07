//
//  SynthPanelView.swift
//  Grainulator
//
//  Minimoog-inspired synth panel container with dark textured background,
//  engraved section labels, and knob-focused layout. Replaces EurorackModuleView
//  for synth voice modules that benefit from a larger, more readable design.
//

import SwiftUI

// MARK: - Synth Panel Container

struct SynthPanelView<Content: View>: View {
    let title: String
    let accentColor: Color
    let width: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        accentColor: Color,
        width: CGFloat = 300,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.accentColor = accentColor
        self.width = width
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Panel title header
            panelHeader

            // Content area
            content()
                .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 8)
        .frame(width: width)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.clear,
                            Color.black.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 4)
    }

    // MARK: - Panel Header

    private var panelHeader: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundColor(ColorPalette.synthPanelLabel)
                .tracking(3)
                .textCase(.uppercase)
                // Engraved text effect: dark shadow below, subtle light above
                .shadow(color: Color.black.opacity(0.8), radius: 0, x: 0, y: 1)
                .shadow(color: Color.white.opacity(0.08), radius: 0, x: 0, y: -1)

            Spacer()

            // Accent dot indicator
            Circle()
                .fill(accentColor)
                .frame(width: 6, height: 6)
                .shadow(color: accentColor.opacity(0.5), radius: 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Panel Background

    private var panelBackground: some View {
        ZStack {
            // Base color
            ColorPalette.synthPanelSurface

            // Subtle vertical gradient for depth
            LinearGradient(
                colors: [
                    ColorPalette.synthPanelSurfaceLight,
                    ColorPalette.synthPanelSurface,
                    Color.black.opacity(0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Noise texture simulation (stipple effect via overlapping gradients)
            RadialGradient(
                colors: [
                    Color.white.opacity(0.02),
                    Color.clear
                ],
                center: UnitPoint(x: 0.3, y: 0.2),
                startRadius: 0,
                endRadius: 200
            )
        }
    }
}

// MARK: - Synth Panel Section Label

/// An engraved section label for use inside SynthPanelView.
/// Renders like screen-printed text on a dark panel.
struct SynthPanelSectionLabel: View {
    let text: String
    let accentColor: Color

    init(_ text: String, accentColor: Color = ColorPalette.synthPanelLabelDim) {
        self.text = text
        self.accentColor = accentColor
    }

    var body: some View {
        HStack(spacing: 8) {
            // Left line
            Rectangle()
                .fill(ColorPalette.synthPanelDivider)
                .frame(height: 1)

            Text(text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(accentColor)
                .tracking(2)
                .textCase(.uppercase)
                .shadow(color: Color.black.opacity(0.8), radius: 0, x: 0, y: 1)

            // Right line
            Rectangle()
                .fill(ColorPalette.synthPanelDivider)
                .frame(height: 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

// MARK: - Synth Panel Knob Row

/// A horizontal row of knobs with consistent spacing for SynthPanelView.
struct SynthPanelKnobRow: View {
    let knobs: [AnyView]

    init(@ViewBuilder content: () -> TupleView<(AnyView, AnyView)>) {
        let tuple = content()
        self.knobs = [tuple.value.0, tuple.value.1]
    }

    init(knobs: [AnyView]) {
        self.knobs = knobs
    }

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(knobs.enumerated()), id: \.offset) { _, knob in
                knob
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Preview

#if DEBUG
struct SynthPanelView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var val1: Float = 0.5
        @State private var val2: Float = 0.75
        @State private var val3: Float = 0.3
        @State private var val4: Float = 0.8

        var body: some View {
            HStack(spacing: 20) {
                SynthPanelView(
                    title: "PLAITS",
                    accentColor: ColorPalette.accentPlaits,
                    width: 300
                ) {
                    VStack(spacing: 8) {
                        SynthPanelSectionLabel("OSCILLATOR", accentColor: ColorPalette.accentPlaits)

                        HStack(spacing: 20) {
                            ProKnobView(
                                value: $val1,
                                label: "HARMONICS",
                                accentColor: ColorPalette.accentPlaits,
                                size: .large,
                                style: .minimoog
                            )
                            ProKnobView(
                                value: $val2,
                                label: "TIMBRE",
                                accentColor: ColorPalette.accentPlaits,
                                size: .large,
                                style: .minimoog
                            )
                        }

                        HStack(spacing: 20) {
                            ProKnobView(
                                value: $val3,
                                label: "MORPH",
                                accentColor: ColorPalette.accentPlaits,
                                size: .large,
                                style: .minimoog
                            )
                            ProKnobView(
                                value: $val4,
                                label: "LEVEL",
                                accentColor: ColorPalette.accentPlaits,
                                size: .large,
                                style: .minimoog
                            )
                        }

                        SynthPanelSectionLabel("LPG", accentColor: ColorPalette.synthPanelLabelDim)

                        HStack(spacing: 20) {
                            ProKnobView(
                                value: $val1,
                                label: "ATTACK",
                                accentColor: ColorPalette.accentLooper1,
                                size: .medium,
                                style: .minimoog
                            )
                            ProKnobView(
                                value: $val2,
                                label: "DECAY",
                                accentColor: ColorPalette.accentLooper1,
                                size: .medium,
                                style: .minimoog
                            )
                            ProKnobView(
                                value: $val3,
                                label: "COLOR",
                                accentColor: ColorPalette.ledAmber,
                                size: .medium,
                                style: .minimoog
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }

                SynthPanelView(
                    title: "RINGS",
                    accentColor: ColorPalette.accentRings,
                    width: 260
                ) {
                    VStack(spacing: 8) {
                        SynthPanelSectionLabel("RESONATOR", accentColor: ColorPalette.accentRings)

                        HStack(spacing: 16) {
                            ProKnobView(
                                value: $val1,
                                label: "STRUCT",
                                accentColor: ColorPalette.accentRings,
                                size: .large,
                                style: .minimoog
                            )
                            ProKnobView(
                                value: $val2,
                                label: "BRIGHT",
                                accentColor: ColorPalette.accentRings,
                                size: .large,
                                style: .minimoog
                            )
                        }

                        HStack(spacing: 16) {
                            ProKnobView(
                                value: $val3,
                                label: "DAMPING",
                                accentColor: ColorPalette.accentRings,
                                size: .medium,
                                style: .minimoog
                            )
                            ProKnobView(
                                value: $val4,
                                label: "POSITION",
                                accentColor: ColorPalette.accentRings,
                                size: .medium,
                                style: .minimoog
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .padding(30)
            .background(ColorPalette.backgroundPrimary)
        }
    }

    static var previews: some View {
        PreviewWrapper()
            .previewLayout(.sizeThatFits)
    }
}
#endif

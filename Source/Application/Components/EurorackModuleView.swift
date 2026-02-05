//
//  EurorackModuleView.swift
//  Grainulator
//
//  Reusable eurorack-style module container with panel aesthetics
//  Features: screw holes, section dividers, brushed panel background
//

import SwiftUI

// MARK: - Eurorack Module Container

struct EurorackModuleView<Content: View>: View {
    let title: String
    let accentColor: Color
    let width: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        accentColor: Color,
        width: CGFloat = 200,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.accentColor = accentColor
        self.width = width
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and screw holes
            moduleHeader

            // Content area
            content()
                .frame(maxWidth: .infinity)

            // Bottom with screw holes
            moduleFooter
        }
        .frame(width: width)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ColorPalette.divider, lineWidth: 1)
        )
        .shadow(color: ColorPalette.shadowDrop, radius: 4, x: 0, y: 2)
    }

    // MARK: - Header

    private var moduleHeader: some View {
        HStack {
            // Left screw hole
            screwHole

            Spacer()

            // Module title
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(accentColor)
                .tracking(2)

            Spacer()

            // Right screw hole
            screwHole
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(ColorPalette.backgroundSecondary)
    }

    // MARK: - Footer

    private var moduleFooter: some View {
        HStack {
            screwHole
            Spacer()
            screwHole
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(ColorPalette.backgroundSecondary)
    }

    // MARK: - Screw Hole Decoration

    private var screwHole: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(ColorPalette.metalSteel)
                .frame(width: 12, height: 12)

            // Inner recess
            Circle()
                .fill(ColorPalette.backgroundPrimary)
                .frame(width: 8, height: 8)

            // Cross slot
            Path { path in
                path.move(to: CGPoint(x: 3, y: 6))
                path.addLine(to: CGPoint(x: 9, y: 6))
                path.move(to: CGPoint(x: 6, y: 3))
                path.addLine(to: CGPoint(x: 6, y: 9))
            }
            .stroke(ColorPalette.metalSteel.opacity(0.5), lineWidth: 1)
            .frame(width: 12, height: 12)
        }
    }

    // MARK: - Panel Background

    private var panelBackground: some View {
        LinearGradient(
            colors: [
                ColorPalette.backgroundTertiary,
                ColorPalette.backgroundSecondary,
                ColorPalette.backgroundTertiary
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Module Section Divider

struct ModuleSectionDivider: View {
    let label: String?
    let accentColor: Color

    init(_ label: String? = nil, accentColor: Color = ColorPalette.textDimmed) {
        self.label = label
        self.accentColor = accentColor
    }

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(ColorPalette.divider)
                .frame(height: 1)

            if let label = label {
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(accentColor)
                    .textCase(.uppercase)
            }

            Rectangle()
                .fill(ColorPalette.divider)
                .frame(height: 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Module Trigger Button

struct ModuleTriggerButton: View {
    let label: String
    let isActive: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(isActive ? ColorPalette.backgroundPrimary : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? accentColor : ColorPalette.backgroundTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(accentColor, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 4))
            .onTapGesture {
                // Defer action to the next runloop tick to avoid mutating audio/view
                // state from inside SwiftUI's gesture dispatch internals.
                DispatchQueue.main.async {
                    action()
                }
            }
            .shadow(color: isActive ? accentColor.opacity(0.4) : .clear, radius: 4)
    }
}

// MARK: - Preview

#if DEBUG
struct EurorackModuleView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            // Example Rings-style module
            EurorackModuleView(
                title: "RINGS",
                accentColor: ColorPalette.accentRings,
                width: 200
            ) {
                VStack(spacing: 12) {
                    // Knob placeholder
                    Circle()
                        .stroke(ColorPalette.accentRings, lineWidth: 2)
                        .frame(width: 50, height: 50)
                    Text("NOTE")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(ColorPalette.textMuted)

                    ModuleSectionDivider("TIMBRE", accentColor: ColorPalette.accentRings)

                    // Slider bank placeholder
                    HStack(spacing: 8) {
                        ForEach(0..<5) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ColorPalette.backgroundPrimary)
                                .frame(width: 12, height: 80)
                        }
                    }

                    ModuleTriggerButton(
                        label: "STRIKE",
                        isActive: false,
                        accentColor: ColorPalette.accentRings
                    ) {}
                }
                .padding(12)
            }

            // Example Plaits-style module
            EurorackModuleView(
                title: "PLAITS",
                accentColor: ColorPalette.accentPlaits,
                width: 280
            ) {
                VStack(spacing: 12) {
                    Text("Module Content")
                        .foregroundColor(ColorPalette.textMuted)

                    ModuleSectionDivider("OSCILLATOR", accentColor: ColorPalette.accentPlaits)

                    Text("Parameters here...")
                        .foregroundColor(ColorPalette.textDimmed)
                        .frame(height: 100)

                    ModuleSectionDivider("LPG", accentColor: ColorPalette.accentPlaits)

                    Text("LPG section...")
                        .foregroundColor(ColorPalette.textDimmed)
                        .frame(height: 60)

                    ModuleTriggerButton(
                        label: "TRIGGER",
                        isActive: true,
                        accentColor: ColorPalette.accentPlaits
                    ) {}
                }
                .padding(12)
            }
        }
        .padding(30)
        .background(ColorPalette.backgroundPrimary)
    }
}
#endif

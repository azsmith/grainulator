//
//  ColorPalette.swift
//  Grainulator
//
//  Centralized color definitions for the vintage analog UI theme
//

import SwiftUI

// MARK: - Color Palette

struct ColorPalette {

    // MARK: - Background Colors (Dark Theme)

    /// Primary background - deepest layer
    static let backgroundPrimary = Color(hex: "#0F0F11")

    /// Secondary background - panels, cards
    static let backgroundSecondary = Color(hex: "#1A1A1D")

    /// Tertiary background - raised elements, buttons
    static let backgroundTertiary = Color(hex: "#252528")

    /// Panel background - for vintage panel look
    static let panelBackground = Color(hex: "#2A2A2D")

    // MARK: - Wood Grain Colors (Vintage Panel Aesthetics)

    /// Walnut wood - dark rich brown
    static let woodWalnut = Color(hex: "#3D2817")

    /// Walnut wood highlight
    static let woodWalnutLight = Color(hex: "#5C3D2E")

    /// Rosewood - reddish brown
    static let woodRosewood = Color(hex: "#4A2C2A")

    /// Oak - lighter brown
    static let woodOak = Color(hex: "#8B7355")

    // MARK: - Metal Colors (Hardware Elements)

    /// Brushed aluminum
    static let metalAluminum = Color(hex: "#A8A8A8")

    /// Chrome highlight
    static let metalChrome = Color(hex: "#C8C8C8")

    /// Aged brass
    static let metalBrass = Color(hex: "#B5A642")

    /// Dark steel
    static let metalSteel = Color(hex: "#555555")

    /// Black anodized
    static let metalBlackAnodized = Color(hex: "#1A1A1A")

    // MARK: - Knob Colors (Bakelite/Vintage Style)

    /// Classic black bakelite
    static let knobBlack = Color(hex: "#1C1C1C")

    /// Brown bakelite (chicken head)
    static let knobBrown = Color(hex: "#3D3028")

    /// Cream/ivory pointer
    static let knobCream = Color(hex: "#F5F0E1")

    /// Red pointer accent
    static let knobPointerRed = Color(hex: "#CC3333")

    // MARK: - VU Meter Colors

    /// VU meter face - warm cream
    static let vuFace = Color(hex: "#F5F0E1")

    /// VU meter face shadow
    static let vuFaceShadow = Color(hex: "#D4CFC0")

    /// VU needle color
    static let vuNeedle = Color(hex: "#1A1A1A")

    /// VU green zone
    static let vuGreen = Color(hex: "#2D8B2D")

    /// VU yellow zone
    static let vuYellow = Color(hex: "#D4A017")

    /// VU red zone
    static let vuRed = Color(hex: "#CC3333")

    /// VU backlight glow (warm)
    static let vuBacklight = Color(hex: "#FFF8E7")

    // MARK: - LED Colors (Jewel Lens Style)

    /// LED off state
    static let ledOff = Color(hex: "#333333")

    /// LED red (mute active)
    static let ledRed = Color(hex: "#FF3333")

    /// LED red glow
    static let ledRedGlow = Color(hex: "#FF6666")

    /// LED amber (solo active)
    static let ledAmber = Color(hex: "#FFB347")

    /// LED amber glow
    static let ledAmberGlow = Color(hex: "#FFCC66")

    /// LED green (signal present)
    static let ledGreen = Color(hex: "#33CC33")

    /// LED green glow
    static let ledGreenGlow = Color(hex: "#66FF66")

    /// LED blue (selected/active)
    static let ledBlue = Color(hex: "#4A9EFF")

    /// LED blue glow
    static let ledBlueGlow = Color(hex: "#7FBFFF")

    // MARK: - LCD Display Colors

    /// LCD green backlight
    static let lcdGreen = Color(hex: "#33FF66")

    /// LCD green background
    static let lcdGreenBg = Color(hex: "#1A3320")

    /// LCD amber backlight
    static let lcdAmber = Color(hex: "#FFB347")

    /// LCD amber background
    static let lcdAmberBg = Color(hex: "#332A1A")

    // MARK: - Fader Colors

    /// Fader track background
    static let faderTrack = Color(hex: "#1A1A1A")

    /// Fader track groove
    static let faderGroove = Color(hex: "#0A0A0A")

    /// Fader cap black
    static let faderCapBlack = Color(hex: "#2A2A2A")

    /// Fader cap highlight
    static let faderCapHighlight = Color(hex: "#3A3A3A")

    // MARK: - Accent Colors (Channel Identity)

    /// Plaits channel - warm red
    static let accentPlaits = Color(hex: "#FF6B6B")

    /// Rings channel - mint/teal
    static let accentRings = Color(hex: "#00D1B2")

    /// Granular 1 - blue
    static let accentGranular1 = Color(hex: "#4A9EFF")

    /// Looper 1 - purple
    static let accentLooper1 = Color(hex: "#9B59B6")

    /// Looper 2 - orange
    static let accentLooper2 = Color(hex: "#E67E22")

    /// Granular 4 - teal
    static let accentGranular4 = Color(hex: "#1ABC9C")

    /// DaisyDrum - yellow
    static let accentDaisyDrum = Color(hex: "#F1C40F")

    /// Master - gold
    static let accentMaster = Color(hex: "#FFD700")

    // MARK: - Text Colors

    /// Primary text - white
    static let textPrimary = Color(hex: "#FFFFFF")

    /// Secondary text - light gray
    static let textSecondary = Color(hex: "#CCCCCC")

    /// Muted text
    static let textMuted = Color(hex: "#888888")

    /// Dimmed text
    static let textDimmed = Color(hex: "#555555")

    /// Panel label text (embossed look)
    static let textPanelLabel = Color(hex: "#AAAAAA")

    // MARK: - Console Module Colors (LUNA/UAD-inspired)

    /// Console module border - warm dark gray
    static let consoleBorder = Color(hex: "#2C2A28")

    /// Console header gradient dark edge
    static let consoleHeaderDark = Color(hex: "#1C1B19")

    /// Console header gradient light center
    static let consoleHeaderLight = Color(hex: "#2A2825")

    /// Console surface - slightly warm panel fill
    static let consoleSurface = Color(hex: "#1E1D1B")

    // MARK: - Divider/Border Colors

    /// Standard divider
    static let divider = Color(hex: "#333333")

    /// Subtle divider
    static let dividerSubtle = Color(hex: "#222222")

    /// Highlight border
    static let borderHighlight = Color(hex: "#444444")

    // MARK: - Shadow Colors

    /// Drop shadow
    static let shadowDrop = Color.black.opacity(0.5)

    /// Inner shadow (inset)
    static let shadowInner = Color.black.opacity(0.3)

    /// Glow shadow (for LEDs)
    static let shadowGlow = Color.white.opacity(0.2)

    // MARK: - Channel Colors Array

    /// Array of channel accent colors indexed by channel number
    static let channelColors: [Color] = [
        accentPlaits,      // 0: Plaits
        accentRings,       // 1: Rings
        accentGranular1,   // 2: Granular 1
        accentLooper1,     // 3: Looper 1
        accentLooper2,     // 4: Looper 2
        accentGranular4,   // 5: Granular 4
        accentDaisyDrum    // 6: DaisyDrum
    ]

    /// Get channel color by index
    static func channelColor(for index: Int) -> Color {
        guard index >= 0 && index < channelColors.count else {
            return textMuted
        }
        return channelColors[index]
    }
}

// MARK: - Color Extension for Hex Support
// Note: Color(hex:) extension is defined in ContentView.swift and available globally

// MARK: - Gradient Presets

struct GradientPresets {

    /// Wood grain gradient (vertical)
    static let woodGrain = LinearGradient(
        colors: [
            ColorPalette.woodWalnut,
            ColorPalette.woodWalnutLight,
            ColorPalette.woodWalnut
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Brushed metal gradient (horizontal)
    static let brushedMetal = LinearGradient(
        colors: [
            ColorPalette.metalSteel,
            ColorPalette.metalAluminum,
            ColorPalette.metalSteel
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// VU meter face gradient
    static let vuMeterFace = LinearGradient(
        colors: [
            ColorPalette.vuFace,
            ColorPalette.vuFaceShadow
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Fader track gradient
    static let faderTrack = LinearGradient(
        colors: [
            ColorPalette.faderGroove,
            ColorPalette.faderTrack,
            ColorPalette.faderGroove
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Knob surface gradient (for 3D effect)
    static let knobSurface = RadialGradient(
        colors: [
            ColorPalette.knobBrown.opacity(1.2),
            ColorPalette.knobBrown,
            ColorPalette.knobBlack
        ],
        center: .topLeading,
        startRadius: 0,
        endRadius: 50
    )

    /// LED glow gradient (radial)
    static func ledGlow(color: Color) -> RadialGradient {
        RadialGradient(
            colors: [
                color,
                color.opacity(0.5),
                color.opacity(0)
            ],
            center: .center,
            startRadius: 0,
            endRadius: 20
        )
    }
}

// MARK: - Preview

#if DEBUG
struct ColorPalette_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Background colors
                Group {
                    Text("Backgrounds")
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack {
                        colorSwatch(ColorPalette.backgroundPrimary, "Primary")
                        colorSwatch(ColorPalette.backgroundSecondary, "Secondary")
                        colorSwatch(ColorPalette.backgroundTertiary, "Tertiary")
                    }
                }

                // Wood colors
                Group {
                    Text("Wood Grains")
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack {
                        colorSwatch(ColorPalette.woodWalnut, "Walnut")
                        colorSwatch(ColorPalette.woodRosewood, "Rosewood")
                        colorSwatch(ColorPalette.woodOak, "Oak")
                    }
                }

                // LED colors
                Group {
                    Text("LEDs")
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack {
                        colorSwatch(ColorPalette.ledRed, "Red")
                        colorSwatch(ColorPalette.ledAmber, "Amber")
                        colorSwatch(ColorPalette.ledGreen, "Green")
                        colorSwatch(ColorPalette.ledBlue, "Blue")
                    }
                }

                // Channel colors
                Group {
                    Text("Channel Accents")
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack {
                        ForEach(0..<6) { i in
                            colorSwatch(ColorPalette.channelColor(for: i), "Ch \(i)")
                        }
                    }
                }
            }
            .padding()
        }
        .background(ColorPalette.backgroundPrimary)
    }

    static func colorSwatch(_ color: Color, _ name: String) -> some View {
        VStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 50, height: 50)
            Text(name)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}
#endif

//
//  Typography.swift
//  Grainulator
//
//  Centralized typography definitions for the vintage analog UI theme
//

import SwiftUI

// MARK: - Typography

struct Typography {

    // MARK: - Font Families

    /// Primary monospace font for technical displays
    static let monospacedFamily = Font.Design.monospaced

    /// Default system font for general UI
    static let defaultFamily = Font.Design.default

    // MARK: - Display Fonts (Large Headers)

    /// App title - large bold
    static let appTitle = Font.system(size: 24, weight: .bold, design: .monospaced)

    /// Section header - medium bold
    static let sectionHeader = Font.system(size: 18, weight: .bold, design: .monospaced)

    /// Panel title - medium semibold
    static let panelTitle = Font.system(size: 14, weight: .semibold, design: .monospaced)

    // MARK: - Label Fonts

    /// Channel name label
    static let channelLabel = Font.system(size: 10, weight: .bold, design: .monospaced)

    /// Parameter label (under knobs)
    static let parameterLabel = Font.system(size: 8, weight: .medium, design: .monospaced)

    /// Small parameter label (dense layouts)
    static let parameterLabelSmall = Font.system(size: 6, weight: .medium, design: .monospaced)

    /// Unit label (Hz, dB, ms)
    static let unitLabel = Font.system(size: 7, weight: .regular, design: .monospaced)

    // MARK: - Value Display Fonts

    /// Large value display (BPM, main readout)
    static let valueLarge = Font.system(size: 24, weight: .bold, design: .monospaced)

    /// Medium value display
    static let valueMedium = Font.system(size: 16, weight: .bold, design: .monospaced)

    /// Standard value display
    static let valueStandard = Font.system(size: 12, weight: .bold, design: .monospaced)

    /// Small value display
    static let valueSmall = Font.system(size: 10, weight: .medium, design: .monospaced)

    /// Tiny value display (on knobs)
    static let valueTiny = Font.system(size: 8, weight: .medium, design: .monospaced)

    // MARK: - LCD/Segment Display Fonts

    /// LCD large digits
    static let lcdLarge = Font.system(size: 32, weight: .light, design: .monospaced)

    /// LCD medium digits
    static let lcdMedium = Font.system(size: 20, weight: .light, design: .monospaced)

    /// LCD small digits
    static let lcdSmall = Font.system(size: 14, weight: .light, design: .monospaced)

    // MARK: - VU Meter Scale Fonts

    /// VU meter scale markings
    static let vuScale = Font.system(size: 6, weight: .medium, design: .default)

    /// VU meter dB values
    static let vuValue = Font.system(size: 7, weight: .bold, design: .monospaced)

    // MARK: - Button Fonts

    /// Button text - standard
    static let buttonStandard = Font.system(size: 11, weight: .semibold, design: .monospaced)

    /// Button text - small (M/S buttons)
    static let buttonSmall = Font.system(size: 9, weight: .bold, design: .monospaced)

    /// Button text - tiny
    static let buttonTiny = Font.system(size: 8, weight: .bold, design: .monospaced)

    // MARK: - Menu/Dropdown Fonts

    /// Menu item text
    static let menuItem = Font.system(size: 12, weight: .regular, design: .default)

    /// Menu item selected
    static let menuItemSelected = Font.system(size: 12, weight: .semibold, design: .default)

    // MARK: - Status/Info Fonts

    /// Status bar text
    static let statusBar = Font.system(size: 10, weight: .medium, design: .monospaced)

    /// CPU/latency readout
    static let statusValue = Font.system(size: 12, weight: .bold, design: .monospaced)

    /// Tooltip text
    static let tooltip = Font.system(size: 11, weight: .regular, design: .default)

    // MARK: - Panel Embossed Text (Vintage Look)

    /// Embossed panel label (uppercase)
    static let embossedLabel = Font.system(size: 9, weight: .heavy, design: .monospaced)

    /// Embossed panel sublabel
    static let embossedSublabel = Font.system(size: 7, weight: .bold, design: .monospaced)
}

// MARK: - Text Style Modifiers

extension View {
    /// Apply channel label styling
    func channelLabelStyle(color: Color = ColorPalette.textPrimary) -> some View {
        self
            .font(Typography.channelLabel)
            .foregroundColor(color)
            .textCase(.uppercase)
    }

    /// Apply parameter label styling
    func parameterLabelStyle(color: Color = ColorPalette.textMuted) -> some View {
        self
            .font(Typography.parameterLabel)
            .foregroundColor(color)
            .textCase(.uppercase)
    }

    /// Apply value display styling
    func valueDisplayStyle(color: Color = ColorPalette.textPrimary) -> some View {
        self
            .font(Typography.valueStandard)
            .foregroundColor(color)
    }

    /// Apply LCD display styling
    func lcdDisplayStyle(color: Color = ColorPalette.lcdGreen) -> some View {
        self
            .font(Typography.lcdMedium)
            .foregroundColor(color)
    }

    /// Apply embossed panel label styling (vintage look)
    func embossedLabelStyle() -> some View {
        self
            .font(Typography.embossedLabel)
            .foregroundColor(ColorPalette.textPanelLabel)
            .textCase(.uppercase)
            .shadow(color: .black.opacity(0.8), radius: 0, x: 0, y: 1)
    }

    /// Apply status bar styling
    func statusBarStyle() -> some View {
        self
            .font(Typography.statusBar)
            .foregroundColor(ColorPalette.textMuted)
    }
}

// MARK: - Scribble Strip View (Backlit Channel Name)

struct ScribbleStripView: View {
    let text: String
    let color: Color
    let isActive: Bool

    init(_ text: String, color: Color = ColorPalette.ledBlue, isActive: Bool = true) {
        self.text = text
        self.color = color
        self.isActive = isActive
    }

    var body: some View {
        Text(text)
            .font(Typography.channelLabel)
            .foregroundColor(isActive ? color : ColorPalette.textDimmed)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(ColorPalette.backgroundPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(isActive ? color.opacity(0.3) : ColorPalette.divider, lineWidth: 1)
                    )
            )
            .shadow(color: isActive ? color.opacity(0.3) : .clear, radius: 4, x: 0, y: 0)
    }
}

// MARK: - Parameter Value Display

struct ParameterValueDisplay: View {
    let value: String
    let unit: String?
    let color: Color

    init(_ value: String, unit: String? = nil, color: Color = ColorPalette.textPrimary) {
        self.value = value
        self.unit = unit
        self.color = color
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(value)
                .font(Typography.valueSmall)
                .foregroundColor(color)

            if let unit = unit {
                Text(unit)
                    .font(Typography.unitLabel)
                    .foregroundColor(ColorPalette.textDimmed)
            }
        }
    }
}

// MARK: - LCD Value Display (Vintage Style)

struct LCDValueDisplay: View {
    let value: String
    let digits: Int
    let style: LCDStyle

    enum LCDStyle {
        case green
        case amber

        var textColor: Color {
            switch self {
            case .green: return ColorPalette.lcdGreen
            case .amber: return ColorPalette.lcdAmber
            }
        }

        var backgroundColor: Color {
            switch self {
            case .green: return ColorPalette.lcdGreenBg
            case .amber: return ColorPalette.lcdAmberBg
            }
        }
    }

    init(_ value: String, digits: Int = 4, style: LCDStyle = .green) {
        self.value = value
        self.digits = digits
        self.style = style
    }

    var body: some View {
        let paddedValue = String(value.prefix(digits)).padding(toLength: digits, withPad: " ", startingAt: 0)

        Text(paddedValue)
            .font(Typography.lcdMedium)
            .foregroundColor(style.textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(style.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(ColorPalette.divider, lineWidth: 1)
                    )
            )
            .shadow(color: style.textColor.opacity(0.2), radius: 4, x: 0, y: 0)
    }
}

// MARK: - Preview

#if DEBUG
struct Typography_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("GRAINULATOR")
                        .font(Typography.appTitle)
                        .foregroundColor(ColorPalette.ledBlue)

                    Text("Section Header")
                        .font(Typography.sectionHeader)
                        .foregroundColor(.white)

                    Text("Panel Title")
                        .font(Typography.panelTitle)
                        .foregroundColor(.white)
                }

                Divider()

                Group {
                    Text("CHANNEL LABEL")
                        .channelLabelStyle()

                    Text("PARAMETER")
                        .parameterLabelStyle()

                    Text("-12.5")
                        .valueDisplayStyle()

                    Text("EMBOSSED LABEL")
                        .embossedLabelStyle()
                }

                Divider()

                Group {
                    ScribbleStripView("PLAITS", color: ColorPalette.accentPlaits)
                    ScribbleStripView("RINGS", color: ColorPalette.accentRings, isActive: false)
                }

                Divider()

                Group {
                    ParameterValueDisplay("440.0", unit: "Hz")
                    ParameterValueDisplay("-6.0", unit: "dB", color: ColorPalette.vuYellow)
                }

                Divider()

                Group {
                    LCDValueDisplay("120", style: .green)
                    LCDValueDisplay("88.5", style: .amber)
                }
            }
            .padding()
        }
        .background(ColorPalette.backgroundPrimary)
    }
}
#endif

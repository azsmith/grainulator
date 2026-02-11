//
//  CompactClockOutputPad.swift
//  Grainulator
//
//  Compact clock output pad for the transport bar.
//  Tapping opens the ClockOutputConfigView popover.
//

import SwiftUI

struct CompactClockOutputPad: View {
    @ObservedObject var output: ClockOutput
    let index: Int

    @State private var showingConfig = false
    @State private var isHovering = false

    private var isActive: Bool {
        !output.muted && abs(output.currentValue) > 0.3
    }

    private var padColor: Color {
        if output.muted {
            return ClockOutputColors.groupColorsDim[min(index / 2, 3)].opacity(0.4)
        }
        return ClockOutputColors.color(for: index, active: isActive)
    }

    private var textColor: Color {
        if output.muted { return ColorPalette.textDimmed }
        if isActive && ClockOutputColors.needsDarkText(for: index) {
            return ClockOutputColors.darkText
        }
        return isActive ? .white : ColorPalette.textMuted
    }

    private var secondaryTextColor: Color {
        if output.muted { return ColorPalette.textDimmed.opacity(0.5) }
        if isActive && ClockOutputColors.needsDarkText(for: index) {
            return ClockOutputColors.darkText.opacity(0.6)
        }
        return isActive ? .white.opacity(0.6) : ColorPalette.textDimmed
    }

    var body: some View {
        Button(action: { showingConfig = true }) {
            VStack(spacing: 0) {
                // Output index
                Text("\(index + 1)")
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundColor(secondaryTextColor)

                // Division or waveform
                Text(output.mode == .clock ? output.division.rawValue : output.waveform.rawValue)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Mode label
                Text(output.mode == .clock ? "CLK" : "LFO")
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundColor(secondaryTextColor)
            }
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(padColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(
                        isActive ? ClockOutputColors.brightColor(for: index).opacity(0.6) : Color.clear,
                        lineWidth: isActive ? 1 : 0
                    )
            )
            .shadow(
                color: isActive ? ClockOutputColors.brightColor(for: index).opacity(0.3) : .clear,
                radius: isActive ? 3 : 0
            )
            .scaleEffect(isHovering ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button(output.muted ? "Unmute" : "Mute") {
                output.muted.toggle()
            }
        }
        .popover(isPresented: $showingConfig) {
            ClockOutputConfigView(output: output, index: index)
        }
    }
}

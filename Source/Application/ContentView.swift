//
//  ContentView.swift
//  Grainulator
//
//  Main content view that switches between different view modes
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    var body: some View {
        ZStack {
            Color(hex: "#1A1A1D")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Status bar
                StatusBarView()
                    .frame(height: 40)

                Divider()
                    .background(Color(hex: "#333333"))

                // Main content area - switches based on view mode
                Group {
                    switch appState.currentView {
                    case .multiVoice:
                        MultiVoiceView()
                    case .focus:
                        FocusView()
                    case .performance:
                        PerformanceView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                    .background(Color(hex: "#333333"))

                // Mixer at the bottom
                MixerView()
                    .frame(height: 200)
            }
        }
        .onAppear {
            audioEngine.start()
        }
        .onDisappear {
            audioEngine.stop()
        }
    }
}

// MARK: - Status Bar

struct StatusBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    var body: some View {
        HStack(spacing: 20) {
            // App title
            Text("GRAINULATOR")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#4A9EFF"))

            Spacer()

            // View mode selector
            HStack(spacing: 8) {
                ViewModeButton(mode: .multiVoice, label: "Multi")
                ViewModeButton(mode: .focus, label: "Focus")
                ViewModeButton(mode: .performance, label: "Perform")
            }

            Spacer()

            // CPU and latency monitoring
            HStack(spacing: 20) {
                StatusLabel(label: "CPU", value: String(format: "%.1f%%", appState.cpuUsage))
                StatusLabel(label: "Latency", value: String(format: "%.1fms", appState.latency))
            }
        }
        .padding(.horizontal, 20)
        .background(Color(hex: "#0F0F11"))
    }
}

struct ViewModeButton: View {
    @EnvironmentObject var appState: AppState
    let mode: AppState.ViewMode
    let label: String

    var isActive: Bool {
        appState.currentView == mode
    }

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                appState.switchToView(mode)
            }
        }) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? Color(hex: "#1A1A1D") : Color(hex: "#CCCCCC"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? Color(hex: "#4A9EFF") : Color.clear)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(hex: "#4A9EFF"), lineWidth: 1)
                        .opacity(isActive ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct StatusLabel: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#888888"))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#4A9EFF"))
        }
    }
}

// MARK: - Placeholder Views (to be implemented)

struct MultiVoiceView: View {
    var body: some View {
        Text("Multi-Voice View")
            .foregroundColor(.white)
    }
}

struct FocusView: View {
    var body: some View {
        Text("Focus View")
            .foregroundColor(.white)
    }
}

struct PerformanceView: View {
    var body: some View {
        Text("Performance View")
            .foregroundColor(.white)
    }
}

struct MixerView: View {
    var body: some View {
        HStack {
            Text("Mixer")
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#0F0F11"))
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

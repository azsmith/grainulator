//
//  RingsView.swift
//  Grainulator
//
//  Mutable Rings-inspired resonator controls.
//

import SwiftUI

struct RingsView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    @State private var modelIndex: Int = 0
    @State private var structure: Float = 0.4
    @State private var brightness: Float = 0.7
    @State private var damping: Float = 0.8
    @State private var position: Float = 0.3
    @State private var level: Float = 0.8
    @State private var note: Float = 48.0

    private let modelNames = [
        "Modal",
        "Sympathetic",
        "String",
        "FM Voice",
        "Symp Quant",
        "String+Rev"
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("RINGS")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00D1B2"))

                Spacer()

                Menu {
                    ForEach(modelNames.indices, id: \.self) { index in
                        Button(modelNames[index]) {
                            modelIndex = index
                            let normalized = Float(index) / Float(max(modelNames.count - 1, 1))
                            audioEngine.setParameter(id: .ringsModel, value: normalized)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(modelNames[modelIndex])
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#00D1B2"))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#252528"))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Button("STRIKE") {
                    audioEngine.noteOn(note: UInt8(note), velocity: 120)
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#0F0F11"))
                .frame(width: 76, height: 30)
                .background(Color(hex: "#00D1B2"))
                .cornerRadius(4)
                .buttonStyle(.plain)
            }

            HStack(spacing: 24) {
                ParameterSlider(label: "NOTE", value: Binding(
                    get: { (note - 24.0) / 72.0 },
                    set: { note = 24.0 + ($0 * 72.0) }
                ), color: Color(hex: "#00D1B2"))

                ParameterSlider(label: "STRUCT", value: $structure, color: Color(hex: "#4A9EFF"))
                    .onChange(of: structure) { audioEngine.setParameter(id: .ringsStructure, value: $0) }

                ParameterSlider(label: "BRIGHT", value: $brightness, color: Color(hex: "#FFD93D"))
                    .onChange(of: brightness) { audioEngine.setParameter(id: .ringsBrightness, value: $0) }

                ParameterSlider(label: "DAMP", value: $damping, color: Color(hex: "#FF8C42"))
                    .onChange(of: damping) { audioEngine.setParameter(id: .ringsDamping, value: $0) }

                ParameterSlider(label: "POS", value: $position, color: Color(hex: "#9B59B6"))
                    .onChange(of: position) { audioEngine.setParameter(id: .ringsPosition, value: $0) }

                ParameterSlider(label: "LEVEL", value: $level, color: Color(hex: "#00D1B2"))
                    .onChange(of: level) { audioEngine.setParameter(id: .ringsLevel, value: $0) }
            }
        }
        .padding(20)
        .background(Color(hex: "#0F0F11"))
        .cornerRadius(8)
        .onAppear {
            audioEngine.setParameter(id: .ringsModel, value: Float(modelIndex) / Float(max(modelNames.count - 1, 1)))
            audioEngine.setParameter(id: .ringsStructure, value: structure)
            audioEngine.setParameter(id: .ringsBrightness, value: brightness)
            audioEngine.setParameter(id: .ringsDamping, value: damping)
            audioEngine.setParameter(id: .ringsPosition, value: position)
            audioEngine.setParameter(id: .ringsLevel, value: level)
        }
    }
}

# Grainulator

A macOS granular/wavetable synthesizer with step sequencer, effects processing, and conversational AI control.

## Overview

Grainulator is a real-time synthesis workstation combining granular sampling, wavetable synthesis, drum machine, and chord-driven sequencing. It features:

- **Granular Synthesis Engine**: 4 independent voices with Morphagene-inspired controls (speed, pitch, size, density, jitter, spread, envelope shaping)
- **Plaits Synthesizer**: 16 synthesis models from Mutable Instruments (virtual analog, FM, wavetable, physical modeling, percussion)
- **Rings Synthesizer**: 6 resonator models from Mutable Instruments (modal, sympathetic, string, FM voice)
- **Drum Machine**: 4-lane percussion sequencer using Plaits drum engines with per-lane timbre controls
- **Step Sequencer**: 2 melodic tracks x 8 steps with probability, ratchets, gate modes, and flexible clock divisions
- **Chord Sequencer**: 8-step chord progression programmer feeding intervals into the melodic sequencer's scale system
- **SoundFont Sampler**: SF2/WAV sample playback with ADSR envelope and filter
- **Effects Chain**: Tape delay (with wow/flutter/sync), reverb, master filter
- **Modular Mixer**: Per-channel gain/pan/mute/solo, insert effects, send routing, micro-delay, phase invert
- **Master Clock**: Multi-output clock/LFO modulation system with per-output waveform, division, and destination
- **Conversational AI Control**: HTTP API on localhost:4850 for ChatGPT/Claude tool-calling integration
- **Project Save/Load**: Full project serialization with versioned snapshots
- **MIDI Support**: Note input, CC mapping, pitch bend

## Building

```bash
# Build from command line
swift build

# Run
.build/debug/Grainulator

# Or open in Xcode
open Package.swift
```

## Testing

```bash
swift test
```

## Project Structure

```
Grainulator/
├── Source/
│   ├── Audio/                          # C++ real-time audio engine
│   │   ├── Core/                       # Audio infrastructure, command queue
│   │   ├── Synthesis/                  # Plaits, Rings, granular engines
│   │   ├── Effects/                    # Delay, reverb, filter, inserts
│   │   └── Mixer/                      # Mixer routing and metering
│   │
│   ├── Application/                    # Swift application layer
│   │   ├── GrainulatorApp.swift        # App entry point, subsystem wiring
│   │   ├── ContentView.swift           # Main layout
│   │   ├── Models/                     # ProjectManager, ProjectSerializer, ProjectSnapshot
│   │   ├── Services/                   # ConversationalControlBridge, MIDI
│   │   ├── SequencerEngine.swift       # Step sequencer clock + state
│   │   ├── ChordSequencerEngine.swift  # Chord progression sequencer
│   │   ├── DrumSequencer.swift         # Drum machine sequencer
│   │   ├── MasterClock.swift           # Clock/LFO modulation system
│   │   └── Views/                      # SwiftUI views (Sequencer, Mixer, Synth, etc.)
│   │
│   └── BridgingHeader.h               # C++/Swift interop
│
├── Resources/                          # Samples, SoundFonts, presets
├── Tests/                              # Unit tests
├── scripts/                            # Test and utility scripts
│
├── ai-conversational-control-spec.md   # AI control system architecture
├── ai-conversational-control-api-spec.md # API endpoint specification
├── ai-conversational-control-openapi.yaml # OpenAPI 3.1.0 schema
└── CLAUDE.md                           # Claude Code project instructions
```

## Architecture

### Audio Engine (C++)
- Real-time DSP with lock-free command queue
- No allocations, locks, or blocking calls on the audio thread
- Granular synthesis, Plaits/Rings ports, effects processing, mixer routing

### Application Layer (Swift/SwiftUI)
- `@MainActor`-isolated state objects (`AudioEngineWrapper`, `StepSequencer`, `MasterClock`, `MixerState`, etc.)
- Minimoog-inspired dark UI with knob controls
- Project save/load with versioned JSON snapshots (currently version 4)

### Conversational Control Bridge
- HTTP/1.1 + WebSocket server on `127.0.0.1:4850`
- Bearer token session auth, idempotency keys, validate-then-schedule action model
- Canonical state snapshots, action bundles, event stream
- See `ai-conversational-control-api-spec.md` for full endpoint documentation

## Technology Stack

- **Platform**: macOS 13.0+
- **Languages**: Swift 5.9+ (UI/App), C++17 (Audio)
- **UI**: SwiftUI
- **Audio**: CoreAudio, AVFoundation
- **MIDI**: CoreMIDI
- **Build**: Swift Package Manager
- **Synthesis**: Mutable Instruments Plaits + Rings (MIT license)

## Acknowledgments

- **Mutable Instruments Plaits/Rings** by Emilie Gillet (MIT License)
- **Make Noise Morphagene** — granular synthesis inspiration
- **Mangl** (norns) — granular sampler inspiration

---

**Last Updated**: 2026-02-06

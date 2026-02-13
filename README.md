# Grainulator

A macOS granular/wavetable synthesizer with step sequencer, effects processing, and conversational AI control.

## Overview

Grainulator is a real-time synthesis workstation combining granular sampling, wavetable synthesis, drum machine, and chord-driven sequencing. It features:

- **Granular Synthesis Engine**: 4 independent voices with Morphagene-inspired controls (speed, pitch, size, density, jitter, spread, envelope shaping)
- **Plaits Synthesizer**: 24 synthesis engines from Mutable Instruments (virtual analog, phase distortion, FM, wavetable, wave terrain, string machine, chiptune, granular, additive, chords, speech/LPC, physical modeling, percussion) with engine crossfade, custom wavetable loading, and a 6-OP FM engine with DX7 patch (.syx) loading
- **Rings Synthesizer**: 6 resonator models from Mutable Instruments (modal, sympathetic, string, FM voice)
- **Drum Machine**: 4-lane percussion sequencer using Plaits drum engines with per-lane timbre controls
- **Step Sequencer**: 2 melodic tracks x 8 steps with probability, ratchets, gate modes, 12 playback directions, and flexible clock divisions
- **Chord Sequencer**: 8-step chord progression programmer feeding intervals into the melodic sequencer's scale system
- **Scramble**: Marbles-inspired probabilistic sequencer — 7 gate modes, 3 clocked note outputs with Spread/Bias/Quantize shaping, Deja Vu pattern memory, and flexible routing to any engine
- **SoundFont Sampler**: SF2/WAV sample playback with ADSR envelope and filter
- **Effects Chain**: Tape delay (with wow/flutter/sync), reverb, master filter
- **Modular Mixer**: Per-channel gain/pan/mute/solo, insert effects, send routing, micro-delay, phase invert
- **Master Clock**: Multi-output clock/LFO modulation system with per-output waveform, division, and destination
- **Conversational AI Control**: HTTP API on localhost:4850 for ChatGPT/Claude tool-calling integration
- **Project Save/Load**: Full project serialization with versioned snapshots
- **MIDI Support**: Note input, CC mapping, pitch bend

## Acknowledgements
This application has been built with the aid of AI coding tools. It builds on the work and ideas of many talented engineers who have created amazing instruments and systems for music creation, often sharing their work through open source software. These include [pichenettes](https://github.com/pichenettes) /Mutable Instruments, the basis of the synth engines and the design inspiration for the Scramble probabilistic sequencer (Marbles), [Tehn](https://github.com/tehn) for Mangl specifically and the entire Monome ecosystem, [Infintedigits](https://github.com/schollz) who created MX.Samples, the basis of the sample player, along with countless other Norns scripts, engineers at Make Noise, Intellijel, and ALM, among others. I'm also indebted to the community that has grown around monome instruments and the norns platform for many of the ideas found here.

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
│   │   ├── ScrambleEngine.swift        # Probabilistic sequencer algorithms (Marbles-inspired)
│   │   ├── ScrambleManager.swift       # Scramble transport, clock polling, routing
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
- Project save/load with versioned JSON snapshots (currently version 6)

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
- **Mutable Instruments Marbles** — probabilistic sequencer design inspiration for the Scramble module
- **Make Noise Morphagene** — granular synthesis inspiration
- **Mangl** (norns) — granular sampler inspiration

---

**Last Updated**: 2026-02-13

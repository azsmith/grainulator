# Grainulator

A macOS granular/wavetable synthesizer with step sequencer, effects processing, and conversational AI control.

## Overview

Grainulator is a real-time synthesis workstation combining granular sampling, wavetable synthesis, drum machine, and chord-driven sequencing. It features:

- **Granular Synthesis Engine**: 4 independent voices with Morphagene-inspired controls (speed, pitch, size, density, jitter, spread, envelope shaping)
- **Plaits Synthesizer**: 17 synthesis models from Mutable Instruments (virtual analog, FM, wavetable, physical modeling, percussion, six-op FM, speech/LPC) with engine crossfade and custom wavetable loading
- **Rings Synthesizer**: 6 resonator models from Mutable Instruments (modal, sympathetic, string, FM voice)
- **Drum Machine**: 4-lane percussion sequencer using Plaits drum engines with per-lane timbre controls
- **Step Sequencer**: 2 melodic tracks x 8 steps with probability, ratchets, gate modes, 12 playback directions, and flexible clock divisions
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

## Keyboard Shortcuts

### Transport

| Shortcut | Action |
|---|---|
| Space | Play / Stop |
| Return | Stop and reset to step 1 |
| Cmd+Up | Increase BPM by 1 |
| Cmd+Down | Decrease BPM by 1 |
| Cmd+Shift+Up | Increase BPM by 10 |
| Cmd+Shift+Down | Decrease BPM by 10 |
| Option+Up | Fine-adjust BPM (+0.1) |
| Option+Down | Fine-adjust BPM (-0.1) |
| Cmd+. | All notes off (panic) |

### Sequencer

| Shortcut | Action |
|---|---|
| Cmd+M | Toggle mute Track 1 |
| Cmd+Shift+M | Toggle mute Track 2 |

### Sequencer Directions

| Mode | Label | Pattern |
|------|-------|---------|
| Forward | FWD | 1, 2, 3, 4, 5, 6, 7, 8 |
| Reverse | REV | 8, 7, 6, 5, 4, 3, 2, 1 |
| Alternate | ALT | 1, 2, 3... 8, 7, 6... (ping-pong) |
| Random | RND | Random step each beat |
| Skip 2 | SKP2 | Every other: 1, 3, 5, 7, 2, 4, 6, 8 |
| Skip 3 | SKP3 | Every 3rd: 1, 4, 7, 2, 5, 8, 3, 6 |
| Climb 2 | CLM2 | Overlapping pairs: 1-2, 2-3, 3-4, 4-5... |
| Climb 3 | CLM3 | Overlapping triplets: 1-2-3, 2-3-4, 3-4-5... |
| Drunk | DRNK | Random walk +/-1 from current step |
| Random No Repeat | RN!R | Random, never same step twice in a row |
| Converge | CNVG | Outside-in: 1, 8, 2, 7, 3, 6, 4, 5 |
| Diverge | DIVG | Inside-out: 4, 5, 3, 6, 2, 7, 1, 8 |

### View / Navigation

| Shortcut | Action |
|---|---|
| Cmd+Shift+1 | Sequencer tab |
| Cmd+Shift+2 | Synths tab |
| Cmd+Shift+3 | Granular tab |
| Cmd+Shift+4 | Drums tab |
| X | Toggle mixer window |
| Cmd+0 | Multi-voice view |
| Cmd+1 - Cmd+4 | Focus granular voice 1-4 |
| Cmd+5 | Focus Plaits |
| Cmd+6 | Focus Rings |
| Cmd+7 | Focus Sampler |
| Cmd+8 | Focus Drums |
| Cmd+Shift+P | Performance view |
| Cmd+F | Cycle focus |

### Effects

| Shortcut | Action |
|---|---|
| Cmd+Shift+D | Toggle delay bypass |
| Cmd+Shift+R | Toggle reverb bypass |
| Cmd+Shift+F | Toggle master filter bypass |

### Project / File

| Shortcut | Action |
|---|---|
| Cmd+N | New project |
| Cmd+O | Open project |
| Cmd+S | Save project |
| Cmd+Shift+S | Save project as |
| Cmd+I | Import audio file |

### Audio Engine

| Shortcut | Action |
|---|---|
| Cmd+Shift+E | Start audio engine |
| Cmd+Option+E | Stop audio engine |
| Cmd+, | Audio settings |

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

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
- **SoundFont Sampler**: SF2/WAV sample playback with ADSR envelope and filter
- **Effects Chain**: Tape delay (with wow/flutter/sync), reverb, master filter
- **Modular Mixer**: Per-channel gain/pan/mute/solo, insert effects, send routing, micro-delay, phase invert
- **Master Clock**: Multi-output clock/LFO modulation system with per-output waveform, division, and destination
- **Conversational AI Control**: HTTP API on localhost:4850 for ChatGPT/Claude tool-calling integration
- **Project Save/Load**: Full project serialization with versioned snapshots
- **MIDI Support**: Note input, CC mapping, pitch bend

## Acknowledgements
This application has been built with the aid of AI coding tools. It builds on the work and ideas of many talented engineers who have created amazing instruments and systems for music creation, often sharing their work through open source software. These include [pichenettes](https://github.com/pichenettes) /Mutable Instruments, the basis of the synth engines, [Tehn](https://github.com/tehn) for Mangl specifically and the entire Monome ecosystem, [Infintedigits](https://github.com/schollz) who created MX.Samples, the basis of the sample player, along with countless other Norns scripts, engineers at Make Noise, Intellijel, and ALM, among others. I'm also indebted to the community that has grown around monome instruments and the norns platform for many of the ideas found here.

## Building

```bash
# Build from command line
swift build

# Run
.build/debug/Grainulator

# Or open in Xcode
open Package.swift
```


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

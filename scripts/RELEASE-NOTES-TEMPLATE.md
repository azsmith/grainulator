# Grainulator v__VERSION__

## What is Grainulator?

A macOS granular/wavetable synthesizer workstation with step sequencer, effects processing, and conversational AI control.

## System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3/M4) or Intel Mac
- Audio output device

## Installation

1. Download `Grainulator-__VERSION__.dmg` below
2. Open the DMG and drag **Grainulator** to your Applications folder
3. Launch from Applications — macOS may ask you to confirm since this is a new app
4. On first launch, grant microphone access if you want to record audio input

## What's Included

### Synthesis
- **Granular Engine** — 4 independent voices with Morphagene-inspired controls (speed, pitch, size, density, jitter, spread, envelope shaping)
- **Plaits** — 24 synthesis engines from Mutable Instruments (virtual analog, phase distortion, FM, wavetable, wave terrain, string machine, chiptune, granular, additive, chords, speech/LPC, physical modeling, percussion) plus a 6-OP FM engine with DX7 patch (.syx) loading
- **Rings** — 6 resonator models from Mutable Instruments (modal, sympathetic, string, FM voice)
- **Drum Machine** — 4-lane percussion sequencer using Plaits drum engines
- **SoundFont Sampler** — SF2/WAV sample playback with ADSR and filter

### Sequencing
- **Step Sequencer** — 2 melodic tracks × 8 steps with probability, ratchets, gate modes, 12 playback directions
- **Chord Sequencer** — 8-step chord progression programmer
- **Master Clock** — Multi-output clock/LFO modulation system

### Effects & Mixing
- **Tape Delay** with wow, flutter, and tempo sync
- **Reverb** and **Master Filter**
- **Modular Mixer** with per-channel gain, pan, mute/solo, insert effects, send routing

### Integration
- **Conversational AI Control** — HTTP API on localhost:4850 for ChatGPT/Claude tool-calling
- **MIDI** — Note input, CC mapping, pitch bend
- **Monome** — Arc and Grid controller support (requires serialosc)
- **Project Save/Load** — Full project serialization

## Hardware Controller Support

Monome Arc and Grid hardware is supported via serialosc. If you use Monome devices, install serialosc separately from [monome.org](https://monome.org/docs/serialosc/).

## Known Limitations

- <!-- List any known issues for this release -->
- Conversational AI bridge binds to localhost only (127.0.0.1:4850) — not accessible from other machines
- First launch may take a moment while macOS verifies the notarization

## Changelog

<!-- Specific changes for this release -->

### Added
-

### Changed
-

### Fixed
-

---

**Full documentation:** See [README](https://github.com/OWNER/Grainulator#readme)

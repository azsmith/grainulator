# Grainulator User Manual

---

## 1. Introduction

### 1.1 What Is Grainulator

Grainulator is a macOS synthesizer and sequencer that combines granular synthesis, wavetable playback, physical-modeling engines (Mutable Instruments Macro Osc and Resonator), a drum machine, a multi-track step sequencer, effects, and an HTTP API for AI-powered conversational control. It is designed for musicians and producers who want deep sound-design capabilities in a single integrated environment.

The application blends two worlds: the flexible, experimental character of hardware modular synthesizers with the recall and automation advantages of software. At its core are two synthesis lineages -- Mutable Instruments' open-source Macro Osc and Resonator DSP code (ported from the original C++ firmware) providing 17+6 synthesis models, and a custom four-voice granular engine with nine analog-modeled Moog ladder filter variants. A step sequencer with advanced direction modes, per-step probability and ratchets, and a chord progression engine ties everything together musically, while eight clock outputs with modulation routing let you animate any parameter from slow sweeps to audio-rate FM.

### 1.2 System Requirements

| Requirement | Minimum |
|---|---|
| Operating System | macOS 13 Ventura or later |
| Processor | Apple Silicon or Intel (64-bit) |
| RAM | 4 GB (8 GB recommended) |
| Audio | Built-in output or any CoreAudio-compatible interface |
| MIDI (optional) | Any CoreMIDI-compatible controller |
| Hardware controllers (optional) | Monome Arc 4, Monome Grid 128 via serialosc |

### 1.3 Installation

**From release build:**
Move `Grainulator.app` to `/Applications` and launch.

**From source:**
```bash
git clone <repo-url>
cd Grainulator
swift build
```
Or open the project in Xcode and build for macOS.

---

## 2. Interface Overview

### 2.1 Main Window Layout

The main window is divided into two areas:

1. **Transport bar** (top) -- transport controls, BPM, clock pads, and tab navigation.
2. **Workspace area** (below) -- the currently selected tab's content.

Two additional **floating windows** can be opened from the transport bar:
- **Mixer** -- channel levels, pans, sends, and master
- **Oscilloscope** -- real-time waveform display with dual-source overlay

### 2.2 Transport Bar

From left to right:

| Control | Description |
|---|---|
| **Play / Stop** | Start or stop the master transport (sequencer + drum machine) |
| **Record** | Toggle master output recording (WAV capture) |
| **BPM** | Draggable tempo display (range 20-300 BPM) |
| **Tap Tempo** | Tap repeatedly to set BPM from your tapping interval |
| **Swing** | Adjustable swing amount |
| **Clock Pads (1-8)** | Eight configurable clock outputs; tap to open configuration popover |
| **Tab Buttons** | SEQ, SYNTH, GRAN, DRUM |
| **Mixer** | Toggle the floating mixer window |
| **Scope** | Toggle the floating oscilloscope window |

### 2.3 Workspace Tabs

| Tab | Short Name | Content |
|---|---|---|
| SEQUENCER | SEQ | Step sequencer (2 tracks x 8 steps) + chord sequencer |
| SYNTHS | SYNTH | Macro Osc and Resonator synthesis panels |
| GRANULAR | GRAN | 4 granular voices + 2 looper voices |
| DRUMS | DRUM | DaisyDrums engine + 4-lane x 16-step drum sequencer |

---

## 3. Synthesis Engines

### 3.1 Macro Osc

Macro Osc is a macro-oscillator with **24 synthesis engines**, based on the full Mutable Instruments Macro Osc firmware (engine1 + engine2 generations). Every engine shares three main knobs -- **Harmonics**, **Timbre**, and **Morph** -- whose meaning changes per engine. The 6-OP FM engines support loading DX7 patches (.syx files).

#### Common Controls

| Control | Description |
|---|---|
| **Harmonics** | Model-dependent primary shape control |
| **Timbre** | Model-dependent spectral/brightness control |
| **Morph** | Model-dependent blend/variation control |
| **Level** | Voice output level (0-100%) |
| **Frequency / Note** | MIDI note pitch |
| **Trigger** | Manual gate button |

#### LPG (Low-Pass Gate)

| Control | Description |
|---|---|
| **Attack** | LPG envelope attack time |
| **Decay** | LPG envelope decay time |
| **Color** | LPG filter character (0 = pure VCA, 1 = VCA + low-pass filter) |
| **Bypass** | Disable the LPG entirely |

#### Model Reference

**Continuous engines (0-10)** -- produce sound continuously while gated:

| # | Name | Harmonics | Timbre | Morph | Musical Character |
|---|---|---|---|---|---|
| 0 | **Virtual Analog** | Detune amount | Pulse width / shape | Waveform blend | Classic subtractive synth -- fat basses, leads, pads. Two detunable oscillators with variable waveforms. |
| 1 | **Waveshaper** | Waveshape amount | Fold/drive intensity | Symmetry | Wavefolding distortion -- edgy, harmonically rich tones. Triangle wave through a waveshaper/folder. |
| 2 | **Two-Op FM** | FM ratio | FM amount / index | Feedback level | Two-operator FM -- electric pianos, bells, metallic textures. Phase modulation with operator feedback. |
| 3 | **Granular Formant** | Formant ratio | Formant frequency | Formant width | VOSIM/Pulsar synthesis -- vocal formants, buzzy resonant textures. |
| 4 | **Harmonic** | Number of bumps | Spectral centroid | Bump width | Additive synthesis with 24 harmonics -- organ-like, evolving spectral shapes. |
| 5 | **Wavetable** | Bank selection | Row (Y position) | Column (X position) | Wavetable scanning -- 4 built-in banks of 8x8 wavetables plus a user-loadable bank. Smooth morphing between waveforms. |
| 6 | **Chords** | Chord type | Inversion | Waveform | Four-note chord generator -- instant pads and stabs. Harmonics selects the chord voicing. |
| 7 | **Speech** | Synthesis mode* | Species (formant shift) | Vowel / phoneme | Vocal synthesis -- robotic speech, vowel drones, talking effects. Three modes controlled by Harmonics. |
| 8 | **Granular Cloud** | Pitch randomization | Grain density | Grain duration / overlap | Swarm of micro-enveloped grains -- ambient textures, shimmer, frozen sounds. |
| 9 | **Filtered Noise** | Filter type (LP→BP→HP) | Clock frequency | Resonance | Clocked noise through a resonant filter -- hi-hats, wind, rhythmic noise. |
| 10 | **Particle Noise** | Frequency randomization | Particle density | Filter type | Dust particles through bandpass filters -- crackle, rain, Geiger counter textures. |

*Speech synthesis modes (controlled by Harmonics):*
- **0.0 - 0.33: Formant synthesis** -- impulse train excitation through parallel resonant filters. Classic formant vocal sound with 16 phonemes.
- **0.33 - 0.66: SAM-like** -- shaped glottal pulse with formant filtering. More natural-sounding vocal character.
- **0.66 - 1.0: Word mode** -- LPC all-pole filter sequenced through phoneme chains. Morph selects from 8 pre-programmed words: "one", "two", "three", "four", "five", "alpha", "red", "hello". The Timbre knob shifts the formant frequencies up/down (species control), transforming the voice from deep/large to small/bright.

**Triggered engines (11-15)** -- have internal envelopes and respond to note-on events. They decay naturally and do not require the LPG:

| # | Name | Harmonics | Timbre | Morph | Musical Character |
|---|---|---|---|---|---|
| 11 | **String** | Inharmonicity / material | Excitation brightness | Decay time | Karplus-Strong physical modeling -- plucked strings, harps, metallic twangs. |
| 12 | **Modal** | Inharmonicity / material | Brightness | Decay time | Modal resonator -- bells, marimbas, glass, struck metal surfaces. |
| 13 | **Bass Drum** | Punch (pitch envelope) | Tone (brightness/drive) | Decay | Analog-style kick drum -- from tight 808 to booming sub hits. |
| 14 | **Snare Drum** | Snare wire amount | Tone balance (body vs crack) | Decay | Analog-style snare -- from tight rimshots to loose rattling snares. |
| 15 | **Hi-Hat** | Metallic tone frequency | Open/closed (decay time) | Additional decay | Analog-style hi-hat -- metallic overtones with variable open/closed behavior. |

**Six-Op FM (16):**

| # | Name | Harmonics | Timbre | Morph | Musical Character |
|---|---|---|---|---|---|
| 16 | **Six-Op FM** | Algorithm selection | Modulation depth | Operator balance | DX7-style 6-operator FM -- classic electric pianos, brass, pads, evolving textures. |

Six-Op FM provides classic DX7-style sounds with 6 operators arranged in **32 algorithms** (the same algorithm set as the Yamaha DX7). Per-operator frequency ratios and feedback are configured internally; the three macro knobs provide expressive real-time control over the sound. Harmonics sweeps through the algorithms, Timbre controls overall modulation intensity, and Morph adjusts the balance between operators for timbral variation.

#### Engine Crossfade

When switching models, Macro Osc performs a **30ms crossfade** between the old and new engine to avoid clicks.

#### Custom Wavetable Loading

When the **Wavetable** model (5) is selected, a **LOAD WAVETABLE** button appears. Click it to load a custom wavetable file into bank 4 (user bank). Set Harmonics >= 0.8 to select the user bank.

---

### 3.2 Resonator

Resonator is a physical-modeling resonator based on Mutable Instruments Resonator. It can be excited by its internal source or by audio from other engines.

#### Controls

| Control | Description |
|---|---|
| **Structure** | Resonator structure / geometry |
| **Brightness** | High-frequency content / excitation brightness |
| **Damping** | Decay time of resonances |
| **Position** | Excitation position along the resonator |
| **FM** | Frequency modulation amount (centered at 0.5 = no FM) |
| **Level** | Output level |

#### Models (6)

| # | Name | Character |
|---|---|---|
| 0 | **Modal** | Classic modal resonator -- bells, bars, plates, and tuned percussion. The Structure knob morphs the geometry from simple bar to complex plate. Brightness controls the high-frequency content of the excitation. |
| 1 | **Sympathetic** | Sympathetic string resonance -- sitar, tanpura, prepared piano. Multiple strings resonate sympathetically with the excited note. Structure controls the tuning spread between strings. |
| 2 | **String** | Plucked or bowed string -- guitar, harp, cello. A Karplus-Strong style model with rich, natural decay. Position controls where the string is excited (bridge to center). |
| 3 | **FM Voice** | FM synthesis voice through the resonator -- electric pianos, tubular bells, crystalline tones. Combines FM oscillators with physical modeling for hybrid timbres. |
| 4 | **Symp Quant** | Sympathetic strings with quantized tuning -- the sympathetic strings snap to musical intervals, producing more harmonically coherent resonance than the free-tuning Sympathetic model. |
| 5 | **String+Rev** | String model with built-in reverb -- adds a lush reverb tail to the string synthesis. Useful for ambient and atmospheric textures without needing the separate reverb send. |

#### Polyphony

Three modes: **1**, **2**, or **4** simultaneous voices. Higher polyphony enables chords and round-robin note allocation.

#### Chord Types (11)

When polyphony is set to 2 or 4, the chord selector determines the interval relationship between voices:

Oct, 5th, sus4, min, m7, m9, m11, 69, M9, M7, Maj

#### Exciter Source

The resonator can be excited by:

| Source | Description |
|---|---|
| Internal | Resonator's built-in noise/impulse exciter |
| Macro Osc | Audio from the Macro Osc engine |
| Granular 1 | Audio from granular voice 1 |
| Looper 1 | Audio from looper voice 1 |
| Looper 2 | Audio from looper voice 2 |
| Granular 4 | Audio from granular voice 4 |
| Drums | Audio from the DaisyDrums engine |
| Sampler | Audio from the SoundFont/WAV sampler |

---

### 3.3 DaisyDrums

DaisyDrums provides **5 percussive synthesis engines**, each with three shared macro knobs:

| Engine | Harmonics | Timbre | Morph |
|---|---|---|---|
| **Analog Kick** | Punch / pitch envelope | Tone / brightness | Decay |
| **Synth Kick** | Harmonics control | Timbre shaping | Morph blend |
| **Analog Snare** | Noise amount | Body / crack balance | Decay |
| **Synth Snare** | Harmonics control | Timbre shaping | Morph blend |
| **Hi-Hat** | Metallic tone | Open / closed amount | Decay |

Each engine also has a **Level** control and a **Note** control (MIDI note C1-C7 range) to set the drum's base pitch.

---

### 3.4 SoundFont / WAV Sampler

The sampler supports three instrument formats:

| Mode | Description |
|---|---|
| **SF2** | SoundFont 2 files with multiple presets and velocity layers |
| **SFZ** | SFZ format sample maps |
| **WAV** | Multi-sample WAV directories (mx.samples instruments) |

#### Controls

| Control | Description |
|---|---|
| **Attack** | Amplitude envelope attack time |
| **Decay** | Amplitude envelope decay time |
| **Sustain** | Amplitude envelope sustain level |
| **Release** | Amplitude envelope release time |
| **Filter Cutoff** | Low-pass filter cutoff frequency |
| **Filter Resonance** | Filter resonance amount |
| **Tuning** | Fine-tune adjustment |
| **Level** | Output level |

#### Loading Instruments

- **SF2/SFZ**: Click **LOAD** and browse for a `.sf2` or `.sfz` file. After loading, use the preset selector to choose instruments within the file.
- **WAV (mx.samples)**: Open the **Sample Library Browser** to browse, download, and load instruments from the mx.samples collection. Instruments are organized by category (Piano, Guitar, Strings, Woodwind, Brass, Percussion, Keys, Other).

---

## 4. Granular Synthesis

### 4.1 Overview

Grainulator provides **4 independent granular voices**, each with its own audio buffer, grain engine, and parameter set.

### 4.2 Loading Audio

Click the **LOAD** button on any voice to open a file browser. Supported formats include WAV, AIFF, MP3, and other formats supported by AVFoundation. After loading, the waveform is displayed above the parameter controls.

> **Tip:** Try loading different types of source material: field recordings, vocal samples, orchestral hits, or even full songs. Granular synthesis can transform any audio into entirely new textures. Short percussive samples work well for rhythmic granular patterns, while sustained tones are ideal for evolving ambient pads.

### 4.3 Grain Parameters

| Parameter | Description |
|---|---|
| **Speed** | Playback rate. 1.0 = normal, 0.5 = half speed, negative = reverse |
| **Pitch** | Pitch shift in semitones (independent of speed) |
| **Size** | Grain duration in milliseconds |
| **Density** | Number of overlapping grains per second |
| **Jitter** | Randomization of grain start position |
| **Spread** | Stereo width of the grain cloud (-1 to +1 pan range) |
| **Morph** | Additional timbral morphing / grain parameter variation |

### 4.4 Filter

Each granular voice has an independent **Moog ladder filter** with cutoff and resonance controls. Nine filter model variants are available, each with a distinct analog character:

| # | Model | Character |
|---|---|---|
| 0 | **Huovilainen** | Accurate Moog emulation, warm saturation |
| 1 | **Stilson** | Bright, aggressive resonance |
| 2 | **Microtracker** | Vintage tracker / chiptune feel |
| 3 | **Krajeski** | Balanced, musical self-oscillation |
| 4 | **MusicDSP** | General-purpose, efficient |
| 5 | **Oberheim** | Smooth Oberheim-style filtering |
| 6 | **Improved** | Enhanced Moog model with clean resonance |
| 7 | **RK Simulation** | Runge-Kutta circuit simulation, very smooth |
| 8 | **Hyperion** | Extended range, rich harmonics |

### 4.5 Grain Envelope Shapes

The grain window controls the amplitude envelope of each grain:

| Shape | Description |
|---|---|
| **Hanning** | Smooth bell curve (default) |
| **Gaussian** | Very smooth, narrow peak |
| **Trapezoid** | Flat top with linear ramps |
| **Triangle** | Simple linear fade in/out |
| **Tukey** | Flat center with cosine edges |
| **Pluck** | Fast exponential decay (plucked string character) |
| **Pluck Soft** | Slower exponential decay (nylon string character) |
| **Exp Decay** | Pure exponential decay from start (percussive) |

### 4.6 Recording into Buffers

Each granular voice can record audio directly into its buffer:

| Setting | Options |
|---|---|
| **Mode** | One-Shot (record once, stop) or Live Loop (continuous overdub) |
| **Source** | External (microphone/audio input), or internal engine channels |
| **Feedback** | Live loop overdub level (0 = destructive replace, 1 = full layer) |

---

## 5. Looper

### 5.1 Overview

Two independent **MLRE-inspired looper voices** provide tape-loop style recording and playback. The looper is inspired by the monome mlr/mlrv Max/MSP applications -- a performance-oriented tool for cutting, slicing, and manipulating audio in real time. Each looper voice maintains its own audio buffer that can be loaded from files or recorded live.

### 5.2 Controls

| Control | Description |
|---|---|
| **Rate** | Playback speed (0.25x to 4x) |
| **Reverse** | Toggle reverse playback |
| **Loop Start** | Start position within the buffer (0-1) |
| **Loop End** | End position within the buffer (0-1) |
| **Cut (1-8)** | Eight cut buttons that jump the playback position to evenly-spaced points in the buffer. Press Cut 1 to jump to the start, Cut 5 to jump to the middle, etc. |

> **Tip:** The cut buttons are designed for live performance. Load a drum loop and rapidly tap different cut positions to create stutter and rearrangement effects. Combine with rate changes and reverse for glitch-style performance. The looper output can also be routed as an exciter source for the Resonator, creating pitched resonances from rhythmic material.

### 5.3 Recording

Each looper voice supports recording from external inputs or internal engine sources, with the same mode (one-shot / live loop) and feedback controls as the granular voices.

---

## 6. Step Sequencer

### 6.1 Overview

The step sequencer provides **2 tracks x 8 steps**, with extensive per-step control and a rich scale/direction system. The two tracks run independently -- each can have its own clock division, direction mode, loop range, and output target. This means you can run a slow bass line on Track 1 targeting Macro Osc at /2 division while Track 2 plays a fast melodic pattern on Resonator at x4 division.

Each step displays its note name (derived from the current scale and root note), its step type label (PLY, SKP, ELD, RST, TIE), and a vertical pitch slider. Click any step to open its full configuration popover.

### 6.2 Track Settings

Each track has independent settings:

| Setting | Description |
|---|---|
| **Output** | Note target: Macro Osc, Resonator, Both, Drums, or Sampler |
| **Direction** | Playback direction (12 modes, see below) |
| **Division** | Clock division relative to master BPM (20 options, see below) |
| **Octave** | Base octave offset (-4 to +4) |
| **Transpose** | Semitone transposition (-24 to +24) |
| **Velocity** | Default MIDI velocity (1-127) |
| **Loop Start** | First step in the loop (1-8) |
| **Loop End** | Last step in the loop (1-8) |
| **Run** | Enable/disable this track independently |
| **Mute** | Silence output without stopping the sequence |

### 6.3 Per-Step Parameters

Click any step to open the detail popover:

| Parameter | Range | Description |
|---|---|---|
| **Note Slot** | 0-8 | Degree position within the current scale |
| **Octave** | -4 to +4 | Octave offset for this step |
| **Velocity** | 1-127 | MIDI velocity |
| **Probability** | 0-100% | Chance this step triggers |
| **Ratchets** | 1-8 | Repetitions within this step's time |
| **Pulses** | 1-8 | Number of sub-pulses per step |
| **Gate Mode** | 5 modes | Controls which ratchet pulses gate |
| **Step Type** | 5 types | Controls step behavior |
| **Gate Length** | 1-100% | Gate duration as fraction of pulse |
| **Slide** | On/Off | Portamento to the next note |

#### Gate Modes

| Mode | Behavior |
|---|---|
| **EVERY** | Gate on every ratchet pulse |
| **FIRST** | Gate only on the first ratchet pulse |
| **LAST** | Gate only on the last ratchet pulse |
| **TIE** | Gate on first pulse, held through the entire step |
| **REST** | No gate (silent step) |

#### Step Types

| Type | Behavior |
|---|---|
| **PLAY** | Normal note triggering |
| **SKIP** | Advance the sequence without triggering a note |
| **ELIDE** | Skip step without consuming a clock pulse |
| **REST** | Silent (no note, no advance) |
| **TIE** | Hold the gate from the previous note |

### 6.4 Direction Modes (12)

| Mode | Label | Behavior |
|---|---|---|
| Forward | FWD | Steps forward linearly |
| Reverse | REV | Steps backward linearly |
| Alternate | ALT | Bounces back and forth |
| Random | RND | Random step selection |
| Skip 2 | SKP2 | Advance by 2, multi-pass coverage |
| Skip 3 | SKP3 | Advance by 3, multi-pass coverage |
| Climb 2 | CLM2 | 2-step window slides forward |
| Climb 3 | CLM3 | 3-step window slides forward |
| Drunk | DRNK | Random +/-1 walk |
| Random No Repeat | RN!R | Random without repeating current step |
| Converge | CNVG | Converges toward center |
| Diverge | DIVG | Diverges from center outward |

### 6.5 Clock Divisions (20)

All divisions are relative to the master BPM quarter-note pulse:

| Division | Multiplier | Division | Multiplier |
|---|---|---|---|
| /16 | 1/16 | x4/3 | 4/3 |
| /12 | 1/12 | x3/2 | 3/2 |
| /8 | 1/8 | x2 | 2x (8th note) |
| /6 | 1/6 | x3 | 3x |
| /4 | 1/4 | x4 | 4x (16th note) |
| /3 | 1/3 | x6 | 6x |
| /2 | 1/2 (half note) | x8 | 8x |
| 2/3x | 2/3 | x12 | 12x |
| 3/4x | 3/4 | x16 | 16x |
| x1 | 1x (quarter note) | | |

### 6.6 Scale System (42 Scales)

The sequencer supports 42 built-in scales plus a dynamic Chord Sequencer mode. The root note selector (C through B) transposes all scales.

| # | Scale | Intervals | Notes |
|---|---|---|---|
| 0 | Major (Ionian) | 0,2,4,5,7,9,11 | 7 |
| 1 | Natural Minor (Aeolian) | 0,2,3,5,7,8,10 | 7 |
| 2 | Harmonic Minor | 0,2,3,5,7,8,11 | 7 |
| 3 | Melodic Minor | 0,2,3,5,7,9,11 | 7 |
| 4 | Dorian | 0,2,3,5,7,9,10 | 7 |
| 5 | Phrygian | 0,1,3,5,7,8,10 | 7 |
| 6 | Lydian | 0,2,4,6,7,9,11 | 7 |
| 7 | Mixolydian | 0,2,4,5,7,9,10 | 7 |
| 8 | Locrian | 0,1,3,5,6,8,10 | 7 |
| 9 | Whole Tone | 0,2,4,6,8,10 | 6 |
| 10 | Major Pentatonic | 0,2,4,7,9 | 5 |
| 11 | Minor Pentatonic | 0,3,5,7,10 | 5 |
| 12 | Major Bebop | 0,2,4,5,7,8,9,11 | 8 |
| 13 | Altered Scale | 0,1,3,4,6,8,10 | 7 |
| 14 | Dorian Bebop | 0,2,3,4,5,7,9,10 | 8 |
| 15 | Mixolydian Bebop | 0,2,4,5,7,9,10,11 | 8 |
| 16 | Blues Scale | 0,3,5,6,7,10 | 6 |
| 17 | Diminished Whole-Half | 0,2,3,5,6,8,9,11 | 8 |
| 18 | Diminished Half-Whole | 0,1,3,4,6,7,9,10 | 8 |
| 19 | Neapolitan Major | 0,1,3,5,7,9,11 | 7 |
| 20 | Hungarian Major | 0,3,4,6,7,9,10 | 7 |
| 21 | Harmonic Major | 0,2,4,5,7,8,11 | 7 |
| 22 | Hungarian Minor | 0,2,3,6,7,8,11 | 7 |
| 23 | Lydian Minor | 0,2,4,6,7,8,10 | 7 |
| 24 | Neapolitan Minor | 0,1,3,5,7,8,11 | 7 |
| 25 | Major Locrian | 0,2,4,5,6,8,10 | 7 |
| 26 | Leading Whole Tone | 0,2,4,6,8,10,11 | 7 |
| 27 | Six Tone Symmetrical | 0,1,4,5,8,9 | 6 |
| 28 | Balinese | 0,1,3,7,8 | 5 |
| 29 | Persian | 0,1,4,5,6,8,11 | 7 |
| 30 | East Indian Purvi | 0,1,4,6,7,8,11 | 7 |
| 31 | Oriental | 0,1,4,5,6,9,10 | 7 |
| 32 | Double Harmonic | 0,1,4,5,7,8,11 | 7 |
| 33 | Enigmatic | 0,1,4,6,8,10,11 | 7 |
| 34 | Overtone | 0,2,4,6,7,9,10 | 7 |
| 35 | Eight Tone Spanish | 0,1,3,4,5,6,8,10 | 8 |
| 36 | Prometheus | 0,2,4,6,9,10 | 6 |
| 37 | Gagaku Rittsu Sen Pou | 0,2,5,7,9 | 5 |
| 38 | In Sen Pou | 0,1,5,7,10 | 5 |
| 39 | Okinawa | 0,4,5,7,11 | 5 |
| 40 | Chromatic | 0-11 | 12 |
| 41 | Chord Sequencer | (dynamic) | varies |

Scale 41 (**Chord Sequencer**) replaces the fixed scale intervals with the intervals of whichever chord is active at the current sequencer step. This means the note slots in each step map into the chord tones rather than a static scale, enabling chord-aware melodic sequencing. See Section 7 for chord configuration.

### 6.7 Accumulator System

Each step has an optional **accumulator** that adds an evolving pitch offset over multiple passes:

| Parameter | Description |
|---|---|
| **Transpose** | Pitch offset per trigger (+/-7 scale degrees) |
| **Range** | Wrap boundary (1-7 scale degrees) |
| **Trigger** | When the counter increments: STG (per stage), PLS (per pulse), RCH (per ratchet) |
| **Mode** | STG (per-step counter) or TRK (shared across all steps) |

The accumulator formula wraps the counter symmetrically within +/- the range, creating rotating pitch patterns that evolve over time. For example, an accumulator with Transpose=2 and Range=3 would produce the offset sequence: 0, 2, -3, -1, 1, 3, -2, 0, 2, ... (wrapping at the boundaries).

**Practical examples:**
- **Slowly ascending melody**: Set Transpose=1, Range=7, Trigger=STG, Mode=TRK. Each time the sequence loops, the entire pattern shifts up by one scale degree, wrapping back after 7 degrees.
- **Ratchet-driven ornamentation**: Set Transpose=1, Range=2, Trigger=RCH. Within a single ratcheted step, each ratchet pulse shifts the note slightly, creating trill-like ornaments.
- **Per-step variation**: Set Trigger=STG, Mode=STG. Each step has its own independent counter, so step 1 might accumulate differently than step 5, creating polymetric pitch evolution.

---

## 7. Chord Sequencer

### 7.1 Overview

The chord sequencer provides an **8-step chord progression** that integrates with the step sequencer's scale system. When the scale is set to "Chord Sequencer" (scale #41), the step sequencer's note slots map to the intervals of the currently active chord rather than a fixed scale.

This creates a powerful harmonic framework: the chord sequencer defines the harmony, and the step sequencer creates melodies that automatically follow the chord changes. For example, if step 1 of the chord sequencer is "IV maj" and the step sequencer's note slot points to degree 2, it will play the third of the IV chord (the 2nd interval in [0, 4, 7]).

The chord sequencer UI is located below the two step sequencer tracks on the SEQ tab. It has its own clock division setting (independent of the track divisions) and can be muted globally.

### 7.2 Per-Step Configuration

Each of the 8 steps can have:
- A **degree** (root of the chord relative to the key)
- A **quality** (chord type: major, minor, diminished, etc.)
- An **active** toggle (mute individual steps)

### 7.3 Degrees (12)

| Degree | Semitones | Degree | Semitones |
|---|---|---|---|
| I | 0 | bV | 6 |
| bII | 1 | V | 7 |
| ii | 2 | bVI | 8 |
| bIII | 3 | vi | 9 |
| iii | 4 | bVII | 10 |
| IV | 5 | vii | 11 |

### 7.4 Qualities (17)

| Quality | Suffix | Intervals |
|---|---|---|
| Major | (none) | 0, 4, 7 |
| Minor | m | 0, 3, 7 |
| Diminished | ° | 0, 3, 6 |
| Augmented | + | 0, 4, 8 |
| Sus2 | sus2 | 0, 2, 7 |
| Sus4 | sus4 | 0, 5, 7 |
| Power | 5 | 0, 7 |
| Maj 7th | maj7 | 0, 4, 7, 11 |
| Min 7th | m7 | 0, 3, 7, 10 |
| Dom 7th | 7 | 0, 4, 7, 10 |
| Half-dim | ø7 | 0, 3, 6, 10 |
| Full-dim | °7 | 0, 3, 6, 9 |
| Dom 9th | 9 | 0, 4, 7, 10, 14 |
| Maj 9th | maj9 | 0, 4, 7, 11, 14 |
| Min 9th | m9 | 0, 3, 7, 10, 14 |
| Dom 11th | 11 | 0, 4, 7, 10, 14, 17 |
| Dom 13th | 13 | 0, 4, 7, 10, 14, 21 |

### 7.5 Presets

Four built-in presets populate the 8-step grid:

| Preset | Progression |
|---|---|
| **Pop** | I - V - vi - IV (repeated) |
| **Jazz** | ii m7 - V 7 - I maj7 (repeated with empties) |
| **Blues** | I 7 - I 7 - IV 7 - IV 7 - V 7 - IV 7 - I 7 - V 7 |
| **Emotional** | vi - IV - I - V (repeated) |

---

## 8. Drum Sequencer

### 8.1 Overview

The drum sequencer provides **4 lanes x 16 steps**, synced to the master transport. Each lane triggers one of the DaisyDrums engines. The 16-step grid provides classic drum machine programming -- click steps to toggle them on/off, adjust velocity per step, and shape each lane's sound with dedicated knob controls.

The drum sequencer runs on its own scheduling clock, synchronized to the master transport's start/stop but with an independent step division setting.

### 8.2 Lane Configuration

| Lane | Default Engine | Default Note |
|---|---|---|
| 0 | Analog Kick | C2 (36) |
| 1 | Synth Snare | D2 (38) |
| 2 | Analog Snare | E2 (52) |
| 3 | Hi-Hat | A4 (69) |

### 8.3 Per-Lane Controls

| Control | Description |
|---|---|
| **Level** | Lane output volume |
| **Harmonics** | Engine harmonics parameter |
| **Timbre** | Engine timbre parameter |
| **Morph** | Engine morph parameter |
| **Note** | MIDI note (C1-C7 range) |
| **Mute** | Silence the lane |

### 8.4 Per-Step Controls

Each of the 16 steps has:
- **Active** toggle (on/off)
- **Velocity** (0-1, mapped to MIDI velocity 1-127)

### 8.5 Step Division

The drum sequencer has its own clock division setting (default: x4 = 16th notes), using the same 20 divisions as the step sequencer.

---

## 9. Master Clock & Modulation

### 9.1 Master Clock

| Control | Description |
|---|---|
| **BPM** | Master tempo (20-300 BPM) |
| **Swing** | Swing amount for grooved timing |
| **Tap Tempo** | Tap repeatedly to detect tempo |

### 9.2 Clock Outputs (8)

Eight configurable clock outputs are displayed as pads in the transport bar. Each output can operate in one of two modes:

| Mode | Description |
|---|---|
| **CLK** | Clock/trigger mode -- generates gate/trigger pulses synced to BPM |
| **LFO** | Low-frequency oscillator mode -- generates continuous modulation waveforms |

### 9.3 Per-Output Settings

| Setting | Description |
|---|---|
| **Waveform** | Shape of the output signal (8 types) |
| **Division** | Clock division (same 20 options as the sequencer) |
| **Level** | Output amplitude (0-100%) |
| **Offset** | DC offset |
| **Phase** | Phase offset (0-360°) |
| **Width** | Pulse width (for gate/square waveforms) |
| **Slow Mode** | Extend the period for very slow modulation |
| **Mute** | Disable the output |

### 9.4 Waveform Types (8)

| Waveform | Label | Description |
|---|---|---|
| Gate | GATE | Gate/trigger pulse |
| Sine | SINE | Sine wave |
| Triangle | TRI | Triangle wave |
| Sawtooth | SAW | Sawtooth (descending) |
| Ramp | RAMP | Ramp (ascending) |
| Square | SQR | Square wave |
| Random | RAND | Random/noise |
| Sample & Hold | S&H | Stepped random values |

### 9.5 Modulation Destinations (25)

Each clock output can be routed to **one modulation destination**, creating up to 8 simultaneous modulation routings. The modulation signal (shaped by the output's waveform, level, and offset) is applied directly to the target parameter.

**Creative modulation ideas:**
- Route a slow sine LFO to Granular 1 Speed for evolving tape-speed effects.
- Route a fast S&H LFO to Macro Osc Timbre for glitchy random timbral variation.
- Route a triangle LFO to Delay Feedback at 1/4 division for rhythmic feedback swells.
- Route a gate clock at x8 division to Resonator Brightness for rhythmic resonance pulsing.

Available destinations:

**Macro Osc:** Harmonics, Timbre, Morph, LPG Decay

**Resonator:** Structure, Brightness, Damping, Position

**Delay:** Time, Feedback, Wow, Flutter

**Granular 1:** Speed, Pitch, Size, Density, Filter

**Granular 2:** Speed, Pitch, Size, Density, Filter

**DaisyDrums:** Harmonics, Timbre, Morph

---

## 10. Mixer

### 10.1 Signal Flow

The audio signal path in Grainulator follows this routing:

```
Synthesis Engines ──► Per-Channel (Level, Pan, Micro Delay) ──► Mix Bus
                  └──► Send A (pre/post fader) ──► Delay ──────► Mix Bus
                  └──► Send B (pre/post fader) ──► Reverb ─────► Mix Bus
                                                                    │
                                                          Master Filter
                                                                    │
                                                          Master Gain
                                                                    │
                                                          Audio Output
                                                         (+ Recording)
```

### 10.2 Channel Layout

The mixer window provides level, pan, and send controls for all audio sources:

| Channel | Source |
|---|---|
| 0 | Macro Osc |
| 1 | Resonator |
| 2 | Granular 1 |
| 3 | Granular 2 / Looper 1 |
| 4 | Looper 2 |
| 5 | Granular 4 |
| 6 | Drums |
| 11 | Sampler |

### 10.3 Per-Channel Controls

| Control | Range | Description |
|---|---|---|
| **Level** | 0-200% | Channel volume (0-1 normalized, maps to 0-2 for +6 dB headroom) |
| **Pan** | L-C-R | Stereo position (0.5 = center) |
| **Send A** | 0-100% | Delay send level |
| **Send B** | 0-100% | Reverb send level |
| **Micro Delay** | 0-50ms | Per-channel stereo delay for width |

### 10.4 Master Section

| Control | Description |
|---|---|
| **Master Gain** | Master output volume (0-200%, with +6 dB headroom above unity) |

> **Tip:** The mixer defaults all channels to unity gain. Use the micro delay on selected channels (even 1-5ms) to create subtle stereo width through the Haas effect. Pan the granular voices and loopers to different positions for a wide stereo image.

---

## 11. Effects

### 11.1 Delay

A tape-style delay with analog character, inspired by classic tape echo units:

| Parameter | Description |
|---|---|
| **Time** | Delay repeat rate -- the interval between echoes |
| **Feedback** | Regeneration amount -- higher values create more repeats. Near maximum, the delay enters self-oscillation, useful as a sound source itself. |
| **Mix** | Dry/wet balance -- 0% = dry signal only, 100% = wet signal only |
| **Head Mode** | Classic tape head configuration -- selects different multi-head playback patterns for rhythmic echo effects |
| **Wow** | Low-frequency pitch wobble -- emulates the slow speed variations of worn tape mechanisms. Adds warmth and organic movement. |
| **Flutter** | High-frequency pitch wobble -- emulates motor speed instability. Adds shimmer and chorus-like effects. |
| **Tone** | Delay tone -- sweeps from dark (tape-saturated, muffled) to bright (clean, present) |
| **Sync** | Free-running or tempo-synced -- when synced, the delay time locks to musical subdivisions of the master BPM |
| **Tempo** | Internal delay tempo (60-180 BPM) when Sync is off |
| **Subdivision** | Rhythmic division when Sync is on (quarter, eighth, dotted, triplet, etc.) |

> **Tip:** For dub-style delays, use moderate feedback with high wow and flutter, and a dark tone setting. For rhythmic delays, enable sync and experiment with different subdivisions. Route the delay via Send A in the mixer to control how much of each channel enters the delay.

### 11.2 Reverb

| Parameter | Description |
|---|---|
| **Size** | Room size -- from small room to large hall to infinite space. Higher values create longer, more diffuse reverb tails. |
| **Damping** | High-frequency damping -- controls how quickly high frequencies decay within the reverb. Low damping = bright, shimmery tail. High damping = dark, warm tail. |
| **Mix** | Dry/wet balance -- 0% = dry signal only, 100% = wet signal only |

> **Tip:** Route reverb via Send B in the mixer. For ambient textures, try high size with moderate damping. For percussive depth, use a short size with low damping. The reverb pairs especially well with the Resonator engine -- try setting Resonator to the String+Rev model with additional reverb send for massive spatial effects.

### 11.3 Master Filter

A global filter applied to the master output:

| Parameter | Description |
|---|---|
| **Cutoff** | Filter frequency (20 Hz - 20 kHz, logarithmic) |
| **Resonance** | Filter resonance amount |
| **Model** | Filter type selector (10 models, 0-9) |

---

## 12. Recording

### 12.1 Master Output Recording

Press the **Record** button on the transport bar to capture the master stereo output.

| Setting | Value |
|---|---|
| **Format** | WAV (Linear PCM) |
| **Sample Rate** | 48 kHz |
| **Bit Depth** | 24-bit integer |
| **Channels** | Stereo |
| **Save Location** | `~/Music/Grainulator/Recordings/` |
| **Filename** | `{ProjectName}_{YYYY-MM-DD_HH-mm-ss}.wav` |

The recordings directory is created automatically on first use.

### 12.2 Per-Voice Recording

Granular and looper voices can record audio directly into their buffers:

1. Select the **source** (external input or internal engine channel).
2. Choose the **mode** (one-shot or live loop).
3. Set **feedback** for live loop mode (0 = destructive, 1 = full overdub).
4. Press the voice's record button to start; press again to stop.

---

## 13. Project Management

### 13.1 Save / Load

Projects are saved as `.grainulator` JSON files.

### 13.2 What's Saved

A project snapshot includes:
- All synthesis parameters (Macro Osc, Resonator, DaisyDrums, Sampler)
- Granular voice parameters and audio buffer references
- Looper parameters and buffer references
- Step sequencer patterns (both tracks, all step data)
- Chord sequencer patterns
- Drum sequencer patterns
- Mixer state (levels, pans, sends)
- Effects parameters (delay, reverb, master filter)
- Clock output configuration (all 8 outputs)
- Master clock settings (BPM, swing, division)
- Scale and root note selection

### 13.3 Version History

The project format has evolved through 4 versions (v1-v4), with automatic migration from older formats. When opening a project saved in an older version, Grainulator automatically migrates it to the current format. Newly added parameters default to sensible values during migration.

> **Note:** Audio files (samples, granular buffers) are stored as file path references in the project JSON, not embedded. If you move audio files after saving a project, those references will need to be updated by re-loading the files.

---

## 14. Hardware Controllers

### 14.1 Monome Arc 4

The Monome Arc 4 provides 4 endless rotary encoders with LED ring feedback for hands-on control of granular and looper parameters.

#### Connection

The Arc connects via serialosc (USB). Grainulator listens on **port 17842** and discovers the Arc through the serialosc protocol on port 12002.

#### Encoder Mappings

**Primary layer (default):**

| Encoder | Parameter |
|---|---|
| 1 | Speed |
| 2 | Size |
| 3 | Density |
| 4 | Position |

**Shift layer (hold shift):**

| Encoder | Parameter |
|---|---|
| 1 | Jitter |
| 2 | Pitch |
| 3 | Filter Cutoff |
| 4 | Morph |

**Looper mode:** When a looper voice is selected, encoders map to looper-specific controls (rate, loop points, etc.).

#### LED Ring Feedback

Each encoder's LED ring displays the current parameter value in real time at 30 Hz. The ring brightness indicates the parameter position.

#### Tap-to-Record Gesture

Pressing an encoder can trigger recording into the associated granular/looper buffer.

---

### 14.2 Monome Grid 128

The Monome Grid 128 provides a 16x8 button grid with variable-brightness LEDs for step sequencer control.

#### Connection

The Grid connects via serialosc on **port 17843** (separate from the Arc's port). Grainulator uses the device prefix `/monome` with the standard `/grid` protocol paths.

#### Layout

**Step matrix (columns 0-7, rows 0-7):**
The left half of the grid displays the step sequencer pattern. Each column represents a step (1-8), and each row represents a note slot within the current scale. Press a button to set the note for that step.

**Control panel (columns 8-15):**
The right half of the grid provides:
- Track selection
- Loop start/end editing
- Chord editing mode
- Step type selection
- Gate mode selection

#### LED Feedback

LED output is rendered at 30 Hz using two 8x8 quadrant messages (`/monome/grid/led/level/map`). The current playhead position, active notes, and control state are shown with variable brightness.

---

## 15. MIDI

### 15.1 Auto-Discovery

Grainulator automatically detects connected MIDI devices via CoreMIDI. Devices appear immediately when plugged in.

### 15.2 Note Input

MIDI note-on and note-off messages are routed to Macro Osc and Resonator for real-time keyboard playing.

### 15.3 Default CC Mappings

| CC Number | Parameter |
|---|---|
| CC 1 (Mod Wheel) | Macro Osc Morph |
| CC 74 (Brightness) | Macro Osc Timbre |
| CC 71 (Resonance) | Macro Osc Harmonics |

---

## 16. Oscilloscope

The oscilloscope opens as a **floating window** and provides a real-time waveform display.

### Features

| Feature | Description |
|---|---|
| **Dual-source overlay** | Display two audio sources simultaneously for comparison |
| **Source selection** | Choose which engine/channel to visualize |
| **Time scale** | Adjust the horizontal zoom level |
| **Per-sample clock waveforms** | Visualize clock output signals alongside audio |

---

## 17. AI Conversational Control

Grainulator includes an HTTP API for AI-powered control, enabling natural-language interaction through tools like ChatGPT or Claude.

### 17.1 Connection

| Setting | Value |
|---|---|
| **Protocol** | HTTP/1.1 + WebSocket |
| **Address** | `127.0.0.1:4850` |
| **Base Path** | `/v1` |
| **Authentication** | Bearer token (obtained via session creation) |

### 17.2 Capabilities

The API provides:
- **Session management**: Create and delete authenticated sessions with scoped permissions
- **State reads**: Full snapshot, targeted path queries, state version history
- **Action bundles**: Validate-then-schedule pattern for reliable parameter changes with timing and quantization support
- **Recording control**: Start/stop recording, set feedback levels, change modes per voice
- **WebSocket events**: Real-time event stream at `/v1/events` for state change notifications

### 17.3 Usage with Claude Code

Use the `/grainulator` skill in Claude Code to control the running Grainulator app through natural language. For example: "set macro osc to the string model and play a C minor arpeggio at 120 BPM."

For full API details, see `ai-conversational-control-api-spec.md` and the OpenAPI schema in `ai-conversational-control-openapi.yaml`.

---

## 18. Settings

### 18.1 Audio

| Setting | Description |
|---|---|
| **Output Device** | Select the CoreAudio output device |
| **Input Device** | Select the CoreAudio input device (for recording) |
| **Sample Rate** | Audio sample rate |
| **Buffer Size** | Audio buffer size (latency vs stability tradeoff) |

### 18.2 Sample Library

| Setting | Description |
|---|---|
| **Sample Folders** | Manage folders that Grainulator scans for audio samples, SF2, and SFZ files |

---

## 19. Keyboard Shortcuts

### File

| Shortcut | Action |
|---|---|
| **Cmd + N** | New Project |
| **Cmd + O** | Open Project |
| **Cmd + S** | Save Project |
| **Cmd + Shift + S** | Save As |
| **Cmd + I** | Import Audio |

### Transport

| Shortcut | Action |
|---|---|
| **Space** | Play / Stop |
| **Return** | Stop & Reset |
| **Cmd + Up** | Increase BPM |
| **Cmd + Down** | Decrease BPM |
| **Cmd + Shift + Up** | Increase BPM x10 |
| **Cmd + Shift + Down** | Decrease BPM x10 |
| **Option + Up** | Fine increase BPM |
| **Option + Down** | Fine decrease BPM |
| **Cmd + .** | All Notes Off (panic) |

### View

| Shortcut | Action |
|---|---|
| **Cmd + Shift + 1** | Sequencer tab |
| **Cmd + Shift + 2** | Synths tab |
| **Cmd + Shift + 3** | Granular tab |
| **Cmd + Shift + 4** | Drums tab |
| **Cmd + 0** | Multi-voice view |
| **Cmd + 1-4** | Focus Granular voice 1-4 |
| **Cmd + 5** | Focus Macro Osc |
| **Cmd + 6** | Focus Resonator |
| **Cmd + 7** | Focus Sampler |
| **Cmd + 8** | Focus Drums |
| **X** | Toggle Mixer window |
| **Cmd + Shift + P** | Performance View |
| **Cmd + F** | Cycle Focus |

### Sequencer

| Shortcut | Action |
|---|---|
| **Cmd + M** | Mute Track 1 |
| **Cmd + Shift + M** | Mute Track 2 |

### Effects

| Shortcut | Action |
|---|---|
| **Cmd + Shift + D** | Toggle Delay Bypass |
| **Cmd + Shift + R** | Toggle Reverb Bypass |
| **Cmd + Shift + F** | Toggle Master Filter Bypass |

### Audio

| Shortcut | Action |
|---|---|
| **Cmd + Shift + E** | Start Audio Engine |
| **Cmd + Option + E** | Stop Audio Engine |
| **Cmd + ,** | Audio Settings |

---

---

## Appendix A: Workflow Tips

### Ambient Pad Creation
1. Load a textured audio file (field recording, orchestral sustain) into Granular Voice 1.
2. Set Size to large (70-90%), Density high, Speed slow (0.1-0.3).
3. Select the Gaussian or Tukey envelope for smooth overlapping grains.
4. Choose the Oberheim or RK Simulation filter model and sweep the cutoff slowly.
5. Route via Send B to the reverb (high size, moderate damping).
6. Assign a clock LFO with a slow sine wave to GR1:FILT for evolving filter movement.

### Rhythmic Glitch Patterns
1. Set up Track 1 with the Blues Scale, direction DRNK (Drunk Walk), division x4.
2. Set several steps to different ratchet counts (1, 3, 2, 4).
3. Mix gate modes: EVERY on some steps, FIRST on others, REST for silence.
4. Set probability to 60-80% on melodic steps for non-repetitive variation.
5. Target both Macro Osc (Virtual Analog model) and the drum sequencer simultaneously.

### Layered Drone Design
1. Use Macro Osc in Harmonic mode (model 4) as the tonal foundation.
2. Set Resonator to Sympathetic model with internal exciter, high damping, low brightness.
3. Record a sustained tone from Macro Osc into a granular buffer.
4. Process the granular voice with extreme settings: very slow speed, large size, low density.
5. Route all three sources through the mixer with different pan positions and send levels.
6. Add clock modulation: slow LFO on Macro Osc Morph, another on Resonator Structure.

### Live Performance Setup with Monome Grid
1. Program your base patterns in both sequencer tracks.
2. Set loop start/end to create short 2-3 step loops.
3. During performance, use the grid's right-side controls to expand/contract loop ranges.
4. Toggle between tracks to switch melodic focus.
5. Use chord mode on the grid to change harmonic context on the fly.
6. The grid's LED feedback shows the current playhead and active notes for visual orientation.

### Using the Chord Sequencer for Composition
1. Start with a preset (Pop, Jazz, Blues, Emotional) as a foundation.
2. Modify individual chord steps: try substituting minor for major, or adding 7th/9th extensions.
3. Set the step sequencer scale to "Chord Sequencer" (scale #41).
4. Program a melody in Track 1 -- the note slots now follow the chord tones automatically.
5. Set Track 2 to a different division for a counter-melody that also follows the chords.
6. Experiment with the chord sequencer's own clock division to change chord rhythm independently of the melody.

---

## Appendix B: Troubleshooting

| Issue | Solution |
|---|---|
| No sound output | Check that the correct audio output device is selected in Settings. Verify that at least one mixer channel has a non-zero level. Check that the master gain is up. |
| MIDI keyboard not detected | Ensure the MIDI device is connected before launching Grainulator. Check System Preferences for MIDI device recognition. |
| Monome Arc/Grid not connecting | Verify serialosc is running. Check that no other application is using the same serialosc port. Restart serialosc if needed. |
| Granular voice silent after loading | Press the voice's Play button. Verify Density is above 0 and Level is up in the mixer. |
| Sequencer not triggering notes | Ensure the transport is playing (Play button). Check that the track's Run toggle is enabled and Mute is off. Verify the Output is set to an active engine. |
| Recording produces empty file | Ensure the transport is playing and audio is routing to the master output before pressing Record. Check that master gain is not at zero. |
| Project file won't open | The file may be from a newer version of Grainulator. Update to the latest version. If audio files have been moved, re-load them manually. |
| High CPU usage | Reduce the number of active granular voices or lower grain density. Disable unused clock LFO outputs. Increase the audio buffer size in Settings. |

---

*Grainulator is built with open-source code from Mutable Instruments (Plaits, Rings) under the MIT License. DaisyDrums is based on code from Electro-Smith. Moog ladder filter implementations are from the open-source MoogLadders collection.*

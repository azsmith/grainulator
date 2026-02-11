# Grainulator Quick Start Guide

Grainulator is a macOS granular/wavetable synthesizer with a built-in step sequencer, physical-modeling engines, effects, and hardware controller support. This guide will get you making sounds in under five minutes.

---

## Installation

1. Download the latest `.app` from the releases page, or build from source:
   ```bash
   git clone <repo-url>
   cd Grainulator
   swift build
   ```
2. Move **Grainulator.app** to your Applications folder and launch it.
3. On first launch, grant microphone access if prompted (required for live audio recording into granular buffers).

---

## First Launch

When Grainulator opens you will see:

- **Transport bar** across the top: Play/Stop, Record, BPM display, tap tempo, eight clock output pads, and workspace tab buttons.
- **Workspace tabs** (right side of transport bar): **SEQ** | **SYNTH** | **GRAN** | **DRUM**
- **Floating windows**: Mixer and Oscilloscope can be opened from the transport bar.

The default view is the **SEQ** (sequencer) tab.

---

## Play Your First Sound

1. Click the **SYNTH** tab in the transport bar.
2. The **Macro Osc** synth panel appears. It defaults to *Virtual Analog* mode.
3. Click the **TRIGGER** button (or press a key on a connected MIDI keyboard) to hear a note.
4. Experiment with the three main knobs:
   - **HARMONICS** -- changes the waveform shape or timbre character
   - **TIMBRE** -- adjusts brightness or spectral content
   - **MORPH** -- blends between timbral variations
5. Open the model selector dropdown and try different engines: **Wavetable**, **Chords**, **Speech**, **String**, **Six-Op FM**, and more (17 models total).

> **Tip:** Models 11-15 (String through Hi-Hat) are *triggered* engines with built-in envelopes -- they respond to note-on events and decay naturally.

---

## Load a Sample into Granular

1. Click the **GRAN** tab.
2. On **Voice 1**, click the **LOAD** button and browse for an audio file (WAV, AIFF, MP3, etc.).
3. The waveform appears in the display. Click **PLAY** to start granular playback.
4. Adjust the grain parameters:
   - **SPEED** -- playback rate (negative = reverse)
   - **PITCH** -- pitch shift in semitones
   - **SIZE** -- grain duration
   - **DENSITY** -- how many grains overlap
   - **JITTER** -- randomize grain start position
   - **SPREAD** -- stereo width of grain cloud
   - **MORPH** -- additional timbral morphing
5. Try different **envelope shapes** (Hanning, Gaussian, Pluck, Trapezoid, etc.) and **filter models** (9 Moog ladder variants) using the dropdowns below the waveform.

---

## Program a Sequence

1. Click the **SEQ** tab.
2. You see **two tracks** of **8 steps** each. Click a step pad to set its pitch within the current scale.
3. Set the **root note** and **scale** using the dropdowns in the header row (42 scales available).
4. Press **Play** on the transport bar. The sequencer triggers notes on your selected output (Macro Osc, Resonator, Both, Drums, or Sampler).
5. Change the **direction** mode (Forward, Reverse, Alternate, Random, Drunk Walk, and more) and **clock division** to reshape the rhythm.
6. Click any step to open its detail popover: adjust **probability**, **ratchets**, **gate mode**, **step type**, **slide**, and the **accumulator** system for evolving pitch patterns.

> **Tip:** Enable the **Chord Sequencer** section below the tracks to drive an 8-step chord progression. Choose from presets (Pop, Jazz, Blues, Emotional) or program your own from 12 degrees and 17 chord qualities.

---

## Record Your Output

1. Press the **Record** button (circle icon) on the transport bar.
2. Audio is captured as a **48 kHz / 24-bit stereo WAV** file.
3. Press **Stop** to finish recording. Files are saved to:
   ```
   ~/Music/Grainulator/Recordings/
   ```
   Filenames follow the format `ProjectName_YYYY-MM-DD_HH-mm-ss.wav`.

---

## Explore Further

Now that you have the basics, dig into these features:

- **Resonator** -- physical-modeling resonator with 6 models, polyphony, and 11 chord types (SYNTH tab)
- **DaisyDrums** -- 5 percussive engines with a 4-lane x 16-step drum sequencer (DRUM tab)
- **Looper** -- 2 MLRE-inspired looper voices with rate control, reverse, and cut buttons (GRAN tab)
- **Mixer** -- per-channel level, pan, delay send, reverb send, and master volume (floating window)
- **Effects** -- tape-style delay (with wow & flutter) and reverb, plus a master filter
- **Clock Modulation** -- 8 configurable clock outputs (CLK or LFO mode) with 25 modulation destinations across all engines
- **Sampler** -- load SF2, SFZ, or WAV instruments with ADSR envelope and filter
- **Monome Arc / Grid** -- hardware controller integration for hands-on performance
- **MIDI** -- auto-discovered MIDI keyboards and controllers
- **AI Control** -- natural-language control via the HTTP API on `localhost:4850`

For full details on every parameter and feature, see the **[User Manual](User-Manual.md)**.

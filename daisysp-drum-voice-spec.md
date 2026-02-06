# DaisySP Drum Voice — Integration Mini-Spec

## Overview

Add a new **DaisyDrumVoice** to Grainulator, wrapping five drum synthesis models from the [DaisySP](https://github.com/electro-smith/DaisySP) library. This gives Grainulator a dedicated, high-quality drum voice with analog-modeled and synthetic drum sounds — distinct from the simpler percussion engines already inside Plaits (engines 13–15).

**License:** MIT — fully compatible with Grainulator's closed-source distribution.

**Origin:** The DaisySP drum modules were themselves ported from `pichenettes/eurorack` (Plaits DSP), but DaisySP extracted them into clean, standalone, single-sample-processing classes with zero hardware dependencies. This makes them significantly easier to integrate than going back to the original MI source.

---

## Engines (5 models)

| Index | Class | Description | Signature Sound |
|-------|-------|-------------|-----------------|
| 0 | `AnalogBassDrum` | Analog-modeled kick with bridged-T network | 808-style deep kick |
| 1 | `SyntheticBassDrum` | Synthetic kick with FM and dirt | 909-style punchy kick |
| 2 | `AnalogSnareDrum` | Analog-modeled snare with noise | 808-style snare |
| 3 | `SyntheticSnareDrum` | Synthetic snare, two oscillators + filtered noise | 909-style snare |
| 4 | `HiHat<>` | Metallic noise through bandpass, template class | 808/909 hi-hat |

---

## DaisySP Source Files Required

Copy these files from `DaisySP/Source/` into the Grainulator project. No build system or library linkage needed — just raw `.h/.cpp` pairs.

### Drum modules (primary)
```
Drums/analogbassdrum.h      Drums/analogbassdrum.cpp
Drums/synthbassdrum.h        Drums/synthbassdrum.cpp
Drums/analogsnaredrum.h      Drums/analogsnaredrum.cpp
Drums/synthsnaredrum.h       Drums/synthsnaredrum.cpp
Drums/hihat.h                Drums/hihat.cpp
```

### Internal dependencies (required by drum modules)
```
Filters/svf.h                Filters/svf.cpp           — used by HiHat
Synthesis/oscillator.h       Synthesis/oscillator.cpp   — used by HiHat
Utility/dsp.h                                           — fclamp, fmap, mtof, etc.
```

### Suggested project location
```
Source/Audio/Synthesis/DaisyDrums/
├── DaisyDrumVoice.h
├── DaisyDrumVoice.cpp
└── DaisySP/                    ← vendored source (keep namespace intact)
    ├── Drums/
    ├── Filters/
    ├── Synthesis/
    └── Utility/
```

### Namespace handling

DaisySP uses `namespace daisysp`. Keep it as-is to minimize edits to vendored code. The wrapper class lives in `namespace Grainulator` and references DaisySP types internally via `daisysp::`.

---

## Wrapper Class: `DaisyDrumVoice`

Follows the established PlaitsVoice / RingsVoice pattern: `Init()` / `Render()` / setters.

### Header

```cpp
// DaisyDrumVoice.h
#ifndef DAISYDRUMVOICE_H
#define DAISYDRUMVOICE_H

#include <cstddef>

namespace Grainulator {

class DaisyDrumVoice {
public:
    enum Engine {
        AnalogKick = 0,
        SyntheticKick,
        AnalogSnare,
        SyntheticSnare,
        HiHat,
        NumEngines
    };

    DaisyDrumVoice();
    ~DaisyDrumVoice();

    void Init(float sample_rate);

    // Block-based render (matches PlaitsVoice signature)
    // aux can be nullptr; drums are mono, aux gets a filtered/alt version
    void Render(float* out, float* aux, size_t size);

    // Engine selection (0–4)
    void SetEngine(int engine);
    int  GetEngine() const { return engine_; }

    // Frequency via MIDI note (converted to Hz internally)
    void SetNote(float note);

    // Unified parameter interface (all 0.0–1.0)
    // Mapping varies per engine — see Parameter Mapping table below
    void SetHarmonics(float value);   // Param A: tone/character
    void SetTimbre(float value);      // Param B: color/brightness
    void SetMorph(float value);       // Param C: decay/snappiness

    // Trigger (true = strike the drum)
    void Trigger(bool state);

    // Accent/velocity (0.0–1.0)
    void SetLevel(float value);

    // Modulation amounts (for clock mod routing, same as Plaits)
    void SetHarmonicsMod(float amount);
    void SetTimbreMod(float amount);
    void SetMorphMod(float amount);

private:
    float sample_rate_;
    int   engine_;
    float note_;
    float harmonics_, timbre_, morph_;
    float level_;
    float harmonics_mod_, timbre_mod_, morph_mod_;
    bool  trigger_state_;
    bool  prev_trigger_;

    // DaisySP engine instances (void* to avoid header leakage)
    void* analog_kick_;
    void* synth_kick_;
    void* analog_snare_;
    void* synth_snare_;
    void* hihat_;

    DaisyDrumVoice(const DaisyDrumVoice&) = delete;
    DaisyDrumVoice& operator=(const DaisyDrumVoice&) = delete;
};

} // namespace Grainulator
#endif
```

### Key implementation details

**Sample-by-sample → block adapter.** DaisySP modules process one sample at a time via `Process(bool trigger)`. The `Render()` method loops over the block:

```cpp
void DaisyDrumVoice::Render(float* out, float* aux, size_t size) {
    bool should_trigger = trigger_state_ && !prev_trigger_;
    prev_trigger_ = trigger_state_;

    // Apply modulation
    float h = std::clamp(harmonics_ + harmonics_mod_, 0.f, 1.f);
    float t = std::clamp(timbre_ + timbre_mod_, 0.f, 1.f);
    float m = std::clamp(morph_ + morph_mod_, 0.f, 1.f);

    // Map unified params to engine-specific setters (see table below)
    // ... SetFreq, SetTone, SetDecay, etc. per engine ...

    for (size_t i = 0; i < size; ++i) {
        bool trig = (i == 0) && should_trigger;
        float sample = 0.f;

        switch (engine_) {
            case AnalogKick:
                sample = static_cast<daisysp::AnalogBassDrum*>(analog_kick_)->Process(trig);
                break;
            // ... other engines ...
        }

        sample *= level_;
        sample = std::tanh(sample * 1.5f) * 0.67f;  // soft clip (matches Plaits)

        if (out) out[i] = sample;
        if (aux) aux[i] = sample * 0.7f;  // aux = attenuated copy
    }

    if (should_trigger) trigger_state_ = false;  // auto-clear after processing
}
```

---

## Parameter Mapping

Unified Harmonics / Timbre / Morph knobs map to engine-specific parameters. Note is always mapped to `SetFreq()` via `mtof()`.

| Engine | Harmonics (Param A) | Timbre (Param B) | Morph (Param C) |
|--------|-------------------|-----------------|----------------|
| **AnalogKick** | Tone (brightness) | AttackFmAmount (punch) | Decay |
| **SyntheticKick** | Tone (brightness) | FmAmount (punch) | Decay |
| **AnalogSnare** | Tone (body vs crack) | Snappy (noise mix) | Decay |
| **SyntheticSnare** | FmAmount (pitch sweep) | Snappy (noise mix) | Decay |
| **HiHat** | Tone (filter color) | Noisiness (metallic) | Decay |

### Additional per-engine parameters accessed via Harmonics/Timbre

These DaisySP setters are available but not all exposed in v1. Could be added later via additional parameter IDs or by subdividing the knob ranges:

- `AnalogBassDrum::SetSelfFmAmount()`, `SetDirtiness()`
- `SyntheticBassDrum::SetDirtiness()`
- All engines: `SetSustain(bool)` — infinite drone mode (could be a toggle)
- All engines: `SetAccent()` — mapped from velocity/level already

---

## AudioEngine Integration

### Mixer channel assignment

Current channel map: `0=Plaits, 1=Rings, 2=Granular1, 3=Looper1, 4=Looper2, 5=Granular4`

**Option A (recommended): Expand to 7 channels.** Add channel 6 for DaisyDrums. This requires bumping `kNumMixerChannels` from 6 → 7 (and `kNumMixerChannelsForRing` similarly). All mixer arrays already use the constant, so this is safe. The multi-channel AU output grows to 7 stereo pairs (14 buffers).

**Option B: Steal channel 5.** Repurpose the Granular4 slot if it's underused. Less invasive but loses a granular track.

### Voice instance

Single instance (drums are monophonic — one sound at a time, retriggered). No polyphony or voice allocation needed.

```cpp
// In AudioEngine.h
#include <memory>
class DaisyDrumVoice;  // forward declare

// In private members:
std::unique_ptr<DaisyDrumVoice> m_daisyDrumVoice;
```

### Initialization (in `AudioEngine::initialize()`)

```cpp
m_daisyDrumVoice = std::make_unique<DaisyDrumVoice>();
m_daisyDrumVoice->Init(static_cast<float>(sampleRate));
```

### Render path (in `process()` and `processMultiChannel()`)

Render the drum voice into its own channel buffer, same pattern as Rings:

```cpp
// Render DaisyDrums into channel 6
float drumOutL[kMaxBufferSize] = {0};
float drumOutR[kMaxBufferSize] = {0};
m_daisyDrumVoice->Render(drumOutL, nullptr, numFrames);
// Mono → stereo (center pan by default, respect m_channelPan[6])
for (int i = 0; i < numFrames; ++i) {
    drumOutR[i] = drumOutL[i];  // mono duplicate, pan applied by mixer
}
// Feed into mixer channel 6
```

### MIDI routing

Add a new `NoteTarget` bit:

```cpp
enum NoteTarget : uint8_t {
    TargetPlaits    = 1 << 0,
    TargetRings     = 1 << 1,
    TargetDaisyDrum = 1 << 2,
    TargetAll       = TargetPlaits | TargetRings | TargetDaisyDrum
};
```

In `noteOnTarget()`:
```cpp
if (targetMask & TargetDaisyDrum) {
    m_daisyDrumVoice->SetNote(static_cast<float>(note));
    m_daisyDrumVoice->SetLevel(static_cast<float>(velocity) / 127.f);
    m_daisyDrumVoice->Trigger(true);
}
```

### New ParameterIDs

```cpp
// In ParameterID enum:
DaisyDrumEngine,       // 0–4 (engine select)
DaisyDrumHarmonics,    // 0–1
DaisyDrumTimbre,       // 0–1
DaisyDrumMorph,        // 0–1
DaisyDrumLevel,        // 0–1
```

### Bridge additions

```cpp
// In AudioEngineBridge.h:
void AudioEngine_SetDaisyDrumEngine(AudioEngineHandle handle, int engine);
void AudioEngine_TriggerDaisyDrum(AudioEngineHandle handle, bool state);
```

### Clock modulation destinations

Add to `ModulationDestination` enum:

```cpp
DaisyDrumHarmonics,
DaisyDrumTimbre,
DaisyDrumMorph,
```

This allows the Pam's-style clock outputs to modulate drum parameters — great for evolving drum patterns.

---

## Build Integration (Xcode)

1. Add all vendored DaisySP `.h/.cpp` files to the Xcode project under the `DaisyDrums` group.
2. Add `Source/Audio/Synthesis/DaisyDrums/DaisySP/` to Header Search Paths.
3. Add `DaisyDrumVoice.cpp` and all DaisySP `.cpp` files to the Compile Sources build phase.
4. May need to suppress some warnings in DaisySP code (`-Wno-missing-field-initializers` etc.) — set per-file compiler flags if needed.
5. DaisySP uses `#include "dsp.h"` style relative includes internally. May need a few `#include` path fixups depending on directory layout. Alternatively, flatten the DaisySP source into one directory.

### Potential build issues

- DaisySP's `dsp.h` uses `fclamp()` which may conflict with system headers. If so, wrap in `namespace daisysp` or rename.
- The `HiHat` class is a template (`HiHat<MetallicNoiseSource, VCA, resonance>`). Check the default typedefs in `hihat.h` — there should be a concrete `SquareNoise`-based typedef ready to use.
- ARM-specific NEON/FPU intrinsics in DaisySP are guarded by `#ifdef __arm__` — on macOS x86/ARM64 these are skipped, so no issue.

---

## Swift UI (Minimal v1)

Reuse the existing Plaits-style knob layout since the interface is identical:

- **Engine selector** — segmented control or picker: Analog Kick / Synth Kick / Analog Snare / Synth Snare / HiHat
- **Three knobs** — labeled contextually per engine (e.g., "Tone / Punch / Decay" for kicks)
- **Trigger button** — manual hit (useful for sound design)
- **Mixer strip** — channel 6 fader, pan, send A/B (reuses existing MixerChannelView)

The sequencer's existing note routing already supports target masks, so sequencing drums requires only adding the DaisyDrum target checkbox.

---

## Testing Checklist

- [ ] All 5 engines produce audio on trigger
- [ ] MIDI note changes pitch correctly (especially kicks respond to note, hihats less so)
- [ ] Harmonics/Timbre/Morph knobs sweep full range without clicks or artifacts
- [ ] Velocity → accent mapping works (soft hits vs hard hits)
- [ ] Fast retrigger (16th notes at 160 BPM) — no audio glitches
- [ ] Clock modulation routes to drum params correctly
- [ ] Mixer channel 6: gain, pan, send A/B, mute/solo all work
- [ ] Multi-channel AU output includes drum channel
- [ ] CPU load acceptable (DaisySP is very lightweight — expect < 1% per voice)

---

## Future Enhancements (v2+)

- **Kit mode:** Map different engines to different MIDI note ranges (e.g., C1=kick, D1=snare, F#1=hat) within a single voice — true drum machine behavior.
- **Per-engine extended params:** Expose `SetDirtiness()`, `SetSelfFmAmount()`, `SetSustain()` as additional knobs or via a "deep edit" panel.
- **Additional DaisySP voices:** `ModalVoice` and `StringVoice` from DaisySP's PhysicalModeling folder use the same `Init()/Process()/Trig()` pattern and could be added as engines 5–6 with minimal effort.
- **Accent patterns:** Dedicated accent sequencer lane that modulates `SetAccent()` per step.

# Plaits Integration Strategy

## Overview

This document outlines the strategy for integrating Mutable Instruments Plaits synthesis engine into Grainulator.

**Date**: February 1, 2026
**Phase**: Phase 1, Week 3-4
**Source**: Mutable Instruments Eurorack (MIT License)

---

## Integration Approach

### Phase 1: Minimal DSP-Only Port

**Goal**: Get one Plaits engine working with audio output

**Steps**:
1. Extract core DSP files (no hardware dependencies)
2. Port stmlib utilities needed for DSP
3. Create C++ wrapper matching our AudioEngine interface
4. Implement one simple engine (Virtual Analog) for testing
5. Bridge to Swift for parameter control
6. Verify audio output

**Files to Port First**:
- `plaits/dsp/voice.h/cc` - Main synthesis controller
- `plaits/dsp/engine/engine.h` - Base engine interface
- `plaits/dsp/engine/virtual_analog_engine.h/cc` - First test engine
- Selected stmlib utilities (filters, interpolators, oscillators)

### Phase 2: All 16 Engines

**Goal**: Port all synthesis models

**Order** (by complexity, easiest first):
1. ✅ Virtual Analog (Phase 1)
2. Waveshaping
3. FM
4. Wavetable (requires resource data)
5. Additive
6. Chord
7. Grain
8. Formant
9. Speech (requires resource data)
10. Noise
11. Particle
12. Swarm
13. Bass Drum
14. Snare Drum
15. Hi-Hat
16. Modal/String (physical modeling)

### Phase 3: Resources & Optimization

**Goal**: Add wavetable data and optimize performance

**Tasks**:
- Port wavetable generation scripts
- Convert binary resources to macOS-friendly format
- Optimize for real-time performance
- Add LPG (low-pass gate) processing
- Implement auxiliary outputs

---

## Architecture Integration

### Current Grainulator Architecture

```
AudioEngineWrapper (Swift) @ Main Thread
    ↓ Commands
AudioEngine (C++) @ Audio Thread
    ├── Granular Voices [To Be Implemented]
    ├── Plaits Voice [NEW]
    ├── Effects Chain
    └── Mixer
```

### Plaits Integration Point

```
AudioEngine::process()
    ├── Process Granular Voices (4x)
    ├── Process Plaits Voice ← NEW
    │   ├── Voice::Render()
    │   │   ├── Engine Selection
    │   │   ├── Modulation
    │   │   └── Current Engine::Render()
    │   └── LPG Processing
    ├── Apply Effects
    └── Mix to Output
```

### Parameter Mapping

**Plaits Parameters** → **Grainulator Parameters**:
- `note` ← MIDI note + pitch CV
- `harmonics` ← Harmonics knob (0.0-1.0)
- `timbre` ← Timbre knob (0.0-1.0)
- `morph` ← Morph knob (0.0-1.0)
- `trigger` ← Gate/trigger from MIDI
- `level` ← Accent/velocity
- `engine` ← Model selector (0-15)

**Modulation Sources**:
- Internal envelopes
- External CV (future)
- LFO (future)

---

## File Organization

### Source Directory Structure

```
Source/Audio/Synthesis/Plaits/
├── Core/
│   ├── voice.h/cc              # Main Plaits voice
│   ├── dsp.h                   # DSP constants
│   └── engine_quantizer.h      # Engine selection
│
├── Engines/
│   ├── engine.h                # Base engine class
│   ├── virtual_analog_engine.h/cc
│   ├── waveshaping_engine.h/cc
│   ├── fm_engine.h/cc
│   └── ... (all 16 engines)
│
├── DSP/                        # Supporting DSP modules
│   ├── oscillator/
│   ├── physical_modelling/
│   ├── fm/
│   ├── drums/
│   └── ...
│
├── Resources/
│   ├── wavetables.h/cc         # Wavetable data
│   ├── lookup_tables.h/cc      # Mathematical tables
│   └── fm_patches.h/cc         # FM configurations
│
└── stmlib/                     # Ported utilities
    ├── dsp/
    │   ├── filter.h
    │   ├── parameter_interpolator.h
    │   ├── polyblep.h
    │   └── ...
    └── utils/
        └── ...
```

### Wrapper Interface

```cpp
// PlaitsVoice.h - Our C++ wrapper
class PlaitsVoice {
public:
    void Init(float sample_rate);
    void Render(float* out, float* aux, size_t size);

    // Parameter setters (thread-safe)
    void SetEngine(int engine);
    void SetNote(float note);         // MIDI note number
    void SetHarmonics(float value);   // 0.0-1.0
    void SetTimbre(float value);      // 0.0-1.0
    void SetMorph(float value);       // 0.0-1.0
    void Trigger(bool state);
    void SetLevel(float value);       // 0.0-1.0

private:
    plaits::Voice voice_;
    float sample_rate_;
};
```

---

## Implementation Plan

### Week 3: Core Voice Implementation

**Day 1-2: Foundation**
- [ ] Copy essential Plaits DSP files
- [ ] Copy required stmlib utilities
- [ ] Create PlaitsVoice wrapper class
- [ ] Set up build configuration
- [ ] Test compilation

**Day 3-4: Virtual Analog Engine**
- [ ] Port Virtual Analog engine
- [ ] Port supporting oscillator code
- [ ] Implement parameter handling
- [ ] Test audio output (sine wave)
- [ ] Verify parameter changes work

**Day 5: Integration**
- [ ] Integrate PlaitsVoice into AudioEngine
- [ ] Add Plaits to audio callback
- [ ] Create Swift bridge for parameters
- [ ] Test end-to-end (UI → Audio)

### Week 4: Remaining Engines & UI

**Day 1-3: Engine Porting**
- [ ] Port remaining 15 engines
- [ ] Port supporting DSP modules
- [ ] Port wavetable/resource data
- [ ] Test each engine individually

**Day 4-5: UI Implementation**
- [ ] Create Plaits UI component
- [ ] Add model selector (dropdown)
- [ ] Add parameter knobs (Harmonics, Timbre, Morph)
- [ ] Add MIDI keyboard input
- [ ] Create envelope visualization
- [ ] Test all models through UI

---

## Dependencies to Port

### From stmlib (Priority Order)

**Essential** (needed immediately):
1. `dsp/parameter_interpolator.h` - Smooth parameter transitions
2. `dsp/units.h` - Unit conversions and constants
3. `dsp/polyblep.h` - Band-limited waveforms
4. `utils/random.h` - Random number generation

**Important** (needed for most engines):
5. `dsp/filter.h` - Filtering operations
6. `dsp/cosine_oscillator.h` - Cosine oscillators
7. `dsp/limiter.h` - Signal limiting
8. `dsp/rsqrt.h` - Fast reciprocal sqrt

**For Specific Engines**:
9. `dsp/delay_line.h` - Delays (for physical modeling)
10. `dsp/hysteresis_quantizer.h` - Engine selection
11. `dsp/sample_rate_converter.h` - For effects

### From Plaits DSP

**Core** (Week 3):
- All `/plaits/dsp/engine/` files
- `/plaits/dsp/voice.h/cc`
- `/plaits/dsp/dsp.h`
- `/plaits/dsp/envelope.h`

**Supporting** (Week 4):
- `/plaits/dsp/oscillator/` - Oscillator implementations
- `/plaits/dsp/physical_modelling/` - String/modal engines
- `/plaits/dsp/fm/` - FM synthesis
- `/plaits/dsp/drums/` - Drum engines
- `/plaits/dsp/speech/` - Speech synthesis

---

## Adaptation Required

### Sample Rate

**Original**: 48kHz fixed
**Grainulator**: Configurable (44.1, 48, 88.2, 96 kHz)

**Solution**: Make sample rate a constructor parameter, scale internal calculations accordingly.

### Block Size

**Original**: 12 samples per block
**Grainulator**: Variable (64-1024 samples)

**Solution**: Process in 12-sample chunks internally, loop for larger buffers.

### Fixed-Point → Floating-Point

**Original**: Floating-point DSP (good!)
**Grainulator**: Also floating-point

**Solution**: Minimal adaptation needed.

### Memory Allocation

**Original**: Static allocation for embedded
**Grainulator**: Can use dynamic allocation

**Solution**: Keep static where possible for real-time safety, but can be more flexible.

### Resource Data

**Original**: Binary blobs in flash memory
**Grainulator**: Bundle in app or generate at init

**Solution**:
- Option 1: Pre-compile to C++ arrays
- Option 2: Load from Resources/ directory
- Option 3: Generate algorithmically (lookup tables)

---

## Testing Strategy

### Unit Tests

1. **Voice Initialization**
   - Test voice.Init() with various sample rates
   - Verify parameter defaults

2. **Engine Switching**
   - Test all 16 engine transitions
   - Verify no clicks/pops during transitions

3. **Parameter Response**
   - Test each parameter affects output
   - Verify modulation application
   - Test parameter interpolation smoothness

4. **Audio Output**
   - Generate test tones for each engine
   - Verify output range (-1.0 to +1.0)
   - Check for NaN/inf values
   - Measure THD for oscillators

### Integration Tests

1. **Real-time Performance**
   - CPU usage per engine (<5% target)
   - No buffer underruns
   - Latency measurements

2. **MIDI Input**
   - Note on/off triggering
   - Pitch tracking
   - Velocity response

3. **UI → Audio Path**
   - Parameter changes from UI
   - Engine switching from UI
   - No audio dropouts during interaction

---

## Success Criteria

### Week 3 Completion
- ✅ PlaitsVoice compiles and links
- ✅ Virtual Analog engine produces audio
- ✅ Parameters controllable from Swift
- ✅ No crashes or memory leaks
- ✅ CPU usage < 5% for one voice

### Week 4 Completion
- ✅ All 16 engines working
- ✅ MIDI keyboard input functional
- ✅ UI complete with all controls
- ✅ Engine switching smooth (no glitches)
- ✅ Documentation complete
- ✅ Ready for Phase 2 (Granular Engine)

---

## Risks & Mitigation

### Risk: Build Complexity
**Impact**: Medium
**Mitigation**: Start with minimal subset of files, add incrementally

### Risk: stmlib Dependencies
**Impact**: Medium
**Mitigation**: Port only needed functions, replace with standard library where possible

### Risk: Resource Data Size
**Impact**: Low
**Mitigation**: Start without wavetables, add later. Can reduce quality if needed.

### Risk: Real-time Performance
**Impact**: High
**Mitigation**: Profile early, optimize hot paths, use SIMD where beneficial

---

## License Compliance

**Mutable Instruments Plaits**: MIT License
**stmlib**: MIT License
**Grainulator**: [TBD - must be MIT-compatible]

**Requirements**:
- Include MIT license text in distribution
- Credit Mutable Instruments/Émilie Gillet
- Maintain copyright notices in ported files

**Compliance Plan**:
- Add LICENSE-PLAITS.txt to repository
- Include attribution in About dialog
- Add header comments to all ported files

---

## Resources

- [Plaits Documentation](https://pichenettes.github.io/mutable-instruments-documentation/modules/plaits/)
- [Plaits Source](https://github.com/pichenettes/eurorack/tree/master/plaits)
- [stmlib Source](https://github.com/pichenettes/stmlib)
- [Rust Port Reference](https://github.com/sourcebox/mi-plaits-dsp-rs)

---

**Last Updated**: February 1, 2026
**Status**: Planning Complete - Ready to Begin Implementation

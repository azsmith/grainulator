# macOS Music Application Specification

## Overview
A macOS music application combining granular synthesis, wavetable synthesis, effects processing, and mixing capabilities with support for multiple hardware controllers.

---

## 1. System Architecture

### 1.1 Application Components
- **Granular Synthesis Engine** - Morphagene-inspired granular processor
- **Plaits Synthesizer Voice** - Wavetable/modal synthesis engine
- **Effects Chain** - Tape delay, reverb, and distortion
- **Mixer** - Voice balance, effects sends, and master output control
- **File Management** - Project and preset handling
- **Input Management** - MIDI keyboard, Monome Grid (128), and Arc controller support

### 1.2 Technology Stack
- **Platform**: macOS (minimum version TBD)
- **Audio Framework**: CoreAudio / AudioUnit
- **UI Framework**: SwiftUI or AppKit
- **Languages**: Swift, C++ (for DSP components)
- **MIDI**: CoreMIDI
- **Grid/Arc Communication**: libmonome or serialosc

---

## 2. Component Specifications

### 2.1 Granular Synthesis Engine

The granular synthesis engine is based on the Mangl/MGlut architecture - a multi-track granular sample player with straightforward, direct controls. Each voice can load a sample and granulate it with independent parameters.

**Reference**: justmat's Mangl for Norns (https://github.com/justmat/mangl)

---

#### 2.1.1 Audio Buffer Architecture

**Simple Buffer Model**
- **Per-voice buffers**: Each granular voice has its own stereo audio buffer
- **Capacity**: Up to 2.5 minutes per buffer at 48kHz
- **Storage**: In-memory during playback
- **Operations**: Load from file, clear
- **Display**: Waveform overview with playhead position

**Loop Points** (Optional)
- **Loop In/Out**: Define a region within the buffer for looped playback
- **Behavior**: When playhead reaches loop_out, it jumps back to loop_in
- **Direction**: Respects current speed direction (forward or reverse)

---

#### 2.1.2 Core Parameters (Per Voice)

Each granular voice has the following independent parameters:

**POSITION (pos)**
- **Function**: Current playback position within the buffer
- **Range**: 0.0 - 1.0 (normalized to buffer length)
- **Behavior**:
  - Automatically advances based on SPEED
  - Can be manually "seeked" to jump to a specific location
  - Wraps around at buffer boundaries (or loop points if set)
- **Visual**: Real-time playhead indicator in waveform display

**SPEED**
- **Function**: Playback speed (tape-style: affects both speed and pitch)
- **Range**: -300% to +300%
- **Behavior**:
  - 100% = normal playback
  - 0% = frozen (grains trigger but position doesn't advance)
  - Negative values = reverse playback
  - Pitch changes proportionally (tape behavior)
- **Display**: Percentage with direction indicator

**PITCH**
- **Function**: Independent pitch shift (does NOT affect playback speed)
- **Range**: -24 to +24 semitones (±2 octaves)
- **Implementation**: Pitch ratio = 2^(semitones/12)
- **Interaction**: Combines with SPEED's inherent pitch change
- **Display**: Semitones (e.g., "+7 st", "-12 st")

**SIZE**
- **Function**: Duration of each grain
- **Range**: 1ms - 500ms
- **Sweet spots**:
  - 1-20ms: Spectral/buzzy effects
  - 20-100ms: Classic granular clouds
  - 100-300ms: Recognizable fragments
  - 300-500ms: Near-continuous with subtle granulation
- **Display**: Milliseconds

**DENSITY**
- **Function**: Grain trigger rate
- **Range**: 0 - 512 Hz
- **Behavior**:
  - Higher values = more grains per second = denser texture
  - Lower values = sparse, rhythmic grains
  - Combined with SIZE determines overlap amount
- **Typical values**: 1-20 Hz for rhythmic, 20-100 Hz for clouds
- **Display**: Hz

**JITTER**
- **Function**: Random position offset applied to each grain
- **Range**: 0 - 500ms
- **Behavior**:
  - 0ms: All grains start at exact playhead position
  - Higher values: Grains scatter around playhead position
  - Creates "smeared" or "cloud-like" textures
- **Display**: Milliseconds

**SPREAD**
- **Function**: Stereo spread (random pan per grain)
- **Range**: 0% - 100%
- **Behavior**:
  - 0%: All grains at center (mono)
  - 100%: Grains randomly panned hard left/right
- **Display**: Percentage

**PAN**
- **Function**: Base stereo position
- **Range**: -100% (left) to +100% (right)
- **Interaction**: SPREAD randomizes around this center point
- **Display**: L/C/R percentage

**GAIN**
- **Function**: Voice volume
- **Range**: -60dB to +20dB
- **Display**: dB

**FILTER CUTOFF**
- **Function**: Low-pass filter cutoff frequency
- **Range**: 20Hz - 20kHz
- **Type**: 4-pole (24dB/octave) low-pass
- **Display**: Hz

**FILTER Q**
- **Function**: Filter resonance
- **Range**: 0.0 - 1.0
- **Behavior**: Higher values create resonant peak at cutoff
- **Display**: 0-100%

**SEND**
- **Function**: Effect send level (to delay/reverb)
- **Range**: 0.0 - 1.0
- **Display**: 0-100%

**ENVELOPE SCALE (envscale)**
- **Function**: Attack/decay time for voice amplitude envelope
- **Range**: 1ms - 9000ms
- **Behavior**: Smooth fade in/out when voice is gated on/off
- **Display**: Milliseconds

---

#### 2.1.3 Voice Control

**GATE (Play)**
- **Function**: Enable/disable grain generation for this voice
- **Behavior**:
  - Gate ON: Grains continuously trigger at DENSITY rate
  - Gate OFF: Voice silences (with envelope release)
- **Use**: Toggle voices on/off, trigger from MIDI

**SEEK**
- **Function**: Jump playhead to a specific position
- **Behavior**: Immediately moves position and resets Phasor
- **Use**: Manual scrubbing, external position control

**FREEZE**
- **Function**: Stop position advancement while continuing grain generation
- **Behavior**: Like SPEED=0 but explicitly freezes current position
- **Use**: Sustain a particular moment in the sample

---

#### 2.1.4 Multi-Voice Architecture

**Voice Configuration**
- **Count**: 4 independent granular voices (expandable to 7)
- **Independence**: Each voice has completely independent parameters
- **Sample assignment**: Each voice loads its own audio file

**Per-Voice Features**
- Independent sample/buffer
- Independent position and speed
- Independent grain parameters (size, density, jitter)
- Independent pitch shift
- Independent filter settings
- Independent panning and gain
- Independent effect send

**Voice Management**
- **Enable/Mute**: Gate on/off per voice
- **Solo**: Isolate single voice for auditioning
- **Visual feedback**: Per-voice waveform with playhead

---

#### 2.1.5 Grain Window (Envelope)

Each grain is shaped by a Hanning window envelope to prevent clicks:

**Window Characteristics**
- **Type**: Hanning (cosine-based bell curve)
- **Application**: Amplitude envelope applied to each grain
- **Behavior**: Smooth fade-in and fade-out

*Future enhancement: Selectable window types*

---

#### 2.1.6 DSP Implementation (Based on MGlut)

**Grain Generation (from SuperCollider GrainBuf)**
```
grain_trig = Impulse.kr(density)           // Trigger grains at density rate
buf_pos = Phasor.kr(rate: speed)           // Advance position through buffer
jitter_offset = TRand.kr(-jitter, jitter)  // Random position offset per grain
pan_offset = TRand.kr(-spread, spread)     // Random pan per grain

signal = GrainBuf.ar(
    trigger: grain_trig,
    dur: size,
    buf: buffer,
    rate: pitch_ratio,
    pos: buf_pos + jitter_offset
)

output = Pan2.ar(signal, pan + pan_offset)
output = LowPass.ar(output, cutoff, q)
```

**Key Implementation Details**
- **Phasor**: Continuously advances position based on speed
- **Impulse**: Triggers grains at regular intervals (density Hz)
- **TRand**: Generates new random values on each trigger (for jitter/spread)
- **GrainBuf**: Core granular synthesis (SuperCollider built-in)

---

#### 2.1.7 Effect Bus (Greyhole Delay)

**Built-in Effect** (from MGlut)
- **Type**: Greyhole algorithmic reverb/delay
- **Parameters**:
  - **Delay Time**: 0.0 - 60.0 seconds
  - **Damping**: 0.0 - 1.0 (high frequency absorption)
  - **Size**: 0.5 - 5.0 (reverb size)
  - **Diffusion**: 0.0 - 1.0 (echo density)
  - **Feedback**: 0.0 - 1.0
  - **Mod Depth**: 0.0 - 1.0 (pitch modulation)
  - **Mod Freq**: 0.0 - 10.0 Hz
  - **Volume**: Effect return level

**Per-Voice Send**
- Each voice has independent send level to effect bus
- Effect output mixed with dry signal at master output

---

#### 2.1.8 Sample Management

**Loading Audio**
- **Supported formats**: WAV, AIFF, FLAC, MP3, M4A, OGG
- **Sample rate support**: 22.05kHz, 44.1kHz, 48kHz, 88.2kHz, 96kHz (auto-resampled to project rate)
- **Bit depth**: 16-bit, 24-bit, 32-bit float (converted to 32-bit float internal)
- **Stereo handling**:
  - Load as stereo (left and right channels into separate buffers)
  - Convert to mono (L+R mix or L/R selection)
- **Drag & drop**: Import by dropping files onto voice waveform
- **File browser**: Click waveform to open file picker

**Per-Voice Loading**
- Each voice can load a different sample
- Or multiple voices can use the same sample with different parameters

---

#### 2.1.9 User Interface Components

**Per-Voice Waveform Display**
- **Waveform**: Visual representation of loaded audio
- **Playhead**: Real-time position indicator
- **Loop markers**: Optional loop in/out points (if set)
- **Color coding**: Each voice has distinct color

**Parameter Controls**
- **Primary**: Position (scrub), Speed, Size, Density
- **Extended**: Pitch, Jitter, Spread, Filter, Send
- **Voice controls**: Gate (play/stop), Gain, Pan

**Simple Layout**
- One waveform + controls per voice
- Collapsible advanced parameters
- Clear visual feedback for active voices

---

#### 2.1.10 Controller Mappings

**Arc (4-encoder) - Primary Mode**
```
Encoder 1: SPEED
           - Center = normal (100%)
           - CCW = slower/reverse
           - CW = faster
           - Press = reset to 100%

Encoder 2: PITCH
           - Center = no shift (0 semitones)
           - CCW = pitch down
           - CW = pitch up
           - Press = reset to 0

Encoder 3: SIZE
           - LED ring shows grain duration
           - Press = default (100ms)

Encoder 4: DENSITY
           - LED ring shows trigger rate
           - Press = default (20 Hz)
```

**Arc (4-encoder) - Alt Mode**
```
Encoder 1: Scrub (seek position)
Encoder 2: Fine tune (pitch cents)
Encoder 3: SPREAD
Encoder 4: JITTER
```

**Grid - Quick Access**
```
Row 1-2: Position scrub (32 positions across buffer)
Row 3:   Size presets (16 values)
Row 4:   Density presets (16 values)
Row 5:   Speed presets (reverse/slow/normal/fast)
Row 6:   Voice select (1-4) + mute toggles
Row 7:   Pitch presets (semitone steps)
Row 8:   Transport + page navigation
```

**MIDI**
- **Note On**: Trigger voice gate
- **Note pitch**: Control pitch parameter
- **Velocity**: Modulate gain and/or filter
- **CC1 (Mod)**: Density
- **CC11 (Expr)**: Position scrub
- **CC74 (Cutoff)**: Filter cutoff

---

#### 2.1.11 Future Enhancements

These features are not part of the initial implementation but could be added later:

- **Splice/marker system** (Morphagene-style)
- **Sound-on-Sound recording**
- **Pitch quantization** (chromatic, scales)
- **LFO modulation** per parameter
- **Pattern recording** (sequence parameter changes)
- **Additional window types**

---

### 2.2 Plaits Synthesizer Voice

#### 2.2.1 Core Features
Based on Mutable Instruments Plaits (open source):
- **Synthesis Models** (16 models from Plaits):
  1. Virtual analog (saw/square with PWM)
  2. Phase distortion
  3. 6-operator FM
  4. Grain formant oscillator
  5. Harmonic oscillator
  6. Wavetable
  7. Chords
  8. Speech synthesis
  9. Swarm of sawtooth waves
  10. Filtered noise (rain, particles)
  11. Twin peaks resonator
  12. String modeling
  13. Modal resonator
  14. Analog bass drum
  15. Analog snare drum
  16. Analog hi-hat

#### 2.2.2 Parameters
- **Model Selection**: Choose synthesis algorithm
- **Harmonics/Timbre**: Spectral content control
- **Morph**: Secondary timbre parameter
- **Frequency**: Note/pitch control
- **Decay**: Internal decay envelope (for percussive models)
- **Level**: Output amplitude

#### 2.2.3 Modulation
- **Internal LFO**:
  - Rate, depth, destination
  - Waveforms: sine, triangle, square, random
- **Envelope**:
  - Attack, Decay, Sustain, Release (ADSR)
  - Envelope amount to multiple destinations

#### 2.2.4 Output
- Stereo output (main + auxiliary from Plaits architecture)
- Individual voice output for routing to mixer

---

### 2.3 Effects Chain

#### 2.3.1 Tape Delay
- **Parameters**:
  - Time: 1ms - 2000ms
  - Feedback: 0% - 100%
  - Wow/flutter: Tape modulation amount
  - Wow rate: Modulation speed
  - Degradation: Simulated tape wear
  - Mix: Dry/wet balance
  - Stereo spread: Ping-pong/stereo delay amount

- **Features**:
  - Tape saturation modeling
  - Low-pass filter in feedback path
  - Sync to tempo (optional)

#### 2.3.2 Reverb
- **Type**: Algorithmic plate/hall reverb
- **Parameters**:
  - Pre-delay: 0ms - 200ms
  - Size: Room dimensions
  - Decay time: 0.1s - 20s
  - Damping: High-frequency absorption
  - Diffusion: Echo density
  - Mix: Dry/wet balance
  - Width: Stereo width of reverb tail

#### 2.3.3 Distortion
- **Type**: Multiple distortion algorithms
  - Tape saturation
  - Tube/valve saturation
  - Fuzz
  - Bit crushing

- **Parameters**:
  - Drive: Input gain/saturation amount
  - Tone: Tilt EQ (pre/post distortion)
  - Type: Algorithm selection
  - Mix: Dry/wet balance (parallel distortion)
  - Output: Makeup gain

#### 2.3.4 Effects Routing
- Series or parallel processing
- Individual effect bypass
- Effects chain ordering (user-configurable)

---

### 2.4 Mixer

#### 2.4.1 Channel Configuration
- **Input Channels**:
  - Granular engine channel
  - Plaits synthesizer channel
  - Additional channels for future expansion

- **Channel Strip** (per channel):
  - Fader: Volume control (-∞ to +6dB)
  - Pan: Stereo positioning (L-C-R)
  - Mute/Solo: Channel management
  - Effects sends (3 sends for Delay, Reverb, Distortion)
    - Pre/post fader selection
    - Send level control per effect

#### 2.4.2 Master Section
- **Master Fader**: Overall output level
- **Master Effects Returns**:
  - Return level for each effect
  - Pan control for effect returns

- **Metering**:
  - Per-channel peak/RMS meters
  - Master output meter
  - Clipping indicators

- **Output**:
  - Master output routing
  - Headroom/limiting (optional safety limiter)

---

### 2.5 File Management

#### 2.5.1 Project Files
- **Save/Load**:
  - Project file format: Custom format (.musicproj or similar)
  - Contains: All parameter states, audio buffer references, preset selections
  - Auto-save functionality (optional)

- **Export**:
  - Bounce to audio file (WAV, AIFF, MP3)
  - Sample rate and bit depth selection
  - Realtime or offline rendering

#### 2.5.2 Preset Management
- **Per-Voice Presets**:
  - Granular engine presets (grain parameters, buffer state)
  - Plaits synthesizer presets (model, parameters, modulation)
  - Effects presets (individual or chain)

- **Preset Operations**:
  - Save preset with custom name
  - Load preset from library
  - Browse/search presets
  - Preset categories/tags
  - Import/export individual presets

#### 2.5.3 Audio File Management
- **Sample Library**:
  - Import audio files for granular processing
  - Organize samples in collections
  - Waveform display and preview
  - Metadata tagging

---

## 3. Input Control Specifications

### 3.1 MIDI Keyboard Controller

#### 3.1.1 Basic MIDI Mapping
- **Note Input**:
  - Note on/off → Plaits synthesizer pitch control
  - Velocity → Amplitude/filter modulation
  - Aftertouch → Timbre/morph modulation (if supported)

- **Control Change (CC)**:
  - Modulation wheel (CC1) → Assignable parameter
  - Expression pedal (CC11) → Assignable parameter
  - Sustain pedal (CC64) → Hold notes
  - Additional CCs → User-mappable to any parameter

#### 3.1.2 MIDI Learn
- Click parameter → Move MIDI control to assign
- Clear mapping functionality
- Save mappings with presets/projects

---

### 3.2 Monome Grid (128 varibright)

#### 3.2.1 Grid Layout Philosophy
- **8x16 button configuration**
- **LED brightness feedback**: Parameter values, active states
- **Page-based navigation**: Switch between control contexts

#### 3.2.2 Proposed Grid Layouts

**Page 1: Granular Control** (see Section 2.1.12 for complete specification)
- **Row 1-2**: Buffer scrubbing (128 positions across active splice with visual playhead feedback)
- **Row 3**: Gene Size (16 preset values from 5ms to 5000ms)
- **Row 4**: Morph (gene-shift to time-stretch continuum)
- **Row 5**: Varispeed (reverse to forward with center freeze)
- **Row 6**: Track selection, mute, loop mode controls
- **Row 7**: Splice triggers (16 quick-access splices, hold for splice editing)
- **Row 8**: Transport, recording, SOS, freeze, and page navigation

**Page 2: Plaits Synthesizer**
- **Column 1-2**: Model selection (16 models)
- **Row 1**: Harmonics/timbre parameter (16 steps)
- **Row 2**: Morph parameter (16 steps)
- **Row 3-6**: 4-note chord/sequencer grid (optional)
- **Row 7**: Octave selection
- **Row 8**: Preset recall (quick access to 16 presets)

**Page 3: Mixer & Effects**
- **Columns 1-4**: Granular channel (fader emulation via vertical press)
- **Columns 5-8**: Plaits channel
- **Columns 9-12**: Effect sends visualization
- **Columns 13-16**: Master controls, effect bypass

#### 3.2.3 Grid Interaction
- **Press**: Trigger/select
- **Hold**: Access secondary function
- **Brightness**: Visual feedback for parameter values and states
- **Gesture support**: Press multiple buttons for chords/complex input

---

### 3.3 Monome Arc (4-encoder version)

#### 3.3.1 Arc Layout

**Configuration 1: Granular Focus - Primary Mode** (see Section 2.1.12 for complete specification)
- **Encoder 1**: SLIDE (buffer position with visual playhead on LED ring)
- **Encoder 2**: GENE SIZE (logarithmic display)
- **Encoder 3**: VARISPEED (centered at 12 o'clock for freeze)
- **Encoder 4**: MORPH (sparse to dense LED visualization)

**Configuration 1: Granular Focus - Alt Mode**
- **Encoder 1**: SPREAD (grain position randomization)
- **Encoder 2**: PITCH (independent pitch shift, ±2 octaves)
- **Encoder 3**: FILTER CUTOFF
- **Encoder 4**: JITTER (timing randomization)

**Configuration 2: Synthesis Focus**
- **Encoder 1**: Harmonics/timbre
- **Encoder 2**: Morph parameter
- **Encoder 3**: Filter cutoff/envelope
- **Encoder 4**: Decay/release

**Configuration 3: Mix Focus**
- **Encoder 1**: Granular level
- **Encoder 2**: Plaits level
- **Encoder 3**: Effect send amount (rotates through effects)
- **Encoder 4**: Master level

#### 3.3.2 Arc Interaction
- **Rotation**: Continuous parameter control
- **LED ring**: Visual parameter feedback
- **Click/press** (if supported by hardware): Mode switching or value reset
- **Configuration switching**: Via keyboard shortcut or Grid button

---

## 4. User Interface Design

### 4.1 Main Window Layout
```
+--------------------------------------------------+
|  Menu Bar: File, Edit, Window, Help              |
+--------------------------------------------------+
|  [Granular Engine]    [Plaits Synthesizer]       |
|  +----------------+   +------------------+        |
|  | Waveform       |   | Model: [Wavetable]|       |
|  | Display        |   | Harmonics: [knob] |       |
|  |                |   | Morph: [knob]     |       |
|  | [Parameters]   |   | [Parameters]      |       |
|  +----------------+   +------------------+        |
|                                                   |
|  [Effects Chain]                                  |
|  +----------------------------------------------+ |
|  | [Tape Delay] [Reverb] [Distortion]          | |
|  | Drive: [x]   Size: [x]  Drive: [x]          | |
|  +----------------------------------------------+ |
|                                                   |
|  [Mixer]                                          |
|  +----------------------------------------------+ |
|  | Granular  Plaits  [Returns]  Master         | |
|  | [=====]   [=====]  [===]     [=====]        | |
|  +----------------------------------------------+ |
|                                                   |
|  [Controller Status]                              |
|  Grid: Connected | Arc: Connected | MIDI: Active  |
+--------------------------------------------------+
```

### 4.2 Design Principles
- **Minimal, clean interface**: Focus on essential controls
- **Visual feedback**: Waveforms, meters, parameter values
- **Modular layout**: Each component clearly separated
- **Resizable**: Accommodate different screen sizes
- **Dark mode support**: Reduce eye strain during long sessions

### 4.3 Additional Windows
- **Preset browser**: Filterable list with preview
- **MIDI learn window**: Mapping overview and management
- **Settings/preferences**: Audio device, buffer size, MIDI ports, Grid/Arc configuration
- **File browser**: Sample management and project files

---

## 5. Audio Specifications

### 5.1 Audio Engine Requirements
- **Sample Rate**: 44.1kHz, 48kHz, 88.2kHz, 96kHz (user-selectable)
- **Bit Depth**: 24-bit or 32-bit float internal processing
- **Buffer Size**: 64 - 2048 samples (user-selectable for latency trade-off)
- **Latency**: Target < 10ms round-trip at 48kHz/128 buffer
- **Polyphony**:
  - Granular engine: Up to 64 concurrent grains per track (configurable)
  - Multi-track: 4 independent granular tracks (expandable to 7)
  - Plaits: Monophonic (1 voice, expandable in future)
- **Memory**:
  - Per-reel buffer: ~14.4 million samples (2.5 min @ 48kHz) = ~58MB per reel
  - 32 reels maximum = ~1.85GB total buffer capacity
  - Additional headroom for processing buffers and grain scheduling

### 5.2 Audio Routing
- **Internal routing**: All components route through internal mixer
- **External audio input**: For granular synthesis live processing
- **Audio output**: Stereo main output to system audio device
- **Inter-app audio** (optional): Support for AudioUnit hosting

---

## 6. Technical Implementation Notes

### 6.1 DSP Libraries and Code Reuse
- **Plaits**: Port Mutable Instruments Plaits C++ code (Emilie Gillet, MIT license)
- **Granular Engine**: Custom implementation combining:
  - Morphagene control paradigm and feature set
  - Mangl technical architecture (multi-track, SuperCollider-style grain scheduling)
  - Custom grain windowing, time-stretching, and pitch-shifting algorithms
- **Time-stretching**: Phase vocoder implementation or library (e.g., RubberBand, SoundTouch)
- **Effects**: Implement using standard DSP algorithms or leverage existing open-source libraries (e.g., JUCE DSP modules)
- **Mangl reference**: Study justmat's Norns/SuperCollider implementation for architectural inspiration

### 6.2 Monome Integration
- **Library**: Use libmonome or direct serialosc OSC communication
- **Connection**: Serial USB communication
- **Discovery**: Auto-detect connected Grid/Arc devices
- **Multi-device**: Support multiple grids or arcs simultaneously (future enhancement)

### 6.3 Performance Optimization
- **Multi-threading**: Separate audio thread from UI thread
- **SIMD**: Use vector instructions for DSP where applicable (Accelerate framework)
- **Memory management**: Efficient buffer handling for granular synthesis
- **Latency compensation**: Account for processing delay in mixer

---

## 7. Development Phases

### Phase 1: Core Audio & Synthesis
- [ ] Basic macOS application scaffold
- [ ] CoreAudio setup and audio I/O
- [ ] Plaits synthesizer port and integration
- [ ] Basic UI for Plaits control

### Phase 2: Granular Engine
- [ ] Audio file loading and reel/buffer management system
- [ ] Basic grain synthesis core (windowing, triggering, polyphony)
- [ ] Hierarchical structure: Reels → Splices → Genes
- [ ] Core parameters: Slide, Gene Size, Morph, Varispeed, Organize
- [ ] Extended parameters: Speed, Pitch, Spread, Jitter, Density, Filter
- [ ] Splice creation, editing, and management system
- [ ] Recording and Sound-on-Sound (SOS) functionality
- [ ] Multi-track architecture (4+ independent tracks)
- [ ] Waveform display with splice visualization
- [ ] Time-stretching and pitch-shifting algorithms (phase vocoder)
- [ ] Performance features: Freeze, macro controls, scene recall

### Phase 3: Effects & Mixer
- [ ] Tape delay implementation
- [ ] Reverb implementation
- [ ] Distortion implementation
- [ ] Mixer with routing and metering

### Phase 4: File Management
- [ ] Project save/load system
- [ ] Preset management for each voice
- [ ] Audio file import/export
- [ ] Settings persistence

### Phase 5: Controller Integration
- [ ] MIDI keyboard input and learn system
- [ ] Monome Grid integration and layout implementation
- [ ] Monome Arc integration
- [ ] Controller configuration UI

### Phase 6: Polish & Optimization
- [ ] UI refinement and visual design
- [ ] Performance optimization
- [ ] Testing and bug fixes
- [ ] Documentation and user manual

---

## 8. Future Enhancements (Post v1.0)

- **Multiple instances**: Support multiple Plaits voices (polyphony)
- **Modulation matrix**: Advanced routing between LFOs, envelopes, and parameters
- **Additional effects**: Chorus, phaser, EQ, compressor
- **Sequencer**: Built-in step sequencer or piano roll
- **Recording**: Record performances to audio files
- **Plugin support**: AudioUnit or VST hosting
- **Ableton Link**: Tempo synchronization with other applications
- **Grid patterns**: Save and recall grid button configurations
- **CV output**: Support for hardware CV interfaces (via DC-coupled audio interface)

---

## 9. Dependencies and Licensing

### 9.1 Open Source Components
- **Mutable Instruments Plaits**: MIT License
  - Source: https://github.com/pichenettes/eurorack
  - Attribution required in application about screen

- **Mangl (Norns)**: Inspiration for granular engine architecture
  - Source: https://github.com/justmat/mangl
  - Credits: @justmat (developer), @tehn (angl), @artfwo (engine/script, glut)
  - License: Check repository for specific license
  - Note: Architectural and design inspiration only, not direct code porting

### 9.2 Third-Party Libraries (Potential)
- **libmonome**: ISC License (for Grid/Arc communication)
- **JUCE** (optional): GPL or commercial license depending on distribution
- **PortAudio** (optional): MIT License (cross-platform audio I/O)

### 9.3 Application License
- To be determined based on project goals (open source vs. commercial)

---

## 10. Testing Requirements

### 10.1 Functional Testing
- Audio engine stability (no dropouts, clicks, pops)
- All parameters respond correctly
- File save/load preserves all state
- Controller input mapping accuracy
- Effects processing quality

### 10.2 Performance Testing
- CPU usage under various configurations
- Memory usage with large audio buffers
- Latency measurements
- Stress testing (maximum grain density, all effects active)

### 10.3 Compatibility Testing
- macOS versions (latest + 2 previous major versions)
- Different audio interfaces and sample rates
- Various MIDI controllers
- Grid/Arc firmware versions

---

## Document Version
- **Version**: 2.0
- **Date**: 2026-02-02
- **Status**: Simplified to Mangl-based granular engine
- **Changes from v1.2**:
  - **Simplified granular architecture** to match Mangl/MGlut behavior
  - Removed complex Morphagene hierarchy (Reels → Splices → Genes)
  - Replaced with simple per-voice buffers with optional loop points
  - **Direct parameter set** based on MGlut engine:
    - POSITION (pos) - playback position (0-1)
    - SPEED - playback speed with tape-style pitch coupling
    - PITCH - independent pitch shift (semitones)
    - SIZE - grain duration (ms)
    - DENSITY - grain trigger rate (Hz)
    - JITTER - random position offset per grain
    - SPREAD - stereo spread (random pan)
    - PAN - base pan position
    - GAIN - volume
    - FILTER (cutoff/Q) - low-pass filter
    - SEND - effect send level
    - ENVELOPE SCALE - attack/decay time
  - Removed complex MORPH parameter (gene-shift vs time-stretch modes)
  - Removed VARISPEED (replaced with simpler SPEED + PITCH)
  - Removed ORGANIZE/SLIDE (replaced with POSITION)
  - Removed Sound-on-Sound, splice creation, CV outputs
  - Removed complex quantization system (future enhancement)
  - Added Greyhole-style effect bus from MGlut
  - Simplified DSP implementation notes based on SuperCollider GrainBuf
  - Simplified controller mappings for direct parameter control

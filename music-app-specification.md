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

The granular synthesis engine synthesizes the technical implementation of Mangl (multi-track granular sampler) with the user control paradigm of Make Noise Morphagene, creating a unified, musically-oriented granular processor. The engine emphasizes musical playability through comprehensive pitch/interval quantization and intuitive performance controls.

---

#### 2.1.1 Audio Buffer Architecture (Morphagene Hierarchy)

The engine implements a three-level hierarchical structure:

**Reels (Top Level)**
- **Definition**: RAM-based audio buffers containing recorded or loaded audio
- **Capacity**: Up to 32 reels per project
- **Length**: 2.5 minutes per reel at 48kHz (approximately 14.4 million samples)
- **Storage**: In-memory during playback, saved to disk with project
- **Operations**: Load, save, record, clear, duplicate
- **Display**: Waveform overview with splice markers visible

**Splices (Middle Level)**
- **Definition**: Subsections within a reel, defining loop regions and playback zones
- **Capacity**: Up to 300 splices per reel
- **Functionality**:
  - Define start/end boundaries for looping
  - Allow non-destructive organization of audio material
  - Can be navigated sequentially or randomly
  - Support independent playback settings
- **Visual representation**: Colored regions in waveform display
- **Metadata**: Name, color, loop on/off state

**Genes (Bottom Level - Individual Grains)**
- **Definition**: Individual grains of audio extracted and played from active splice
- **Size**: 1ms - 5000ms (typically 20-200ms for classic granular textures)
- **Windowing**: Adjustable envelope shapes to prevent clicks
- **Polyphony**: Up to 64 concurrent genes/grains (configurable)

---

#### 2.1.2 Core Parameters (Morphagene Control Set)

**SLIDE** (Playback Position)
- **Function**: Determines where within the active splice grain playback begins
- **Range**: 0% - 100% of splice length
- **Behavior**:
  - Manual control: Direct scrubbing through splice
  - Modulated: Creates evolving textures by scanning position
  - At 0%: Grains start at splice beginning
  - At 100%: Grains start at splice end
- **CV/Modulation**: Accepts external modulation for animated scanning
- **Visual**: Real-time playhead indicator in waveform display

**GENE SIZE** (Grain Size)
- **Function**: Sets the duration of each individual grain
- **Range**: 1ms - 5000ms
- **Sweet spots**:
  - 1-10ms: Spectral/formant effects
  - 20-200ms: Classic granular clouds
  - 500-2000ms: Recognizable phrases with texture
  - 2000ms+: Near-continuous playback with subtle granulation
- **Interaction**: Works with Morph to determine grain overlap
- **Quantize option**: Snap to musical divisions (1/4, 1/8, 1/16, etc.)

**MORPH** (Grain Spacing, Density & Time-Stretch)
- **Function**: Multi-function control that changes behavior across its range
- **Range**: 0% - 100% with distinct regions
- **Behavior zones**:

  *0% - 40% (Gene-Shifting Mode)*:
  - Discrete grain triggering with gaps
  - Lower values = more space between grains
  - Grains alternate between left/right channels
  - Pitch shifting artifacts present
  - Clock-syncable for rhythmic effects

  *50% (Neutral)*:
  - Grains just begin to overlap
  - Transition point between modes

  *60% - 100% (Time-Stretch Mode)*:
  - Overlapping grains create continuous sound
  - Higher values = more overlap/density
  - Pitch preservation active (time-stretch without pitch change)
  - Smoother, more sustained textures
  - Stereo spread increases with value

- **Internal calculations**:
  - Grain trigger rate = f(Gene Size, Morph value)
  - Overlap count = automatic based on Morph
  - Panning = alternating or spread based on mode

**VARISPEED** (Playback Speed & Pitch - Unified Control)
- **Function**: Controls playback speed of individual grains (tape-style, coupled speed/pitch)
- **Range**: -400% to +400% (speed multiplier, ±2 octaves)
- **Center position** (12 o'clock): 100% = normal playback
- **Zero point**: 0% = freeze (no playback)
- **Behavior**:
  - Below 100%: Slower playback, lower pitch
  - Above 100%: Faster playback, higher pitch
  - Negative values: Reverse playback with pitch shift
- **Quantization Modes** (Musical Focus):
  - **Off**: Continuous speed/pitch (vintage tape feel)
  - **Chromatic**: Semitone steps (12-TET)
  - **Octaves Only**: 25%, 50%, 100%, 200%, 400% (pure octave ratios)
  - **Octaves + Fifths**: Add 150% (fifth up), 300% (octave+fifth), etc.
  - **Octaves + Fourths**: Add 133% (fourth up), 266% (octave+fourth), etc.
  - **Custom Ratios**: User-definable speed multipliers
- **Coupled vs. Decoupled**:
  - *Coupled* (default): Speed and pitch change together (classic tape/Morphagene behavior)
  - *Decoupled*: PITCH parameter handles pitch independently via time-stretching
- **Use cases**:
  - Octaves Only mode: Clean harmonic doubling (-1 oct, unison, +1 oct)
  - Octaves + Fifths: Power chord textures across multiple tracks
  - Continuous mode: Tape wobble, lo-fi effects

**ORGANIZE** (Splice Selection)
- **Function**: Navigates through splices within the active reel
- **Range**: Discrete selection of all available splices (1-300)
- **Behavior**:
  - Manual: Turn to select specific splice
  - CV/Modulation: Sequence through splices
  - Quantized: Always selects complete splice (no in-between)
- **Display**: Shows splice number and name
- **Integration**: Works with Shift trigger for automatic advancing

---

#### 2.1.3 Extended Parameters (Unified Approach)

These parameters extend the core Morphagene controls with multi-track capabilities and enhanced musical control:

**PITCH** (Musical Transposition)
- **Function**: Independent pitch shift WITHOUT speed change (time-stretch algorithm)
- **Range**: ±4 octaves (±48 semitones)
- **Algorithm**: Phase vocoder with formant preservation option
- **Quantization Modes** (Musical Focus):
  - **Off**: Continuous pitch shift (±0.01 semitone resolution)
  - **Chromatic**: 12-tone equal temperament (semitone steps)
  - **Octaves Only**: -4, -3, -2, -1, 0, +1, +2, +3, +4 octaves
  - **Octaves + Fifths**: Octaves plus perfect fifth intervals (0, +7, +12, +19, +24, etc.)
  - **Octaves + Fourths**: Octaves plus perfect fourth intervals (0, +5, +12, +17, +24, etc.)
  - **Major Scale**: Quantize to major scale degrees relative to root
  - **Minor Scale**: Quantize to natural minor scale degrees
  - **Pentatonic**: Quantize to pentatonic scale
  - **Custom Intervals**: User-definable interval set (e.g., 0, +3, +7, +12 for minor triads)
- **Root Note**: Set reference pitch for scale-based quantization (C, C#, D, etc.)
- **Per-track**: Each track can have independent pitch and quantization settings
- **Use cases**:
  - Octave doubling for thickness
  - Harmonic layering (octaves + fifths for power chord textures)
  - Melodic transposition with scale constraints
  - Multi-track harmonization

**SPREAD** (Grain Position Randomization)
- **Function**: Random deviation from Slide position within the splice
- **Range**: 0% - 100% of splice length
- **Behavior**:
  - 0%: All grains at exact Slide position (precise, focused)
  - 25%: Grains within ±25% of Slide position (slight shimmer)
  - 50%: Wide cloud around Slide position (diffuse texture)
  - 100%: Grains anywhere in splice (maximum chaos)
- **Distribution**: Gaussian (default) or uniform (user-selectable)
- **Musical Application**: Creates ensemble/chorus effects while maintaining pitch center

**JITTER** (Grain Timing Randomization)
- **Function**: Randomizes grain trigger timing
- **Range**: 0% - 100%
- **Behavior**:
  - 0%: Perfect metronomic grain triggering
  - 25%: Slight humanization (natural feel)
  - 50%: Moderate timing variation
  - 100%: Maximum randomization (cloud-like, ambient)
- **Interaction**: Works with Morph density to create organic vs. mechanical textures
- **Quantize option**: Can snap jitter to tempo subdivisions (8th, 16th, 32nd notes)

**FILTER** (Per-Grain Filtering)
- **Function**: Low-pass filter applied to grain output
- **Type**: Resonant low-pass (12dB or 24dB/octave, user-selectable)
- **Parameters**:
  - **Cutoff**: 20Hz - 20kHz
  - **Resonance**: 0% - 90% (approaching self-oscillation at high values)
  - **Key tracking**: Optional pitch following (higher grain pitches = higher cutoff)
- **Application**: Pre-mix (each grain filtered individually)
- **Musical Use**: Spectral shaping, vowel-like formants, subtractive synthesis

---

#### 2.1.4 Recording & Sound-on-Sound

**Recording Modes**

*Basic Record*
- **Trigger**: Press Record to start/stop
- **Input source**: Live input or internal resampling
- **Behavior**: Overwrites existing reel content
- **Length**: Records until buffer full (2.5 min) or manually stopped
- **Auto-normalize**: Optional gain adjustment after recording

*Clock-Synced Record*
- **Trigger**: Arm recording, wait for clock pulse to begin
- **Quantization**: Start/stop aligned to clock divisions
- **Use**: Perfect loop recording synchronized to tempo
- **Clock source**: Internal clock, MIDI clock, or external trigger

*Sound-on-Sound (SOS)*
- **Function**: Blends live input with current playback for overdubbing
- **Parameter**: SOS amount (0% = input only, 100% = playback only)
- **Feedback**: Create delay/loop effects by balancing input and playback
- **Use cases**:
  - 50%: Equal mix (build up layers)
  - 90%: Long delay effect (mostly playback)
  - 10%: Overdub with minimal existing audio
- **Recording**: Can record the SOS mix back into buffer (resampling)

**Splice Creation During Recording**
- **Manual**: Press Splice button to mark current position
- **Auto-splice**: Automatically create splices at regular intervals
- **Trigger-based**: External trigger creates splice markers
- **Result**: Recorded audio pre-divided into navigable sections

---

#### 2.1.5 Gates, Triggers & Modulation I/O

**PLAY** (Grain Trigger Input)
- **Function**: Manual or triggered grain generation
- **Modes**:
  - *Gate*: Continuous grain generation while high
  - *Trigger*: Generate one grain per trigger
  - *Free-running*: Auto-trigger based on Morph (density)
- **Rising edge behavior**: Resets grain playback position
- **Use**: Rhythmic grain triggering, performance control

**RECORD** (Record Gate/Trigger)
- **Gate mode**: Record while high, stop when low
- **Trigger mode**: Toggle record on/off with each trigger
- **Clock integration**: Start on next clock pulse

**SHIFT** (Splice Advance Trigger)
- **Function**: Advances to next splice
- **Timing**: Trigger can be immediate or wait for end-of-gene
- **Direction**: Forward, reverse, or random (user setting)
- **Use**: Create evolving textures by sequencing through splices

**SPLICE** (Create Splice Marker)
- **Function**: Add new splice point at current playback position
- **Behavior**: Divides active splice into two new splices
- **Limit**: Maximum 300 splices per reel
- **Visual**: Immediate update in waveform display

**CV Outputs** (Morphagene-inspired)
- **Envelope Follower**: Amplitude CV follows gene/grain output
  - Response time: Fast (for percussive) or Slow (for sustained)
  - Range: 0-5V or 0-10V (normalized to DAW parameters)

- **End-of-Gene (EOG) Gate**: Trigger pulse at end of each grain
  - Duration: 10ms pulse
  - Use: Sync other modules/parameters to grain boundaries

- **End-of-Splice (EOS) Gate**: Trigger pulse when splice ends
  - Use: Chain splice navigation, create macro-structures

---

#### 2.1.6 Window Shapes & Grain Envelopes

To prevent clicks/pops, each grain is shaped by an amplitude envelope:

**Available Window Types**
1. **Linear**: Simple linear fade in/out
2. **Hanning**: Smooth bell curve (cosine-based)
3. **Hamming**: Similar to Hanning with slightly different characteristics
4. **Gaussian**: Very smooth, narrow peak
5. **Tukey**: Flat top with cosine edges (adjustable taper)
6. **Trapezoid**: Linear ramps with sustain section

**Envelope Parameters**
- **Attack**: Fade-in time (0-50% of grain)
- **Release**: Fade-out time (0-50% of grain)
- **Shape**: Window type selection
- **Asymmetry**: Different attack vs. release curves (advanced)

**Presets**
- "Smooth" (Hanning, 40% attack/release)
- "Punchy" (Linear, 10% attack/release)
- "Pad" (Gaussian, 45% attack/release)

---

#### 2.1.7 Multi-Track Architecture (Mangl-Inspired)

Unlike the single-voice Morphagene, the engine supports multiple independent tracks:

**Track Configuration**
- **Count**: 4 independent granular tracks (expandable to 7 in future)
- **Per-track parameters**: Each track has full independent parameter set
  - Independent reel/splice selection
  - Independent grain parameters: Gene Size, Morph, Slide, Organize
  - Independent pitch: VARISPEED and/or PITCH with per-track quantization
  - Individual filter settings (cutoff, resonance, key tracking)
  - Separate Spread, Jitter amounts
  - Individual output routing and level

**Track Management**
- **Enable/Mute**: Activate or silence individual tracks
- **Solo**: Isolate single track for editing and auditioning
- **Link**: Lock parameters across multiple tracks (e.g., link Slide for unified scrubbing)
- **Copy**: Duplicate complete track settings to another track
- **Output routing**:
  - Individual outputs (for multi-channel processing)
  - Mixed stereo output
  - Send to different effect buses per track

**Musical Use Cases**
- **Octave Layering**: Same reel, Track 1 at unison, Track 2 at +1 octave, Track 3 at -1 octave
- **Harmonic Stacking**: Octaves + Fifths quantization for rich, consonant textures
  - Track 1: Unison (0 semitones)
  - Track 2: +7 semitones (perfect fifth)
  - Track 3: +12 semitones (octave)
  - Track 4: +19 semitones (octave + fifth)
- **Rhythmic Polyrhythms**: Different grain sizes and densities per track
- **Textural Contrast**: Track 1 (tight, focused), Track 2 (wide Spread, ambient cloud)
- **Call and Response**: Alternate between different splices on different tracks

---

#### 2.1.8 Sample Management & File I/O

**Loading Audio**
- **Supported formats**: WAV, AIFF, FLAC, MP3, M4A, OGG
- **Sample rate conversion**: Automatic resampling to project rate
- **Bit depth**: Convert to 32-bit float internal
- **Stereo handling**:
  - Load as stereo
  - Convert to mono (L+R mix or L/R selection)
  - Load L and R into separate reels

**Reel Library**
- **Browser**: Visual browser with waveform previews
- **Metadata**: Name, tags, duration, sample rate
- **Collections**: Organize reels into user-defined groups
- **Search**: Filter by name, tags, duration
- **Drag & drop**: Import from Finder

**Export Options**
- **Bounce to file**: Render current reel with all processing
- **Export splice**: Extract individual splice as audio file
- **Batch export**: Export all splices as individual files
- **Format**: WAV (16/24/32-bit), AIFF, FLAC

---

#### 2.1.9 Advanced Features

**Loop Modes (Per-Splice)**
- **Forward**: Standard playback direction
- **Reverse**: Grains play backwards through splice
- **Ping-pong**: Alternate forward/reverse on each grain
- **Random**: Each grain chooses random direction

**Grain Stereo Processing**
- **Panning**:
  - Alternating L/R (Morph gene-shift mode)
  - Spread (width increases with Morph in time-stretch mode)
  - Random pan per grain
  - Fixed pan position

- **Stereo width**: Control overall stereo field (0% = mono, 100% = full width)

**Freeze Mode**
- **Function**: Capture current grain output and loop infinitely
- **Trigger**: Button or external gate
- **Use**: Create sustained pads from transient material
- **Interaction**: Freeze layer can be mixed with live granulation

**Musical Quantization System**

The engine includes comprehensive quantization to ensure musical results:

*Pitch/Interval Quantization*
- **Global or per-track**: Apply quantization globally or per individual track
- **Quantization targets**: VARISPEED and/or PITCH parameters
- **Interval Sets** (user-selectable):
  - **Octaves**: -2 oct, -1 oct, unison, +1 oct, +2 oct (clean, simple)
  - **Octaves + Fifths**: Perfect intervals for power chords and open voicings
  - **Octaves + Fourths**: Alternative perfect interval set
  - **Chromatic**: All 12 semitones (full harmonic palette)
  - **Diatonic Scales**: Major, natural minor, harmonic minor, melodic minor
  - **Pentatonic**: Major and minor pentatonic scales
  - **Custom**: User defines specific interval set (e.g., [0, +3, +7, +12] for minor triads)
- **Root note**: C, C#, D, D#, E, F, F#, G, G#, A, A#, B
- **Snap behavior**: Immediate or gradual (glide to nearest quantized value)

*Rhythmic Quantization*
- **Grain trigger sync**: Align grain triggering to tempo grid
  - Whole notes, half notes, quarter notes, 8th, 16th, 32nd, triplets
- **Clock source**: Internal tempo, MIDI clock, or manual tap tempo
- **Swing**: Add rhythmic feel (50-75% swing amount)

*Splice Quantization*
- **Auto-splice**: Create splice markers at beat divisions
- **Divisions**: 1 bar, 2 bars, 4 bars, or custom length
- **Use**: Automatically organize loops and phrases musically

---

#### 2.1.10 DSP Implementation Notes

**Grain Scheduling**
- **Algorithm**: Priority queue with microsecond precision
- **Look-ahead**: 100ms grain pre-calculation for smooth triggering
- **Overlap management**: Dynamic voice allocation up to max polyphony
- **Anti-aliasing**: Sinc interpolation for pitch-shifting

**Time-Stretching Algorithm**
- **Method**: Phase vocoder (PSOLA or similar)
- **FFT size**: 2048-4096 samples (quality vs. CPU trade-off)
- **Hop size**: Adaptive based on stretch ratio
- **Formant preservation**: Optional for vocal material

**Pitch-Shifting Algorithm**
- **Method**: Decoupled pitch shift uses time-domain pitch shifting or phase vocoder
- **Varispeed method**: Simple resampling (coupled speed/pitch, classic tape behavior)
- **Formant preservation**: Optional (essential for musical vocal/instrument content)
- **Quality modes**:
  - Low-latency (lighter CPU, simple interpolation, suitable for real-time performance)
  - High-quality (higher CPU, phase vocoder with formant correction)
- **Quantization**: Applied post-algorithm to snap to musical intervals
  - Lookup table for semitone → frequency ratio conversions
  - Interpolation for smooth transitions between quantized values (if glide enabled)

**Buffer Management**
- **Circular buffers**: For efficient memory usage
- **Lock-free design**: Audio thread never blocks on memory allocation
- **Double-buffering**: UI can read waveform data without blocking audio

---

#### 2.1.11 User Interface Components

**Waveform Display**
- **Overview**: Full reel with all splices visible
- **Zoom**: Drill down to sample-level precision
- **Splice markers**: Draggable regions with color coding
- **Playhead**: Real-time Slide position indicator
- **Spray visualization**: Cloud showing grain distribution
- **Recording meter**: Level indication during record

**Parameter Panel**
- **Primary controls**: Large knobs for Slide, Gene Size, Morph, Varispeed, Organize
- **Extended parameters**: Expandable section for Pitch, Spread, Jitter, Filter
- **Quantization indicators**: Visual feedback showing active quantization (e.g., "Octaves" badge)
- **Modulation indicators**: Visual feedback when parameters are being modulated
- **Value readouts**: Numeric display with units and interval notation
  - Pitch displays: "+12 st (1 oct)", "+7 st (P5)", etc.
  - Varispeed displays: "200% (+1 oct)" when quantized

**Splice Manager**
- **List view**: All splices with name, length, loop status
- **Edit**: Rename, recolor, set loop points
- **Reorder**: Drag to change Organize sequence
- **Actions**: Delete, duplicate, merge, split

**Track Mixer (for multi-track mode)**
- **Per-track strip**: Volume, pan, solo, mute
- **Visual feedback**: Level meters, activity indicators
- **Routing**: Output destination selection

---

#### 2.1.12 Controller Mappings

**Monome Grid (128) - Granular Page (Revised)**

*Layout*
```
Row 1-2: Buffer scrubbing (128 positions across active splice)
         - Brightness = playhead position
         - Touch = jump to position (Slide control)

Row 3:   Gene Size (16 preset values)
         - Brightness = selected size
         - Values: 5ms, 10ms, 20ms, 40ms, 80ms, 120ms, 200ms, 350ms,
                   500ms, 750ms, 1000ms, 1500ms, 2000ms, 3000ms, 4000ms, 5000ms

Row 4:   Morph (16 values from gene-shift to time-stretch)
         - Dimmer at low values (gene-shift zone)
         - Brighter at high values (time-stretch zone)
         - Mid-brightness at 50% transition

Row 5:   Varispeed (16 values)
         - Left half = reverse, right half = forward
         - Center = freeze (off)
         - Brightness = speed amount

Row 6:   Track selection (columns 1-4) + Track mute (columns 5-8)
         - Bright = selected/unmuted
         - Dim = unselected/muted
         - Columns 9-12: Quantization mode (off/chromatic/octaves/oct+5ths)
         - Columns 13-16: Loop mode (forward/reverse/ping-pong/random)

Row 7:   Splice triggers (16 quick-access splices)
         - Press = jump to splice (Organize)
         - Brightness = current splice indicator
         - Hold + Row 1-2 = set splice boundaries

Row 8:   Transport & recording
         - Col 1-2: Record (press=toggle, bright=recording)
         - Col 3-4: Play mode (gate/trigger/free-running)
         - Col 5-6: Splice create (press=add splice at playhead)
         - Col 7-8: Shift (advance splice)
         - Col 9-10: SOS amount (5 levels: 0%, 25%, 50%, 75%, 100%)
         - Col 11-12: Freeze mode
         - Col 13-16: Page navigation (to Plaits/Mixer/etc.)
```

**Monome Arc (4-encoder) - Granular Configuration (Revised)**

*Primary Mode*
```
Encoder 1: SLIDE (buffer position)
           - LED ring shows position in splice
           - Full rotation = full splice length
           - Press = reset to center

Encoder 2: GENE SIZE
           - LED ring shows size amount (logarithmic)
           - Small values = few LEDs, large values = many LEDs
           - Press = default (100ms)

Encoder 3: VARISPEED
           - LED ring centered at 12 o'clock (normal speed)
           - Clockwise = faster forward
           - Counter-clockwise = faster reverse
           - Press = reset to 0% (freeze)

Encoder 4: MORPH
           - LED ring shows density/overlap
           - Low values = sparse LEDs (gene-shift)
           - High values = dense LEDs (time-stretch)
           - Press = 50% (neutral)
```

*Alt Mode (Hold Grid button or keyboard modifier)*
```
Encoder 1: SPREAD (grain position randomization)
           - LED ring shows amount
           - Press = 0% (reset)

Encoder 2: PITCH (independent pitch shift with quantization)
           - Centered at 12 o'clock (no shift)
           - ±4 octaves range
           - LED ring snaps to quantized intervals when enabled
           - Octaves Only mode: Shows discrete LED segments at octave positions
           - Octaves + Fifths: Additional LED segments at fifth intervals

Encoder 3: FILTER CUTOFF
           - Full range = full LED ring
           - Low cutoff = few LEDs
           - Key tracking option follows PITCH setting

Encoder 4: JITTER (timing randomization)
           - More LEDs = more randomization
           - Press = 0% (reset)
```

**MIDI Control**
- **Note On**: Trigger grain playback (if in trigger mode)
- **Note Pitch**: Transpose grain pitch (chromatic, overrides PITCH parameter)
  - Respects global quantization settings if enabled
  - Can set "reference pitch" (e.g., C3 = unison, C4 = +1 oct)
- **Velocity**: Modulate grain amplitude and/or filter cutoff
- **Aftertouch**: Assignable (default: Morph or Filter Cutoff)
- **Mod Wheel (CC1)**: Assigned to Morph by default
- **Expression (CC11)**: Assigned to Slide by default
- **Sustain Pedal (CC64)**: Hold current grains, freeze mode
- **CC Learn**: Map any CC to any parameter
- **MIDI Clock**: Sync grain triggering and tempo-based quantization

---

#### 2.1.13 Presets & Recall

**Preset Structure**
Each preset contains:
- All parameter values (Slide, Gene Size, Morph, Varispeed, etc.)
- Reel reference (path to audio file or embedded audio data)
- All splice markers and metadata
- Track configuration (for multi-track mode)
- Modulation assignments
- Controller mappings

**Preset Categories**
- **Textures**: Ambient, pad-like granular clouds
- **Rhythmic**: Synced, percussive grain patterns
- **Pitched/Harmonic**: Musical, melodic granulation with quantization presets
  - "Octave Doubler" (multiple tracks at octave intervals)
  - "Power Chords" (octaves + fifths stacking)
  - "Vocal Harmonizer" (formant-preserved pitch shifts)
- **Experimental**: Extreme, glitchy, chaotic
- **User**: Custom saved presets

**Preset Morphing**
- **A/B comparison**: Load two presets, crossfade between them
- **Morph amount**: Interpolate all parameters
- **Use**: Smooth transitions, performance tool

---

#### 2.1.14 Performance Features

**Macro Controls**
- **Complexity**: Master control over Morph, Jitter, and Spread
  - Low = simple, predictable, musical
  - High = chaotic, evolving, experimental

- **Brightness**: Master control over Filter Cutoff and high-frequency content
  - Can be linked to key tracking for musical filtering

- **Movement**: Master control over Slide modulation rate and Spread
  - Tempo-syncable for musical movement

- **Harmony** (NEW): Master control over multi-track pitch relationships
  - Presets: "Unison", "Octaves", "Octaves+5ths", "Triad", "Cluster"
  - Instantly configure all track pitch offsets for harmonic stacking

**Randomization**
- **Per-parameter**: Randomize individual parameters within range
- **Organized chaos**: Randomize with musically-sensible constraints
- **Dice roll**: Completely randomize all parameters
- **Undo**: Return to pre-randomization state

**Scene Recall**
- **8 scene slots**: Store complete engine state
- **Instant recall**: Single button press to load scene
- **Morphing**: Smooth interpolation between scenes
- **Use**: Live performance, A/B/C/D arrangement sections

---

#### 2.1.15 Output & Routing

**Direct Outputs**
- **Main stereo**: Summed output of all tracks
- **Individual tracks**: Separate outputs for external processing
- **Aux outputs**: Pre-fader sends to effects

**Internal Routing**
- **To mixer**: Granular engine channel with full mixer controls
- **To effects**: Send levels to delay/reverb/distortion
- **Sidechain**: Granular output can modulate other parameters

**Export Rendering**
- **Offline bounce**: Render to file faster than real-time
- **Stem export**: Each track as separate audio file
- **Effect rendering**: Render with or without effects

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
- **Version**: 1.2
- **Date**: 2026-02-01
- **Status**: Unified granular specification with musical focus
- **Changes from v1.1**:
  - Rationalized Morphagene and Mangl approaches into unified parameter set
  - Removed redundant SPEED parameter (functionality merged into VARISPEED)
  - Removed DENSITY parameter (functionality handled by MORPH)
  - Comprehensive musical quantization system for pitch/intervals
  - Octaves, Octaves+Fifths, Octaves+Fourths, and custom interval quantization
  - Per-track or global quantization settings
  - Enhanced multi-track architecture for harmonic layering and octave doubling
  - Harmony macro control for instant harmonic stack configuration
  - MIDI note input with quantization support
  - Updated controller mappings to reflect unified approach

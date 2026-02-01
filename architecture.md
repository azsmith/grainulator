# Grainulator Architecture Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [High-Level Architecture](#high-level-architecture)
3. [Component Architecture](#component-architecture)
4. [Audio Processing Pipeline](#audio-processing-pipeline)
5. [Threading Model](#threading-model)
6. [Data Flow Diagrams](#data-flow-diagrams)
7. [Module Dependencies](#module-dependencies)
8. [Memory Architecture](#memory-architecture)

---

## 1. System Overview

Grainulator is a macOS music application built around real-time granular synthesis with multi-track capabilities. The application follows a modular architecture with clear separation between:

- **Audio Engine** (C++ for performance)
- **Application Logic** (Swift for macOS integration)
- **User Interface** (SwiftUI for modern UI)
- **Controller I/O** (MIDI, Grid, Arc communication)

### Core Design Principles

1. **Real-time Performance**: Audio processing runs in dedicated real-time threads with no locks
2. **Lock-Free Communication**: Audio and UI threads communicate via lock-free structures
3. **Modular Design**: Components are loosely coupled and independently testable
4. **Type Safety**: Swift for high-level logic, C++ for DSP performance
5. **Immutable State**: Parameter changes create new state rather than mutating

---

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Interface Layer                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   SwiftUI    │  │   Waveform   │  │  Parameter Controls  │  │
│  │   Windows    │  │   Display    │  │   & Visualizations   │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└────────────────────────┬────────────────────────────────────────┘
                         │ View Models / Commands
┌────────────────────────▼────────────────────────────────────────┐
│                    Application Logic Layer                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   Project    │  │    Preset    │  │   File Management    │  │
│  │  Management  │  │  Management  │  │   & Persistence      │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└────────────────────────┬────────────────────────────────────────┘
                         │ Parameter Updates / Audio Commands
┌────────────────────────▼────────────────────────────────────────┐
│                     Audio Engine Layer (C++)                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   Granular   │  │    Plaits    │  │   Effects Chain      │  │
│  │    Engine    │  │ Synthesizer  │  │ (Delay/Verb/Dist)    │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
│         │                  │                      │              │
│         └──────────────────┼──────────────────────┘              │
│                            ▼                                     │
│                    ┌──────────────┐                              │
│                    │  Audio Mixer │                              │
│                    └──────┬───────┘                              │
└───────────────────────────┼──────────────────────────────────────┘
                            ▼
┌───────────────────────────────────────────────────────────────┐
│                    System I/O Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │  CoreAudio   │  │   CoreMIDI   │  │  serialosc (OSC)   │  │
│  │  (Audio I/O) │  │  (MIDI I/O)  │  │ (Grid/Arc Comms)   │  │
│  └──────────────┘  └──────────────┘  └────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

---

## 3. Component Architecture

### 3.1 Granular Synthesis Engine

```
GranularEngine
├── BufferManager
│   ├── ReelBuffer[32]              // Up to 32 reels
│   │   ├── AudioBuffer             // 2.5 min @ 48kHz
│   │   ├── SpliceMarkers[300]      // Splice metadata
│   │   └── Metadata                // Name, tags, etc.
│   └── BufferPool                  // Memory management
│
├── GranularVoice[4]                // Multi-track voices
│   ├── GrainScheduler
│   │   ├── GrainPool               // Pre-allocated grain objects
│   │   ├── PriorityQueue           // Scheduled grain events
│   │   └── VoiceAllocator          // Dynamic voice assignment
│   │
│   ├── GrainProcessor
│   │   ├── WindowGenerator         // Envelope shapes
│   │   ├── PitchShifter           // Time-domain pitch shift
│   │   ├── TimeStretcher          // Phase vocoder
│   │   └── Interpolator           // Sample-accurate playback
│   │
│   ├── ParameterState
│   │   ├── Slide (position)
│   │   ├── GeneSize (grain size)
│   │   ├── Morph (density/overlap)
│   │   ├── Varispeed (speed/pitch coupled)
│   │   ├── Organize (splice selector)
│   │   ├── Pitch (independent pitch)
│   │   ├── Spread (position jitter)
│   │   ├── Jitter (time randomness)
│   │   └── Filter (per-grain LPF)
│   │
│   └── QuantizationEngine
│       ├── IntervalSet              // Active intervals
│       ├── SnapToNearest()          // Quantize function
│       └── CustomScales[]           // User-defined scales
│
├── RecordingEngine
│   ├── InputBuffer                  // Live input capture
│   ├── SOSMixer                     // Sound-on-Sound blend
│   ├── SpliceDetector              // Auto-splice creation
│   └── NormalizationProcessor      // Post-record gain
│
└── ModulationRouter
    ├── LFOs[4]                      // Per-voice modulation
    ├── EnvelopeFollowers[4]         // Amplitude tracking
    └── CVOutputs[]                  // EOG/EOS gates
```

### 3.2 Plaits Synthesizer

```
PlaitsSynthesizer
├── PlaitsEngine                     // Ported from Mutable Instruments
│   ├── SynthesisModels[16]
│   │   ├── VirtualAnalog
│   │   ├── PhaseDistortion
│   │   ├── FM
│   │   ├── WavetableOsc
│   │   └── ... (12 more models)
│   │
│   └── ParameterSet
│       ├── ModelIndex
│       ├── Harmonics (timbre)
│       ├── Morph (secondary timbre)
│       ├── Frequency
│       └── Decay
│
├── ModulationMatrix
│   ├── LFO
│   │   ├── Rate
│   │   ├── Depth
│   │   ├── Waveform
│   │   └── Destinations[]
│   │
│   └── ADSR Envelope
│       ├── Attack, Decay, Sustain, Release
│       └── EnvelopeAmount[destinations]
│
└── OutputProcessor
    ├── MainOut                      // Primary output
    └── AuxOut                       // Secondary output
```

### 3.3 Effects Chain

```
EffectsChain
├── TapeDelay
│   ├── DelayLine[2]                 // Stereo delays
│   ├── FeedbackPath
│   │   ├── LowPassFilter           // Tape darkening
│   │   └── Saturation              // Tape saturation
│   ├── LFO                          // Wow/flutter modulation
│   └── PingPongRouter              // Stereo spread
│
├── Reverb
│   ├── PreDelay                     // Early reflection delay
│   ├── AllPassFilters[8]           // Diffusion network
│   ├── CombFilters[4]              // Resonant delays
│   ├── DampingFilter               // High-freq absorption
│   └── StereoWidth                 // Width control
│
└── Distortion
    ├── DistortionTypes[]
    │   ├── TapeSaturation          // Soft clipping
    │   ├── TubeSaturation          // Asymmetric warmth
    │   ├── Fuzz                    // Hard clipping
    │   └── BitCrusher              // Sample rate/bit reduction
    │
    ├── ToneControl                  // Pre/post EQ
    └── ParallelMixer               // Dry/wet blend
```

### 3.4 Mixer

```
Mixer
├── InputChannels[N]
│   ├── ChannelStrip
│   │   ├── Gain (-∞ to +6dB)
│   │   ├── Pan (L-C-R)
│   │   ├── Mute/Solo
│   │   ├── Metering (Peak/RMS)
│   │   └── EffectsSends[3]
│   │       ├── Send to Delay
│   │       ├── Send to Reverb
│   │       └── Send to Distortion
│   │
│   └── PrePostFaderSwitch          // Send routing
│
├── EffectsReturns[3]
│   ├── ReturnLevel
│   └── ReturnPan
│
├── MasterChannel
│   ├── MasterFader
│   ├── Limiter (optional safety)
│   └── MasterMetering
│
└── RoutingMatrix
    └── InternalBusRouting          // Flexible signal flow
```

---

## 4. Audio Processing Pipeline

### 4.1 Signal Flow (Per-Sample Block)

```
Input Audio (Live/File)
    │
    ▼
┌─────────────────────────┐
│  Granular Engine Track 1 │ ──┐
└─────────────────────────┘   │
┌─────────────────────────┐   │
│  Granular Engine Track 2 │ ──┤
└─────────────────────────┘   │
┌─────────────────────────┐   │   Mix
│  Granular Engine Track 3 │ ──┼──────►  Granular Sum
└─────────────────────────┘   │
┌─────────────────────────┐   │
│  Granular Engine Track 4 │ ──┘
└─────────────────────────┘
                                        ┌─────────────────┐
                                        │  Channel Strip  │
                                        │   (Gain/Pan)    │
                                        └────────┬────────┘
                                                 │
MIDI Input                                       ├──► Send to Delay ──┐
    │                                            │                     │
    ▼                                            ├──► Send to Reverb ─┤
┌─────────────────────────┐                     │                     │
│  Plaits Synthesizer     │                     └──► Send to Dist ───┤
└──────────┬──────────────┘                                           │
           │                      ┌─────────────────┐                 │
           └─────────────────────►│  Channel Strip  │                 │
                                  │   (Gain/Pan)    │                 │
                                  └────────┬────────┘                 │
                                           │                          │
                                           ├──► Send to Delay ──┐     │
                                           ├──► Send to Reverb ─┤     │
                                           └──► Send to Dist ───┤     │
                                                                 │     │
                        ┌────────────────────────────────────────┘     │
                        ▼                                              │
                 ┌──────────────┐                                      │
                 │  Tape Delay  │◄─────────────────────────────────────┘
                 └──────┬───────┘
                        │
                 ┌──────▼───────┐
                 │    Reverb    │◄─────────────────────────────────────┐
                 └──────┬───────┘                                      │
                        │                                              │
                 ┌──────▼───────┐                                      │
                 │  Distortion  │◄─────────────────────────────────────┘
                 └──────┬───────┘
                        │
                        ├──► Effect Returns (with levels)
                        │
                        ▼
                ┌───────────────┐
                │  Master Mixer │
                └───────┬───────┘
                        │
                        ▼
                ┌───────────────┐
                │ Optional      │
                │ Safety Limiter│
                └───────┬───────┘
                        │
                        ▼
                  Output Audio
```

### 4.2 Granular Processing Detail (Single Voice)

```
Buffer Read Position (Slide)
    │
    ▼
┌─────────────────────────────────────┐
│  Position Calculation               │
│  base_pos = Slide * splice_length   │
│  if (Spread > 0):                   │
│    pos += random(-Spread, +Spread)  │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│  Grain Scheduling                   │
│  interval = f(GeneSize, Morph)      │
│  if (Jitter > 0):                   │
│    interval += random_timing()      │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│  Grain Playback                     │
│  1. Read samples from buffer        │
│  2. Apply playback speed:           │
│     - Varispeed (coupled)           │
│     - Quantize if enabled           │
│  3. Apply independent Pitch shift   │
│     - Quantize if enabled           │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│  Grain Envelope Application         │
│  sample *= window[phase]            │
│  (Hanning, Gaussian, etc.)          │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│  Per-Grain Filter                   │
│  if (Filter cutoff < 20kHz):        │
│    sample = lpf.process(sample)     │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│  Stereo Placement                   │
│  Mode-dependent panning:            │
│  - Alternate L/R (gene-shift)       │
│  - Spread (time-stretch)            │
│  - Random per grain                 │
└──────────────┬──────────────────────┘
               ▼
┌─────────────────────────────────────┐
│  Mix all active grains              │
│  Sum up to 64 concurrent grains     │
└──────────────┬──────────────────────┘
               ▼
         Track Output
```

---

## 5. Threading Model

### 5.1 Thread Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                          Main Thread                              │
│  - UI Event Handling                                              │
│  - View Updates                                                   │
│  - File I/O (non-blocking)                                        │
│  - Controller Communication (MIDI/Grid/Arc)                       │
└────────────────┬─────────────────────────────────────────────────┘
                 │
                 │ Lock-Free Command Queue
                 │ (Parameter Changes, Load/Save Commands)
                 │
                 ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Audio Processing Thread                        │
│  - Real-time priority (THREAD_TIME_CONSTRAINT_POLICY)            │
│  - CoreAudio callback: process(buffer, frameCount)               │
│  - No memory allocation                                           │
│  - No locks or mutexes                                            │
│  - No system calls                                                │
│                                                                   │
│  Processing order per callback:                                   │
│  1. Read parameter updates from command queue                     │
│  2. Process granular engines (all tracks)                         │
│  3. Process Plaits synthesizer                                    │
│  4. Process effects chain                                         │
│  5. Mix to output buffer                                          │
│  6. Update metering data (to lock-free buffer)                    │
└────────────────┬─────────────────────────────────────────────────┘
                 │
                 │ Lock-Free Response Queue
                 │ (Metering Data, Status Updates)
                 │
                 ▼
┌──────────────────────────────────────────────────────────────────┐
│                      Display Link Thread                          │
│  - 60Hz refresh rate                                              │
│  - Read metering data                                             │
│  - Update waveform display position                               │
│  - Trigger UI updates via main thread                             │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                     Background Worker Thread                      │
│  - File loading/saving (async)                                    │
│  - Audio file decoding                                            │
│  - Preset scanning                                                │
│  - Non-realtime bouncing                                          │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                   Controller Input Threads                        │
│  - MIDI input callback                                            │
│  - serialosc OSC listener (Grid/Arc)                              │
│  - Forward events to main thread                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 5.2 Lock-Free Communication

**Command Queue (Main → Audio Thread)**
```swift
struct ParameterCommand {
    enum CommandType {
        case setParameter(voiceID: Int, param: ParamID, value: Float)
        case loadBuffer(voiceID: Int, bufferID: Int)
        case recordStart(voiceID: Int)
        case recordStop(voiceID: Int)
        case createSplice(voiceID: Int, position: Float)
    }
    let timestamp: UInt64
    let command: CommandType
}

// Lock-free SPSC ring buffer
class CommandQueue {
    private var ringBuffer: [ParameterCommand?]
    private var writeIndex: Atomic<Int>
    private var readIndex: Atomic<Int>

    func push(_ command: ParameterCommand) { /* ... */ }
    func pop() -> ParameterCommand? { /* ... */ }
}
```

**Response Queue (Audio Thread → Main)**
```swift
struct AudioThreadResponse {
    enum ResponseType {
        case meterData(voiceID: Int, peak: Float, rms: Float)
        case playheadPosition(voiceID: Int, position: Float)
        case endOfGene(voiceID: Int, timestamp: UInt64)
        case endOfSplice(voiceID: Int, spliceID: Int)
        case bufferLoaded(voiceID: Int, success: Bool)
    }
    let timestamp: UInt64
    let response: ResponseType
}
```

---

## 6. Data Flow Diagrams

### 6.1 Parameter Change Flow

```
User adjusts knob/slider
         │
         ▼
SwiftUI View detects change
         │
         ▼
ViewModel receives update
         │
         ▼
Create ParameterCommand
         │
         ▼
Push to CommandQueue (lock-free)
         │
         ▼
Audio thread callback begins
         │
         ▼
Pop commands from queue
         │
         ▼
Update audio engine parameters
  (atomic or by copy)
         │
         ▼
Process audio with new parameters
         │
         ▼
Push response (if needed)
         │
         ▼
DisplayLink reads response
         │
         ▼
Update UI elements (meters, position)
```

### 6.2 Grid Controller Flow

```
User presses Grid button
         │
         ▼
serialosc sends OSC message
         │
         ▼
OSC listener thread receives
         │
         ▼
Decode Grid position (x, y)
         │
         ▼
Map to function (based on page/row)
         │
         ▼
Dispatch to main thread
         │
         ▼
ViewModel processes Grid event
         │
         ▼
Create appropriate ParameterCommand(s)
         │
         ▼
Push to CommandQueue
         │
         ▼
Audio thread processes command
         │
         ▼
Generate Grid LED update
         │
         ▼
Send OSC message back to Grid
         │
         ▼
Grid LEDs update (visual feedback)
```

### 6.3 File Loading Flow

```
User selects "Load Audio File"
         │
         ▼
NSOpenPanel presents file picker
         │
         ▼
User selects file → get URL
         │
         ▼
Dispatch to background thread
         │
         ▼
AudioFileReader decodes file
  - AVAudioFile or libsndfile
  - Resample if needed
  - Convert to 32-bit float
         │
         ▼
Allocate buffer in BufferManager
         │
         ▼
Copy decoded audio to buffer
         │
         ▼
Generate waveform overview (downsampled)
         │
         ▼
Create LoadBufferCommand
         │
         ▼
Push to CommandQueue
         │
         ▼
Audio thread receives command
         │
         ▼
Update buffer pointer (atomic swap)
         │
         ▼
Send confirmation response
         │
         ▼
UI updates waveform display
```

---

## 7. Module Dependencies

### 7.1 Dependency Graph

```
Application Layer (Swift)
    │
    ├─── AppKit/SwiftUI (UI Framework)
    ├─── AVFoundation (Audio file I/O)
    ├─── CoreMIDI (MIDI communication)
    └─── AudioEngineWrapper (C++/Swift bridge)
            │
            ▼
Audio Engine Layer (C++)
    │
    ├─── GranularEngine
    │       ├─── BufferManager
    │       ├─── GrainScheduler
    │       └─── DSP utilities
    │
    ├─── PlaitsEngine
    │       └─── Plaits source (Mutable Instruments)
    │
    ├─── EffectsChain
    │       ├─── TapeDelay
    │       ├─── Reverb
    │       └─── Distortion
    │
    ├─── Mixer
    │       └─── Channel routing
    │
    └─── CoreAudio
            └─── AudioUnit / AUHAL
```

### 7.2 External Dependencies

**Swift Packages**
- `AudioKit` (optional, for additional DSP utilities)
- `SwiftOSC` (for Grid/Arc communication via serialosc)

**C++ Libraries**
- `Mutable Instruments Plaits` (MIT License, bundled)
- `Accelerate.framework` (vDSP, vForce for SIMD operations)
- `libsndfile` (optional, for audio file I/O)

**System Frameworks**
- `CoreAudio.framework`
- `AudioUnit.framework`
- `CoreMIDI.framework`
- `AVFoundation.framework`
- `Accelerate.framework`

---

## 8. Memory Architecture

### 8.1 Audio Buffer Memory Layout

```
ReelBuffer Structure (per reel):

┌────────────────────────────────────────────────────────┐
│  Header (64 bytes, cache-aligned)                      │
│  - Buffer length (samples)                             │
│  - Sample rate                                          │
│  - Number of channels                                   │
│  - Number of splices                                    │
│  - Metadata pointer                                     │
└────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────┐
│  Audio Data (7,200,000 samples @ 48kHz = 2.5 min)     │
│  - 32-bit float interleaved stereo                     │
│  - 28.8 MB per reel                                    │
│  - Aligned to 16-byte boundary (SIMD)                  │
└────────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────────┐
│  Splice Markers (up to 300 splices)                    │
│  Each splice: 32 bytes                                 │
│  - Start position (sample index)                       │
│  - End position (sample index)                         │
│  - Name (pointer to string)                            │
│  - Color (RGB)                                         │
│  - Loop enabled (bool)                                 │
│  - Metadata (reserved)                                 │
└────────────────────────────────────────────────────────┘
```

**Total Memory per Reel**: ~29 MB
**Total for 32 Reels**: ~928 MB
**Additional overhead**: ~100 MB (grain pool, processing buffers)
**Total RAM usage estimate**: ~1 GB

### 8.2 Grain Pool Memory

```
GrainPool (per voice):

- Pre-allocated pool of 128 Grain objects
- Each Grain: ~256 bytes
  - Playback state (position, phase, speed, pitch)
  - Window coefficients pointer
  - Source buffer reference
  - Target output channels

Total per voice: 128 * 256 bytes = 32 KB
Total for 4 voices: 128 KB
```

### 8.3 Processing Buffers

```
Per Audio Callback:
- Input buffer: 2 channels × 512 samples × 4 bytes = 4 KB
- Output buffer: 2 channels × 512 samples × 4 bytes = 4 KB
- Per-voice temp buffers: 4 voices × 4 KB = 16 KB
- Effect processing buffers: 3 effects × 4 KB = 12 KB
- Mixer buffers: 8 KB

Total per callback: ~48 KB (allocated once at startup)
```

### 8.4 Memory Allocation Strategy

**Startup Allocation (Non-Real-Time)**
- Reel buffers (lazy allocation on first load)
- Grain pools
- Processing buffers
- Delay line buffers
- Reverb buffers

**Runtime (Real-Time Safe)**
- No allocations in audio thread
- All objects pre-allocated
- Use placement new for grain reuse
- Lock-free data structures only

**File Loading (Background Thread)**
- Temporary decode buffers
- Freed immediately after transfer to reel

---

## 9. Performance Characteristics

### 9.1 CPU Usage Targets

| Configuration | Target CPU | Notes |
|--------------|------------|-------|
| 1 granular voice, no effects | <5% | Modern Mac (M1 or later) |
| 4 granular voices, no effects | <15% | |
| 4 granular + Plaits + 3 effects | <25% | Full configuration |
| Recording + playback | +3-5% | Additional overhead |

### 9.2 Latency Targets

| Buffer Size | Expected Latency | Use Case |
|-------------|------------------|----------|
| 64 samples | ~3-4 ms | Live performance |
| 128 samples | ~6-7 ms | Default (balanced) |
| 256 samples | ~11-12 ms | Complex processing |
| 512 samples | ~21-22 ms | High track count |

### 9.3 Memory Bandwidth

- Streaming audio from buffers: ~2.5 MB/s per voice @ 48kHz stereo
- Peak bandwidth (4 voices + effects): ~15 MB/s
- Well within modern system capabilities (>20 GB/s)

---

## 10. Error Handling & Resilience

### 10.1 Audio Thread Protection

```cpp
// Audio callback NEVER throws exceptions
void audioCallback(float** output, int frameCount) {
    try {
        // Processing code
    } catch (...) {
        // Fill with silence and log error
        memset(output[0], 0, frameCount * sizeof(float));
        memset(output[1], 0, frameCount * sizeof(float));
        errorFlag.store(true);
    }
}
```

### 10.2 Buffer Underrun Handling

- Grain scheduler maintains minimum look-ahead
- If grain pool exhausted: gracefully fade out oldest grains
- Never crash, always produce audio (silence if necessary)

### 10.3 File Loading Failures

- Validate file format before loading
- Display error to user with specific message
- Continue operation with current state
- Provide fallback to default/empty buffer

---

## 11. Testing Strategy

### 11.1 Unit Tests
- Individual DSP components (grain generation, filtering, etc.)
- Parameter quantization
- Splice management
- Buffer management

### 11.2 Integration Tests
- Full audio pipeline with mock CoreAudio
- Parameter changes during playback
- Multi-track coordination
- Effect routing

### 11.3 Performance Tests
- CPU usage profiling (Instruments)
- Memory leak detection
- Real-time safety verification (no allocations/locks)
- Stress testing (maximum grains, all tracks active)

### 11.4 UI Tests
- Controller input handling
- File loading workflows
- Preset management
- Visual feedback accuracy

---

## 12. Build Configuration

### 12.1 Optimization Flags

**Debug Build**
```
- O0 (no optimization)
- Debug symbols enabled
- Assertions enabled
- Audio thread safety checks active
```

**Release Build**
```
- O3 (aggressive optimization)
- Link-time optimization (LTO)
- Vector instructions enabled (-mavx2 or -march=native)
- Assertions disabled
- Debug symbols stripped
```

### 12.2 Code Organization

```
Grainulator/
├── Source/
│   ├── Audio/              (C++ audio engine)
│   │   ├── Granular/
│   │   ├── Plaits/
│   │   ├── Effects/
│   │   └── Mixer/
│   │
│   ├── Application/        (Swift app logic)
│   │   ├── Models/
│   │   ├── ViewModels/
│   │   └── Services/
│   │
│   ├── UI/                 (SwiftUI views)
│   │   ├── MainWindow/
│   │   ├── Components/
│   │   └── Visualizations/
│   │
│   └── Controllers/        (MIDI/Grid/Arc)
│       ├── MIDI/
│       └── Monome/
│
├── Resources/
│   ├── Assets.xcassets
│   ├── Presets/
│   └── Samples/
│
└── Tests/
    ├── AudioEngineTests/
    ├── ApplicationTests/
    └── UITests/
```

---

## Document Information
- **Version**: 1.0
- **Date**: 2026-02-01
- **Author**: Architecture specification for Grainulator
- **Related Documents**: music-app-specification.md

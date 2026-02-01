# Grainulator

A sophisticated macOS music application combining granular synthesis, wavetable synthesis, and effects processing with extensive hardware controller support.

## Overview

Grainulator is a real-time granular synthesis engine with multi-track capabilities, inspired by the Make Noise Morphagene and the Mangl engine for norns. It features:

- **Granular Synthesis Engine**: 4 independent voices with Morphagene-inspired controls
- **Plaits Synthesizer**: 16 synthesis models from Mutable Instruments
- **Effects Chain**: Tape delay, reverb, and distortion
- **Multi-View Interface**: Focus, multi-voice, and performance modes
- **Hardware Integration**: MIDI, Monome Grid (128), and Arc support
- **Musical Quantization**: Octaves, fifths, custom intervals for harmonic layering

## Project Status

**Current Phase**: Specification & Planning
- ✅ Feature specification complete
- ✅ Architecture documentation complete
- ✅ API specification complete
- ✅ UI/UX design complete
- ✅ Project structure initialized
- ⏳ Implementation pending

## Documentation

### Core Specifications
- **[music-app-specification.md](music-app-specification.md)** - Complete feature specification with detailed parameter descriptions
- **[architecture.md](architecture.md)** - System architecture, threading model, and technical design
- **[api-specification.md](api-specification.md)** - API documentation for C++, Swift, and controller protocols
- **[ui-design-specification.md](ui-design-specification.md)** - UI/UX design guidelines and component specifications

### Key Features

#### Granular Synthesis Engine
- **Hierarchical Structure**: Reels → Splices → Grains
- **Core Parameters**: Slide, Gene Size, Morph, Varispeed, Organize, Pitch
- **Extended Parameters**: Spread, Jitter, Filter (cutoff & resonance)
- **Multi-Track**: 4 independent granular voices
- **Recording**: Live input, Sound-on-Sound overdubbing
- **Musical Quantization**: Octaves, octaves+fifths, chromatic, custom intervals

#### Plaits Synthesizer
- **16 Synthesis Models**: Virtual analog, FM, wavetable, physical modeling, percussion
- **Modulation**: Internal LFO and ADSR envelope
- **Dual Outputs**: Main and auxiliary outputs

#### Effects
- **Tape Delay**: With wow/flutter and tape saturation
- **Reverb**: Algorithmic plate/hall with adjustable decay and damping
- **Distortion**: Multiple algorithms (tape, tube, fuzz, bit crushing)

#### User Interface
- **Multi-Voice View**: See all voices simultaneously
- **Focus View**: Full-width single voice with all parameters visible
- **Performance View**: Minimal UI with scene recall and large visual feedback
- **Dark Theme**: Eye-strain reducing color scheme

#### Controllers
- **MIDI**: Learn mode, CC mapping, note input with quantization
- **Monome Grid 128**: Custom pages for granular, synthesis, mixer
- **Monome Arc**: 4-encoder control with visual LED feedback

## Project Structure

```
grainulator/
├── README.md                          # This file
├── music-app-specification.md          # Feature specification
├── architecture.md                     # Architecture documentation
├── api-specification.md                # API documentation
├── ui-design-specification.md          # UI/UX design spec
│
├── Source/                             # Source code
│   ├── Audio/                          # C++ audio engine
│   │   ├── Core/                       # Core audio infrastructure
│   │   ├── Granular/                   # Granular synthesis engine
│   │   ├── Plaits/                     # Plaits synthesizer (ported)
│   │   ├── Effects/                    # Effects processors
│   │   └── Mixer/                      # Mixer and routing
│   │
│   ├── Application/                    # Swift application layer
│   │   ├── Models/                     # Data models
│   │   ├── ViewModels/                 # View models
│   │   └── Services/                   # Business logic services
│   │
│   ├── UI/                             # SwiftUI user interface
│   │   ├── Views/                      # Main views
│   │   ├── Components/                 # Reusable UI components
│   │   └── Visualizations/             # Waveform, meters, etc.
│   │
│   └── Controllers/                    # Controller integration
│       ├── MIDI/                       # MIDI controller support
│       └── Monome/                     # Grid and Arc support
│
├── Resources/                          # Application resources
│   ├── Assets/                         # Images, icons, colors
│   ├── Presets/                        # Factory presets
│   ├── Samples/                        # Demo audio samples
│   └── Documentation/                  # Additional docs
│
├── Tests/                              # Test suites
│   ├── AudioEngineTests/               # Audio engine unit tests
│   ├── ApplicationTests/               # Application logic tests
│   ├── UITests/                        # UI automation tests
│   └── IntegrationTests/               # End-to-end tests
│
├── Build/                              # Build outputs
└── Tools/                              # Development tools & scripts
```

## Technology Stack

### Core Technologies
- **Platform**: macOS 12.0+
- **Languages**: Swift 5.9+ (UI/App), C++17 (Audio)
- **Audio**: CoreAudio, AudioUnit
- **UI**: SwiftUI
- **MIDI**: CoreMIDI
- **Grid/Arc**: serialosc (OSC protocol)

### Frameworks & Dependencies
- **Accelerate.framework** - SIMD DSP operations
- **AVFoundation** - Audio file I/O
- **CoreMIDI** - MIDI communication
- **SwiftOSC** - OSC messaging for Monome devices
- **Mutable Instruments Plaits** - Synthesis engine (MIT license)

### Development Tools
- **Xcode** 15.0+
- **Swift Package Manager** - Dependency management
- **Instruments** - Performance profiling
- **Git** - Version control

## Getting Started

### Prerequisites
- macOS 12.0 (Monterey) or later
- Xcode 15.0 or later
- Audio interface (recommended for low latency)
- Optional: MIDI controller, Monome Grid, Monome Arc

### Building (Future)
```bash
# Clone the repository
git clone <repository-url>
cd grainulator

# Open in Xcode
open Grainulator.xcodeproj

# Or build from command line
xcodebuild -scheme Grainulator -configuration Release
```

### Running Tests (Future)
```bash
# Run all tests
xcodebuild test -scheme Grainulator

# Run specific test suite
xcodebuild test -scheme Grainulator -only-testing:AudioEngineTests
```

## Development Roadmap

### Phase 1: Core Audio & Synthesis (Planned)
- [ ] Basic macOS application scaffold
- [ ] CoreAudio setup and audio I/O
- [ ] Plaits synthesizer port and integration
- [ ] Basic UI for Plaits control

### Phase 2: Granular Engine (Planned)
- [ ] Audio file loading and buffer management
- [ ] Basic granular synthesis engine
- [ ] Morphagene-inspired parameter implementation
- [ ] Waveform display and buffer navigation UI
- [ ] Multi-track architecture
- [ ] Musical quantization system

### Phase 3: Effects & Mixer (Planned)
- [ ] Tape delay implementation
- [ ] Reverb implementation
- [ ] Distortion implementation
- [ ] Mixer with routing and metering

### Phase 4: File Management (Planned)
- [ ] Project save/load system
- [ ] Preset management for each voice
- [ ] Audio file import/export
- [ ] Settings persistence

### Phase 5: Controller Integration (Planned)
- [ ] MIDI keyboard input and learn system
- [ ] Monome Grid integration and layout implementation
- [ ] Monome Arc integration
- [ ] Controller configuration UI

### Phase 6: Polish & Optimization (Planned)
- [ ] UI refinement and visual design
- [ ] Performance optimization
- [ ] Testing and bug fixes
- [ ] Documentation and user manual

## Architecture Highlights

### Threading Model
- **Main Thread**: UI, file I/O, controller communication
- **Audio Thread**: Real-time processing (lock-free, allocation-free)
- **Background Thread**: File loading, preset scanning, bouncing
- **Display Link Thread**: 60Hz UI updates

### Lock-Free Communication
- Command queue: Main → Audio thread
- Response queue: Audio → Main thread
- No mutexes or locks in audio processing path

### Memory Architecture
- Pre-allocated grain pools (128 grains per voice)
- Circular buffers for reels (up to 32 × 2.5 minutes)
- Zero allocation in real-time path

### Performance Targets
- **CPU Usage**: <25% (full configuration on M1)
- **Latency**: <10ms round-trip at 48kHz/128 buffer
- **Grain Polyphony**: Up to 64 concurrent grains

## License

To be determined. Project uses the following open-source components:

- **Mutable Instruments Plaits**: MIT License
  - Source: https://github.com/pichenettes/eurorack
  - Copyright (c) 2014-2023 Émilie Gillet

## Contributing

This project is currently in the specification phase. Contribution guidelines will be established once implementation begins.

## Contact & Support

- **Issues**: [To be set up on GitHub]
- **Discussions**: [To be set up on GitHub]
- **Documentation**: See `/Resources/Documentation/` for additional guides

## Acknowledgments

### Inspiration
- **Make Noise Morphagene** - Hardware granular processor by Tony Rolando
- **Mangl** - Norns granular sampler by @justmat
- **Mutable Instruments Plaits** - Macro oscillator by Émilie Gillet
- **Monome** - Grid and Arc controllers

### Similar Projects
- **Morphagene** (hardware)
- **Mangl** (norns/lua)
- **Granulator** (Max/MSP)
- **PaulStretch** (extreme time-stretching)

---

**Version**: 1.0.0-spec
**Status**: Specification Complete
**Last Updated**: 2026-02-01

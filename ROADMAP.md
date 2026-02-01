# Grainulator Development Roadmap

## Overview

This roadmap outlines the development phases for Grainulator, from initial prototype to production release. Each phase includes estimated timelines, milestones, and deliverables.

---

## Development Phases

### Phase 1: Foundation & Core Audio (Weeks 1-4)

**Goal**: Establish basic macOS application with working audio I/O and Plaits integration

#### Week 1-2: Project Setup & Basic Audio
- [ ] **Xcode Project Setup**
  - Create Xcode workspace
  - Configure build settings (Debug/Release)
  - Set up Swift Package Manager dependencies
  - Configure code signing
  - **Deliverable**: Buildable Xcode project

- [ ] **CoreAudio Integration**
  - Implement AudioEngine wrapper class
  - Set up audio callback with proper threading
  - Configure audio device selection
  - Implement buffer size/sample rate selection
  - Test audio throughput (silence → speakers)
  - **Deliverable**: Working audio I/O with <10ms latency

- [ ] **Basic UI Shell**
  - Create main window with SwiftUI
  - Implement menu bar
  - Add audio settings panel
  - Create status bar with CPU/latency monitoring
  - **Deliverable**: Empty but functional UI shell

#### Week 3-4: Plaits Integration
- [ ] **Port Plaits Code**
  - Import Mutable Instruments Plaits C++ code
  - Create C++/Swift bridge for Plaits
  - Adapt to CoreAudio callback
  - Implement all 16 synthesis models
  - **Deliverable**: Working Plaits engine

- [ ] **Plaits UI**
  - Create model selector dropdown
  - Implement parameter knobs (Harmonics, Morph, Frequency)
  - Add MIDI keyboard input
  - Create basic envelope visualization
  - **Deliverable**: Playable Plaits synthesizer

- [ ] **Testing & Optimization**
  - Profile CPU usage (target <10%)
  - Test all 16 models
  - Verify MIDI input works correctly
  - Fix any audio glitches
  - **Deliverable**: Stable Plaits voice

**Phase 1 Milestone**: Playable synthesizer with MIDI input and working UI

---

### Phase 2: Granular Engine (Weeks 5-10)

**Goal**: Implement complete granular synthesis engine with multi-track support

#### Week 5-6: Buffer Management & File I/O
- [ ] **Audio File Loading**
  - Implement file picker for audio files
  - Create audio file decoder (AVAudioFile)
  - Implement sample rate conversion
  - Add stereo-to-mono conversion
  - **Deliverable**: Can load and store audio files

- [ ] **Buffer Management**
  - Implement ReelBuffer class (2.5 min capacity)
  - Create BufferManager for multiple reels
  - Implement memory-efficient storage
  - Add waveform overview generation
  - **Deliverable**: 32 reel buffer system

- [ ] **Waveform Display**
  - Create waveform visualization component
  - Implement zoom and pan
  - Add playhead indicator
  - Render at 60fps
  - **Deliverable**: Interactive waveform view

#### Week 7-8: Core Granular Synthesis
- [ ] **Grain Engine**
  - Implement Grain class
  - Create GrainPool (128 grains pre-allocated)
  - Implement GrainScheduler with priority queue
  - Add window functions (Hanning, Gaussian, etc.)
  - **Deliverable**: Basic grain playback

- [ ] **Morphagene Parameters**
  - Implement Slide (position control)
  - Implement GeneSize (grain duration)
  - Implement Morph (density/time-stretch)
  - Implement Varispeed (speed/pitch coupled)
  - **Deliverable**: Core Morphagene controls working

- [ ] **Granular UI (Basic)**
  - Create parameter knobs for core controls
  - Add track selector (4 voices)
  - Implement real-time grain cloud visualization
  - **Deliverable**: Interactive granular UI

#### Week 9: Advanced Granular Features
- [ ] **Extended Parameters**
  - Implement Organize (splice selection)
  - Implement Pitch (independent pitch shift)
  - Implement Spread (position randomization)
  - Implement Jitter (timing randomization)
  - Add per-grain filter
  - **Deliverable**: Full parameter set

- [ ] **Splice Management**
  - Implement splice data structure (300 per reel)
  - Create splice markers in waveform
  - Add splice creation/deletion
  - Implement splice looping
  - **Deliverable**: Working splice system

#### Week 10: Musical Quantization
- [ ] **Quantization System**
  - Implement PitchQuantizer class
  - Add interval sets (octaves, fifths, chromatic)
  - Create custom interval support
  - Integrate with Varispeed and Pitch params
  - **Deliverable**: Musical pitch quantization

- [ ] **Multi-Track Architecture**
  - Implement 4 independent granular voices
  - Add per-track parameter management
  - Create voice routing system
  - Test polyphony (up to 64 grains total)
  - **Deliverable**: 4-track granular engine

**Phase 2 Milestone**: Complete granular synthesis engine with multi-track support

---

### Phase 3: Effects & Mixer (Weeks 11-14)

**Goal**: Implement effects chain and comprehensive mixer

#### Week 11: Tape Delay
- [ ] **Delay Implementation**
  - Create circular delay buffer
  - Implement feedback path
  - Add tape saturation modeling
  - Implement wow/flutter LFO
  - Add low-pass filter in feedback
  - **Deliverable**: Working tape delay

- [ ] **Delay UI**
  - Create delay parameter controls
  - Add bypass button
  - Implement tempo sync (optional)
  - **Deliverable**: Controllable delay effect

#### Week 12: Reverb & Distortion
- [ ] **Reverb Implementation**
  - Create all-pass filter network
  - Implement comb filters
  - Add damping filters
  - Implement stereo width control
  - **Deliverable**: Working reverb

- [ ] **Distortion Implementation**
  - Implement tape saturation
  - Add tube saturation
  - Create fuzz algorithm
  - Add bit crusher
  - Implement parallel mix
  - **Deliverable**: Multi-mode distortion

- [ ] **Effects UI**
  - Create effects chain layout
  - Add parameter controls for all effects
  - Implement bypass buttons
  - **Deliverable**: Complete effects UI

#### Week 13-14: Mixer
- [ ] **Mixer Implementation**
  - Create ChannelStrip class
  - Implement gain/pan per channel
  - Add mute/solo functionality
  - Create effects send routing
  - Implement master fader
  - **Deliverable**: Working mixer

- [ ] **Metering**
  - Implement peak/RMS metering
  - Add clip detection
  - Create meter visualization
  - Update at 60fps
  - **Deliverable**: Real-time metering

- [ ] **Mixer UI**
  - Create channel strip components
  - Add fader controls
  - Implement mute/solo buttons
  - Create send level controls
  - Add master section
  - **Deliverable**: Complete mixer interface

**Phase 3 Milestone**: Full signal chain with effects and mixing

---

### Phase 4: File Management & Persistence (Weeks 15-17)

**Goal**: Project save/load, presets, and file export

#### Week 15: Project System
- [ ] **Project Data Model**
  - Define project file format (JSON)
  - Create Project struct
  - Implement serialization/deserialization
  - Handle buffer references
  - **Deliverable**: Project data structure

- [ ] **Save/Load Implementation**
  - Implement project save
  - Implement project load
  - Add auto-save functionality
  - Handle file versioning
  - **Deliverable**: Working save/load

#### Week 16: Preset Management
- [ ] **Preset System**
  - Define preset file format
  - Create preset browser UI
  - Implement preset save/load
  - Add preset categories
  - Create search/filter functionality
  - **Deliverable**: Preset management system

- [ ] **Factory Presets**
  - Create 20+ granular presets
  - Create 20+ Plaits presets
  - Organize by category
  - Test all presets
  - **Deliverable**: Factory preset library

#### Week 17: Audio Export
- [ ] **Export Functionality**
  - Implement offline rendering
  - Add audio file export (WAV, AIFF)
  - Create sample rate/bit depth selection
  - Add stem export option
  - **Deliverable**: Audio export feature

**Phase 4 Milestone**: Complete file management with presets

---

### Phase 5: Controller Integration (Weeks 18-21)

**Goal**: Full MIDI, Grid, and Arc support

#### Week 18: MIDI Controller
- [ ] **MIDI Implementation**
  - Create MIDIController class
  - Implement MIDI device selection
  - Add note input handling
  - Create CC mapping system
  - **Deliverable**: Basic MIDI support

- [ ] **MIDI Learn**
  - Implement MIDI learn mode
  - Create mapping storage
  - Add visual feedback
  - Save/load mappings with project
  - **Deliverable**: MIDI learn system

#### Week 19-20: Monome Grid
- [ ] **Grid Communication**
  - Implement serialosc OSC client
  - Create device discovery
  - Add button input handling
  - Implement LED output
  - **Deliverable**: Grid connectivity

- [ ] **Grid Layouts**
  - Create granular page layout
  - Implement Plaits page
  - Add mixer page
  - Create page switching
  - **Deliverable**: Complete Grid integration

#### Week 21: Monome Arc
- [ ] **Arc Implementation**
  - Implement Arc OSC protocol
  - Create encoder input handling
  - Add LED ring output
  - **Deliverable**: Arc connectivity

- [ ] **Arc Configurations**
  - Create granular configuration
  - Implement Plaits configuration
  - Add mixer configuration
  - Create configuration switching
  - **Deliverable**: Complete Arc integration

**Phase 5 Milestone**: Full hardware controller support

---

### Phase 6: Advanced Features (Weeks 22-24)

**Goal**: Recording, modulation, and performance features

#### Week 22: Recording & SOS
- [ ] **Recording Implementation**
  - Add live input capture
  - Implement Sound-on-Sound
  - Create overdub mode
  - Add clock-synced recording
  - **Deliverable**: Recording system

- [ ] **Recording UI**
  - Create record controls
  - Add SOS level control
  - Implement recording indicators
  - **Deliverable**: Recording interface

#### Week 23: Modulation & Macros
- [ ] **Modulation System**
  - Implement internal LFO
  - Create modulation routing
  - Add envelope follower
  - Implement CV outputs (EOG/EOS)
  - **Deliverable**: Modulation system

- [ ] **Macro Controls**
  - Implement Complexity macro
  - Add Brightness macro
  - Create Movement macro
  - **Deliverable**: Performance macros

#### Week 24: Performance Features
- [ ] **Scene Recall**
  - Implement 8 scene slots
  - Add scene save/load
  - Create scene morphing
  - **Deliverable**: Scene system

- [ ] **Performance View**
  - Create Performance View UI
  - Implement scene recall buttons
  - Add hidden control overlay
  - **Deliverable**: Performance mode

**Phase 6 Milestone**: Complete performance and recording features

---

### Phase 7: View Modes & Polish (Weeks 25-27)

**Goal**: Implement all view modes and polish UI/UX

#### Week 25: Focus View
- [ ] **Focus View Implementation**
  - Create full-width layout
  - Implement expanded waveform
  - Add splice management table
  - Create track selector
  - Add modulation section
  - **Deliverable**: Working Focus View

- [ ] **View Transitions**
  - Implement smooth animations
  - Add view mode switching
  - Create view mode memory
  - **Deliverable**: Polished transitions

#### Week 26: UI Polish
- [ ] **Visual Refinement**
  - Refine all UI components
  - Ensure consistent styling
  - Add dark mode support
  - Implement accessibility features
  - **Deliverable**: Polished UI

- [ ] **Interaction Polish**
  - Refine all animations
  - Improve parameter feedback
  - Add tooltips everywhere
  - Test all interactions
  - **Deliverable**: Refined UX

#### Week 27: Documentation
- [ ] **User Documentation**
  - Write user manual
  - Create quick start guide
  - Add parameter reference
  - Create video tutorials (optional)
  - **Deliverable**: Complete documentation

**Phase 7 Milestone**: Complete, polished application

---

### Phase 8: Testing & Optimization (Weeks 28-30)

**Goal**: Comprehensive testing, optimization, and bug fixes

#### Week 28: Performance Optimization
- [ ] **CPU Optimization**
  - Profile all code paths
  - Optimize hot spots
  - Reduce memory allocations
  - Use SIMD where possible
  - **Target**: <25% CPU with full config

- [ ] **Latency Optimization**
  - Minimize processing delay
  - Optimize buffer sizes
  - Test different configurations
  - **Target**: <10ms round-trip latency

#### Week 29: Testing
- [ ] **Unit Testing**
  - Write tests for all audio components
  - Test parameter handling
  - Verify splice management
  - Test quantization system
  - **Target**: >80% code coverage

- [ ] **Integration Testing**
  - Test full audio pipeline
  - Verify controller integration
  - Test file operations
  - Check memory leaks
  - **Deliverable**: Stable, tested code

#### Week 30: Bug Fixes & Final Polish
- [ ] **Bug Fixing**
  - Fix all critical bugs
  - Address major issues
  - Resolve minor issues
  - **Deliverable**: Bug-free app

- [ ] **Final Testing**
  - Beta testing with users
  - Stress testing
  - Compatibility testing
  - **Deliverable**: Production-ready build

**Phase 8 Milestone**: Tested, optimized, production-ready application

---

### Phase 9: Release Preparation (Weeks 31-32)

**Goal**: Prepare for public release

#### Week 31: Release Build
- [ ] **Build Preparation**
  - Create release build
  - Code signing
  - Notarization for macOS
  - Create DMG installer
  - **Deliverable**: Distributable package

- [ ] **Release Materials**
  - Write release notes
  - Create marketing materials
  - Prepare website/landing page
  - Create demo videos
  - **Deliverable**: Release package

#### Week 32: Launch
- [ ] **Public Release**
  - Tag v1.0.0 release on GitHub
  - Publish to distribution channels
  - Announce on social media
  - Monitor feedback
  - **Deliverable**: v1.0.0 released

**Phase 9 Milestone**: Public v1.0.0 release

---

## Post-Release Roadmap (v1.1+)

### Short-Term (3-6 months)
- [ ] Bug fixes based on user feedback
- [ ] Performance improvements
- [ ] Additional presets
- [ ] Tutorial videos
- [ ] Community support forum

### Medium-Term (6-12 months)
- [ ] Multiple Plaits voices (polyphony)
- [ ] Additional effects (chorus, phaser, EQ, compressor)
- [ ] Advanced modulation matrix
- [ ] Built-in sequencer
- [ ] Plugin hosting (AudioUnit/VST)

### Long-Term (12+ months)
- [ ] iOS/iPadOS version
- [ ] Ableton Link integration
- [ ] Cloud preset sharing
- [ ] CV output support
- [ ] Additional synthesis engines

---

## Risk Management

### Technical Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| Real-time audio glitches | High | Extensive testing, lock-free design |
| CPU usage too high | Medium | Profile early, optimize hot paths |
| Memory issues with large buffers | Medium | Test with max capacity, optimize allocation |
| Controller integration issues | Low | Test with real hardware early |

### Schedule Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| Feature creep | Medium | Strict adherence to specification |
| Underestimated complexity | Medium | Build in 20% buffer time |
| External dependencies | Low | Minimize dependencies |

---

## Success Criteria

### v1.0 Release Requirements
- ✅ All core features implemented and working
- ✅ CPU usage <25% with full configuration
- ✅ Latency <10ms at 48kHz/128 buffer
- ✅ No critical or major bugs
- ✅ Complete user documentation
- ✅ Tested on macOS 12, 13, 14
- ✅ Factory presets included
- ✅ Hardware controller support working

### Quality Metrics
- **Stability**: No crashes during 1-hour test sessions
- **Performance**: Maintains real-time with 4 voices + effects
- **Usability**: Users can create sound within 5 minutes
- **Documentation**: All features documented with examples

---

## Timeline Summary

| Phase | Duration | Weeks | Deliverable |
|-------|----------|-------|-------------|
| 1: Foundation | 4 weeks | 1-4 | Working Plaits synth |
| 2: Granular | 6 weeks | 5-10 | Complete granular engine |
| 3: Effects & Mixer | 4 weeks | 11-14 | Full signal chain |
| 4: File Management | 3 weeks | 15-17 | Save/load/presets |
| 5: Controllers | 4 weeks | 18-21 | MIDI/Grid/Arc |
| 6: Advanced Features | 3 weeks | 22-24 | Recording/modulation |
| 7: View Modes | 3 weeks | 25-27 | Polished UI |
| 8: Testing | 3 weeks | 28-30 | Optimized code |
| 9: Release | 2 weeks | 31-32 | v1.0.0 launch |
| **Total** | **32 weeks** | **~8 months** | **Production app** |

---

## Resources Required

### Development
- 1 full-time developer (or equivalent)
- macOS development machine (M1/M2/M3)
- Audio interface for testing
- Xcode 15+

### Testing Hardware
- MIDI keyboard controller
- Monome Grid 128
- Monome Arc (4 encoder)
- Multiple Macs for compatibility testing

### Optional Tools
- Instruments (profiling)
- Audio analysis tools
- Version control (Git/GitHub)

---

## Document Version
- **Version**: 1.0
- **Date**: 2026-02-01
- **Status**: Initial roadmap
- **Estimated Completion**: Q3 2026 (8 months from start)

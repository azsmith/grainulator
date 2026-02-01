# Grainulator Project Structure

## Directory Organization

This document details the complete project structure and the purpose of each directory and file.

---

## Root Level

```
grainulator/
├── README.md                           # Project overview and getting started
├── music-app-specification.md          # Complete feature specification
├── architecture.md                     # System architecture documentation
├── api-specification.md                # API reference documentation
├── ui-design-specification.md          # UI/UX design guidelines
├── PROJECT-STRUCTURE.md                # This file
├── .gitignore                          # Git ignore patterns
├── .gitattributes                      # Git attributes for line endings
├── LICENSE                             # Project license (TBD)
├── CONTRIBUTING.md                     # Contribution guidelines (future)
└── CHANGELOG.md                        # Version history (future)
```

---

## Source Code (`Source/`)

### Audio Engine (`Source/Audio/`)

Pure C++ audio processing code for real-time performance.

```
Source/Audio/
├── Core/                               # Core audio infrastructure
│   ├── AudioEngine.h/cpp               # Main audio engine interface
│   ├── AudioCallback.h/cpp             # CoreAudio callback handler
│   ├── CommandQueue.h/cpp              # Lock-free command queue
│   ├── ResponseQueue.h/cpp             # Lock-free response queue
│   ├── Parameters.h                    # Parameter definitions and types
│   ├── Types.h                         # Common type definitions
│   └── Utils.h/cpp                     # Utility functions (interpolation, etc.)
│
├── Granular/                           # Granular synthesis engine
│   ├── GranularEngine.h/cpp            # Main granular engine
│   ├── GranularVoice.h/cpp             # Single granular voice
│   ├── GrainScheduler.h/cpp            # Grain scheduling and timing
│   ├── GrainProcessor.h/cpp            # Grain playback and processing
│   ├── Grain.h/cpp                     # Individual grain object
│   ├── GrainPool.h/cpp                 # Pre-allocated grain pool
│   ├── BufferManager.h/cpp             # Audio buffer management
│   ├── ReelBuffer.h/cpp                # Individual reel buffer
│   ├── SpliceManager.h/cpp             # Splice management
│   ├── WindowGenerator.h/cpp           # Grain envelope shapes
│   ├── PitchShifter.h/cpp              # Time-domain pitch shifting
│   ├── TimeStretcher.h/cpp             # Phase vocoder time-stretching
│   ├── PitchQuantizer.h/cpp            # Musical pitch quantization
│   ├── RecordingEngine.h/cpp           # Recording and SOS
│   └── ModulationRouter.h/cpp          # LFO and modulation routing
│
├── Plaits/                             # Plaits synthesizer (ported from MI)
│   ├── PlaitsEngine.h/cpp              # Main Plaits engine wrapper
│   ├── plaits/                         # Original Plaits source code
│   │   ├── dsp/                        # DSP modules
│   │   │   ├── engine/                 # Synthesis engines (16 models)
│   │   │   ├── oscillator/             # Oscillator building blocks
│   │   │   ├── physical_modelling/     # Physical modeling modules
│   │   │   └── ...
│   │   └── ...
│   ├── ModulationMatrix.h/cpp          # Plaits modulation system
│   └── OutputProcessor.h/cpp           # Main/aux output processing
│
├── Effects/                            # Effects processors
│   ├── EffectsChain.h/cpp              # Effects chain manager
│   ├── TapeDelay.h/cpp                 # Tape delay effect
│   │   ├── DelayLine.h/cpp             # Circular delay buffer
│   │   ├── TapeSaturation.h/cpp        # Tape saturation modeling
│   │   └── WowFlutter.h/cpp            # Modulation (wow/flutter)
│   ├── Reverb.h/cpp                    # Reverb effect
│   │   ├── AllPassFilter.h/cpp         # All-pass diffusion
│   │   ├── CombFilter.h/cpp            # Comb filter resonators
│   │   └── DampingFilter.h/cpp         # High-frequency damping
│   ├── Distortion.h/cpp                # Distortion effect
│   │   ├── TapeSaturation.h/cpp        # Soft clipping
│   │   ├── TubeSaturation.h/cpp        # Asymmetric warmth
│   │   ├── Fuzz.h/cpp                  # Hard clipping
│   │   └── BitCrusher.h/cpp            # Sample rate/bit reduction
│   └── BaseEffect.h                    # Effect base class
│
└── Mixer/                              # Mixer and routing
    ├── Mixer.h/cpp                     # Main mixer
    ├── ChannelStrip.h/cpp              # Individual channel processing
    ├── EffectsSend.h/cpp               # Effects send routing
    ├── Metering.h/cpp                  # Level metering
    └── RoutingMatrix.h/cpp             # Flexible signal routing
```

### Application Layer (`Source/Application/`)

Swift code for application logic, business rules, and data management.

```
Source/Application/
├── Models/                             # Data models
│   ├── Project.swift                   # Project data model
│   ├── VoiceConfiguration.swift        # Voice configuration model
│   ├── MixerConfiguration.swift        # Mixer settings model
│   ├── EffectsConfiguration.swift      # Effects settings model
│   ├── BufferReference.swift           # Audio buffer reference
│   ├── SpliceInfo.swift                # Splice metadata
│   ├── Parameter.swift                 # Parameter value object
│   ├── ParameterDefinition.swift       # Parameter metadata
│   └── Preset.swift                    # Preset data model
│
├── ViewModels/                         # View models (MVVM pattern)
│   ├── MainViewModel.swift             # Main window view model
│   ├── GranularViewModel.swift         # Granular voice view model
│   ├── PlaitsViewModel.swift           # Plaits view model
│   ├── EffectsViewModel.swift          # Effects chain view model
│   ├── MixerViewModel.swift            # Mixer view model
│   ├── WaveformViewModel.swift         # Waveform display view model
│   ├── PresetBrowserViewModel.swift    # Preset browser view model
│   └── SettingsViewModel.swift         # Settings view model
│
└── Services/                           # Business logic services
    ├── AudioEngineWrapper.swift        # C++/Swift bridge
    ├── ProjectManager.swift            # Project save/load
    ├── PresetManager.swift             # Preset management
    ├── FileManager.swift               # File operations
    ├── AudioFileReader.swift           # Audio file decoding
    ├── AudioFileWriter.swift           # Audio file encoding
    └── VisualizationEngine.swift       # Waveform generation
```

### User Interface (`Source/UI/`)

SwiftUI views and components for the user interface.

```
Source/UI/
├── Views/                              # Main application views
│   ├── MainWindow.swift                # Main window container
│   ├── MultiVoiceView.swift            # Multi-voice layout
│   ├── FocusView.swift                 # Single voice focus layout
│   ├── PerformanceView.swift           # Performance mode layout
│   ├── GranularVoiceView.swift         # Granular voice section
│   ├── PlaitsVoiceView.swift           # Plaits section
│   ├── EffectsChainView.swift          # Effects chain section
│   ├── MixerView.swift                 # Mixer section
│   ├── PresetBrowserView.swift         # Preset browser window
│   ├── SettingsView.swift              # Settings/preferences window
│   └── AboutView.swift                 # About window
│
├── Components/                         # Reusable UI components
│   ├── RotaryKnob.swift                # Rotary knob control
│   ├── Fader.swift                     # Vertical fader control
│   ├── Button/                         # Button variants
│   │   ├── PrimaryButton.swift         # Primary action button
│   │   ├── SecondaryButton.swift       # Secondary button
│   │   ├── IconButton.swift            # Icon-only button
│   │   └── ToggleButton.swift          # Toggle button
│   ├── Dropdown.swift                  # Dropdown menu
│   ├── Slider.swift                    # Horizontal slider
│   ├── TextField.swift                 # Styled text field
│   ├── Label.swift                     # Styled label
│   ├── Meter.swift                     # Level meter
│   ├── StatusIndicator.swift           # Status LED/indicator
│   ├── SpliceMarker.swift              # Splice marker overlay
│   ├── ParameterDisplay.swift          # Parameter value display
│   └── ContextMenu.swift               # Context menu helpers
│
└── Visualizations/                     # Complex visualizations
    ├── WaveformView.swift              # Waveform display
    ├── WaveformRenderer.swift          # Waveform rendering engine
    ├── GrainCloudView.swift            # Grain cloud visualization
    ├── MeterView.swift                 # Metering visualization
    ├── SpliceEditor.swift              # Interactive splice editor
    └── EnvelopeView.swift              # Envelope visualization
```

### Controllers (`Source/Controllers/`)

Hardware controller integration.

```
Source/Controllers/
├── MIDI/                               # MIDI controller support
│   ├── MIDIController.swift            # Main MIDI controller
│   ├── MIDILearn.swift                 # MIDI learn functionality
│   ├── MIDIMapping.swift               # CC mapping manager
│   └── MIDIDevice.swift                # MIDI device abstraction
│
└── Monome/                             # Monome Grid and Arc
    ├── GridController.swift            # Grid controller
    ├── ArcController.swift             # Arc controller
    ├── OSCClient.swift                 # OSC communication
    ├── SerialOSCDiscovery.swift        # Device discovery
    ├── GridLayoutManager.swift         # Grid LED layout logic
    ├── GridPages/                      # Grid page implementations
    │   ├── GranularGridPage.swift      # Granular control page
    │   ├── PlaitsGridPage.swift        # Plaits control page
    │   └── MixerGridPage.swift         # Mixer control page
    └── ArcConfigurations/              # Arc encoder configurations
        ├── GranularArcConfig.swift     # Granular configuration
        ├── PlaitsArcConfig.swift       # Plaits configuration
        └── MixerArcConfig.swift        # Mixer configuration
```

---

## Resources (`Resources/`)

### Assets (`Resources/Assets/`)

Application assets (icons, images, colors).

```
Resources/Assets/
├── Assets.xcassets/                    # Xcode asset catalog
│   ├── AppIcon.appiconset/             # Application icon
│   ├── Colors/                         # Named colors
│   │   ├── AccentColor.colorset/
│   │   ├── BackgroundPrimary.colorset/
│   │   └── ...
│   └── Icons/                          # UI icons
│       ├── PlayIcon.imageset/
│       ├── RecordIcon.imageset/
│       └── ...
└── Fonts/                              # Custom fonts (if any)
```

### Presets (`Resources/Presets/`)

Factory presets organized by category.

```
Resources/Presets/
├── Granular/                           # Granular voice presets
│   ├── Textures/                       # Texture presets
│   │   ├── shimmer-pad.grainpreset
│   │   ├── granular-wash.grainpreset
│   │   └── ...
│   ├── Rhythmic/                       # Rhythmic presets
│   │   ├── stuttering-glitch.grainpreset
│   │   └── ...
│   ├── Pitched/                        # Pitched presets
│   └── Experimental/                   # Experimental presets
│
└── Plaits/                             # Plaits synthesizer presets
    ├── Keys/                           # Keyboard presets
    ├── Pads/                           # Pad presets
    ├── Bass/                           # Bass presets
    └── Percussion/                     # Percussion presets
```

### Samples (`Resources/Samples/`)

Demo audio samples for experimentation.

```
Resources/Samples/
├── Demo/                               # Demo samples
│   ├── drone-1.wav
│   ├── pad-texture.wav
│   ├── percussion-loop.wav
│   └── vocal-phrase.wav
└── Factory/                            # Factory samples (bundled)
    └── ...
```

### Documentation (`Resources/Documentation/`)

Additional user-facing documentation.

```
Resources/Documentation/
├── UserGuide.md                        # User manual (future)
├── QuickStart.md                       # Quick start guide (future)
├── ParameterReference.md               # Parameter reference (future)
├── ControllerMapping.md                # Controller setup guide (future)
└── FAQ.md                              # Frequently asked questions (future)
```

---

## Tests (`Tests/`)

Test suites for different application layers.

```
Tests/
├── AudioEngineTests/                   # Audio engine unit tests
│   ├── GranularEngineTests.cpp         # Granular engine tests
│   ├── PlaitsEngineTests.cpp           # Plaits tests
│   ├── EffectsTests.cpp                # Effects tests
│   ├── MixerTests.cpp                  # Mixer tests
│   └── ParameterTests.cpp              # Parameter handling tests
│
├── ApplicationTests/                   # Application logic tests
│   ├── ProjectManagerTests.swift       # Project save/load tests
│   ├── PresetManagerTests.swift        # Preset management tests
│   ├── FileManagerTests.swift          # File operations tests
│   └── ViewModelTests.swift            # View model tests
│
├── UITests/                            # UI automation tests
│   ├── MainWindowUITests.swift         # Main window tests
│   ├── PresetBrowserUITests.swift      # Preset browser tests
│   └── SettingsUITests.swift           # Settings tests
│
└── IntegrationTests/                   # End-to-end integration tests
    ├── AudioPipelineTests.swift        # Full audio pipeline tests
    ├── ControllerIntegrationTests.swift # Controller integration
    └── FileWorkflowTests.swift         # File loading/saving workflows
```

---

## Build (`Build/`)

Build outputs and intermediates (git-ignored).

```
Build/
├── Debug/                              # Debug builds
├── Release/                            # Release builds
├── Intermediates/                      # Build intermediates
└── Products/                           # Final build products
```

---

## Tools (`Tools/`)

Development tools and scripts.

```
Tools/
├── Scripts/                            # Utility scripts
│   ├── generate-presets.sh             # Generate preset files
│   ├── format-code.sh                  # Code formatting
│   └── run-tests.sh                    # Test runner
├── Templates/                          # Code templates
│   ├── effect-template.cpp             # Effect boilerplate
│   └── view-template.swift             # View boilerplate
└── Utilities/                          # Development utilities
    └── preset-validator.swift          # Validate preset files
```

---

## Configuration Files

### Git Configuration

**`.gitignore`**
```
# Xcode
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcodeproj/xcshareddata/
*.xcworkspace/*
!*.xcworkspace/contents.xcworkspacedata
*.xcuserdata
DerivedData/
Build/

# Swift
*.swiftmodule
*.swiftdoc
.build/

# macOS
.DS_Store
*.dSYM.zip
*.dSYM

# Dependencies
Packages/
.swiftpm/

# User-specific
*.perspectivev3
*.mode1v3
*.mode2v3

# Audio samples (too large for git)
Resources/Samples/*
!Resources/Samples/Demo/
!Resources/Samples/.gitkeep
```

**`.gitattributes`**
```
# Auto detect text files and perform LF normalization
* text=auto

# Source code
*.swift text diff=swift
*.cpp text diff=cpp
*.h text diff=cpp
*.hpp text diff=cpp

# Documentation
*.md text
*.txt text

# Binary files
*.wav binary
*.aiff binary
*.mp3 binary
*.flac binary
*.png binary
*.jpg binary
*.jpeg binary
```

---

## File Naming Conventions

### C++ Files
- **Headers**: PascalCase with `.h` extension (e.g., `GranularEngine.h`)
- **Implementation**: PascalCase with `.cpp` extension (e.g., `GranularEngine.cpp`)
- **Test files**: PascalCase with `Tests.cpp` suffix (e.g., `GranularEngineTests.cpp`)

### Swift Files
- **Source files**: PascalCase with `.swift` extension (e.g., `MainViewModel.swift`)
- **Test files**: PascalCase with `Tests.swift` suffix (e.g., `MainViewModelTests.swift`)

### Resource Files
- **Presets**: kebab-case with `.grainpreset` extension (e.g., `shimmer-pad.grainpreset`)
- **Projects**: User-defined with `.grainproj` extension
- **Audio samples**: kebab-case with audio extension (e.g., `drone-1.wav`)

### Documentation
- **Markdown**: UPPERCASE for root-level docs (e.g., `README.md`, `LICENSE`)
- **Markdown**: PascalCase for nested docs (e.g., `UserGuide.md`)

---

## Code Organization Principles

### Modularity
- Each module has a clear, single responsibility
- Minimize dependencies between modules
- Use dependency injection where appropriate

### Separation of Concerns
- **Audio layer**: Pure DSP, no UI dependencies
- **Application layer**: Business logic, no UI specifics
- **UI layer**: Presentation only, delegates to view models

### Real-Time Safety
- No allocations in audio thread
- No locks or mutexes in audio path
- Lock-free communication between threads

### Testability
- Small, focused functions
- Pure functions where possible
- Dependency injection for testability
- Comprehensive unit test coverage

---

## Version History

- **v1.0.0-spec** (2026-02-01): Initial specification and project structure

---

## Related Documentation

- [README.md](README.md) - Project overview
- [architecture.md](architecture.md) - System architecture
- [api-specification.md](api-specification.md) - API reference
- [ui-design-specification.md](ui-design-specification.md) - UI/UX design
- [music-app-specification.md](music-app-specification.md) - Feature specification

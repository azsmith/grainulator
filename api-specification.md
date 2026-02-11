# Grainulator API Specification

## Table of Contents
1. [Overview](#overview)
2. [Audio Engine API (C++)](#audio-engine-api-c)
3. [Swift Application API](#swift-application-api)
4. [Controller API](#controller-api)
5. [Parameter Specifications](#parameter-specifications)
6. [File Format Specifications](#file-format-specifications)
7. [OSC Protocol (Grid/Arc)](#osc-protocol-gridarc)

---

## 1. Overview

This document defines the public APIs for the Grainulator application, including:
- C++ audio engine interfaces (for DSP processing)
- Swift application layer interfaces (for UI and logic)
- Controller communication protocols (MIDI, OSC)
- File formats and data structures

### API Design Principles
- **Type Safety**: Strong typing in both C++ and Swift
- **Real-Time Safety**: Audio thread APIs are lock-free and allocation-free
- **Immutability**: Parameters use value semantics where possible
- **Clear Ownership**: Explicit lifetime management

---

## 2. Audio Engine API (C++)

### 2.1 Core Audio Engine Interface

```cpp
namespace Grainulator {

// Main audio engine interface
class AudioEngine {
public:
    // Lifecycle
    AudioEngine(double sampleRate, int bufferSize);
    ~AudioEngine();

    // Audio processing (called from CoreAudio thread)
    void process(float** outputBuffer, int frameCount);

    // Parameter control (thread-safe, lock-free)
    void setParameter(VoiceID voiceID, ParameterID paramID, float value);
    void setQuantizationMode(VoiceID voiceID, QuantizationMode mode);
    void setIntervalSet(VoiceID voiceID, const IntervalSet& intervals);

    // Buffer management
    BufferID loadAudioFile(const std::string& path);
    void assignBufferToVoice(VoiceID voiceID, BufferID bufferID);
    void unloadBuffer(BufferID bufferID);

    // Recording
    void startRecording(VoiceID voiceID, RecordMode mode);
    void stopRecording(VoiceID voiceID);
    void setSOSAmount(VoiceID voiceID, float amount); // 0.0 - 1.0

    // Splice management
    SpliceID createSplice(VoiceID voiceID, float position);
    void deleteSplice(VoiceID voiceID, SpliceID spliceID);
    void setSpliceLoop(VoiceID voiceID, SpliceID spliceID, bool enabled);

    // State queries (safe to call from any thread)
    EngineState getState() const;
    MeterData getMeterData(VoiceID voiceID) const;
    float getPlayheadPosition(VoiceID voiceID) const;

private:
    // Implementation details hidden
    class Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace Grainulator
```

### 2.2 Parameter Types

```cpp
// Voice identifier (0-3 for granular tracks, 4 for Plaits)
using VoiceID = uint8_t;
constexpr VoiceID GRANULAR_VOICE_0 = 0;
constexpr VoiceID GRANULAR_VOICE_1 = 1;
constexpr VoiceID GRANULAR_VOICE_2 = 2;
constexpr VoiceID GRANULAR_VOICE_3 = 3;
constexpr VoiceID PLAITS_VOICE = 4;

// Parameter identifiers
enum class ParameterID : uint16_t {
    // Granular parameters
    Slide = 0,          // 0.0 - 1.0 (position in splice)
    GeneSize,           // 0.001 - 5.0 (seconds)
    Morph,              // 0.0 - 1.0 (gene-shift to time-stretch)
    Varispeed,          // -2.0 - 2.0 (speed multiplier)
    Organize,           // 0 - 299 (splice index)
    Pitch,              // -24.0 - 24.0 (semitones)
    Spread,             // 0.0 - 1.0 (position jitter)
    Jitter,             // 0.0 - 1.0 (timing randomness)
    FilterCutoff,       // 20.0 - 20000.0 (Hz)
    FilterResonance,    // 0.0 - 0.9 (Q)

    // Plaits parameters
    PlaitsModel,        // 0 - 23 (synthesis engine)
    PlaitsHarmonics,    // 0.0 - 1.0
    PlaitsMorph,        // 0.0 - 1.0
    PlaitsFrequency,    // 20.0 - 20000.0 (Hz)
    PlaitsDecay,        // 0.0 - 1.0

    // Mixer parameters (per voice)
    Volume,             // 0.0 - 1.0 (linear, 0 = -inf dB)
    Pan,                // -1.0 - 1.0 (L to R)
    DelaySend,          // 0.0 - 1.0
    ReverbSend,         // 0.0 - 1.0
    DistortionSend,     // 0.0 - 1.0

    // Effect parameters
    DelayTime,          // 0.001 - 2.0 (seconds)
    DelayFeedback,      // 0.0 - 1.0
    DelayWow,           // 0.0 - 1.0
    DelayMix,           // 0.0 - 1.0

    ReverbSize,         // 0.0 - 1.0
    ReverbDecay,        // 0.1 - 20.0 (seconds)
    ReverbDamping,      // 0.0 - 1.0
    ReverbMix,          // 0.0 - 1.0

    DistortionDrive,    // 0.0 - 1.0
    DistortionType,     // 0 - 3 (enum)
    DistortionTone,     // -1.0 - 1.0
    DistortionMix,      // 0.0 - 1.0

    // Master
    MasterVolume,       // 0.0 - 1.0

    COUNT
};

// Normalized parameter value (0.0 - 1.0 or specified range)
struct ParameterValue {
    float value;

    // Convert to actual parameter range
    float toSeconds() const;      // For time-based params
    float toHertz() const;        // For frequency params
    float toSemitones() const;    // For pitch params
    int toIndex() const;          // For discrete params
};
```

### 2.3 Quantization System

```cpp
// Quantization mode
enum class QuantizationMode {
    Off,                    // No quantization
    Octaves,                // 0, ±12, ±24 semitones
    OctavesFifths,          // 0, ±7, ±12, ±19, ±24 semitones
    OctavesFourths,         // 0, ±5, ±12, ±17, ±24 semitones
    Chromatic,              // All 12 semitones
    Major,                  // Major scale intervals
    Minor,                  // Natural minor scale
    Pentatonic,             // Pentatonic scale
    Custom                  // User-defined intervals
};

// Interval set for custom quantization
struct IntervalSet {
    std::vector<float> intervals;  // In semitones
    float rootNote;                 // Reference pitch (default: 0.0)

    // Factory methods
    static IntervalSet octaves();
    static IntervalSet octavesAndFifths();
    static IntervalSet chromatic();
    static IntervalSet majorScale(float root = 0.0f);
    static IntervalSet custom(std::vector<float> intervals);
};

// Quantizer utility
class PitchQuantizer {
public:
    explicit PitchQuantizer(QuantizationMode mode);
    void setIntervalSet(const IntervalSet& intervals);

    // Quantize a pitch value (in semitones) to nearest interval
    float quantize(float pitchInSemitones) const;

private:
    IntervalSet intervals_;
};
```

### 2.4 Buffer Management

```cpp
// Buffer identifier
using BufferID = uint32_t;
constexpr BufferID INVALID_BUFFER_ID = 0;

// Buffer information
struct BufferInfo {
    BufferID id;
    std::string name;
    double duration;          // In seconds
    int sampleRate;
    int channels;
    size_t sizeInBytes;
    int spliceCount;
};

// Splice information
using SpliceID = uint16_t;

struct SpliceInfo {
    SpliceID id;
    std::string name;
    uint32_t startSample;
    uint32_t endSample;
    bool loopEnabled;
    uint8_t color[3];        // RGB
};

// Buffer manager interface
class BufferManager {
public:
    // Load audio file (blocking, call from background thread)
    BufferID loadAudioFile(const std::string& path);

    // Load audio data directly
    BufferID loadAudioData(const float* data, size_t frameCount,
                          int channels, int sampleRate);

    // Unload buffer
    void unloadBuffer(BufferID bufferID);

    // Query
    BufferInfo getBufferInfo(BufferID bufferID) const;
    std::vector<BufferID> getAllBuffers() const;

    // Splice management
    SpliceID createSplice(BufferID bufferID, uint32_t position);
    void deleteSplice(BufferID bufferID, SpliceID spliceID);
    void updateSplice(BufferID bufferID, SpliceID spliceID,
                     const SpliceInfo& info);
    std::vector<SpliceInfo> getSplices(BufferID bufferID) const;
};
```

### 2.5 Recording Interface

```cpp
// Recording mode
enum class RecordMode {
    Replace,            // Overwrite existing buffer
    Overdub,            // Mix with existing (SOS)
    Append              // Add to end of buffer
};

// Recording state
struct RecordingState {
    bool isRecording;
    double recordedDuration;
    float inputLevel;           // Current input peak
    uint32_t currentPosition;   // Sample position
};

class RecordingEngine {
public:
    void startRecording(VoiceID voiceID, RecordMode mode);
    void stopRecording(VoiceID voiceID);
    void setInputSource(AudioDeviceID deviceID, int channelIndex);
    void setSOSAmount(float amount);  // 0.0 = input only, 1.0 = playback only

    RecordingState getState(VoiceID voiceID) const;
};
```

### 2.6 Metering & Visualization

```cpp
// Meter data for UI display
struct MeterData {
    float peakLeft;         // Peak level (0.0 - 1.0+)
    float peakRight;
    float rmsLeft;          // RMS level (0.0 - 1.0)
    float rmsRight;
    bool clipping;          // True if clipped in last period
};

// Playhead information
struct PlayheadInfo {
    float normalizedPosition;  // 0.0 - 1.0 within current splice
    uint32_t samplePosition;   // Absolute sample in buffer
    SpliceID currentSplice;
    int activeGrainCount;      // Number of concurrent grains
};

// Waveform data for display (downsampled)
struct WaveformData {
    std::vector<float> minSamples;  // Min value per bin
    std::vector<float> maxSamples;  // Max value per bin
    int binsPerSecond;              // Resolution
    double totalDuration;
};

class VisualizationEngine {
public:
    // Get current meter data
    MeterData getMeterData(VoiceID voiceID) const;

    // Get playhead position
    PlayheadInfo getPlayheadInfo(VoiceID voiceID) const;

    // Generate waveform overview (call once per buffer load)
    WaveformData generateWaveform(BufferID bufferID,
                                 int targetBins) const;
};
```

---

## 3. Swift Application API

### 3.1 Audio Engine Wrapper

```swift
import Foundation
import Combine

// Swift wrapper around C++ audio engine
@available(macOS 12.0, *)
public class AudioEngineWrapper: ObservableObject {

    // MARK: - Published State
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var cpuUsage: Float = 0.0
    @Published public private(set) var meterData: [VoiceID: MeterData] = [:]

    // MARK: - Initialization
    public init(sampleRate: Double = 48000, bufferSize: Int = 128) throws

    // MARK: - Lifecycle
    public func start() throws
    public func stop()

    // MARK: - Parameter Control
    public func setParameter(
        voice: VoiceID,
        parameter: ParameterID,
        value: Float
    )

    public func setParameters(
        voice: VoiceID,
        parameters: [ParameterID: Float]
    )

    // MARK: - Buffer Management
    public func loadAudioFile(url: URL) async throws -> BufferID
    public func assignBuffer(buffer: BufferID, to voice: VoiceID)
    public func unloadBuffer(_ buffer: BufferID)

    // MARK: - Recording
    public func startRecording(voice: VoiceID, mode: RecordMode)
    public func stopRecording(voice: VoiceID)

    // MARK: - Splice Management
    @discardableResult
    public func createSplice(
        voice: VoiceID,
        position: Float
    ) -> SpliceID

    public func deleteSplice(voice: VoiceID, splice: SpliceID)
    public func getSplices(voice: VoiceID) -> [SpliceInfo]

    // MARK: - Quantization
    public func setQuantizationMode(
        voice: VoiceID,
        mode: QuantizationMode
    )

    public func setCustomIntervals(
        voice: VoiceID,
        intervals: [Float]
    )
}
```

### 3.2 Parameter Models

```swift
// Parameter definition with metadata
public struct ParameterDefinition {
    let id: ParameterID
    let name: String
    let shortName: String
    let range: ClosedRange<Float>
    let defaultValue: Float
    let unit: ParameterUnit
    let displayFormat: ParameterFormat

    // Convert normalized (0-1) to actual value
    func denormalize(_ value: Float) -> Float

    // Convert actual value to normalized
    func normalize(_ value: Float) -> Float
}

public enum ParameterUnit {
    case normalized     // 0.0 - 1.0
    case seconds
    case hertz
    case semitones
    case decibels
    case degrees        // For pan (-90° to +90°)
    case index          // Discrete integer
}

public enum ParameterFormat {
    case decimal(places: Int)
    case integer
    case percentage
    case note           // Display as note name
}

// Parameter value with associated metadata
public struct Parameter {
    let definition: ParameterDefinition
    var value: Float
    var normalizedValue: Float {
        definition.normalize(value)
    }

    func formatted() -> String
}
```

### 3.3 Project Management

```swift
// Project represents the complete application state
public struct Project: Codable {
    var name: String
    var version: String
    var sampleRate: Double

    var voices: [VoiceConfiguration]
    var mixer: MixerConfiguration
    var effects: EffectsConfiguration

    var buffers: [BufferReference]
    var controllerMappings: ControllerMappings

    var metadata: ProjectMetadata
}

public struct VoiceConfiguration: Codable {
    var id: VoiceID
    var type: VoiceType
    var enabled: Bool
    var parameters: [ParameterID: Float]
    var assignedBuffer: BufferID?
    var quantizationMode: QuantizationMode
    var customIntervals: [Float]?
}

public enum VoiceType: String, Codable {
    case granular
    case plaits
}

public struct MixerConfiguration: Codable {
    var channels: [ChannelConfiguration]
    var masterVolume: Float
    var masterLimiterEnabled: Bool
}

public struct ChannelConfiguration: Codable {
    var voiceID: VoiceID
    var volume: Float
    var pan: Float
    var muted: Bool
    var soloed: Bool
    var sends: [EffectSend]
}

public struct EffectSend: Codable {
    var effectType: EffectType
    var level: Float
    var prePost: SendMode
}

public enum SendMode: String, Codable {
    case preFader
    case postFader
}

// Project manager for save/load
public class ProjectManager {
    public func saveProject(
        _ project: Project,
        to url: URL
    ) async throws

    public func loadProject(
        from url: URL
    ) async throws -> Project

    public func exportAudio(
        project: Project,
        to url: URL,
        format: AudioFormat
    ) async throws
}
```

### 3.4 Preset Management

```swift
// Preset for a single voice
public struct VoicePreset: Codable, Identifiable {
    var id: UUID
    var name: String
    var category: PresetCategory
    var tags: [String]
    var voiceType: VoiceType
    var parameters: [ParameterID: Float]
    var bufferReference: BufferReference?
    var splices: [SpliceInfo]?

    var dateCreated: Date
    var author: String?
    var description: String?
}

public enum PresetCategory: String, Codable, CaseIterable {
    case textures
    case rhythmic
    case pitched
    case experimental
    case user
}

// Preset browser and management
public class PresetManager: ObservableObject {
    @Published public private(set) var presets: [VoicePreset] = []

    public func loadPresets() async
    public func savePreset(_ preset: VoicePreset) async throws
    public func deletePreset(id: UUID) async throws

    public func searchPresets(
        query: String,
        category: PresetCategory?,
        tags: [String]
    ) -> [VoicePreset]

    public func importPreset(from url: URL) async throws -> VoicePreset
    public func exportPreset(_ preset: VoicePreset, to url: URL) async throws
}
```

---

## 4. Controller API

### 4.1 MIDI Controller

```swift
import CoreMIDI

public protocol MIDIControllerDelegate: AnyObject {
    func midiNoteOn(note: UInt8, velocity: UInt8, channel: UInt8)
    func midiNoteOff(note: UInt8, channel: UInt8)
    func midiControlChange(cc: UInt8, value: UInt8, channel: UInt8)
    func midiPitchBend(value: Int16, channel: UInt8)
}

public class MIDIController {
    public weak var delegate: MIDIControllerDelegate?

    public init() throws

    // MIDI device management
    public func availableSources() -> [MIDIEndpointRef]
    public func connectToSource(_ source: MIDIEndpointRef) throws
    public func disconnect()

    // MIDI learn
    public func startMIDILearn(
        for parameter: ParameterID,
        voice: VoiceID
    )
    public func stopMIDILearn()
    public var isLearning: Bool { get }

    // Mapping management
    public func mapCC(
        _ cc: UInt8,
        to parameter: ParameterID,
        voice: VoiceID,
        range: ClosedRange<Float>? = nil
    )

    public func removeMapping(cc: UInt8)
    public func clearAllMappings()

    public var mappings: [UInt8: MIDIMapping] { get }
}

public struct MIDIMapping: Codable {
    var cc: UInt8
    var parameter: ParameterID
    var voice: VoiceID
    var range: ClosedRange<Float>
    var curve: MappingCurve
}

public enum MappingCurve: String, Codable {
    case linear
    case logarithmic
    case exponential
}
```

### 4.2 Monome Grid Controller

```swift
import SwiftOSC

public protocol GridControllerDelegate: AnyObject {
    func gridButtonPressed(x: Int, y: Int)
    func gridButtonReleased(x: Int, y: Int)
}

public class GridController {
    public weak var delegate: GridControllerDelegate?

    public let width: Int = 16
    public let height: Int = 8

    public init() throws

    // Connection
    public func connect(host: String = "127.0.0.1", port: Int = 8080) throws
    public func disconnect()
    public var isConnected: Bool { get }

    // LED control
    public func setLED(x: Int, y: Int, brightness: UInt8)
    public func setRow(y: Int, brightnesses: [UInt8])
    public func setColumn(x: Int, brightnesses: [UInt8])
    public func setAll(brightness: UInt8)

    // Page management
    public func setPage(_ page: GridPage)
    public var currentPage: GridPage { get }
}

public enum GridPage {
    case granular
    case plaits
    case mixer
    case effects
}

// Grid layout handler
public class GridLayoutManager {
    public func handleButton(
        x: Int,
        y: Int,
        pressed: Bool,
        page: GridPage,
        engine: AudioEngineWrapper
    )

    public func updateDisplay(
        grid: GridController,
        page: GridPage,
        engineState: EngineState
    )
}
```

### 4.3 Monome Arc Controller

```swift
public protocol ArcControllerDelegate: AnyObject {
    func arcEncoderDelta(encoder: Int, delta: Int)
    func arcEncoderKey(encoder: Int, pressed: Bool)
}

public class ArcController {
    public weak var delegate: ArcControllerDelegate?

    public let encoderCount: Int = 4
    public let ledCount: Int = 64  // LEDs per encoder

    public init() throws

    // Connection
    public func connect(host: String = "127.0.0.1", port: Int = 8080) throws
    public func disconnect()
    public var isConnected: Bool { get }

    // LED control
    public func setEncoder(encoder: Int, brightnesses: [UInt8])
    public func setEncoderRange(
        encoder: Int,
        start: Int,
        end: Int,
        brightness: UInt8
    )
    public func setAllEncoders(brightness: UInt8)

    // Configuration management
    public func setConfiguration(_ config: ArcConfiguration)
    public var currentConfiguration: ArcConfiguration { get }
}

public enum ArcConfiguration {
    case granular       // Slide, GeneSize, Varispeed, Morph
    case synthesis      // Harmonics, Morph, Filter, Decay
    case mixer          // Granular level, Plaits level, Sends, Master
}
```

---

## 5. Parameter Specifications

### 5.1 Granular Parameters

| Parameter | Range | Default | Unit | Description |
|-----------|-------|---------|------|-------------|
| Slide | 0.0 - 1.0 | 0.5 | normalized | Position within splice |
| GeneSize | 0.001 - 5.0 | 0.1 | seconds | Grain duration |
| Morph | 0.0 - 1.0 | 0.5 | normalized | Density (0=gene-shift, 1=time-stretch) |
| Varispeed | -2.0 - 2.0 | 1.0 | multiplier | Playback speed (coupled pitch) |
| Organize | 0 - 299 | 0 | index | Active splice selector |
| Pitch | -24.0 - 24.0 | 0.0 | semitones | Independent pitch shift |
| Spread | 0.0 - 1.0 | 0.0 | normalized | Position randomization |
| Jitter | 0.0 - 1.0 | 0.0 | normalized | Timing randomization |
| FilterCutoff | 20.0 - 20000.0 | 20000.0 | Hz | Low-pass filter cutoff |
| FilterResonance | 0.0 - 0.9 | 0.0 | Q | Filter resonance |

### 5.2 Plaits Parameters

| Parameter | Range | Default | Unit | Description |
|-----------|-------|---------|------|-------------|
| PlaitsModel | 0 - 23 | 0 | index | Synthesis engine (24 engines + 6-OP FM with DX7 patches) |
| PlaitsHarmonics | 0.0 - 1.0 | 0.5 | normalized | Spectral content |
| PlaitsMorph | 0.0 - 1.0 | 0.5 | normalized | Secondary timbre |
| PlaitsFrequency | 20.0 - 20000.0 | 440.0 | Hz | Pitch/frequency |
| PlaitsDecay | 0.0 - 1.0 | 0.5 | normalized | Envelope decay |

### 5.3 Mixer Parameters

| Parameter | Range | Default | Unit | Description |
|-----------|-------|---------|------|-------------|
| Volume | 0.0 - 1.0 | 0.8 | linear | Channel volume |
| Pan | -1.0 - 1.0 | 0.0 | position | Stereo position |
| DelaySend | 0.0 - 1.0 | 0.0 | level | Send to delay |
| ReverbSend | 0.0 - 1.0 | 0.0 | level | Send to reverb |
| DistortionSend | 0.0 - 1.0 | 0.0 | level | Send to distortion |

### 5.4 Effect Parameters

**Tape Delay**
| Parameter | Range | Default | Unit | Description |
|-----------|-------|---------|------|-------------|
| DelayTime | 0.001 - 2.0 | 0.5 | seconds | Delay time |
| DelayFeedback | 0.0 - 1.0 | 0.4 | amount | Feedback level |
| DelayWow | 0.0 - 1.0 | 0.1 | amount | Wow/flutter amount |
| DelayMix | 0.0 - 1.0 | 0.5 | mix | Dry/wet balance |

**Reverb**
| Parameter | Range | Default | Unit | Description |
|-----------|-------|---------|------|-------------|
| ReverbSize | 0.0 - 1.0 | 0.5 | normalized | Room size |
| ReverbDecay | 0.1 - 20.0 | 2.0 | seconds | Decay time |
| ReverbDamping | 0.0 - 1.0 | 0.5 | amount | High-freq damping |
| ReverbMix | 0.0 - 1.0 | 0.3 | mix | Dry/wet balance |

**Distortion**
| Parameter | Range | Default | Unit | Description |
|-----------|-------|---------|------|-------------|
| DistortionDrive | 0.0 - 1.0 | 0.3 | amount | Drive/gain |
| DistortionType | 0 - 3 | 0 | index | Algorithm type |
| DistortionTone | -1.0 - 1.0 | 0.0 | tilt | Tone control |
| DistortionMix | 0.0 - 1.0 | 0.5 | mix | Parallel mix |

---

## 6. File Format Specifications

### 6.1 Project File Format (.grainproj)

```json
{
  "version": "1.0.0",
  "name": "My Project",
  "sampleRate": 48000,
  "bufferSize": 128,

  "voices": [
    {
      "id": 0,
      "type": "granular",
      "enabled": true,
      "parameters": {
        "slide": 0.5,
        "geneSize": 0.1,
        "morph": 0.6,
        "varispeed": 1.0,
        "organize": 0,
        "pitch": 0.0,
        "spread": 0.2,
        "jitter": 0.1,
        "filterCutoff": 8000.0,
        "filterResonance": 0.3
      },
      "bufferReference": {
        "id": "buffer-001",
        "path": "Samples/drone.wav",
        "embedded": false
      },
      "quantization": {
        "mode": "octavesFifths",
        "customIntervals": null
      },
      "splices": [
        {
          "id": 0,
          "name": "Intro",
          "startSample": 0,
          "endSample": 48000,
          "loopEnabled": true,
          "color": [255, 100, 100]
        }
      ]
    }
  ],

  "mixer": {
    "channels": [
      {
        "voiceID": 0,
        "volume": 0.8,
        "pan": 0.0,
        "muted": false,
        "soloed": false,
        "sends": [
          {"effect": "delay", "level": 0.3, "prePost": "postFader"},
          {"effect": "reverb", "level": 0.4, "prePost": "postFader"},
          {"effect": "distortion", "level": 0.0, "prePost": "preFader"}
        ]
      }
    ],
    "masterVolume": 0.85,
    "limiterEnabled": true
  },

  "effects": {
    "delay": {
      "time": 0.5,
      "feedback": 0.4,
      "wow": 0.1,
      "mix": 0.5
    },
    "reverb": {
      "size": 0.6,
      "decay": 2.5,
      "damping": 0.5,
      "mix": 0.3
    },
    "distortion": {
      "drive": 0.3,
      "type": 0,
      "tone": 0.0,
      "mix": 0.5
    }
  },

  "controllerMappings": {
    "midi": [
      {
        "cc": 1,
        "parameter": "morph",
        "voice": 0,
        "range": [0.0, 1.0],
        "curve": "linear"
      }
    ]
  },

  "metadata": {
    "created": "2026-02-01T10:00:00Z",
    "modified": "2026-02-01T14:30:00Z",
    "author": "User Name",
    "notes": "Ambient texture experiment"
  }
}
```

### 6.2 Preset File Format (.grainpreset)

```json
{
  "version": "1.0.0",
  "id": "preset-uuid-here",
  "name": "Shimmer Texture",
  "category": "textures",
  "tags": ["ambient", "pad", "reverb"],
  "voiceType": "granular",

  "parameters": {
    "slide": 0.5,
    "geneSize": 0.15,
    "morph": 0.75,
    "varispeed": 1.0,
    "organize": 0,
    "pitch": 7.0,
    "spread": 0.3,
    "jitter": 0.2,
    "filterCutoff": 12000.0,
    "filterResonance": 0.1
  },

  "quantization": {
    "mode": "octavesFifths",
    "customIntervals": null
  },

  "bufferReference": null,

  "metadata": {
    "dateCreated": "2026-02-01T10:00:00Z",
    "author": "Factory",
    "description": "Shimmering granular pad with octave+fifth harmony"
  }
}
```

---

## 7. OSC Protocol (Grid/Arc)

### 7.1 Grid OSC Messages

**Incoming (from Grid to Application)**

```
/monome/grid/key [x] [y] [state]
  x: int (0-15)
  y: int (0-7)
  state: int (1=pressed, 0=released)

Example: /monome/grid/key 5 3 1
  (Button at column 5, row 3 was pressed)
```

**Outgoing (from Application to Grid)**

```
/monome/grid/led/set [x] [y] [brightness]
  x: int (0-15)
  y: int (0-7)
  brightness: int (0-15, 0=off, 15=brightest)

/monome/grid/led/all [brightness]
  brightness: int (0-15)

/monome/grid/led/row [y] [x_offset] [brightness_array...]
  y: int (0-7)
  x_offset: int (0-15)
  brightness_array: int... (0-15 per LED)

Example: /monome/grid/led/row 0 0 15 15 15 0 0 0 8 8 8 0 0 0 3 3 3 0
  (Set row 0 with pattern: bright, off, medium, off, dim, off...)
```

### 7.2 Arc OSC Messages

**Incoming (from Arc to Application)**

```
/monome/arc/enc/delta [encoder] [delta]
  encoder: int (0-3)
  delta: int (-128 to 127, rotation amount)

/monome/arc/enc/key [encoder] [state]
  encoder: int (0-3)
  state: int (1=pressed, 0=released)

Example: /monome/arc/enc/delta 0 5
  (Encoder 0 rotated 5 steps clockwise)
```

**Outgoing (from Application to Arc)**

```
/monome/arc/ring/set [encoder] [led] [brightness]
  encoder: int (0-3)
  led: int (0-63)
  brightness: int (0-15)

/monome/arc/ring/all [encoder] [brightness]
  encoder: int (0-3)
  brightness: int (0-15)

/monome/arc/ring/range [encoder] [start] [end] [brightness]
  encoder: int (0-3)
  start: int (0-63)
  end: int (0-63)
  brightness: int (0-15)

Example: /monome/arc/ring/range 0 0 32 12
  (Set LEDs 0-32 on encoder 0 to brightness 12)
```

### 7.3 serialosc Discovery

```
// Query for devices
/serialosc/list [host] [port]
  host: string (IP to send response to)
  port: int

// Response (received for each device)
/serialosc/device [id] [type] [port]
  id: string (device serial)
  type: string ("monome 128" or "monome arc 4")
  port: int (device OSC port)

// Connect to specific device
/serialosc/notify [host] [port]
  host: string
  port: int

// Device info query
/sys/port [port]
/sys/host [host]
/sys/prefix [prefix]
/sys/rotation [degrees]  // Grid only: 0, 90, 180, 270
```

---

## Document Information
- **Version**: 1.0
- **Date**: 2026-02-01
- **Related Documents**:
  - music-app-specification.md
  - architecture.md

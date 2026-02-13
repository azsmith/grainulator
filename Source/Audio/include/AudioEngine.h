//
//  AudioEngine.h
//  Grainulator
//
//  Main C++ audio engine interface
//

#ifndef AUDIOENGINE_H
#define AUDIOENGINE_H

#include <cstdint>
#include <atomic>
#include <array>
#include <memory>
#include <thread>
#include <cstring>

// Forward declaration for LadderFilterBase (in global namespace)
class LadderFilterBase;

namespace Grainulator {

// Forward declarations
class PlaitsVoice;
class DaisyDrumVoice;
class SoundFontVoice;
class WavSamplerVoice;

// Scope buffer constants (for oscilloscope visualization)
constexpr int kScopeBufferSize = 32768;  // ~682ms @ 48kHz
constexpr int kScopeNumSources = 17;     // 8 voices + master + 8 clocks

// Multi-channel ring buffer constants
constexpr int kMultiChannelRingBufferSize = 4096;  // ~85ms @ 48kHz
constexpr int kNumMixerChannelsForRing = 8;
constexpr int kRingBufferProcessFrames = 256;      // Chunk size for background processing

// Master output capture ring buffer (for recording to file via Swift)
constexpr int kMasterCaptureRingSize = 480000;     // 10 seconds @ 48kHz

/// Lock-free ring buffer for multi-channel audio
/// Uses single write index (producer writes all channels together)
/// and per-channel read indices (callbacks fire independently)
class MultiChannelRingBuffer {
public:
    MultiChannelRingBuffer();

    // Producer (background thread) - writes all channels for a chunk
    void writeChannel(int channelIndex, const float* left, const float* right, int numFrames);
    void advanceWriteIndex(int numFrames);
    bool canWrite(int numFrames) const;

    // Consumer (audio callbacks) - reads one channel at a time
    void readChannel(int channelIndex, float* left, float* right, int numFrames);
    bool canRead(int channelIndex, int numFrames) const;

    // Monitoring
    size_t getReadableFrames(int channelIndex) const;
    size_t getWritableFrames() const;

    // Reset all indices and clear buffers
    void reset();

private:
    // Stereo buffers for each channel
    float m_bufferL[kNumMixerChannelsForRing][kMultiChannelRingBufferSize];
    float m_bufferR[kNumMixerChannelsForRing][kMultiChannelRingBufferSize];

    // Single write index (all channels written together by producer)
    std::atomic<size_t> m_writeIndex{0};

    // Per-channel read indices (callbacks fire independently)
    std::atomic<size_t> m_readIndex[kNumMixerChannelsForRing];
};

/// SPSC lock-free stereo ring buffer for master output capture (recording to WAV).
/// Single producer (audio thread) writes post-clip stereo samples.
/// Single consumer (Swift drain timer) reads and writes to AVAudioFile.
class MasterCaptureRingBuffer {
public:
    void write(const float* left, const float* right, int numFrames);
    int read(float* left, float* right, int maxFrames);
    void reset();

private:
    float m_bufferL[kMasterCaptureRingSize]{};
    float m_bufferR[kMasterCaptureRingSize]{};
    std::atomic<size_t> m_writeIndex{0};
    std::atomic<size_t> m_readIndex{0};
};

class GranularVoice;
class ReelBuffer;
class RingsVoice;
class LooperVoice;

// Constants
constexpr int kSampleRate = 48000;
constexpr int kMaxGrains = 128;
constexpr int kNumGranularVoices = 4;
constexpr int kNumLooperVoices = 2;
constexpr int kMaxBufferSize = 2048;
constexpr int kNumPlaitsVoices = 1;  // Start with single canonical Plaits voice
constexpr int kNumClockOutputs = 8;  // Master clock outputs (Pam's style)
constexpr int kNumLegacyOutputBuses = 3; // 0=dry, 1=send A, 2=send B

// Audio processing callback type
typedef void (*AudioCallback)(float** outputBuffers, int numChannels, int numFrames, void* userData);

/// Main audio engine class
/// This is the C++ interface that will be called from Swift
class AudioEngine {
public:
    enum NoteTarget : uint8_t {
        TargetPlaits    = 1 << 0,
        TargetRings     = 1 << 1,
        TargetDaisyDrum = 1 << 2,
        // Drum sequencer lanes (4 dedicated voices)
        TargetDrumLane0 = 1 << 3,  // Analog Kick
        TargetDrumLane1 = 1 << 4,  // Synth Kick
        TargetDrumLane2 = 1 << 5,  // Analog Snare
        TargetDrumLane3 = 1 << 6,  // Hi-Hat
        TargetSampler   = 1 << 7,  // SoundFont sampler
        TargetBoth      = TargetPlaits | TargetRings,
        TargetAll       = TargetPlaits | TargetRings | TargetDaisyDrum | TargetSampler
    };

    AudioEngine();
    ~AudioEngine();

    // Lifecycle
    bool initialize(int sampleRate, int bufferSize);
    void shutdown();

    // Audio processing
    void process(float** inputBuffers, float** outputBuffers, int numChannels, int numFrames);

    // Multi-channel output for AU plugin hosting
    // Outputs 8 separate stereo channels (16 buffers total) without mixing or effects
    // Buffer layout: [ch0_L, ch0_R, ch1_L, ch1_R, ..., ch7_L, ch7_R]
    // Channel mapping: 0=Plaits, 1=Rings, 2=Granular1, 3=Looper1, 4=Looper2, 5=Granular4, 6=DaisyDrum, 7=Sampler
    void processMultiChannel(float** channelBuffers, int numFrames);
    void renderAndReadMultiChannel(int channelIndex, int64_t sampleTime, float* left, float* right, int numFrames);
    void renderAndReadLegacyBus(int busIndex, int64_t sampleTime, float* left, float* right, int numFrames);

    // Parameter control
    enum class ParameterID {
        // Granular parameters (Mangl-style)
        GranularSpeed = 0,   // Playback speed (-3 to +3)
        GranularPitch,       // Independent pitch shift (semitones)
        GranularSize,        // Grain size (ms)
        GranularDensity,     // Grain rate (Hz)
        GranularJitter,      // Position randomization (ms)
        GranularSpread,      // Stereo spread
        GranularPan,         // Base pan position
        GranularFilterCutoff,
        GranularFilterResonance,
        GranularGain,        // Volume
        GranularSend,        // Effect send
        GranularEnvelope,    // Grain envelope type (0-7)
        GranularDecay,       // Envelope decay rate (1-10)

        // Plaits parameters
        PlaitsModel,
        PlaitsHarmonics,
        PlaitsTimbre,
        PlaitsMorph,
        PlaitsFrequency,
        PlaitsLevel,
        PlaitsMidiNote,  // Direct MIDI note (0-127, not normalized)
        PlaitsLPGColor,  // LPG color: 0 = VCA only, 1 = VCA + filter
        PlaitsLPGDecay,  // LPG decay time
        PlaitsLPGAttack, // LPG attack time
        PlaitsLPGBypass, // LPG bypass: 0 = normal, 1 = bypass (for testing)

        // Effects parameters
        DelayTime,
        DelayFeedback,
        DelayMix,
        ReverbSize,
        ReverbDamping,
        ReverbMix,
        DistortionAmount,
        DistortionType,

        // Mixer parameters
        VoiceGain,
        VoicePan,
        VoiceSend,       // Per-channel FX send level
        MasterGain,

        // Master filter parameters
        MasterFilterCutoff,   // 20-20000 Hz
        MasterFilterResonance, // 0-1
        MasterFilterModel,    // 0-1 maps to available ladder models

        // Tape echo extended parameters
        DelayHeadMode,   // 0-1 maps to discrete head combo modes
        DelayWow,        // 0-1 modulation depth
        DelayFlutter,    // 0-1 modulation depth
        DelayTone,       // 0-1 dark to bright repeats
        DelaySync,       // 0=free, 1=tempo sync
        DelayTempo,      // 0-1 maps to BPM
        DelaySubdivision, // 0-1 maps to rhythmic divisions

        // Granular extended parameters
        GranularFilterModel, // 0-1 maps to available ladder models
        GranularReverse, // 0=forward grains, 1=reverse grains
        GranularMorph, // 0-1 per-grain randomization probability/depth

        // Rings parameters
        RingsModel,
        RingsStructure,
        RingsBrightness,
        RingsDamping,
        RingsPosition,
        RingsLevel,

        // Looper parameters
        LooperRate,
        LooperReverse,
        LooperLoopStart,
        LooperLoopEnd,
        LooperCut,

        // Mixer timing alignment
        VoiceMicroDelay,

        // Master clock parameters
        ClockBPM,           // Master BPM (10-330)
        ClockSwing,         // Global swing amount (0-1)
        ClockRunning,       // Clock running state (0 or 1)

        // DaisyDrum parameters
        DaisyDrumEngine,       // 0–4 engine select
        DaisyDrumHarmonics,    // 0–1
        DaisyDrumTimbre,       // 0–1
        DaisyDrumMorph,        // 0–1
        DaisyDrumLevel,        // 0–1
        DaisyDrumNote,         // 0–1 maps to MIDI 24–84

        // SoundFont sampler parameters
        SamplerPreset,          // 0–1 maps to preset index
        SamplerAttack,          // 0–1 ADSR attack
        SamplerDecay,           // 0–1 ADSR decay
        SamplerSustain,         // 0–1 ADSR sustain level
        SamplerRelease,         // 0–1 ADSR release
        SamplerFilterCutoff,    // 0–1 maps to 20–20kHz
        SamplerFilterResonance, // 0–1
        SamplerTuning,          // 0–1 maps to –24..+24 semitones
        SamplerLevel,           // 0–1 output level
        SamplerMode,            // 0=SoundFont, 1=WavSampler

        // Rings extended parameters
        RingsPolyphony,         // 0=1, 0.5=2, 1.0=4
        RingsChord,             // 0-1 maps to 0-10 chord index
        RingsFM,                // 0-1 maps to ±24 semitones
        RingsExciterSource      // 0=internal, >0 maps to source channels
    };

    // Sampler engine mode: SoundFont (.sf2), SFZ, or WAV-based (mx.samples)
    enum class SamplerMode { SoundFont = 0, Sfz = 1, WavSampler = 2 };

    // Clock output waveform types
    enum class ClockWaveform {
        Gate = 0,
        Sine,
        Triangle,
        Saw,
        Ramp,
        Square,
        Random,
        SampleHold,
        NumWaveforms
    };

    // Modulation destinations
    enum class ModulationDestination {
        None = 0,
        // Plaits
        PlaitsHarmonics,
        PlaitsTimbre,
        PlaitsMorph,
        PlaitsLPGDecay,
        // Rings
        RingsStructure,
        RingsBrightness,
        RingsDamping,
        RingsPosition,
        // Delay
        DelayTime,
        DelayFeedback,
        DelayWow,
        DelayFlutter,
        // Granular 1
        Granular1Speed,
        Granular1Pitch,
        Granular1Size,
        Granular1Density,
        Granular1Filter,
        // Granular 2
        Granular2Speed,
        Granular2Pitch,
        Granular2Size,
        Granular2Density,
        Granular2Filter,
        // DaisyDrum
        DaisyDrumHarmonics,
        DaisyDrumTimbre,
        DaisyDrumMorph,
        // SoundFont Sampler
        SamplerFilterCutoff,
        SamplerLevel,
        // Trigger destinations (fire NoteOn on clock rising edge)
        PlaitsGate,         // Trigger Macro Osc
        RingsGate,          // Trigger Resonator
        RingsInput,         // Trigger Resonator (as exciter/strum)
        DaisyDrumGate,      // Trigger Drums
        DrumLane0Gate,      // Trigger Analog Kick
        DrumLane1Gate,      // Trigger Synth Kick
        DrumLane2Gate,      // Trigger Analog Snare
        DrumLane3Gate,      // Trigger Hi-Hat
        SamplerGate,        // Trigger Sampler
        NumDestinations
    };

    /// Returns true if the destination is a trigger (gate) rather than CV modulation.
    static inline bool isModDestTrigger(ModulationDestination dest) {
        return dest >= ModulationDestination::PlaitsGate && dest < ModulationDestination::NumDestinations;
    }

    /// Returns NoteTarget bitmask for a trigger destination.
    static inline uint8_t targetMaskForTriggerDest(ModulationDestination dest) {
        switch (dest) {
            case ModulationDestination::PlaitsGate:    return TargetPlaits;
            case ModulationDestination::RingsGate:     return TargetRings;
            case ModulationDestination::RingsInput:    return TargetRings;
            case ModulationDestination::DaisyDrumGate: return TargetDaisyDrum;
            case ModulationDestination::DrumLane0Gate: return TargetDrumLane0;
            case ModulationDestination::DrumLane1Gate: return TargetDrumLane1;
            case ModulationDestination::DrumLane2Gate: return TargetDrumLane2;
            case ModulationDestination::DrumLane3Gate: return TargetDrumLane3;
            case ModulationDestination::SamplerGate:   return TargetSampler;
            default: return 0;
        }
    }

    /// Returns default MIDI note for a trigger destination.
    static inline int noteForTriggerDest(ModulationDestination dest) {
        switch (dest) {
            case ModulationDestination::DrumLane0Gate: return 36;  // Kick
            case ModulationDestination::DrumLane1Gate: return 38;  // Snare
            case ModulationDestination::DrumLane2Gate: return 40;  // Tom
            case ModulationDestination::DrumLane3Gate: return 42;  // Hi-Hat
            default: return 60;  // Middle C for melodic targets
        }
    }

    void setParameter(ParameterID id, int voiceIndex, float value);
    float getParameter(ParameterID id, int voiceIndex) const;

    // Channel metering (returns peak level 0-1)
    float getChannelLevel(int channelIndex) const;  // 0=Plaits, 1=Rings, 2-5=tracks
    float getMasterLevel(int channel) const;        // 0=left, 1=right
    void setChannelSendLevel(int channelIndex, int sendIndex, float level);

    // Trigger control (legacy - uses voice 0)
    void triggerPlaits(bool state);
    void triggerDaisyDrum(bool state);

    // Drum sequencer lane control (4 dedicated voices)
    static constexpr int kNumDrumSeqLanes = 4;
    void triggerDrumSeqLane(int laneIndex, bool state);
    void setDrumSeqLaneLevel(int laneIndex, float level);
    void setDrumSeqLaneHarmonics(int laneIndex, float value);
    void setDrumSeqLaneTimbre(int laneIndex, float value);
    void setDrumSeqLaneMorph(int laneIndex, float value);

    // SoundFont sampler control
    bool loadSoundFont(const char* filePath);
    void unloadSoundFont();
    int getSoundFontPresetCount() const;
    const char* getSoundFontPresetName(int index) const;

    // WAV sampler control (mx.samples)
    bool loadWavSampler(const char* dirPath);
    bool loadSfzFile(const char* sfzPath);
    void unloadWavSampler();
    const char* getWavSamplerInstrumentName() const;
    void setSamplerMode(SamplerMode mode);
    SamplerMode getSamplerMode() const { return m_samplerMode; }

    // Polyphonic note control
    void noteOn(int note, int velocity);
    void noteOff(int note);
    void scheduleNoteOn(int note, int velocity, uint64_t sampleTime);
    void scheduleNoteOff(int note, uint64_t sampleTime);
    void scheduleNoteOnTarget(int note, int velocity, uint64_t sampleTime, uint8_t targetMask);
    void scheduleNoteOffTarget(int note, uint64_t sampleTime, uint8_t targetMask);
    void scheduleNoteOnTargetTagged(int note, int velocity, uint64_t sampleTime, uint8_t targetMask, uint8_t trackId);
    void scheduleNoteOffTargetTagged(int note, uint64_t sampleTime, uint8_t targetMask, uint8_t trackId);
    void clearScheduledNotes();
    uint64_t getCurrentSampleTime() const;

    // Buffer management
    bool loadAudioFile(const char* filePath, int reelIndex);
    bool loadAudioData(int reelIndex, const float* leftChannel, const float* rightChannel, size_t numSamples, float sampleRate);
    void clearReel(int reelIndex);
    size_t getReelLength(int reelIndex) const;
    void getWaveformOverview(int reelIndex, float* output, size_t outputSize) const;

    // Wavetable loading
    void loadUserWavetable(const float* data, int numSamples, int frameSize = 0);
    bool loadPlaitsSixOpCustomBank(const uint8_t* data, int numBytes);
    void setPlaitsSixOpCustomMode(bool enabled);
    void setPlaitsSixOpCustomPatch(int patchIndex);

    // Granular playback control
    void setGranularPlaying(int voiceIndex, bool playing);
    void setGranularPosition(int voiceIndex, float position);
    float getGranularPosition(int voiceIndex) const;

    // Recording control
    // mode: 0=OneShot, 1=LiveLoop
    // sourceType: 0=external (mic/line), 1=internal voice
    // sourceChannel: mixer channel index (0=Plaits,1=Rings,2=Gran1,3=Loop1,4=Loop2,5=Gran4,6=Drums(all),7=Kick,8=SynthKick,9=Snare,10=HiHat)
    void startRecording(int reelIndex, int mode, int sourceType, int sourceChannel);
    void stopRecording(int reelIndex);
    void setRecordingFeedback(int reelIndex, float feedback);
    bool isRecording(int reelIndex) const;
    float getRecordingPosition(int reelIndex) const;  // 0-1 normalized

    // External audio input (called from Swift input tap callback)
    void writeExternalInput(const float* left, const float* right, int numFrames);

    // Master output capture (for file recording via Swift)
    void startMasterCapture();
    void stopMasterCapture();
    bool isMasterCaptureActive() const;
    int readMasterCaptureBuffer(float* left, float* right, int maxFrames);

    // Quantization
    enum class QuantizationMode {
        None = 0,
        Octaves,
        OctavesFifths,
        OctavesFourths,
        Chromatic,
        Custom
    };

    void setQuantizationMode(int voiceIndex, QuantizationMode mode);
    void setCustomIntervals(int voiceIndex, const float* intervals, int count);

    // Performance metrics
    float getCPULoad() const;
    int getActiveGrainCount() const;

    // Master clock control
    void setClockBPM(float bpm);
    void setClockRunning(bool running);
    void setClockStartSample(uint64_t startSample);  // Sync clock to sequencer
    void setClockSwing(float swing);
    float getClockBPM() const;
    bool isClockRunning() const;

    // Clock output configuration (8 outputs)
    void setClockOutputMode(int outputIndex, int mode);           // 0=clock, 1=LFO
    void setClockOutputWaveform(int outputIndex, int waveform);   // ClockWaveform enum
    void setClockOutputDivision(int outputIndex, int division);   // Division index
    void setClockOutputLevel(int outputIndex, float level);       // 0-1
    void setClockOutputOffset(int outputIndex, float offset);     // -1 to +1
    void setClockOutputPhase(int outputIndex, float phase);       // 0-1 (0-360 deg)
    void setClockOutputWidth(int outputIndex, float width);       // 0-1 pulse width
    void setClockOutputDestination(int outputIndex, int dest);    // ModulationDestination enum
    void setClockOutputModAmount(int outputIndex, float amount);  // 0-1
    void setClockOutputMuted(int outputIndex, bool muted);
    void setClockOutputSlowMode(int outputIndex, bool slow);      // Slow mode (/4 multiplier)
    void resetClockOutput(int outputIndex);                       // Reset phase & euclidean step to 1
    float getClockOutputValue(int outputIndex) const;             // Current output value
    float getModulationValue(int destination) const;              // Current modulation for destination

    // Euclidean rhythm control
    void setClockOutputEuclidean(int outputIndex, bool enabled, int steps,
                                  const bool* pattern, int patternLength);
    int getClockOutputEuclideanStep(int outputIndex) const;

    // Clock start sample (for bar:beat calculation)
    uint64_t getClockStartSample() const;

    // Clock output quantize
    void setClockOutputQuantize(int outputIndex, int mode);  // 0=off, 1=1/16, 2=1/8, 3=1/4, 4=bar

    // Time signature
    void setTimeSignature(int numerator, int denominator);
    int getTimeSignatureNumerator() const;
    int getTimeSignatureDenominator() const;
    float getQuarterNotesPerBar() const;

private:
    struct ScheduledNoteEvent {
        uint64_t sampleTime;
        uint8_t note;
        uint8_t velocity;
        bool isNoteOn;
        uint8_t targetMask;
        uint8_t trackId;  // 0 = keyboard/untagged, 1+ = sequencer track
    };

    static constexpr uint32_t kScheduledEventCapacity = 4096;

    // Internal state
    int m_sampleRate;
    int m_bufferSize;
    std::atomic<bool> m_initialized;
    std::atomic<uint64_t> m_currentSampleTime;

    // Performance monitoring
    std::atomic<float> m_cpuLoad;
    std::atomic<int> m_activeGrains;

    // Processing buffers
    float* m_processingBuffer[2];
    float* m_voiceBuffer[2];  // Temp buffer for individual voice rendering
    float m_tempVoiceL[kMaxBufferSize];  // Pre-allocated temp buffer for voice rendering (avoids stack allocation)
    float m_tempVoiceR[kMaxBufferSize];
    float m_tempDrumSeq[kMaxBufferSize]; // Pre-allocated temp buffer for drum seq rendering
    static constexpr int kMaxOutputChannels = 16;
    float* m_chunkOutputPtrs[kMaxOutputChannels];  // Pre-allocated pointer array for chunked processing

    // Polyphonic Plaits voices
    std::unique_ptr<PlaitsVoice> m_plaitsVoices[kNumPlaitsVoices];
    std::unique_ptr<RingsVoice> m_ringsVoice;
    std::unique_ptr<DaisyDrumVoice> m_daisyDrumVoice;
    // Drum sequencer: 4 dedicated voices (AnalogKick, SynthKick, AnalogSnare, HiHat)
    std::unique_ptr<DaisyDrumVoice> m_drumSeqVoices[kNumDrumSeqLanes];
    // SoundFont sampler voice
    std::unique_ptr<SoundFontVoice> m_soundFontVoice;
    // WAV sampler voice (mx.samples)
    std::unique_ptr<WavSamplerVoice> m_wavSamplerVoice;
    SamplerMode m_samplerMode;

    // Sampler parameters (mirrored for getParameter readback)
    float m_samplerAttack;
    float m_samplerDecay;
    float m_samplerSustain;
    float m_samplerRelease;
    float m_samplerFilterCutoff;
    float m_samplerFilterResonance;
    float m_samplerTuning;
    float m_samplerLevel;
    float m_drumSeqLevel[kNumDrumSeqLanes];
    float m_drumSeqHarmonics[kNumDrumSeqLanes];
    float m_drumSeqTimbre[kNumDrumSeqLanes];
    float m_drumSeqMorph[kNumDrumSeqLanes];
    int m_voiceNote[kNumPlaitsVoices];         // MIDI note for each voice (-1 = free)
    uint8_t m_voiceTrackId[kNumPlaitsVoices];  // Track that owns this voice (0 = keyboard)
    uint32_t m_voiceAge[kNumPlaitsVoices];     // For voice stealing (older = lower priority)
    uint32_t m_voiceCounter;                    // Increments on each note-on

    // Granular voices (4 tracks)
    std::unique_ptr<GranularVoice> m_granularVoices[kNumGranularVoices];
    std::unique_ptr<LooperVoice> m_looperVoices[kNumLooperVoices];
    std::unique_ptr<ReelBuffer> m_reelBuffers[32];  // Up to 32 reel buffers
    int m_activeGranularVoice;  // Currently selected granular voice for parameter control

    // Recording state (up to 6 concurrent sessions, one per mixer channel target)
    static constexpr int kMaxRecordingSessions = 6;
    struct RecordingState {
        std::atomic<bool> active{false};
        int sourceType{0};       // 0=external, 1=internal voice
        int sourceChannel{0};    // Mixer channel index (0=Plaits,1=Rings,2=Gran1,3=Loop1,4=Loop2,5=Gran4)
        int targetReel{0};       // Which reel buffer to record into
    };
    RecordingState m_recordingStates[kMaxRecordingSessions];

    // External audio input staging buffer (written by Swift input tap, read by process())
    float m_externalInputL[kMaxBufferSize]{};
    float m_externalInputR[kMaxBufferSize]{};
    std::atomic<int> m_externalInputFrameCount{0};

    // Recording helpers
    void processRecordingForChannel(int channelIndex, const float* srcLeft, const float* srcRight, int numFrames);
    void processExternalInputRecording(int numFrames);

    // Master output capture state
    MasterCaptureRingBuffer m_masterCaptureRing;
    std::atomic<bool> m_masterCaptureActive{false};

    // Shared parameters (applied to all voices)
    int m_currentEngine;
    int m_currentRingsModel;
    float m_harmonics;
    float m_timbre;
    float m_morph;
    float m_plaitsLevel;
    float m_plaitsFrequency;  // Normalized 0-1 (maps to note 24-96)
    bool m_plaitsSixOpCustomEnabled;
    int m_plaitsSixOpCustomPatchIndex;
    float m_lpgColor;
    float m_lpgDecay;
    float m_lpgAttack;
    bool m_lpgBypass;

    // Rings basic parameters (mirrored for getParameter readback)
    float m_ringsStructure;
    float m_ringsBrightness;
    float m_ringsDamping;
    float m_ringsPosition;
    float m_ringsLevel;

    // Rings extended parameters
    int m_ringsPolyphony;         // 1, 2, or 4
    int m_ringsChord;             // 0-10
    float m_ringsFM;              // 0-1
    int m_ringsExciterSource;     // -1=internal, 0-11=channel index
    float m_ringsExciterBufferL[kMaxBufferSize];
    float m_ringsExciterBufferR[kMaxBufferSize];

    // DaisyDrum shared parameters
    int m_currentDaisyDrumEngine;
    float m_daisyDrumHarmonics;
    float m_daisyDrumTimbre;
    float m_daisyDrumMorph;
    float m_daisyDrumLevel;
    float m_daisyDrumNoteOffset;  // Semitone offset (-30 to +30), applied to all trigger sources

    // Granular parameters (Mangl-style, for currently selected voice)
    float m_granularSpeed;
    float m_granularPitch;
    float m_granularSize;
    float m_granularDensity;
    float m_granularJitter;
    float m_granularSpread;
    float m_granularPan;
    float m_granularFilterCutoff;
    float m_granularFilterQ;
    float m_granularGain;
    float m_granularSend;
    int m_granularEnvelope;

    // Effects parameters
    float m_delayTime;      // 0-1 repeat rate
    float m_delayFeedback;  // 0-1
    float m_delayMix;       // 0-1 dry/wet
    float m_delayHeadMode;  // 0-1 discrete mode index
    float m_delayWow;       // 0-1 depth
    float m_delayFlutter;   // 0-1 depth
    float m_delayTone;      // 0-1 dark->bright
    bool m_delaySync;       // tempo sync enable
    float m_delayTempoBPM;  // synced tempo
    float m_delaySubdivision; // 0-1 discrete subdivision index
    float m_reverbSize;     // 0-1 room size
    float m_reverbDamping;  // 0-1 high freq damping
    float m_reverbMix;      // 0-1 dry/wet

    // Tape echo state (RE-201 style multi-head delay)
    static constexpr size_t kMaxDelayLength = 192000;  // 4 seconds @ 48kHz
    float* m_delayBufferL;
    float* m_delayBufferR;
    size_t m_delayWritePos;
    float m_delayTimeSmoothed;
    float m_tapeWowPhase;
    float m_tapeFlutterPhase;
    float m_tapeDrift;
    float m_tapeFeedbackLP;
    float m_tapeFeedbackHPIn;
    float m_tapeFeedbackHPOut;
    float m_tapeToneL;
    float m_tapeToneR;
    uint32_t m_tapeNoiseState;

    // Simple reverb state (Freeverb-style comb + allpass)
    static constexpr size_t kNumCombs = 8;
    static constexpr size_t kNumAllpasses = 4;
    float* m_combBuffersL[kNumCombs];
    float* m_combBuffersR[kNumCombs];
    size_t m_combLengths[kNumCombs];
    size_t m_combPos[kNumCombs];
    float m_combFilters[kNumCombs];
    float m_combFiltersR[kNumCombs];  // Right channel damping (symmetric with left)

    float* m_allpassBuffersL[kNumAllpasses];
    float* m_allpassBuffersR[kNumAllpasses];
    size_t m_allpassLengths[kNumAllpasses];
    size_t m_allpassPos[kNumAllpasses];

    // Effects send buffers (A and B)
    float* m_sendBufferAL;
    float* m_sendBufferAR;
    float* m_sendBufferBL;
    float* m_sendBufferBR;
    bool m_externalSendRoutingEnabled{false};
    float m_lastSendBusAL[kMaxBufferSize]{};
    float m_lastSendBusAR[kMaxBufferSize]{};
    float m_lastSendBusBL[kMaxBufferSize]{};
    float m_lastSendBusBR[kMaxBufferSize]{};

    // Per-channel mixer state (0=Plaits, 1=Rings, 2-5=Track voices, 6=DaisyDrum, 7=Sampler)
    static constexpr int kNumMixerChannels = 8;
    static constexpr int kMaxChannelDelaySamples = 2400; // 50ms @ 48kHz
    float m_channelGain[kNumMixerChannels];       // Target gain (set from UI)
    float m_channelGainSmoothed[kNumMixerChannels]; // Smoothed gain (used in DSP)
    float m_channelPan[kNumMixerChannels];        // Target pan (set from UI)
    float m_channelPanSmoothed[kNumMixerChannels];  // Smoothed pan (used in DSP)
    float m_channelSendA[kNumMixerChannels];
    float m_channelSendASmoothed[kNumMixerChannels];
    float m_channelSendB[kNumMixerChannels];
    float m_channelSendBSmoothed[kNumMixerChannels];
    int m_channelDelaySamples[kNumMixerChannels];
    int m_channelDelayWritePos[kNumMixerChannels];
    std::array<std::array<float, kMaxChannelDelaySamples + 1>, kNumMixerChannels> m_channelDelayBufferL;
    std::array<std::array<float, kMaxChannelDelaySamples + 1>, kNumMixerChannels> m_channelDelayBufferR;
    bool m_channelMute[kNumMixerChannels];
    bool m_channelSolo[kNumMixerChannels];
    float m_masterGain;          // Target master gain
    float m_masterGainSmoothed;  // Smoothed master gain

    // Master filter (flexible Moog ladder models)
    float m_masterFilterCutoff;     // 20-20000 Hz
    float m_masterFilterResonance;  // 0-1
    int m_masterFilterModel;        // Index of selected filter model
    std::unique_ptr<LadderFilterBase> m_masterFilterL;
    std::unique_ptr<LadderFilterBase> m_masterFilterR;
    void initMasterFilter();
    void updateMasterFilterParameters();
    void processMasterFilter(float& left, float& right);

    // Channel metering (peak levels, updated per buffer)
    std::atomic<float> m_channelLevels[kNumMixerChannels];
    std::atomic<float> m_masterLevelL;
    std::atomic<float> m_masterLevelR;

    // Scope buffer for oscilloscope visualization (lock-free, audio thread writes, UI reads)
    float m_scopeBuffer[kScopeNumSources][kScopeBufferSize];
    std::atomic<size_t> m_scopeWriteIndex{0};

    // Effects processing helpers
    void processDelay(float& left, float& right);
    void processReverb(float& left, float& right);
    void initEffects();
    void cleanupEffects();
    bool enqueueScheduledEvent(const ScheduledNoteEvent& event);
    void noteOnTarget(int note, int velocity, uint8_t targetMask);
    void noteOnTarget(int note, int velocity, uint8_t targetMask, uint8_t trackId);
    void noteOffTarget(int note, uint8_t targetMask);
    void noteOffTarget(int note, uint8_t targetMask, uint8_t trackId);

    // Voice allocation helper
    int allocateVoice(int note, uint8_t trackId);

    // Scheduled event queue state.
    // Producers are serialized with m_scheduledWriteLock; consumer is the audio thread.
    std::array<ScheduledNoteEvent, kScheduledEventCapacity> m_scheduledEvents;
    std::atomic<uint32_t> m_scheduledReadIndex;
    std::atomic<uint32_t> m_scheduledWriteIndex;
    std::atomic_flag m_scheduledWriteLock = ATOMIC_FLAG_INIT;

    // Master clock state (Pam's Pro Workout-style)
    struct ClockOutputState {
        int mode;                  // 0=clock, 1=LFO
        int waveform;              // ClockWaveform enum
        int divisionIndex;         // Index into division table
        float level;               // 0-1 amplitude
        float offset;              // -1 to +1 bipolar offset
        float phase;               // 0-1 phase offset
        float width;               // 0-1 pulse width/skew
        int destination;           // ModulationDestination enum
        float modulationAmount;    // 0-1 mod depth
        bool muted;                // Mute state
        bool slowMode;             // When true, applies /4 multiplier to rate

        // Trigger quantize mode (0=off, 1=1/16, 2=1/8, 3=1/4, 4=bar)
        // Atomic: written from main thread via setClockOutputQuantize(), read on audio thread
        std::atomic<int> quantizeMode;

        // Euclidean rhythm parameters
        bool euclideanEnabled;                    // When true, filter triggers through pattern
        int euclideanSteps;                       // Total pattern length (1-32)
        std::array<bool, 32> euclideanPattern;    // Precomputed pattern (from Bjorklund)
        int euclideanCurrentStep;                 // Current step in pattern (runtime)

        // Runtime state
        bool pendingTriggerOnStart;          // Fire trigger at beat 1 (first buffer after start)
        std::atomic<bool> pendingResync;     // When true, reset lastProcessedCycle (user reset)
        uint64_t lastTriggerSampleTime;      // Sample time of last trigger tick (for quantize grid reset)
        int64_t lastProcessedCycle;          // Last integer cycle boundary that fired (-1 = none yet)
        double phaseAccumulator;   // Current phase (0-1), transport-derived
        double lastPhaseAccumulator; // Phase at start of buffer (for scope/waveform rendering)
        float currentValue;        // Current output value (-1 to +1)
        float sampleHoldValue;     // Held value for S&H waveform
        float smoothedRandomValue; // Smoothed random for interpolation
        float randomTarget;        // Target value for smoothed random
        uint32_t randomState;      // Random generator state
        double lastPhaseForSH;     // Track phase wrapping for S&H trigger
    };

    std::atomic<float> m_clockBPM;
    std::atomic<bool> m_clockRunning;
    float m_clockSwing;
    uint64_t m_clockStartSample;         // Sample time when clock started
    std::array<ClockOutputState, kNumClockOutputs> m_clockOutputs;
    std::atomic<float> m_clockOutputValues[kNumClockOutputs];  // For UI feedback

    // Time signature state (read by audio thread, written by main thread)
    std::atomic<int> m_timeSignatureNumerator{4};
    std::atomic<int> m_timeSignatureDenominator{4};
    std::atomic<float> m_quarterNotesPerBar{4.0f};

    // Modulation accumulator (sum of all mod sources per destination)
    float m_modulationValues[static_cast<int>(ModulationDestination::NumDestinations)];

    // Clock processing helpers
    void processClockOutputs(int numFrames);
    float generateWaveform(int waveform, double phase, float width, ClockOutputState& state);
    void applyModulation();

    // Division multiplier table (matches SequencerClockDivision enum order)
    static constexpr float kDivisionMultipliers[] = {
        1.0f / 16.0f,  // /16
        1.0f / 12.0f,  // /12
        1.0f / 8.0f,   // /8
        1.0f / 6.0f,   // /6
        1.0f / 4.0f,   // /4
        1.0f / 3.0f,   // /3
        1.0f / 2.0f,   // /2
        2.0f / 3.0f,   // 2/3x
        3.0f / 4.0f,   // 3/4x
        1.0f,          // x1
        4.0f / 3.0f,   // x4/3
        3.0f / 2.0f,   // x3/2
        2.0f,          // x2
        3.0f,          // x3
        4.0f,          // x4
        6.0f,          // x6
        8.0f,          // x8
        12.0f,         // x12
        16.0f          // x16
    };

    // Multi-channel ring buffer processing (for AU plugin hosting)
    MultiChannelRingBuffer m_ringBuffer;
    std::atomic<bool> m_multiChannelProcessingActive{false};
    std::thread m_processingThread;
    float m_cachedMultiChannelL[kNumMixerChannelsForRing][kMaxBufferSize]{};
    float m_cachedMultiChannelR[kNumMixerChannelsForRing][kMaxBufferSize]{};
    std::atomic<int64_t> m_cachedBlockSampleTime{-1};
    std::atomic<int> m_cachedBlockFrames{0};
    std::atomic<bool> m_cachedRenderInProgress{false};
    std::atomic<int64_t> m_renderingBlockSampleTime{-1};
    std::atomic<int> m_renderingBlockFrames{0};
    float m_cachedLegacyBusL[kNumLegacyOutputBuses][kMaxBufferSize]{};
    float m_cachedLegacyBusR[kNumLegacyOutputBuses][kMaxBufferSize]{};
    std::atomic<int64_t> m_cachedLegacyBlockSampleTime{-1};
    std::atomic<int> m_cachedLegacyBlockFrames{0};
    std::atomic<bool> m_cachedLegacyRenderInProgress{false};
    std::atomic<int64_t> m_renderingLegacyBlockSampleTime{-1};
    std::atomic<int> m_renderingLegacyBlockFrames{0};

    void multiChannelProcessingLoop();

public:
    // Scope buffer access (called from UI thread, lock-free)
    void readScopeBuffer(int sourceIndex, float* output, int numFrames) const;
    size_t getScopeWriteIndex() const;

    // Ring buffer control (called from Swift)
    void startMultiChannelProcessing();
    void stopMultiChannelProcessing();
    void readChannelFromRingBuffer(int channelIndex, float* left, float* right, int numFrames);
    size_t getRingBufferReadableFrames(int channelIndex) const;

private:
    // Prevent copying
    AudioEngine(const AudioEngine&) = delete;
    AudioEngine& operator=(const AudioEngine&) = delete;
};

} // namespace Grainulator

#endif // AUDIOENGINE_H

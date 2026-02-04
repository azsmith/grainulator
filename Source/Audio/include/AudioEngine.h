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

namespace Grainulator {

// Forward declarations
class PlaitsVoice;
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
constexpr int kNumPlaitsVoices = 8;  // Polyphony

// Audio processing callback type
typedef void (*AudioCallback)(float** outputBuffers, int numChannels, int numFrames, void* userData);

/// Main audio engine class
/// This is the C++ interface that will be called from Swift
class AudioEngine {
public:
    enum NoteTarget : uint8_t {
        TargetPlaits = 1 << 0,
        TargetRings = 1 << 1,
        TargetBoth = TargetPlaits | TargetRings
    };

    AudioEngine();
    ~AudioEngine();

    // Lifecycle
    bool initialize(int sampleRate, int bufferSize);
    void shutdown();

    // Audio processing
    void process(float** inputBuffers, float** outputBuffers, int numChannels, int numFrames);

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
        LooperCut
    };

    void setParameter(ParameterID id, int voiceIndex, float value);
    float getParameter(ParameterID id, int voiceIndex) const;

    // Channel metering (returns peak level 0-1)
    float getChannelLevel(int channelIndex) const;  // 0=Plaits, 1=Rings, 2-5=tracks
    float getMasterLevel(int channel) const;        // 0=left, 1=right

    // Trigger control (legacy - uses voice 0)
    void triggerPlaits(bool state);

    // Polyphonic note control
    void noteOn(int note, int velocity);
    void noteOff(int note);
    void scheduleNoteOn(int note, int velocity, uint64_t sampleTime);
    void scheduleNoteOff(int note, uint64_t sampleTime);
    void scheduleNoteOnTarget(int note, int velocity, uint64_t sampleTime, uint8_t targetMask);
    void scheduleNoteOffTarget(int note, uint64_t sampleTime, uint8_t targetMask);
    void clearScheduledNotes();
    uint64_t getCurrentSampleTime() const;

    // Buffer management
    bool loadAudioFile(const char* filePath, int reelIndex);
    bool loadAudioData(int reelIndex, const float* leftChannel, const float* rightChannel, size_t numSamples, float sampleRate);
    void clearReel(int reelIndex);
    size_t getReelLength(int reelIndex) const;
    void getWaveformOverview(int reelIndex, float* output, size_t outputSize) const;

    // Granular playback control
    void setGranularPlaying(int voiceIndex, bool playing);
    void setGranularPosition(int voiceIndex, float position);
    float getGranularPosition(int voiceIndex) const;

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

private:
    struct ScheduledNoteEvent {
        uint64_t sampleTime;
        uint8_t note;
        uint8_t velocity;
        bool isNoteOn;
        uint8_t targetMask;
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

    // Polyphonic Plaits voices
    std::unique_ptr<PlaitsVoice> m_plaitsVoices[kNumPlaitsVoices];
    std::unique_ptr<RingsVoice> m_ringsVoice;
    int m_voiceNote[kNumPlaitsVoices];      // MIDI note for each voice (-1 = free)
    uint32_t m_voiceAge[kNumPlaitsVoices];  // For voice stealing (older = lower priority)
    uint32_t m_voiceCounter;                 // Increments on each note-on

    // Granular voices (4 tracks)
    std::unique_ptr<GranularVoice> m_granularVoices[kNumGranularVoices];
    std::unique_ptr<LooperVoice> m_looperVoices[kNumLooperVoices];
    std::unique_ptr<ReelBuffer> m_reelBuffers[32];  // Up to 32 reel buffers
    int m_activeGranularVoice;  // Currently selected granular voice for parameter control

    // Shared parameters (applied to all voices)
    int m_currentEngine;
    float m_harmonics;
    float m_timbre;
    float m_morph;
    float m_lpgColor;
    float m_lpgDecay;
    float m_lpgAttack;
    bool m_lpgBypass;

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

    float* m_allpassBuffersL[kNumAllpasses];
    float* m_allpassBuffersR[kNumAllpasses];
    size_t m_allpassLengths[kNumAllpasses];
    size_t m_allpassPos[kNumAllpasses];

    // Effects send buffer
    float* m_sendBufferL;
    float* m_sendBufferR;

    // Per-channel mixer state (0=Plaits, 1=Rings, 2-5=Track voices)
    static constexpr int kNumMixerChannels = 6;
    float m_channelGain[kNumMixerChannels];
    float m_channelPan[kNumMixerChannels];
    float m_channelSend[kNumMixerChannels];
    bool m_channelMute[kNumMixerChannels];
    bool m_channelSolo[kNumMixerChannels];
    float m_masterGain;  // Master output volume

    // Channel metering (peak levels, updated per buffer)
    std::atomic<float> m_channelLevels[kNumMixerChannels];
    std::atomic<float> m_masterLevelL;
    std::atomic<float> m_masterLevelR;

    // Effects processing helpers
    void processDelay(float& left, float& right);
    void processReverb(float& left, float& right);
    void initEffects();
    void cleanupEffects();
    bool enqueueScheduledEvent(const ScheduledNoteEvent& event);
    void noteOnTarget(int note, int velocity, uint8_t targetMask);
    void noteOffTarget(int note, uint8_t targetMask);

    // Voice allocation helper
    int allocateVoice(int note);

    // Lock-free queue state for sequencer-scheduled events (single producer, single consumer).
    std::array<ScheduledNoteEvent, kScheduledEventCapacity> m_scheduledEvents;
    std::atomic<uint32_t> m_scheduledReadIndex;
    std::atomic<uint32_t> m_scheduledWriteIndex;

    // Prevent copying
    AudioEngine(const AudioEngine&) = delete;
    AudioEngine& operator=(const AudioEngine&) = delete;
};

} // namespace Grainulator

#endif // AUDIOENGINE_H

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

namespace Grainulator {

// Constants
constexpr int kSampleRate = 48000;
constexpr int kMaxGrains = 128;
constexpr int kNumGranularVoices = 4;
constexpr int kMaxBufferSize = 2048;

// Audio processing callback type
typedef void (*AudioCallback)(float** outputBuffers, int numChannels, int numFrames, void* userData);

/// Main audio engine class
/// This is the C++ interface that will be called from Swift
class AudioEngine {
public:
    AudioEngine();
    ~AudioEngine();

    // Lifecycle
    bool initialize(int sampleRate, int bufferSize);
    void shutdown();

    // Audio processing
    void process(float** inputBuffers, float** outputBuffers, int numChannels, int numFrames);

    // Parameter control
    enum class ParameterID {
        // Granular parameters
        Slide = 0,
        GeneSize,
        Morph,
        Varispeed,
        Organize,
        Pitch,
        Spread,
        Jitter,
        FilterCutoff,
        FilterResonance,

        // Plaits parameters
        PlaitsModel,
        PlaitsHarmonics,
        PlaitsTimbre,
        PlaitsFrequency,

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
        MasterGain
    };

    void setParameter(ParameterID id, int voiceIndex, float value);
    float getParameter(ParameterID id, int voiceIndex) const;

    // Buffer management
    bool loadAudioFile(const char* filePath, int reelIndex);
    void clearReel(int reelIndex);

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
    // Internal state
    int m_sampleRate;
    int m_bufferSize;
    std::atomic<bool> m_initialized;

    // Performance monitoring
    std::atomic<float> m_cpuLoad;
    std::atomic<int> m_activeGrains;

    // Processing buffers
    float* m_processingBuffer[2];

    // Prevent copying
    AudioEngine(const AudioEngine&) = delete;
    AudioEngine& operator=(const AudioEngine&) = delete;
};

} // namespace Grainulator

#endif // AUDIOENGINE_H

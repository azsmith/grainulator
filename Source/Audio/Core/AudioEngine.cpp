//
//  AudioEngine.cpp
//  Grainulator
//
//  Main C++ audio engine implementation
//

#include "AudioEngine.h"
#include "Plaits/PlaitsVoice.h"
#include <cstring>
#include <cmath>
#include <algorithm>

namespace Grainulator {

AudioEngine::AudioEngine()
    : m_sampleRate(kSampleRate)
    , m_bufferSize(512)
    , m_initialized(false)
    , m_cpuLoad(0.0f)
    , m_activeGrains(0)
{
    // Initialize processing buffers
    m_processingBuffer[0] = nullptr;
    m_processingBuffer[1] = nullptr;
}

AudioEngine::~AudioEngine() {
    shutdown();
}

bool AudioEngine::initialize(int sampleRate, int bufferSize) {
    if (m_initialized.load()) {
        return false;
    }

    m_sampleRate = sampleRate;
    m_bufferSize = bufferSize;

    // Allocate processing buffers
    m_processingBuffer[0] = new float[kMaxBufferSize];
    m_processingBuffer[1] = new float[kMaxBufferSize];

    // Clear buffers
    std::memset(m_processingBuffer[0], 0, kMaxBufferSize * sizeof(float));
    std::memset(m_processingBuffer[1], 0, kMaxBufferSize * sizeof(float));

    // Initialize Plaits voice
    m_plaitsVoice = std::make_unique<PlaitsVoice>();
    m_plaitsVoice->Init(static_cast<float>(sampleRate));

    // TODO: Initialize granular engine
    // TODO: Initialize effects

    m_initialized.store(true);
    return true;
}

void AudioEngine::shutdown() {
    if (!m_initialized.load()) {
        return;
    }

    // Cleanup Plaits voice
    m_plaitsVoice.reset();

    // TODO: Cleanup granular engine
    // TODO: Cleanup effects

    // Free processing buffers
    if (m_processingBuffer[0]) {
        delete[] m_processingBuffer[0];
        m_processingBuffer[0] = nullptr;
    }
    if (m_processingBuffer[1]) {
        delete[] m_processingBuffer[1];
        m_processingBuffer[1] = nullptr;
    }

    m_initialized.store(false);
}

void AudioEngine::process(float** inputBuffers, float** outputBuffers, int numChannels, int numFrames) {
    if (!m_initialized.load() || numFrames > kMaxBufferSize) {
        // Not initialized or buffer too large - output silence
        for (int ch = 0; ch < numChannels; ++ch) {
            std::memset(outputBuffers[ch], 0, numFrames * sizeof(float));
        }
        return;
    }

    // Clear processing buffers
    std::memset(m_processingBuffer[0], 0, numFrames * sizeof(float));
    std::memset(m_processingBuffer[1], 0, numFrames * sizeof(float));

    // Process Plaits voice
    if (m_plaitsVoice) {
        m_plaitsVoice->Render(m_processingBuffer[0], m_processingBuffer[1], numFrames);
    }

    // TODO: Process granular voices
    // TODO: Apply effects
    // TODO: Mix voices

    // Copy to output buffers
    for (int ch = 0; ch < numChannels; ++ch) {
        std::memcpy(outputBuffers[ch], m_processingBuffer[ch % 2], numFrames * sizeof(float));
    }

    // Update performance metrics
    // This is a simplified version - real implementation would measure actual CPU time
    m_activeGrains.store(0);
}

void AudioEngine::setParameter(ParameterID id, int voiceIndex, float value) {
    float clampedValue = std::max(0.0f, std::min(1.0f, value));

    // Route Plaits parameters
    if (m_plaitsVoice) {
        switch (id) {
            case ParameterID::PlaitsModel:
                m_plaitsVoice->SetEngine(static_cast<int>(value * 15.0f)); // 0-15
                break;
            case ParameterID::PlaitsHarmonics:
                m_plaitsVoice->SetHarmonics(clampedValue);
                break;
            case ParameterID::PlaitsTimbre:
                m_plaitsVoice->SetTimbre(clampedValue);
                break;
            case ParameterID::PlaitsFrequency:
                // Convert 0-1 to MIDI note range (24-96 = C1 to C7)
                m_plaitsVoice->SetNote(24.0f + clampedValue * 72.0f);
                break;
            default:
                // TODO: Handle other parameters
                break;
        }
    }

    // TODO: Route to granular voices, effects, mixer
    (void)voiceIndex;
}

float AudioEngine::getParameter(ParameterID id, int voiceIndex) const {
    // TODO: Get actual parameter values
    (void)id;
    (void)voiceIndex;
    return 0.0f;
}

bool AudioEngine::loadAudioFile(const char* filePath, int reelIndex) {
    // TODO: Implement audio file loading
    (void)filePath;
    (void)reelIndex;
    return false;
}

void AudioEngine::clearReel(int reelIndex) {
    // TODO: Clear reel buffer
    (void)reelIndex;
}

void AudioEngine::setQuantizationMode(int voiceIndex, QuantizationMode mode) {
    // TODO: Set quantization mode for voice
    (void)voiceIndex;
    (void)mode;
}

void AudioEngine::setCustomIntervals(int voiceIndex, const float* intervals, int count) {
    // TODO: Set custom interval set
    (void)voiceIndex;
    (void)intervals;
    (void)count;
}

float AudioEngine::getCPULoad() const {
    return m_cpuLoad.load();
}

int AudioEngine::getActiveGrainCount() const {
    return m_activeGrains.load();
}

} // namespace Grainulator

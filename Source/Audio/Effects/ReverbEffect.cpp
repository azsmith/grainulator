//
//  ReverbEffect.cpp
//  Grainulator
//
//  Freeverb-style algorithmic reverb implementation
//

#include "ReverbEffect.h"
#include <cstring>

namespace Grainulator {

// Static member definitions
constexpr size_t ReverbEffect::kCombTunings[kNumCombs];
constexpr size_t ReverbEffect::kAllpassTunings[kNumAllpasses];

// MARK: - Constructor / Destructor

ReverbEffect::ReverbEffect()
    : m_size(0.5f)
    , m_damping(0.5f)
    , m_preDelay(0.0f)
    , m_width(1.0f)
    , m_preDelayBufferL(nullptr)
    , m_preDelayBufferR(nullptr)
    , m_preDelayWritePos(0)
    , m_preDelayLength(0)
    , m_feedback(0.84f)
    , m_damp1(0.2f)
    , m_damp2(0.8f)
{
    // Initialize buffer pointers
    for (size_t i = 0; i < kNumCombs; ++i) {
        m_combBuffersL[i] = nullptr;
        m_combBuffersR[i] = nullptr;
        m_combLengths[i] = 0;
        m_combPos[i] = 0;
        m_combFilters[i] = 0.0f;
    }
    for (size_t i = 0; i < kNumAllpasses; ++i) {
        m_allpassBuffersL[i] = nullptr;
        m_allpassBuffersR[i] = nullptr;
        m_allpassLengths[i] = 0;
        m_allpassPos[i] = 0;
    }
}

ReverbEffect::~ReverbEffect() {
    // Free comb buffers
    for (size_t i = 0; i < kNumCombs; ++i) {
        if (m_combBuffersL[i]) {
            delete[] m_combBuffersL[i];
            m_combBuffersL[i] = nullptr;
        }
        if (m_combBuffersR[i]) {
            delete[] m_combBuffersR[i];
            m_combBuffersR[i] = nullptr;
        }
    }

    // Free allpass buffers
    for (size_t i = 0; i < kNumAllpasses; ++i) {
        if (m_allpassBuffersL[i]) {
            delete[] m_allpassBuffersL[i];
            m_allpassBuffersL[i] = nullptr;
        }
        if (m_allpassBuffersR[i]) {
            delete[] m_allpassBuffersR[i];
            m_allpassBuffersR[i] = nullptr;
        }
    }

    // Free pre-delay buffers
    if (m_preDelayBufferL) {
        delete[] m_preDelayBufferL;
        m_preDelayBufferL = nullptr;
    }
    if (m_preDelayBufferR) {
        delete[] m_preDelayBufferR;
        m_preDelayBufferR = nullptr;
    }
}

// MARK: - Lifecycle

void ReverbEffect::initialize(float sampleRate) {
    m_sampleRate = sampleRate;

    // Scale factor for sample rate (tunings are based on 44.1kHz)
    float scaleFactor = sampleRate / 44100.0f;

    // Allocate and initialize comb filter buffers
    for (size_t i = 0; i < kNumCombs; ++i) {
        m_combLengths[i] = static_cast<size_t>(kCombTunings[i] * scaleFactor);
        if (m_combLengths[i] < 1) m_combLengths[i] = 1;

        if (m_combBuffersL[i]) delete[] m_combBuffersL[i];
        if (m_combBuffersR[i]) delete[] m_combBuffersR[i];

        m_combBuffersL[i] = new float[m_combLengths[i]];
        m_combBuffersR[i] = new float[m_combLengths[i]];
    }

    // Allocate and initialize allpass filter buffers
    for (size_t i = 0; i < kNumAllpasses; ++i) {
        m_allpassLengths[i] = static_cast<size_t>(kAllpassTunings[i] * scaleFactor);
        if (m_allpassLengths[i] < 1) m_allpassLengths[i] = 1;

        if (m_allpassBuffersL[i]) delete[] m_allpassBuffersL[i];
        if (m_allpassBuffersR[i]) delete[] m_allpassBuffersR[i];

        m_allpassBuffersL[i] = new float[m_allpassLengths[i]];
        m_allpassBuffersR[i] = new float[m_allpassLengths[i]];
    }

    // Allocate pre-delay buffer
    if (m_preDelayBufferL) delete[] m_preDelayBufferL;
    if (m_preDelayBufferR) delete[] m_preDelayBufferR;

    m_preDelayBufferL = new float[kMaxPreDelayLength];
    m_preDelayBufferR = new float[kMaxPreDelayLength];

    reset();
}

void ReverbEffect::reset() {
    // Clear comb buffers
    for (size_t i = 0; i < kNumCombs; ++i) {
        if (m_combBuffersL[i]) {
            std::memset(m_combBuffersL[i], 0, m_combLengths[i] * sizeof(float));
        }
        if (m_combBuffersR[i]) {
            std::memset(m_combBuffersR[i], 0, m_combLengths[i] * sizeof(float));
        }
        m_combPos[i] = 0;
        m_combFilters[i] = 0.0f;
    }

    // Clear allpass buffers
    for (size_t i = 0; i < kNumAllpasses; ++i) {
        if (m_allpassBuffersL[i]) {
            std::memset(m_allpassBuffersL[i], 0, m_allpassLengths[i] * sizeof(float));
        }
        if (m_allpassBuffersR[i]) {
            std::memset(m_allpassBuffersR[i], 0, m_allpassLengths[i] * sizeof(float));
        }
        m_allpassPos[i] = 0;
    }

    // Clear pre-delay buffer
    if (m_preDelayBufferL) {
        std::memset(m_preDelayBufferL, 0, kMaxPreDelayLength * sizeof(float));
    }
    if (m_preDelayBufferR) {
        std::memset(m_preDelayBufferR, 0, kMaxPreDelayLength * sizeof(float));
    }
    m_preDelayWritePos = 0;

    // Update coefficients
    m_feedback = m_size * 0.28f + 0.7f;
    m_damp1 = m_damping * 0.4f;
    m_damp2 = 1.0f - m_damp1;
}

// MARK: - Processing

void ReverbEffect::process(float* leftChannel, float* rightChannel, int numFrames) {
    if (m_bypassed || m_mix < 0.001f) {
        return;
    }

    // Check that buffers are initialized
    if (!m_combBuffersL[0] || !m_allpassBuffersL[0]) {
        return;
    }

    for (int i = 0; i < numFrames; ++i) {
        float dryL = leftChannel[i];
        float dryR = rightChannel[i];

        float wetL = dryL;
        float wetR = dryR;
        processSample(wetL, wetR);

        // Apply wet/dry mix
        leftChannel[i] = dryL * (1.0f - m_mix) + wetL * m_mix;
        rightChannel[i] = dryR * (1.0f - m_mix) + wetR * m_mix;
    }
}

void ReverbEffect::processSample(float& left, float& right) {
    float inputL = left;
    float inputR = right;

    // Apply pre-delay if enabled
    if (m_preDelayLength > 0 && m_preDelayBufferL && m_preDelayBufferR) {
        size_t readPos = (m_preDelayWritePos + kMaxPreDelayLength - m_preDelayLength) % kMaxPreDelayLength;
        float delayedL = m_preDelayBufferL[readPos];
        float delayedR = m_preDelayBufferR[readPos];

        m_preDelayBufferL[m_preDelayWritePos] = inputL;
        m_preDelayBufferR[m_preDelayWritePos] = inputR;
        m_preDelayWritePos = (m_preDelayWritePos + 1) % kMaxPreDelayLength;

        inputL = delayedL;
        inputR = delayedR;
    }

    // Accumulate comb filter outputs
    float outL = 0.0f;
    float outR = 0.0f;

    for (size_t i = 0; i < kNumCombs; ++i) {
        // Left channel comb
        float combOutL = m_combBuffersL[i][m_combPos[i]];

        // Apply lowpass filter (damping)
        m_combFilters[i] = combOutL * m_damp2 + m_combFilters[i] * m_damp1;

        // Write back with feedback
        m_combBuffersL[i][m_combPos[i]] = inputL + m_combFilters[i] * m_feedback;

        outL += combOutL;

        // Right channel comb (slightly offset for stereo)
        size_t rightPos = (m_combPos[i] + 23) % m_combLengths[i];
        float combOutR = m_combBuffersR[i][rightPos];
        m_combBuffersR[i][rightPos] = inputR + combOutR * m_feedback;
        outR += combOutR;

        // Advance position
        m_combPos[i] = (m_combPos[i] + 1) % m_combLengths[i];
    }

    // Process through allpass filters for diffusion
    for (size_t i = 0; i < kNumAllpasses; ++i) {
        // Left channel
        float bufOutL = m_allpassBuffersL[i][m_allpassPos[i]];
        float allpassOutL = -outL + bufOutL;
        m_allpassBuffersL[i][m_allpassPos[i]] = outL + bufOutL * 0.5f;
        outL = allpassOutL;

        // Right channel
        float bufOutR = m_allpassBuffersR[i][m_allpassPos[i]];
        float allpassOutR = -outR + bufOutR;
        m_allpassBuffersR[i][m_allpassPos[i]] = outR + bufOutR * 0.5f;
        outR = allpassOutR;

        // Advance position
        m_allpassPos[i] = (m_allpassPos[i] + 1) % m_allpassLengths[i];
    }

    // Scale output
    outL *= 0.15f;
    outR *= 0.15f;

    // Apply stereo width
    float mono = (outL + outR) * 0.5f;
    float side = (outL - outR) * 0.5f * m_width;
    left = mono + side;
    right = mono - side;
}

// MARK: - Parameter Setters

void ReverbEffect::setSize(float value) {
    m_size = clamp(value, 0.0f, 1.0f);
    m_feedback = m_size * 0.28f + 0.7f;
}

void ReverbEffect::setDamping(float value) {
    m_damping = clamp(value, 0.0f, 1.0f);
    m_damp1 = m_damping * 0.4f;
    m_damp2 = 1.0f - m_damp1;
}

void ReverbEffect::setPreDelay(float value) {
    m_preDelay = clamp(value, 0.0f, 1.0f);
    // Map 0-1 to 0-100ms
    float preDelayMs = m_preDelay * 100.0f;
    m_preDelayLength = static_cast<size_t>(preDelayMs * m_sampleRate / 1000.0f);
    if (m_preDelayLength >= kMaxPreDelayLength) {
        m_preDelayLength = kMaxPreDelayLength - 1;
    }
}

void ReverbEffect::setWidth(float value) {
    m_width = clamp(value, 0.0f, 1.0f);
}

// MARK: - Parameter Interface

int ReverbEffect::getParameterCount() const {
    return static_cast<int>(ReverbParameter::NumParameters);
}

EffectParameterInfo ReverbEffect::getParameterInfo(int index) const {
    switch (static_cast<ReverbParameter>(index)) {
        case ReverbParameter::Size:
            return EffectParameterInfo("Room Size", "SIZE", 0.0f, 1.0f, 0.5f, false, "");

        case ReverbParameter::Damping:
            return EffectParameterInfo("Damping", "DAMP", 0.0f, 1.0f, 0.5f, false, "");

        case ReverbParameter::PreDelay:
            return EffectParameterInfo("Pre-Delay", "PRE", 0.0f, 1.0f, 0.0f, false, "ms");

        case ReverbParameter::Width:
            return EffectParameterInfo("Stereo Width", "WIDTH", 0.0f, 1.0f, 1.0f, false, "");

        default:
            return EffectParameterInfo();
    }
}

float ReverbEffect::getParameter(int index) const {
    switch (static_cast<ReverbParameter>(index)) {
        case ReverbParameter::Size:
            return m_size;
        case ReverbParameter::Damping:
            return m_damping;
        case ReverbParameter::PreDelay:
            return m_preDelay;
        case ReverbParameter::Width:
            return m_width;
        default:
            return 0.0f;
    }
}

void ReverbEffect::setParameter(int index, float value) {
    switch (static_cast<ReverbParameter>(index)) {
        case ReverbParameter::Size:
            setSize(value);
            break;
        case ReverbParameter::Damping:
            setDamping(value);
            break;
        case ReverbParameter::PreDelay:
            setPreDelay(value);
            break;
        case ReverbParameter::Width:
            setWidth(value);
            break;
        default:
            break;
    }
}

} // namespace Grainulator

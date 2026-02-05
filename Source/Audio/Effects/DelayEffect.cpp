//
//  DelayEffect.cpp
//  Grainulator
//
//  Multi-head tape delay effect implementation
//

#include "DelayEffect.h"
#include <cstring>

namespace Grainulator {

// Static member definitions
constexpr float DelayEffect::kHeadRatios[kNumHeads];
constexpr float DelayEffect::kHeadGains[kNumHeads];
constexpr float DelayEffect::kHeadPans[kNumHeads];
constexpr float DelayEffect::kModeMatrix[kNumHeadModes][kNumHeads];
constexpr float DelayEffect::kDivisionTable[kNumDivisions];

// MARK: - Constructor / Destructor

DelayEffect::DelayEffect()
    : m_delayBufferL(nullptr)
    , m_delayBufferR(nullptr)
    , m_delayWritePos(0)
    , m_delayTime(0.3f)
    , m_delayFeedback(0.4f * 0.95f)
    , m_delayHeadMode(0.86f)        // Default to 1+2+3 mode
    , m_delayWow(0.5f)
    , m_delayFlutter(0.5f)
    , m_delayTone(0.45f)
    , m_delaySync(false)
    , m_delayTempoBPM(120.0f)
    , m_delaySubdivision(0.375f)    // Quarter-note slot
    , m_delayTimeSmoothed(0.095f)
    , m_tapeWowPhase(0.0f)
    , m_tapeFlutterPhase(0.0f)
    , m_tapeDrift(0.0f)
    , m_tapeFeedbackLP(0.0f)
    , m_tapeFeedbackHPIn(0.0f)
    , m_tapeFeedbackHPOut(0.0f)
    , m_tapeToneL(0.0f)
    , m_tapeToneR(0.0f)
    , m_tapeNoiseState(0x12345678u)
{
}

DelayEffect::~DelayEffect() {
    if (m_delayBufferL) {
        delete[] m_delayBufferL;
        m_delayBufferL = nullptr;
    }
    if (m_delayBufferR) {
        delete[] m_delayBufferR;
        m_delayBufferR = nullptr;
    }
}

// MARK: - Lifecycle

void DelayEffect::initialize(float sampleRate) {
    m_sampleRate = sampleRate;

    // Allocate delay buffers
    if (!m_delayBufferL) {
        m_delayBufferL = new float[kMaxDelayLength];
    }
    if (!m_delayBufferR) {
        m_delayBufferR = new float[kMaxDelayLength];
    }

    reset();
}

void DelayEffect::reset() {
    if (m_delayBufferL) {
        std::memset(m_delayBufferL, 0, kMaxDelayLength * sizeof(float));
    }
    if (m_delayBufferR) {
        std::memset(m_delayBufferR, 0, kMaxDelayLength * sizeof(float));
    }

    m_delayWritePos = 0;
    m_tapeWowPhase = 0.0f;
    m_tapeFlutterPhase = 0.0f;
    m_tapeDrift = 0.0f;
    m_tapeFeedbackLP = 0.0f;
    m_tapeFeedbackHPIn = 0.0f;
    m_tapeFeedbackHPOut = 0.0f;
    m_tapeToneL = 0.0f;
    m_tapeToneR = 0.0f;

    // Initialize smoothed delay time
    if (m_delaySync) {
        const int divisionIndex = detail::clamp(
            static_cast<int>(m_delaySubdivision * (kNumDivisions - 1) + 0.5f),
            0, kNumDivisions - 1);
        const float beatSeconds = 60.0f / std::max(40.0f, m_delayTempoBPM);
        m_delayTimeSmoothed = beatSeconds * kDivisionTable[divisionIndex];
    } else {
        m_delayTimeSmoothed = 0.06f + (m_delayTime * m_delayTime) * 0.39f;
    }
}

// MARK: - Processing

void DelayEffect::process(float* leftChannel, float* rightChannel, int numFrames) {
    if (!m_delayBufferL || !m_delayBufferR || m_bypassed) {
        return;
    }

    // If mix is near zero, skip processing
    if (m_mix < 0.001f) {
        return;
    }

    for (int i = 0; i < numFrames; ++i) {
        float dryL = leftChannel[i];
        float dryR = rightChannel[i];

        processSample(leftChannel[i], rightChannel[i]);

        // Apply wet/dry mix using base class mix parameter
        leftChannel[i] = dryL * (1.0f - m_mix) + leftChannel[i] * m_mix;
        rightChannel[i] = dryR * (1.0f - m_mix) + rightChannel[i] * m_mix;
    }
}

void DelayEffect::processSample(float& left, float& right) {
    // Calculate current head mode
    const int modeIndex = detail::clamp(
        static_cast<int>(m_delayHeadMode * static_cast<float>(kNumHeadModes - 1) + 0.5f),
        0, kNumHeadModes - 1);

    // Calculate target delay time
    float targetHead1Seconds;
    if (m_delaySync) {
        const int divisionIndex = detail::clamp(
            static_cast<int>(m_delaySubdivision * static_cast<float>(kNumDivisions - 1) + 0.5f),
            0, kNumDivisions - 1);
        const float beatSeconds = 60.0f / std::max(40.0f, m_delayTempoBPM);
        targetHead1Seconds = beatSeconds * kDivisionTable[divisionIndex];
    } else {
        // Free repeat-rate mapping: short head ranges ~60ms to ~450ms
        const float repeatCurve = m_delayTime * m_delayTime;
        targetHead1Seconds = 0.06f + repeatCurve * 0.39f;
    }

    // Clamp to buffer size
    const float maxHead1Seconds = (static_cast<float>(kMaxDelayLength - 4) / m_sampleRate) / kHeadRatios[kNumHeads - 1];
    targetHead1Seconds = detail::clamp(targetHead1Seconds, 0.03f, maxHead1Seconds);

    // Smooth delay time changes
    const float timeSmoothing = m_delaySync ? 0.0028f : 0.0015f;
    m_delayTimeSmoothed += (targetHead1Seconds - m_delayTimeSmoothed) * timeSmoothing;

    // Tape speed modulation (wow, flutter, and slow random drift)
    m_tapeWowPhase += kTwoPi * 0.17f / m_sampleRate;
    m_tapeFlutterPhase += kTwoPi * 5.4f / m_sampleRate;
    if (m_tapeWowPhase > kTwoPi) m_tapeWowPhase -= kTwoPi;
    if (m_tapeFlutterPhase > kTwoPi) m_tapeFlutterPhase -= kTwoPi;

    // Random drift for tape instability
    m_tapeNoiseState = m_tapeNoiseState * 1664525u + 1013904223u;
    float randomDrift = (static_cast<float>((m_tapeNoiseState >> 8) & 0x00FFFFFF) / 16777216.0f) * 2.0f - 1.0f;
    m_tapeDrift = m_tapeDrift * 0.99985f + randomDrift * 0.00015f;

    // Calculate combined speed modulation
    const float wowDepth = 0.0010f + m_delayWow * 0.0070f;
    const float flutterDepth = 0.00025f + m_delayFlutter * 0.0025f;
    const float driftDepth = 0.0007f + m_delayWow * 0.0014f;
    const float speedMod = detail::clamp(
        std::sin(m_tapeWowPhase) * wowDepth +
        std::sin(m_tapeFlutterPhase) * flutterDepth +
        m_tapeDrift * driftDepth,
        -0.02f,
        0.02f
    );

    // Read from each head and accumulate
    float echoL = 0.0f;
    float echoR = 0.0f;
    float feedbackSum = 0.0f;

    for (int i = 0; i < kNumHeads; ++i) {
        const float modeGain = kModeMatrix[modeIndex][i];
        if (modeGain < 0.001f) {
            continue;
        }

        float delaySeconds = m_delayTimeSmoothed * kHeadRatios[i] * (1.0f + speedMod);
        float delaySamples = delaySeconds * m_sampleRate;

        float tapL = readInterpolated(m_delayBufferL, delaySamples);
        float tapR = readInterpolated(m_delayBufferR, delaySamples);
        float tapMono = (tapL + tapR) * 0.5f;
        float headOut = tapMono * kHeadGains[i] * modeGain;

        // Apply pan for stereo spread
        float panAngle = (kHeadPans[i] + 1.0f) * 0.25f * kPi;
        float panL = std::cos(panAngle);
        float panR = std::sin(panAngle);

        echoL += headOut * panL;
        echoR += headOut * panR;
        feedbackSum += headOut * (i == (kNumHeads - 1) ? 0.85f : 1.0f);
    }

    // Roll off highs/lows in the feedback path like aging tape
    const float feedbackLPCoeff = detail::clamp(
        (0.28f + m_delayTone * 0.32f) - m_delayFeedback * 0.12f,
        0.08f, 0.80f);
    m_tapeFeedbackLP += (std::tanh(feedbackSum * (1.1f + m_delayFeedback * 2.2f)) - m_tapeFeedbackLP) * feedbackLPCoeff;

    // High-pass filter to remove DC and low rumble
    float feedbackHPCoeff = 1.0f - (kTwoPi * 110.0f / m_sampleRate);
    feedbackHPCoeff = std::max(0.0f, std::min(feedbackHPCoeff, 0.9999f));
    float feedbackHP = feedbackHPCoeff * (m_tapeFeedbackHPOut + m_tapeFeedbackLP - m_tapeFeedbackHPIn);
    m_tapeFeedbackHPIn = m_tapeFeedbackLP;
    m_tapeFeedbackHPOut = feedbackHP;

    // Tape preamp behavior before writing back to the loop
    float inputMono = (left + right) * 0.5f;
    float preampedInput = std::tanh(inputMono * (1.0f + m_delayFeedback * 1.4f));

    // Add subtle tape hiss
    m_tapeNoiseState = m_tapeNoiseState * 1664525u + 1013904223u;
    float hiss = ((static_cast<float>((m_tapeNoiseState >> 8) & 0x00FFFFFF) / 16777216.0f) * 2.0f - 1.0f) * 0.00003f;

    // Write to delay buffer
    float writeSample = preampedInput + feedbackHP * (m_delayFeedback * 0.92f) + hiss;
    m_delayBufferL[m_delayWritePos] = writeSample;
    m_delayBufferR[m_delayWritePos] = writeSample * 0.985f + feedbackHP * 0.02f;
    m_delayWritePos = (m_delayWritePos + 1) % kMaxDelayLength;

    // Output tone shaping to keep repeats dark and soft
    const float outputToneCoeff = detail::clamp(
        (0.35f + m_delayTone * 0.35f) - m_delayFeedback * 0.15f,
        0.10f, 0.90f);
    m_tapeToneL += (echoL - m_tapeToneL) * outputToneCoeff;
    m_tapeToneR += (echoR - m_tapeToneR) * outputToneCoeff;

    // Soft-clip the output
    left = std::tanh(m_tapeToneL * 1.25f);
    right = std::tanh(m_tapeToneR * 1.25f);
}

float DelayEffect::readInterpolated(float* buffer, float delaySamples) const {
    float clampedDelay = std::max(1.0f, std::min(delaySamples, static_cast<float>(kMaxDelayLength - 2)));
    float readPos = static_cast<float>(m_delayWritePos) - clampedDelay;
    while (readPos < 0.0f) {
        readPos += static_cast<float>(kMaxDelayLength);
    }

    int indexA = static_cast<int>(readPos);
    int indexB = (indexA + 1) % static_cast<int>(kMaxDelayLength);
    float frac = readPos - static_cast<float>(indexA);
    return buffer[indexA] + (buffer[indexB] - buffer[indexA]) * frac;
}

// MARK: - Parameter Interface

int DelayEffect::getParameterCount() const {
    return static_cast<int>(DelayParameter::NumParameters);
}

EffectParameterInfo DelayEffect::getParameterInfo(int index) const {
    switch (static_cast<DelayParameter>(index)) {
        case DelayParameter::Time:
            return EffectParameterInfo("Delay Time", "TIME", 0.0f, 1.0f, 0.3f, false, "");

        case DelayParameter::Feedback:
            return EffectParameterInfo("Feedback", "FDBK", 0.0f, 1.0f, 0.4f, false, "%");

        case DelayParameter::HeadMode:
            return EffectParameterInfo("Head Mode", "MODE", 0.0f, 1.0f, 0.86f, false, "");

        case DelayParameter::Wow:
            return EffectParameterInfo("Wow", "WOW", 0.0f, 1.0f, 0.5f, false, "");

        case DelayParameter::Flutter:
            return EffectParameterInfo("Flutter", "FLTR", 0.0f, 1.0f, 0.5f, false, "");

        case DelayParameter::Tone:
            return EffectParameterInfo("Tone", "TONE", 0.0f, 1.0f, 0.45f, false, "");

        case DelayParameter::TempoSync:
            return EffectParameterInfo("Tempo Sync", "SYNC", 0.0f, 1.0f, 0.0f, false, "");

        case DelayParameter::TempoBPM:
            return EffectParameterInfo("Tempo BPM", "BPM", 40.0f, 300.0f, 120.0f, false, "BPM");

        case DelayParameter::Subdivision:
            return EffectParameterInfo("Subdivision", "DIV", 0.0f, 1.0f, 0.375f, false, "");

        default:
            return EffectParameterInfo();
    }
}

float DelayEffect::getParameter(int index) const {
    switch (static_cast<DelayParameter>(index)) {
        case DelayParameter::Time:
            return m_delayTime;
        case DelayParameter::Feedback:
            return m_delayFeedback / 0.95f;
        case DelayParameter::HeadMode:
            return m_delayHeadMode;
        case DelayParameter::Wow:
            return m_delayWow;
        case DelayParameter::Flutter:
            return m_delayFlutter;
        case DelayParameter::Tone:
            return m_delayTone;
        case DelayParameter::TempoSync:
            return m_delaySync ? 1.0f : 0.0f;
        case DelayParameter::TempoBPM:
            return (m_delayTempoBPM - 40.0f) / 260.0f;  // Normalize to 0-1
        case DelayParameter::Subdivision:
            return m_delaySubdivision;
        default:
            return 0.0f;
    }
}

void DelayEffect::setParameter(int index, float value) {
    switch (static_cast<DelayParameter>(index)) {
        case DelayParameter::Time:
            setTime(value);
            break;
        case DelayParameter::Feedback:
            setFeedback(value);
            break;
        case DelayParameter::HeadMode:
            setHeadMode(value);
            break;
        case DelayParameter::Wow:
            setWow(value);
            break;
        case DelayParameter::Flutter:
            setFlutter(value);
            break;
        case DelayParameter::Tone:
            setTone(value);
            break;
        case DelayParameter::TempoSync:
            setTempoSync(value > 0.5f);
            break;
        case DelayParameter::TempoBPM:
            setTempoBPM(40.0f + value * 260.0f);  // Denormalize from 0-1
            break;
        case DelayParameter::Subdivision:
            setSubdivision(value);
            break;
        default:
            break;
    }
}

} // namespace Grainulator

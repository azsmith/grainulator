//
//  DelayEffect.h
//  Grainulator
//
//  Multi-head tape delay effect with vintage characteristics
//  Extracted from AudioEngine for modular effect architecture
//

#ifndef DELAYEFFECT_H
#define DELAYEFFECT_H

#include "EffectBase.h"
#include <cmath>
#include <algorithm>

// Helper for clamp if not available in std
namespace Grainulator {
namespace detail {
    template<typename T>
    inline T clamp(T value, T minVal, T maxVal) {
        return (value < minVal) ? minVal : (value > maxVal) ? maxVal : value;
    }
}
}

namespace Grainulator {

// MARK: - Delay Parameter IDs

enum class DelayParameter {
    Time = 0,           // 0-1 repeat rate
    Feedback,           // 0-1 feedback amount
    HeadMode,           // 0-1 discrete mode index (8 modes)
    Wow,                // 0-1 wow depth
    Flutter,            // 0-1 flutter depth
    Tone,               // 0-1 dark to bright
    TempoSync,          // 0-1 (>0.5 = enabled)
    TempoBPM,           // 60-180 BPM (normalized 0-1)
    Subdivision,        // 0-1 discrete subdivision index (9 values)
    NumParameters
};

// MARK: - Delay Effect Class

class DelayEffect : public EffectBase {
public:
    DelayEffect();
    ~DelayEffect() override;

    // EffectBase interface
    void initialize(float sampleRate) override;
    void reset() override;
    void process(float* leftChannel, float* rightChannel, int numFrames) override;

    int getParameterCount() const override;
    EffectParameterInfo getParameterInfo(int index) const override;
    float getParameter(int index) const override;
    void setParameter(int index, float value) override;

    const char* getName() const override { return "Tape Delay"; }
    const char* getShortName() const override { return "DELAY"; }
    EffectType getType() const override { return EffectType::Delay; }

    // Direct parameter access for convenience
    void setTime(float value) { m_delayTime = detail::clamp(value, 0.0f, 1.0f); }
    void setFeedback(float value) { m_delayFeedback = detail::clamp(value, 0.0f, 1.0f) * 0.95f; }
    void setHeadMode(float value) { m_delayHeadMode = detail::clamp(value, 0.0f, 1.0f); }
    void setWow(float value) { m_delayWow = detail::clamp(value, 0.0f, 1.0f); }
    void setFlutter(float value) { m_delayFlutter = detail::clamp(value, 0.0f, 1.0f); }
    void setTone(float value) { m_delayTone = detail::clamp(value, 0.0f, 1.0f); }
    void setTempoSync(bool enabled) { m_delaySync = enabled; }
    void setTempoBPM(float bpm) { m_delayTempoBPM = detail::clamp(bpm, 40.0f, 300.0f); }
    void setSubdivision(float value) { m_delaySubdivision = detail::clamp(value, 0.0f, 1.0f); }

    float getTime() const { return m_delayTime; }
    float getFeedback() const { return m_delayFeedback / 0.95f; }
    float getHeadMode() const { return m_delayHeadMode; }
    float getWow() const { return m_delayWow; }
    float getFlutter() const { return m_delayFlutter; }
    float getTone() const { return m_delayTone; }
    bool getTempoSync() const { return m_delaySync; }
    float getTempoBPM() const { return m_delayTempoBPM; }
    float getSubdivision() const { return m_delaySubdivision; }

private:
    // Process a single sample pair
    void processSample(float& left, float& right);

    // Interpolated buffer read
    float readInterpolated(float* buffer, float delaySamples) const;

    // Buffer management
    static constexpr size_t kMaxDelayLength = 192000;  // 4 seconds @ 48kHz

    float* m_delayBufferL;
    float* m_delayBufferR;
    size_t m_delayWritePos;

    // Parameters
    float m_delayTime;          // 0-1 repeat rate
    float m_delayFeedback;      // 0-0.95 (capped to prevent runaway)
    float m_delayHeadMode;      // 0-1 discrete mode index
    float m_delayWow;           // 0-1 depth
    float m_delayFlutter;       // 0-1 depth
    float m_delayTone;          // 0-1 dark->bright
    bool m_delaySync;           // tempo sync enable
    float m_delayTempoBPM;      // synced tempo
    float m_delaySubdivision;   // 0-1 discrete subdivision index

    // Internal state
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

    // Constants
    static constexpr float kPi = 3.14159265358979323846f;
    static constexpr float kTwoPi = 6.28318530717958647692f;
    static constexpr int kNumHeads = 3;
    static constexpr int kNumHeadModes = 8;
    static constexpr int kNumDivisions = 9;

    // Head configuration (space-echo style)
    static constexpr float kHeadRatios[kNumHeads] = {1.0f, 1.42f, 1.95f};
    static constexpr float kHeadGains[kNumHeads] = {0.55f, 0.40f, 0.30f};
    static constexpr float kHeadPans[kNumHeads] = {-0.55f, 0.0f, 0.55f};

    // Head mode matrix (which heads are active and at what level)
    static constexpr float kModeMatrix[kNumHeadModes][kNumHeads] = {
        {1.00f, 0.00f, 0.00f}, // Head 1
        {0.00f, 1.00f, 0.00f}, // Head 2
        {0.00f, 0.00f, 1.00f}, // Head 3
        {0.85f, 0.65f, 0.00f}, // 1 + 2
        {0.00f, 0.75f, 0.58f}, // 2 + 3
        {0.80f, 0.00f, 0.58f}, // 1 + 3
        {0.72f, 0.55f, 0.42f}, // 1 + 2 + 3
        {0.95f, 0.45f, 0.28f}  // dense stack
    };

    // Tempo sync division table (in quarter-note units)
    static constexpr float kDivisionTable[kNumDivisions] = {
        2.0f, 1.333333f, 1.5f, 1.0f, 0.666667f, 0.75f, 0.5f, 0.333333f, 0.25f
    };
};

} // namespace Grainulator

#endif // DELAYEFFECT_H

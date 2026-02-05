//
//  ReverbEffect.h
//  Grainulator
//
//  Freeverb-style algorithmic reverb effect
//  Extracted from AudioEngine for modular effect architecture
//

#ifndef REVERBEFFECT_H
#define REVERBEFFECT_H

#include "EffectBase.h"
#include <cmath>
#include <algorithm>

namespace Grainulator {

// MARK: - Reverb Parameter IDs

enum class ReverbParameter {
    Size = 0,           // Room size (0-1)
    Damping,            // High frequency damping (0-1)
    PreDelay,           // Pre-delay time (0-1, 0-100ms)
    Width,              // Stereo width (0-1)
    NumParameters
};

// MARK: - Reverb Effect Class

class ReverbEffect : public EffectBase {
public:
    ReverbEffect();
    ~ReverbEffect() override;

    // EffectBase interface
    void initialize(float sampleRate) override;
    void reset() override;
    void process(float* leftChannel, float* rightChannel, int numFrames) override;

    int getParameterCount() const override;
    EffectParameterInfo getParameterInfo(int index) const override;
    float getParameter(int index) const override;
    void setParameter(int index, float value) override;

    const char* getName() const override { return "Plate Reverb"; }
    const char* getShortName() const override { return "REVERB"; }
    EffectType getType() const override { return EffectType::Reverb; }

    // Direct parameter access for convenience
    void setSize(float value);
    void setDamping(float value);
    void setPreDelay(float value);
    void setWidth(float value);

    float getSize() const { return m_size; }
    float getDamping() const { return m_damping; }
    float getPreDelay() const { return m_preDelay; }
    float getWidth() const { return m_width; }

private:
    // Process a single sample pair
    void processSample(float& left, float& right);

    // Helper for clamping
    template<typename T>
    static T clamp(T value, T minVal, T maxVal) {
        return (value < minVal) ? minVal : (value > maxVal) ? maxVal : value;
    }

    // Buffer sizes - Freeverb-style tunings
    static constexpr size_t kNumCombs = 8;
    static constexpr size_t kNumAllpasses = 4;

    // Comb filter tunings (in samples at 44.1kHz, scaled for actual sample rate)
    static constexpr size_t kCombTunings[kNumCombs] = {
        1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617
    };

    // Allpass filter tunings
    static constexpr size_t kAllpassTunings[kNumAllpasses] = {
        556, 441, 341, 225
    };

    // Pre-delay buffer (max 100ms at 192kHz)
    static constexpr size_t kMaxPreDelayLength = 19200;

    // Parameters
    float m_size;           // Room size (0-1)
    float m_damping;        // High frequency damping (0-1)
    float m_preDelay;       // Pre-delay amount (0-1, maps to 0-100ms)
    float m_width;          // Stereo width (0-1)

    // Comb filter state
    float* m_combBuffersL[kNumCombs];
    float* m_combBuffersR[kNumCombs];
    size_t m_combLengths[kNumCombs];
    size_t m_combPos[kNumCombs];
    float m_combFilters[kNumCombs];

    // Allpass filter state
    float* m_allpassBuffersL[kNumAllpasses];
    float* m_allpassBuffersR[kNumAllpasses];
    size_t m_allpassLengths[kNumAllpasses];
    size_t m_allpassPos[kNumAllpasses];

    // Pre-delay buffer
    float* m_preDelayBufferL;
    float* m_preDelayBufferR;
    size_t m_preDelayWritePos;
    size_t m_preDelayLength;

    // Cached coefficients
    float m_feedback;
    float m_damp1;
    float m_damp2;
};

} // namespace Grainulator

#endif // REVERBEFFECT_H

//
//  EffectBase.h
//  Grainulator
//
//  Abstract base class for modular audio effects
//  Provides a plugin-like interface for all effect processors
//

#ifndef EFFECTBASE_H
#define EFFECTBASE_H

#include <cstdint>
#include <string>
#include <vector>
#include <memory>

namespace Grainulator {

// MARK: - Effect Parameter Info

struct EffectParameterInfo {
    std::string name;           // Display name (e.g., "Delay Time")
    std::string shortName;      // Short name for UI (e.g., "TIME")
    float minValue;             // Minimum value
    float maxValue;             // Maximum value
    float defaultValue;         // Default value
    bool isLogarithmic;         // Use log scaling for display
    std::string unit;           // Unit string (e.g., "ms", "Hz", "%")

    EffectParameterInfo(
        const std::string& name = "",
        const std::string& shortName = "",
        float minValue = 0.0f,
        float maxValue = 1.0f,
        float defaultValue = 0.5f,
        bool isLogarithmic = false,
        const std::string& unit = ""
    ) : name(name), shortName(shortName), minValue(minValue), maxValue(maxValue),
        defaultValue(defaultValue), isLogarithmic(isLogarithmic), unit(unit) {}
};

// MARK: - Effect Type Enumeration

enum class EffectType {
    Delay,
    Reverb,
    Filter,
    EQ,
    Compressor,
    Saturator,
    Chorus,
    Phaser,
    NumTypes
};

// MARK: - Effect Base Class

class EffectBase {
public:
    virtual ~EffectBase() = default;

    // Lifecycle
    virtual void initialize(float sampleRate) = 0;
    virtual void reset() = 0;

    // Processing
    virtual void process(float* leftChannel, float* rightChannel, int numFrames) = 0;

    // Bypass
    void setBypass(bool bypassed) { m_bypassed = bypassed; }
    bool isBypassed() const { return m_bypassed; }

    // Parameters
    virtual int getParameterCount() const = 0;
    virtual EffectParameterInfo getParameterInfo(int index) const = 0;
    virtual float getParameter(int index) const = 0;
    virtual void setParameter(int index, float value) = 0;

    // Metadata
    virtual const char* getName() const = 0;
    virtual const char* getShortName() const = 0;
    virtual EffectType getType() const = 0;

    // Mix control (dry/wet)
    void setMix(float mix) { m_mix = std::max(0.0f, std::min(1.0f, mix)); }
    float getMix() const { return m_mix; }

protected:
    float m_sampleRate = 48000.0f;
    float m_mix = 1.0f;           // Dry/wet mix (1.0 = 100% wet)
    bool m_bypassed = false;

    // Helper for processing with dry/wet mix
    void applyMix(float* leftIn, float* rightIn,
                  float* leftOut, float* rightOut,
                  int numFrames) {
        if (m_mix >= 0.999f) {
            // 100% wet - just copy
            for (int i = 0; i < numFrames; ++i) {
                leftIn[i] = leftOut[i];
                rightIn[i] = rightOut[i];
            }
        } else if (m_mix <= 0.001f) {
            // 100% dry - do nothing (input unchanged)
        } else {
            // Blend
            float wet = m_mix;
            float dry = 1.0f - m_mix;
            for (int i = 0; i < numFrames; ++i) {
                leftIn[i] = leftIn[i] * dry + leftOut[i] * wet;
                rightIn[i] = rightIn[i] * dry + rightOut[i] * wet;
            }
        }
    }
};

// MARK: - Effect Factory Function Type

using EffectFactoryFunc = std::unique_ptr<EffectBase>(*)();

} // namespace Grainulator

#endif // EFFECTBASE_H

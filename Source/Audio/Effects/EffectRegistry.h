//
//  EffectRegistry.h
//  Grainulator
//
//  Factory and registry for modular audio effects
//  Provides type-safe creation and management of effects
//

#ifndef EFFECTREGISTRY_H
#define EFFECTREGISTRY_H

#include "EffectBase.h"
#include "DelayEffect.h"
#include "ReverbEffect.h"
#include <unordered_map>
#include <functional>
#include <string>

namespace Grainulator {

// MARK: - Effect Info

struct EffectInfo {
    EffectType type;
    std::string name;
    std::string shortName;
    std::string description;
    EffectFactoryFunc factory;

    EffectInfo(
        EffectType type = EffectType::NumTypes,
        const std::string& name = "",
        const std::string& shortName = "",
        const std::string& description = "",
        EffectFactoryFunc factory = nullptr
    ) : type(type), name(name), shortName(shortName),
        description(description), factory(factory) {}
};

// MARK: - Effect Registry

class EffectRegistry {
public:
    // Singleton access
    static EffectRegistry& instance() {
        static EffectRegistry registry;
        return registry;
    }

    // Registration
    void registerEffect(const EffectInfo& info) {
        m_effects[info.type] = info;
    }

    // Factory methods
    std::unique_ptr<EffectBase> createEffect(EffectType type) const {
        auto it = m_effects.find(type);
        if (it != m_effects.end() && it->second.factory) {
            return it->second.factory();
        }
        return nullptr;
    }

    // Convenience factory by name
    std::unique_ptr<EffectBase> createEffectByName(const std::string& name) const {
        for (const auto& pair : m_effects) {
            if (pair.second.name == name || pair.second.shortName == name) {
                if (pair.second.factory) {
                    return pair.second.factory();
                }
            }
        }
        return nullptr;
    }

    // Query available effects
    const EffectInfo* getEffectInfo(EffectType type) const {
        auto it = m_effects.find(type);
        return (it != m_effects.end()) ? &it->second : nullptr;
    }

    std::vector<EffectType> getAvailableTypes() const {
        std::vector<EffectType> types;
        for (const auto& pair : m_effects) {
            types.push_back(pair.first);
        }
        return types;
    }

    size_t getEffectCount() const {
        return m_effects.size();
    }

private:
    EffectRegistry() {
        // Register built-in effects on construction
        registerBuiltinEffects();
    }

    void registerBuiltinEffects() {
        // Delay effect
        registerEffect(EffectInfo(
            EffectType::Delay,
            "Tape Delay",
            "DELAY",
            "Multi-head tape delay with vintage character",
            []() -> std::unique_ptr<EffectBase> {
                return std::make_unique<DelayEffect>();
            }
        ));

        // Reverb effect
        registerEffect(EffectInfo(
            EffectType::Reverb,
            "Plate Reverb",
            "REVERB",
            "Freeverb-style algorithmic reverb",
            []() -> std::unique_ptr<EffectBase> {
                return std::make_unique<ReverbEffect>();
            }
        ));

        // Placeholder for future effects
        // Filter effect (to be implemented)
        registerEffect(EffectInfo(
            EffectType::Filter,
            "Filter",
            "FILTER",
            "Moog-style ladder filter",
            nullptr  // Not yet implemented
        ));

        // EQ effect (to be implemented)
        registerEffect(EffectInfo(
            EffectType::EQ,
            "Equalizer",
            "EQ",
            "3-band parametric EQ",
            nullptr  // Not yet implemented
        ));

        // Compressor effect (to be implemented)
        registerEffect(EffectInfo(
            EffectType::Compressor,
            "Compressor",
            "COMP",
            "VCA-style dynamics compressor",
            nullptr  // Not yet implemented
        ));

        // Saturator effect (to be implemented)
        registerEffect(EffectInfo(
            EffectType::Saturator,
            "Saturator",
            "SAT",
            "Tube/tape saturation and warmth",
            nullptr  // Not yet implemented
        ));
    }

    // Prevent copying
    EffectRegistry(const EffectRegistry&) = delete;
    EffectRegistry& operator=(const EffectRegistry&) = delete;

    std::unordered_map<EffectType, EffectInfo> m_effects;
};

// MARK: - Effect Chain

// A simple effect chain that manages multiple effects in series
class EffectChain {
public:
    EffectChain() = default;
    ~EffectChain() = default;

    // Initialize all effects in the chain
    void initialize(float sampleRate) {
        m_sampleRate = sampleRate;
        for (auto& effect : m_effects) {
            if (effect) {
                effect->initialize(sampleRate);
            }
        }
    }

    // Reset all effects
    void reset() {
        for (auto& effect : m_effects) {
            if (effect) {
                effect->reset();
            }
        }
    }

    // Process audio through all effects
    void process(float* leftChannel, float* rightChannel, int numFrames) {
        for (auto& effect : m_effects) {
            if (effect && !effect->isBypassed()) {
                effect->process(leftChannel, rightChannel, numFrames);
            }
        }
    }

    // Add an effect to the chain
    void addEffect(std::unique_ptr<EffectBase> effect) {
        if (effect) {
            if (m_sampleRate > 0) {
                effect->initialize(m_sampleRate);
            }
            m_effects.push_back(std::move(effect));
        }
    }

    // Insert an effect at a specific position
    void insertEffect(size_t index, std::unique_ptr<EffectBase> effect) {
        if (effect) {
            if (m_sampleRate > 0) {
                effect->initialize(m_sampleRate);
            }
            if (index >= m_effects.size()) {
                m_effects.push_back(std::move(effect));
            } else {
                m_effects.insert(m_effects.begin() + index, std::move(effect));
            }
        }
    }

    // Remove an effect at a specific position
    std::unique_ptr<EffectBase> removeEffect(size_t index) {
        if (index < m_effects.size()) {
            auto effect = std::move(m_effects[index]);
            m_effects.erase(m_effects.begin() + index);
            return effect;
        }
        return nullptr;
    }

    // Swap two effects
    void swapEffects(size_t indexA, size_t indexB) {
        if (indexA < m_effects.size() && indexB < m_effects.size()) {
            std::swap(m_effects[indexA], m_effects[indexB]);
        }
    }

    // Get effect at index
    EffectBase* getEffect(size_t index) {
        return (index < m_effects.size()) ? m_effects[index].get() : nullptr;
    }

    const EffectBase* getEffect(size_t index) const {
        return (index < m_effects.size()) ? m_effects[index].get() : nullptr;
    }

    // Get number of effects in chain
    size_t getEffectCount() const {
        return m_effects.size();
    }

    // Clear all effects
    void clear() {
        m_effects.clear();
    }

private:
    std::vector<std::unique_ptr<EffectBase>> m_effects;
    float m_sampleRate = 0.0f;
};

// MARK: - Send Effect Bus

// Manages a send/return effect with level control
class SendEffectBus {
public:
    SendEffectBus() = default;

    void initialize(float sampleRate) {
        m_sampleRate = sampleRate;
        if (m_effect) {
            m_effect->initialize(sampleRate);
        }
    }

    void reset() {
        if (m_effect) {
            m_effect->reset();
        }
        m_accumulatorL = 0.0f;
        m_accumulatorR = 0.0f;
    }

    // Set the effect for this bus
    void setEffect(std::unique_ptr<EffectBase> effect) {
        m_effect = std::move(effect);
        if (m_effect && m_sampleRate > 0) {
            m_effect->initialize(m_sampleRate);
        }
    }

    EffectBase* getEffect() {
        return m_effect.get();
    }

    // Send audio to the bus (accumulate from multiple sources)
    void send(float left, float right, float level) {
        m_accumulatorL += left * level;
        m_accumulatorR += right * level;
    }

    // Process accumulated sends and return result
    void processAndReturn(float& returnL, float& returnR) {
        if (m_effect && !m_effect->isBypassed()) {
            float processL = m_accumulatorL;
            float processR = m_accumulatorR;
            m_effect->process(&processL, &processR, 1);
            returnL = processL * m_returnLevel;
            returnR = processR * m_returnLevel;
        } else {
            returnL = 0.0f;
            returnR = 0.0f;
        }

        // Clear accumulators for next frame
        m_accumulatorL = 0.0f;
        m_accumulatorR = 0.0f;
    }

    // Return level control
    void setReturnLevel(float level) {
        m_returnLevel = (level < 0.0f) ? 0.0f : (level > 2.0f) ? 2.0f : level;
    }

    float getReturnLevel() const {
        return m_returnLevel;
    }

private:
    std::unique_ptr<EffectBase> m_effect;
    float m_sampleRate = 0.0f;
    float m_accumulatorL = 0.0f;
    float m_accumulatorR = 0.0f;
    float m_returnLevel = 1.0f;
};

} // namespace Grainulator

#endif // EFFECTREGISTRY_H

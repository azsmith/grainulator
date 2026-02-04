//
//  Grain.h
//  Grainulator
//
//  Individual grain for granular synthesis
//  Handles playback, windowing, and pitch shifting
//

#ifndef GRAIN_H
#define GRAIN_H

#include <cmath>
#include <cstdint>
#include <cstddef>

namespace Grainulator {

/// Window types for grain envelope
enum class WindowType {
    Hanning,    // Smooth bell curve (default)
    Gaussian,   // Very smooth, narrow peak
    Trapezoid,  // Flat top with linear ramps
    Triangle,   // Simple linear fade
    Tukey,      // Flat center with cosine edges
    Pluck,      // Exponential decay (like plucked string)
    PluckSoft,  // Slower exponential decay
    ExpDecay    // Pure exponential decay (no attack)
};

/// Pre-computed window lookup table
class WindowTable {
public:
    static constexpr size_t kTableSize = 4096;

    WindowTable() {
        // Pre-compute all window types
        ComputeHanning();
        ComputeGaussian();
        ComputeTrapezoid();
        ComputeTriangle();
        ComputeTukey();
        ComputePluck();
        ComputePluckSoft();
        ComputeExpDecay();
    }

    /// Get window value at normalized position (0.0 to 1.0)
    float Get(WindowType type, float position) const {
        // Clamp position
        if (position < 0.0f) position = 0.0f;
        if (position > 1.0f) position = 1.0f;

        // Convert to table index
        float index_f = position * static_cast<float>(kTableSize - 1);
        size_t index = static_cast<size_t>(index_f);
        float frac = index_f - static_cast<float>(index);

        // Get table pointer
        const float* table = GetTable(type);

        // Linear interpolation
        float val1 = table[index];
        float val2 = (index + 1 < kTableSize) ? table[index + 1] : val1;

        return val1 + frac * (val2 - val1);
    }

    static WindowTable& Instance() {
        static WindowTable instance;
        return instance;
    }

private:
    float hanning_[kTableSize];
    float gaussian_[kTableSize];
    float trapezoid_[kTableSize];
    float triangle_[kTableSize];
    float tukey_[kTableSize];
    float pluck_[kTableSize];
    float plucksoft_[kTableSize];
    float expdecay_[kTableSize];

    const float* GetTable(WindowType type) const {
        switch (type) {
            case WindowType::Hanning:   return hanning_;
            case WindowType::Gaussian:  return gaussian_;
            case WindowType::Trapezoid: return trapezoid_;
            case WindowType::Triangle:  return triangle_;
            case WindowType::Tukey:     return tukey_;
            case WindowType::Pluck:     return pluck_;
            case WindowType::PluckSoft: return plucksoft_;
            case WindowType::ExpDecay:  return expdecay_;
            default:                    return hanning_;
        }
    }

    void ComputeHanning() {
        for (size_t i = 0; i < kTableSize; ++i) {
            float x = static_cast<float>(i) / static_cast<float>(kTableSize - 1);
            hanning_[i] = 0.5f * (1.0f - std::cos(2.0f * 3.14159265f * x));
        }
    }

    void ComputeGaussian() {
        // Gaussian with sigma = 0.25 (concentrated in center)
        const float sigma = 0.25f;
        for (size_t i = 0; i < kTableSize; ++i) {
            float x = static_cast<float>(i) / static_cast<float>(kTableSize - 1);
            float centered = x - 0.5f;
            gaussian_[i] = std::exp(-(centered * centered) / (2.0f * sigma * sigma));
        }
    }

    void ComputeTrapezoid() {
        // 10% attack, 80% sustain, 10% release
        const float attack = 0.1f;
        const float release_start = 0.9f;

        for (size_t i = 0; i < kTableSize; ++i) {
            float x = static_cast<float>(i) / static_cast<float>(kTableSize - 1);
            if (x < attack) {
                trapezoid_[i] = x / attack;
            } else if (x > release_start) {
                trapezoid_[i] = (1.0f - x) / (1.0f - release_start);
            } else {
                trapezoid_[i] = 1.0f;
            }
        }
    }

    void ComputeTriangle() {
        for (size_t i = 0; i < kTableSize; ++i) {
            float x = static_cast<float>(i) / static_cast<float>(kTableSize - 1);
            triangle_[i] = 1.0f - std::abs(2.0f * x - 1.0f);
        }
    }

    void ComputeTukey() {
        // Tukey window with alpha = 0.5 (50% cosine taper)
        const float alpha = 0.5f;
        for (size_t i = 0; i < kTableSize; ++i) {
            float x = static_cast<float>(i) / static_cast<float>(kTableSize - 1);
            if (x < alpha / 2.0f) {
                tukey_[i] = 0.5f * (1.0f + std::cos(3.14159265f * (2.0f * x / alpha - 1.0f)));
            } else if (x > 1.0f - alpha / 2.0f) {
                tukey_[i] = 0.5f * (1.0f + std::cos(3.14159265f * (2.0f * x / alpha - 2.0f / alpha + 1.0f)));
            } else {
                tukey_[i] = 1.0f;
            }
        }
    }

    void ComputePluck() {
        // Pluck envelope: brief attack (5%), then exponential decay
        // Like a plucked string - fast initial decay, then slower fadeout
        const float attack = 0.05f;  // 5% attack
        const float decay_rate = 5.0f;  // Fast decay constant

        for (size_t i = 0; i < kTableSize; ++i) {
            float x = static_cast<float>(i) / static_cast<float>(kTableSize - 1);
            if (x < attack) {
                // Quick linear attack to peak
                pluck_[i] = x / attack;
            } else {
                // Exponential decay: e^(-rate * normalized_time)
                // Normalize time so decay starts at 0 after attack
                float decay_x = (x - attack) / (1.0f - attack);
                pluck_[i] = std::exp(-decay_rate * decay_x);
            }
        }
    }

    void ComputePluckSoft() {
        // Softer pluck: longer attack (10%), slower exponential decay
        // More mellow, like a nylon string
        const float attack = 0.10f;  // 10% attack
        const float decay_rate = 3.0f;  // Slower decay constant

        for (size_t i = 0; i < kTableSize; ++i) {
            float x = static_cast<float>(i) / static_cast<float>(kTableSize - 1);
            if (x < attack) {
                // Smooth cosine attack (less abrupt than linear)
                float attack_phase = x / attack;
                plucksoft_[i] = 0.5f * (1.0f - std::cos(3.14159265f * attack_phase));
            } else {
                // Slower exponential decay
                float decay_x = (x - attack) / (1.0f - attack);
                plucksoft_[i] = std::exp(-decay_rate * decay_x);
            }
        }
    }

    void ComputeExpDecay() {
        // Pure exponential decay from the start (no attack)
        // Useful for percussive sounds
        const float decay_rate = 4.0f;

        for (size_t i = 0; i < kTableSize; ++i) {
            float x = static_cast<float>(i) / static_cast<float>(kTableSize - 1);
            // Pure exponential: starts at 1.0, decays to near 0
            expdecay_[i] = std::exp(-decay_rate * x);
        }
    }
};

/// Individual grain state
struct Grain {
    // Playback state
    bool active;                // Is this grain currently playing?
    float position;             // Current read position in source buffer (samples)
    float position_start;       // Starting position in buffer
    float phase;                // Current phase within grain envelope (0.0 to 1.0)

    // Grain parameters
    float duration_samples;     // Total duration of grain in samples
    float speed;                // Playback speed (1.0 = normal, 0.5 = half, 2.0 = double)
    float pitch_ratio;          // Additional pitch shift (1.0 = no shift)
    float amplitude;            // Grain amplitude (0.0 to 1.0)
    float pan;                  // Stereo position (-1.0 = left, 0.0 = center, 1.0 = right)

    // Envelope
    WindowType window_type;
    float decay_rate;           // Decay rate for pluck/decay envelopes (1.0 - 10.0)

    // Source reference
    size_t buffer_index;        // Which reel buffer to read from
    size_t splice_index;        // Which splice within the reel

    Grain()
        : active(false)
        , position(0.0f)
        , position_start(0.0f)
        , phase(0.0f)
        , duration_samples(4800.0f)  // 100ms @ 48kHz
        , speed(1.0f)
        , pitch_ratio(1.0f)
        , amplitude(1.0f)
        , pan(0.0f)
        , window_type(WindowType::Hanning)
        , decay_rate(5.0f)
        , buffer_index(0)
        , splice_index(0)
    {}

    /// Reset grain to initial state
    void Reset() {
        active = false;
        position = 0.0f;
        position_start = 0.0f;
        phase = 0.0f;
    }

    /// Start a new grain
    void Start(float start_position, float duration, float playback_speed, float pitch) {
        active = true;
        position = start_position;
        position_start = start_position;
        phase = 0.0f;
        duration_samples = duration;
        speed = playback_speed;
        pitch_ratio = pitch;
    }

    /// Advance the grain by one sample
    /// Returns true if grain is still active, false if finished
    bool Advance(float sample_rate) {
        if (!active) return false;

        // Advance position by speed * pitch_ratio
        position += speed * pitch_ratio;

        // Advance envelope phase
        float phase_increment = 1.0f / duration_samples;
        phase += phase_increment;

        // Check if grain is complete
        if (phase >= 1.0f) {
            active = false;
            return false;
        }

        return true;
    }

    /// Get the current envelope amplitude
    float GetEnvelopeAmplitude() const {
        float env;

        // For decay-based envelopes, compute on the fly with adjustable decay rate
        switch (window_type) {
            case WindowType::Pluck: {
                // Pluck: brief attack, then exponential decay
                const float attack = 0.05f;
                if (phase < attack) {
                    env = phase / attack;
                } else {
                    float decay_x = (phase - attack) / (1.0f - attack);
                    env = std::exp(-decay_rate * decay_x);
                }
                break;
            }
            case WindowType::PluckSoft: {
                // Softer pluck: longer attack, slower decay
                const float attack = 0.10f;
                if (phase < attack) {
                    float attack_phase = phase / attack;
                    env = 0.5f * (1.0f - std::cos(3.14159265f * attack_phase));
                } else {
                    float decay_x = (phase - attack) / (1.0f - attack);
                    env = std::exp(-decay_rate * 0.6f * decay_x);  // Slower than pluck
                }
                break;
            }
            case WindowType::ExpDecay: {
                // Pure exponential decay
                env = std::exp(-decay_rate * 0.8f * phase);
                break;
            }
            default:
                // Use pre-computed table for non-decay envelopes
                env = WindowTable::Instance().Get(window_type, phase);
                break;
        }

        return env * amplitude;
    }

    /// Get stereo gains (left, right)
    void GetPanGains(float& left, float& right) const {
        // Equal power panning
        float angle = (pan + 1.0f) * 0.25f * 3.14159265f;  // 0 to pi/2
        left = std::cos(angle);
        right = std::sin(angle);
    }
};

} // namespace Grainulator

#endif // GRAIN_H

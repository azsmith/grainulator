//
//  grain_engine.h
//  Grainulator
//
//  Granular/particle synthesis engine inspired by Mutable Instruments Plaits
//  Creates textural sounds from swarms of tiny grains
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Émilie Gillet
//

#ifndef GRAIN_ENGINE_H
#define GRAIN_ENGINE_H

#include <cmath>
#include <algorithm>
#include <cstdlib>

namespace Grainulator {
namespace Engines {

/// Single grain structure
struct Grain {
    float phase;
    float phase_increment;
    float envelope_phase;
    float envelope_increment;
    float pan;
    bool active;

    void Reset() {
        phase = 0.0f;
        phase_increment = 0.0f;
        envelope_phase = 0.0f;
        envelope_increment = 0.0f;
        pan = 0.5f;
        active = false;
    }
};

/// Granular/Particle synthesis engine
/// Creates clouds of short grains for textural sounds
class GrainEngine {
public:
    static constexpr int kMaxGrains = 8;

    GrainEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.5f)
        , timbre_(0.5f)
        , morph_(0.5f)
        , grain_trigger_phase_(0.0f)
    {
        for (int i = 0; i < kMaxGrains; ++i) {
            grains_[i].Reset();
        }
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        grain_trigger_phase_ = 0.0f;

        for (int i = 0; i < kMaxGrains; ++i) {
            grains_[i].Reset();
        }

        // Simple pseudo-random seed
        random_state_ = 12345;
    }

    void SetNote(float note) {
        note_ = note;
    }

    /// Harmonics controls grain density (grains per second)
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// Timbre controls grain duration
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// Morph controls pitch randomization amount
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    void Render(float* out, float* aux, size_t size) {
        // Base frequency
        float base_freq = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);

        // Grain density: 1 to 50 grains per second
        float density = 1.0f + harmonics_ * 49.0f;
        float trigger_rate = density / sample_rate_;

        // Grain duration: 5ms to 200ms
        float grain_duration = 0.005f + timbre_ * 0.195f;
        float envelope_rate = 1.0f / (grain_duration * sample_rate_);

        // Pitch randomization range (in semitones)
        float pitch_random_range = morph_ * 24.0f; // 0 to 2 octaves

        for (size_t i = 0; i < size; ++i) {
            // Check if we should trigger a new grain
            grain_trigger_phase_ += trigger_rate;
            if (grain_trigger_phase_ >= 1.0f) {
                grain_trigger_phase_ -= 1.0f;
                TriggerGrain(base_freq, envelope_rate, pitch_random_range);
            }

            // Render all active grains
            float left = 0.0f;
            float right = 0.0f;

            for (int g = 0; g < kMaxGrains; ++g) {
                if (grains_[g].active) {
                    // Generate grain sample (sine wave)
                    float sample = std::sin(grains_[g].phase * 6.28318530718f);

                    // Apply Hann window envelope
                    float env = HannWindow(grains_[g].envelope_phase);
                    sample *= env;

                    // Pan
                    left += sample * (1.0f - grains_[g].pan);
                    right += sample * grains_[g].pan;

                    // Advance phase
                    grains_[g].phase += grains_[g].phase_increment;
                    if (grains_[g].phase >= 1.0f) grains_[g].phase -= 1.0f;

                    // Advance envelope
                    grains_[g].envelope_phase += grains_[g].envelope_increment;
                    if (grains_[g].envelope_phase >= 1.0f) {
                        grains_[g].active = false;
                    }
                }
            }

            // Normalize and limit
            float scale = 0.4f; // Prevent clipping with many grains
            left = std::tanh(left * scale);
            right = std::tanh(right * scale);

            if (out) {
                out[i] = (left + right) * 0.5f; // Mono mix
            }

            if (aux) {
                aux[i] = (right - left) * 0.5f; // Stereo difference for width
            }
        }
    }

    static const char* GetName() {
        return "Grain";
    }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;

    Grain grains_[kMaxGrains];
    float grain_trigger_phase_;
    uint32_t random_state_;

    void TriggerGrain(float base_freq, float envelope_rate, float pitch_random_range) {
        // Find inactive grain slot
        int slot = -1;
        for (int i = 0; i < kMaxGrains; ++i) {
            if (!grains_[i].active) {
                slot = i;
                break;
            }
        }

        if (slot < 0) return; // All grains active

        // Random pitch offset
        float pitch_offset = (Random() - 0.5f) * pitch_random_range;
        float freq = base_freq * std::pow(2.0f, pitch_offset / 12.0f);
        float normalized_freq = freq / sample_rate_;

        // Random pan position
        float pan = Random();

        // Initialize grain
        grains_[slot].active = true;
        grains_[slot].phase = Random(); // Random start phase
        grains_[slot].phase_increment = normalized_freq;
        grains_[slot].envelope_phase = 0.0f;
        grains_[slot].envelope_increment = envelope_rate;
        grains_[slot].pan = pan;
    }

    /// Hann window for grain envelope
    float HannWindow(float phase) {
        return 0.5f * (1.0f - std::cos(phase * 6.28318530718f));
    }

    /// Simple pseudo-random number generator (0.0 to 1.0)
    float Random() {
        random_state_ = random_state_ * 1103515245 + 12345;
        return static_cast<float>((random_state_ >> 16) & 0x7FFF) / 32767.0f;
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // GRAIN_ENGINE_H

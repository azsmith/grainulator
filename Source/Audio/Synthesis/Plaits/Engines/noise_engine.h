//
//  noise_engine.h
//  Grainulator
//
//  Noise synthesis engine inspired by Mutable Instruments Plaits
//  Filtered noise and particle synthesis
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Émilie Gillet
//

#ifndef NOISE_ENGINE_H
#define NOISE_ENGINE_H

#include <cmath>
#include <algorithm>

namespace Grainulator {
namespace Engines {

/// Noise synthesis engine
/// Creates filtered noise and particle/dust sounds
class NoiseEngine {
public:
    enum Mode {
        FILTERED_NOISE = 0,  // Clocked noise through resonant filter
        PARTICLE_NOISE = 1   // Dust particles through reverb/filter
    };

    NoiseEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.5f)
        , timbre_(0.5f)
        , morph_(0.5f)
        , mode_(FILTERED_NOISE)
        , noise_state_(12345)
        , clock_phase_(0.0f)
        , held_noise_(0.0f)
        , filter_lp_(0.0f)
        , filter_bp_(0.0f)
        , filter_hp_(0.0f)
    {
        // Initialize allpass delays for particle mode
        for (int i = 0; i < 4; ++i) {
            allpass_state_[i] = 0.0f;
        }
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        clock_phase_ = 0.0f;
        held_noise_ = 0.0f;
        filter_lp_ = 0.0f;
        filter_bp_ = 0.0f;
        filter_hp_ = 0.0f;

        for (int i = 0; i < 4; ++i) {
            allpass_state_[i] = 0.0f;
        }
    }

    void SetNote(float note) {
        note_ = note;
    }

    /// HARMONICS: Filter type (Filtered Noise) / Frequency randomization (Particle)
    /// Filtered: LP -> BP -> HP crossfade
    /// Particle: Amount of frequency randomization in particles
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// TIMBRE: Clock rate (Filtered Noise) / Particle density (Particle)
    /// Controls how often new noise samples or particles are generated
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// MORPH: Filter resonance (Filtered) / Processing type (Particle)
    /// Filtered: Resonance amount
    /// Particle: Reverberant tail -> Resonant filter
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    void SetMode(Mode mode) {
        mode_ = mode;
    }

    void Trigger() {
        // Trigger can restart clock or create particle burst
        clock_phase_ = 0.0f;
        particle_burst_ = 1.0f;
    }

    void Render(float* out, float* aux, size_t size) {
        if (mode_ == FILTERED_NOISE) {
            RenderFilteredNoise(out, aux, size);
        } else {
            RenderParticleNoise(out, aux, size);
        }
    }

    static const char* GetName() {
        return "Noise";
    }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;
    Mode mode_;

    uint32_t noise_state_;
    float clock_phase_;
    float held_noise_;

    // SVF filter state
    float filter_lp_;
    float filter_bp_;
    float filter_hp_;

    // Allpass for particle reverb
    float allpass_state_[4];
    float particle_burst_ = 0.0f;

    void RenderFilteredNoise(float* out, float* aux, size_t size) {
        // Clock frequency from timbre (20Hz to 20kHz)
        float clock_freq = 20.0f * std::pow(1000.0f, timbre_);

        // Filter frequency from note
        float filter_freq = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);
        filter_freq = std::min(filter_freq, sample_rate_ * 0.45f);

        // Resonance from morph
        float resonance = 0.5f + morph_ * 0.45f;  // 0.5 to 0.95

        // Filter coefficients (State Variable Filter)
        float f = 2.0f * std::sin(3.14159265f * filter_freq / sample_rate_);
        float q = 1.0f / resonance;

        for (size_t i = 0; i < size; ++i) {
            // Clock for sample & hold
            clock_phase_ += clock_freq / sample_rate_;
            if (clock_phase_ >= 1.0f) {
                clock_phase_ -= 1.0f;
                held_noise_ = GenerateNoise();
            }

            // SVF filter
            filter_lp_ += f * filter_bp_;
            filter_hp_ = held_noise_ - filter_lp_ - q * filter_bp_;
            filter_bp_ += f * filter_hp_;

            // Mix LP/BP/HP based on harmonics
            float sample;
            if (harmonics_ < 0.33f) {
                // Mostly LP
                float blend = harmonics_ * 3.0f;
                sample = filter_lp_ * (1.0f - blend) + filter_bp_ * blend;
            } else if (harmonics_ < 0.66f) {
                // Mostly BP
                float blend = (harmonics_ - 0.33f) * 3.0f;
                sample = filter_bp_ * (1.0f - blend) + filter_hp_ * blend;
            } else {
                // Mostly HP
                sample = filter_hp_;
            }

            sample = std::tanh(sample * 2.0f);

            if (out) {
                out[i] = sample;
            }
            if (aux) {
                // Dual BP for aux (different frequency)
                aux[i] = filter_bp_ * 0.8f;
            }
        }
    }

    void RenderParticleNoise(float* out, float* aux, size_t size) {
        // Particle density from timbre
        float density = 0.0001f + timbre_ * timbre_ * 0.01f;

        // Frequency randomization from harmonics
        float freq_random = harmonics_;

        for (size_t i = 0; i < size; ++i) {
            // Generate particles (dust)
            float particle = 0.0f;
            float random = GenerateNoise();

            // Add burst energy if triggered
            float effective_density = density + particle_burst_ * 0.1f;
            particle_burst_ *= 0.999f;

            if (std::abs(random) > (1.0f - effective_density)) {
                // Particle triggered
                particle = random * 2.0f;

                // Randomize pitch if harmonics is high
                if (freq_random > 0.3f) {
                    particle *= (0.5f + random * random);
                }
            }

            // Process through allpass network (creates reverberant tail)
            float processed = particle;

            // Morph controls filter type: allpass reverb (low) to bandpass (high)
            if (morph_ < 0.5f) {
                // Allpass reverb mode
                float feedback = 0.5f + morph_;
                for (int a = 0; a < 4; ++a) {
                    float delay_time = 0.01f + a * 0.007f;  // 10-38ms delays
                    float input = processed + allpass_state_[a] * feedback;
                    float output = allpass_state_[a] - input * feedback;
                    allpass_state_[a] = input;
                    processed = output;
                }
            } else {
                // Bandpass resonant mode
                float f = 0.05f + (morph_ - 0.5f) * 0.3f;
                filter_lp_ += f * (processed - filter_lp_);
                filter_hp_ = processed - filter_lp_;
                filter_bp_ += f * (filter_hp_ - filter_bp_);
                processed = filter_bp_ * 4.0f;
            }

            float sample = std::tanh(processed);

            if (out) {
                out[i] = sample;
            }
            if (aux) {
                // Raw dust to aux
                aux[i] = particle * 0.5f;
            }
        }
    }

    float GenerateNoise() {
        noise_state_ = noise_state_ * 1664525 + 1013904223;
        return (static_cast<float>(noise_state_) / 2147483648.0f) - 1.0f;
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // NOISE_ENGINE_H

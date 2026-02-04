//
//  harmonic_engine.h
//  Grainulator
//
//  Harmonic/Additive synthesis engine inspired by Mutable Instruments Plaits
//  Generates sounds using 24 harmonics with spectral shaping
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Émilie Gillet
//

#ifndef HARMONIC_ENGINE_H
#define HARMONIC_ENGINE_H

#include <cmath>
#include <algorithm>

namespace Grainulator {
namespace Engines {

/// Harmonic/Additive synthesis engine
/// Creates sounds using up to 24 harmonics with spectral control
class HarmonicEngine {
public:
    static constexpr int kNumHarmonics = 24;

    HarmonicEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.5f)
        , timbre_(0.5f)
        , morph_(0.5f)
    {
        for (int i = 0; i < kNumHarmonics; ++i) {
            phases_[i] = 0.0f;
        }
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        for (int i = 0; i < kNumHarmonics; ++i) {
            phases_[i] = 0.0f;
        }
    }

    void SetNote(float note) {
        note_ = note;
    }

    /// HARMONICS: Number of spectral bumps (1-6)
    /// More bumps = more complex, evolving harmonic content
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// TIMBRE: Spectral centroid position
    /// Which harmonic is most prominent (low = bass, high = treble)
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// MORPH: Bump width
    /// Narrow peaks (resonant) to wide smooth spectrum (organ-like)
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    void Render(float* out, float* aux, size_t size) {
        // Base frequency
        float base_freq = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);

        // Number of bumps in the spectrum (1-6)
        int num_bumps = 1 + static_cast<int>(harmonics_ * 5.0f);

        // Center of the spectral shape (which harmonic is brightest)
        float center = 1.0f + timbre_ * (kNumHarmonics - 2);

        // Width of the spectral bump (narrow to wide)
        float width = 0.5f + morph_ * 4.0f;

        // Calculate harmonic amplitudes
        float amplitudes[kNumHarmonics];
        CalculateSpectrum(amplitudes, num_bumps, center, width);

        for (size_t i = 0; i < size; ++i) {
            float sample = 0.0f;
            float aux_sample = 0.0f;

            for (int h = 0; h < kNumHarmonics; ++h) {
                if (amplitudes[h] < 0.001f) continue;

                float harmonic_freq = base_freq * (h + 1);

                // Skip harmonics above Nyquist
                if (harmonic_freq > sample_rate_ * 0.45f) continue;

                // Update phase
                phases_[h] += harmonic_freq / sample_rate_;
                if (phases_[h] >= 1.0f) phases_[h] -= 1.0f;

                // Sine wave
                float sine = std::sin(phases_[h] * 6.28318530718f);

                sample += sine * amplitudes[h];

                // Odd harmonics to aux for organ-like stereo
                if (h % 2 == 0) {
                    aux_sample += sine * amplitudes[h];
                }
            }

            // Normalize and limit
            sample = std::tanh(sample * 0.5f);
            aux_sample = std::tanh(aux_sample * 0.6f);

            if (out) {
                out[i] = sample;
            }
            if (aux) {
                aux[i] = aux_sample;
            }
        }
    }

    static const char* GetName() {
        return "Harmonic";
    }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;

    float phases_[kNumHarmonics];

    void CalculateSpectrum(float* amplitudes, int num_bumps, float center, float width) {
        // Create a spectrum with multiple bumps
        // Similar to drawing curves with gaussian bumps

        for (int h = 0; h < kNumHarmonics; ++h) {
            float harmonic = static_cast<float>(h + 1);
            float amplitude = 0.0f;

            for (int b = 0; b < num_bumps; ++b) {
                // Position each bump across the spectrum
                float bump_center;
                if (num_bumps == 1) {
                    bump_center = center;
                } else {
                    // Spread bumps across the spectrum
                    float spread = static_cast<float>(b) / (num_bumps - 1);
                    bump_center = 1.0f + spread * (kNumHarmonics - 1);
                    // Shift by timbre
                    bump_center = std::fmod(bump_center + center - 1.0f, static_cast<float>(kNumHarmonics)) + 1.0f;
                }

                // Gaussian bump
                float distance = harmonic - bump_center;
                float gaussian = std::exp(-(distance * distance) / (2.0f * width * width));
                amplitude += gaussian;
            }

            // Natural rolloff for higher harmonics
            float rolloff = 1.0f / (1.0f + harmonic * 0.1f);
            amplitudes[h] = amplitude * rolloff;
        }

        // Normalize
        float max_amp = 0.0f;
        for (int h = 0; h < kNumHarmonics; ++h) {
            if (amplitudes[h] > max_amp) max_amp = amplitudes[h];
        }
        if (max_amp > 0.0f) {
            for (int h = 0; h < kNumHarmonics; ++h) {
                amplitudes[h] /= max_amp;
            }
        }
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // HARMONIC_ENGINE_H

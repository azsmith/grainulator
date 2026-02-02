//
//  waveshaping_engine.h
//  Grainulator
//
//  Waveshaping synthesis engine inspired by Mutable Instruments Plaits
//  Uses waveshaping/distortion to create complex harmonics from simple waves
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Émilie Gillet
//

#ifndef WAVESHAPING_ENGINE_H
#define WAVESHAPING_ENGINE_H

#include "../DSP/oscillator/oscillator.h"
#include <cmath>
#include <algorithm>

namespace Grainulator {
namespace Engines {

/// Waveshaping synthesis engine
/// Creates complex timbres by applying waveshaping functions to simple oscillators
class WaveshapingEngine {
public:
    WaveshapingEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.5f)
        , timbre_(0.5f)
        , morph_(0.5f)
    {
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        oscillator_.Init();
        dc_blocker_.Init();
        lp_filter_.Init();
    }

    void SetNote(float note) {
        note_ = note;
    }

    /// Harmonics controls the waveshaper selection
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// Timbre controls the waveshaping amount/drive
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// Morph blends between triangle and sine source
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    void Render(float* out, float* aux, size_t size) {
        float frequency = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);
        float normalized_freq = std::min(frequency / sample_rate_, 0.45f);

        oscillator_.SetFrequency(normalized_freq);

        // Select waveshaper based on harmonics
        int shaper = static_cast<int>(harmonics_ * 4.99f);

        // Drive amount from timbre
        float drive = 1.0f + timbre_ * 15.0f;

        // Post-filter to reduce harshness
        float filter_coef = 0.3f + (1.0f - timbre_) * 0.6f;
        lp_filter_.SetCoefficient(filter_coef);

        for (size_t i = 0; i < size; ++i) {
            // Source oscillator (morph between triangle and sine)
            float tri = oscillator_.Render(1);  // Triangle
            float sine = std::sin(tri * 1.57079632679f); // Approximate sine from triangle

            float source = tri + morph_ * (sine - tri);

            // Apply waveshaping
            float shaped = ApplyWaveshaper(source * drive, shaper);

            // Remove DC offset
            shaped = dc_blocker_.Process(shaped);

            // Apply low-pass to tame harshness
            shaped = lp_filter_.Process(shaped);

            // Normalize output level
            shaped *= 0.5f;

            if (out) {
                out[i] = shaped;
            }

            if (aux) {
                // Aux: less processed version
                aux[i] = source * 0.7f;
            }
        }
    }

    static const char* GetName() {
        return "Waveshaper";
    }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;

    DSP::PolyBlepOscillator oscillator_;
    DSP::DCBlocker dc_blocker_;
    DSP::OnePole lp_filter_;

    /// Apply selected waveshaping function
    float ApplyWaveshaper(float x, int type) {
        switch (type) {
            case 0: // Soft clip (tanh)
                return std::tanh(x);

            case 1: // Hard clip
                return std::max(-1.0f, std::min(1.0f, x));

            case 2: // Asymmetric (tube-like)
                if (x >= 0.0f) {
                    return std::tanh(x);
                } else {
                    return std::tanh(x * 0.5f);
                }

            case 3: // Foldback distortion
                return Foldback(x);

            case 4: // Chebyshev polynomial (adds specific harmonics)
                return Chebyshev(x);

            default:
                return std::tanh(x);
        }
    }

    /// Foldback distortion - wraps signal back when it exceeds threshold
    float Foldback(float x) {
        while (x > 1.0f || x < -1.0f) {
            if (x > 1.0f) {
                x = 2.0f - x;
            } else if (x < -1.0f) {
                x = -2.0f - x;
            }
        }
        return x;
    }

    /// Chebyshev polynomial - adds specific harmonics
    float Chebyshev(float x) {
        // Mix of T3, T5, T7 Chebyshev polynomials
        float x2 = x * x;
        float x3 = x2 * x;
        float x5 = x3 * x2;
        float x7 = x5 * x2;

        // T3(x) = 4x³ - 3x
        // T5(x) = 16x⁵ - 20x³ + 5x
        // T7(x) = 64x⁷ - 112x⁵ + 56x³ - 7x

        float t3 = 4.0f * x3 - 3.0f * x;
        float t5 = 16.0f * x5 - 20.0f * x3 + 5.0f * x;

        return std::tanh(x + 0.3f * t3 + 0.1f * t5);
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // WAVESHAPING_ENGINE_H

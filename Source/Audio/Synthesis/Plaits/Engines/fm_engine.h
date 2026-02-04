//
//  fm_engine.h
//  Grainulator
//
//  2-operator FM synthesis engine inspired by Mutable Instruments Plaits
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Émilie Gillet
//

#ifndef FM_ENGINE_H
#define FM_ENGINE_H

#include <cmath>
#include <algorithm>

namespace Grainulator {
namespace Engines {

/// 2-operator FM synthesis engine
/// Produces a wide range of timbres from bells to brass to woodwinds
class FMEngine {
public:
    FMEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.5f)
        , timbre_(0.5f)
        , morph_(0.5f)
        , carrier_phase_(0.0f)
        , modulator_phase_(0.0f)
    {
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        carrier_phase_ = 0.0f;
        modulator_phase_ = 0.0f;
    }

    /// Set the MIDI note (0-127, fractional allowed)
    void SetNote(float note) {
        note_ = note;
    }

    /// HARMONICS: Modulator/carrier frequency ratio
    /// Selects common FM ratios (0.5, 1, 2, 3, 4, 5, 6, 7, 8)
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// TIMBRE: FM modulation index (depth)
    /// Low = subtle harmonics, High = rich/harsh timbres
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// MORPH: Feedback amount
    /// Adds feedback to modulator for more complex, noisy timbres
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    /// Render audio samples
    void Render(float* out, float* aux, size_t size) {
        // Convert MIDI note to frequency
        float carrier_freq = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);
        float carrier_inc = carrier_freq / sample_rate_;

        // Calculate modulator frequency ratio from harmonics
        // Map 0-1 to common FM ratios: 0.5, 1, 2, 3, 4, 5, 6, 7, 8
        float ratio = GetRatio(harmonics_);
        float modulator_inc = carrier_inc * ratio;

        // Modulation index from timbre (0 to 8)
        float mod_index = timbre_ * 8.0f;

        // Feedback amount from morph
        float feedback = morph_ * morph_ * 1.5f; // Quadratic for smoother response

        const float two_pi = 2.0f * 3.14159265358979323846f;

        for (size_t i = 0; i < size; ++i) {
            // Calculate feedback from previous carrier sample
            float fb = feedback * previous_sample_;

            // Modulator oscillator with feedback
            float modulator = std::sin(two_pi * modulator_phase_ + fb);

            // Apply modulation to carrier phase
            float modulated_phase = carrier_phase_ + mod_index * modulator / two_pi;

            // Carrier oscillator
            float carrier = std::sin(two_pi * modulated_phase);

            // Store for feedback
            previous_sample_ = carrier;

            // Output
            if (out) {
                out[i] = carrier * 0.8f; // Slight level reduction
            }

            // Aux output: modulator signal for variety
            if (aux) {
                aux[i] = modulator * 0.5f;
            }

            // Advance phases
            carrier_phase_ += carrier_inc;
            if (carrier_phase_ >= 1.0f) carrier_phase_ -= 1.0f;

            modulator_phase_ += modulator_inc;
            if (modulator_phase_ >= 1.0f) modulator_phase_ -= 1.0f;
        }
    }

    static const char* GetName() {
        return "FM";
    }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;

    float carrier_phase_;
    float modulator_phase_;
    float previous_sample_ = 0.0f;

    /// Map harmonics parameter to common FM frequency ratios
    float GetRatio(float harmonics) {
        // Common FM ratios mapped to 0-1 range
        // These ratios produce musically useful timbres
        const float ratios[] = {
            0.5f,   // Sub-harmonic (bell-like)
            1.0f,   // Unison (warm)
            2.0f,   // Octave (bright)
            3.0f,   // Fifth above octave (brass-like)
            4.0f,   // Two octaves (electric piano)
            5.0f,   // Major third above two octaves (woodwind)
            6.0f,   // Fifth above two octaves (metallic)
            7.0f,   // Minor seventh (inharmonic)
            8.0f    // Three octaves (bell)
        };

        const int num_ratios = sizeof(ratios) / sizeof(ratios[0]);

        // Interpolate between ratios
        float index = harmonics * (num_ratios - 1);
        int index_int = static_cast<int>(index);
        float frac = index - index_int;

        if (index_int >= num_ratios - 1) {
            return ratios[num_ratios - 1];
        }

        return ratios[index_int] + frac * (ratios[index_int + 1] - ratios[index_int]);
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // FM_ENGINE_H

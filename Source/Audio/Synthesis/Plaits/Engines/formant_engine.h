//
//  formant_engine.h
//  Grainulator
//
//  Formant/VOSIM synthesis engine inspired by Mutable Instruments Plaits
//  Creates formant-rich sounds using VOSIM, Pulsar, and CZ-style synthesis
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Émilie Gillet
//

#ifndef FORMANT_ENGINE_H
#define FORMANT_ENGINE_H

#include <cmath>
#include <algorithm>

namespace Grainulator {
namespace Engines {

/// Formant/VOSIM synthesis engine
/// Creates vowel-like sounds using sync'd waveforms
class FormantEngine {
public:
    FormantEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.5f)
        , timbre_(0.5f)
        , morph_(0.5f)
        , carrier_phase_(0.0f)
        , formant_phase_(0.0f)
    {
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        carrier_phase_ = 0.0f;
        formant_phase_ = 0.0f;
    }

    void SetNote(float note) {
        note_ = note;
    }

    /// HARMONICS: Ratio between formant 1 and formant 2
    /// Controls the interval/relationship between the two formant peaks
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// TIMBRE: Formant frequency
    /// Controls the absolute position of the formant (brightness/vowel character)
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// MORPH: Formant width
    /// Narrow formant (few pulses) to wide spectrum (many pulses)
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    void Render(float* out, float* aux, size_t size) {
        // Carrier frequency (fundamental)
        float carrier_freq = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);

        // Formant frequency - timbre controls the formant position
        // Range from 200Hz to 4000Hz for vocal range
        float formant_freq = 200.0f + timbre_ * timbre_ * 3800.0f;

        // Second formant ratio based on harmonics
        float formant2_ratio = 1.5f + harmonics_ * 2.0f;

        // Number of pulses in the formant (controlled by morph)
        // Low morph = many pulses (narrow formant), high morph = few pulses (wide)
        int num_pulses = 1 + static_cast<int>((1.0f - morph_) * 6.0f);

        // Phase increments
        float carrier_inc = carrier_freq / sample_rate_;
        float formant_inc = formant_freq / sample_rate_;

        for (size_t i = 0; i < size; ++i) {
            // Advance carrier (resets formant on each cycle)
            carrier_phase_ += carrier_inc;
            if (carrier_phase_ >= 1.0f) {
                carrier_phase_ -= 1.0f;
                formant_phase_ = 0.0f;  // Hard sync
            }

            // Advance formant
            formant_phase_ += formant_inc;

            // VOSIM: sum of squared sines
            float sample = 0.0f;

            // Window based on carrier phase (decaying over carrier period)
            float window = 1.0f - carrier_phase_;
            window = window * window;  // Quadratic decay

            // Only generate sound in first part of carrier cycle
            if (carrier_phase_ < (0.3f + morph_ * 0.5f)) {
                // First formant
                for (int p = 0; p < num_pulses; ++p) {
                    float pulse_phase = formant_phase_ * (p + 1);
                    if (pulse_phase < 1.0f) {
                        float sine = std::sin(pulse_phase * 3.14159265f);
                        sample += sine * sine;
                    }
                }

                // Second formant (creates vowel character)
                if (harmonics_ > 0.2f) {
                    float formant2_phase = formant_phase_ * formant2_ratio;
                    for (int p = 0; p < num_pulses / 2 + 1; ++p) {
                        float pulse_phase = formant2_phase * (p + 1);
                        if (pulse_phase < 1.0f) {
                            float sine = std::sin(pulse_phase * 3.14159265f);
                            sample += sine * sine * harmonics_ * 0.5f;
                        }
                    }
                }

                sample *= window;
            }

            // Normalize
            sample = sample / (num_pulses + 1);

            // DC offset removal and limiting
            sample = std::tanh(sample * 2.0f - 0.5f);

            if (out) {
                out[i] = sample;
            }
            if (aux) {
                // CZ-style resonant waveform for aux
                float cz = std::sin(carrier_phase_ * 6.28318530718f * (1.0f + formant_phase_ * timbre_ * 4.0f));
                aux[i] = cz * (1.0f - carrier_phase_) * 0.7f;
            }
        }
    }

    static const char* GetName() {
        return "Formant";
    }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;

    float carrier_phase_;
    float formant_phase_;
};

} // namespace Engines
} // namespace Grainulator

#endif // FORMANT_ENGINE_H

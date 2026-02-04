//
//  virtual_analog_engine.h
//  Grainulator
//
//  Virtual Analog synthesis engine inspired by Mutable Instruments Plaits
//  Implements classic analog waveforms with modern band-limiting
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Émilie Gillet
//
//  REAL PLAITS PARAMETER MAPPING:
//  - HARMONICS: Detuning between the two oscillators
//  - TIMBRE: Variable square - narrow pulse to full square to hardsync formants
//  - MORPH: Variable saw - triangle to saw with increasingly wide notch
//

#ifndef VIRTUAL_ANALOG_ENGINE_H
#define VIRTUAL_ANALOG_ENGINE_H

#include "../DSP/oscillator/oscillator.h"
#include <cmath>
#include <algorithm>

namespace Grainulator {
namespace Engines {

class VirtualAnalogEngine {
public:
    VirtualAnalogEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.5f)
        , timbre_(0.5f)
        , morph_(0.5f)
        , phase1_(0.0f)
        , phase2_(0.0f)
    {
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        phase1_ = 0.0f;
        phase2_ = 0.0f;
    }

    void SetNote(float note) {
        note_ = note;
    }

    /// HARMONICS: Detuning between the two oscillators
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// TIMBRE: Variable square - pulse width from narrow to wide
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// MORPH: Variable saw - triangle to saw with notch
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    void Render(float* out, float* aux, size_t size) {
        float frequency = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);
        float base_inc = frequency / sample_rate_;

        // HARMONICS controls detuning between oscillators
        // 0 = unison, 0.5 = slight detune, 1 = major detuning (up to a 5th)
        float detune_amount = harmonics_ * harmonics_ * 0.5f;  // Up to 50% = ~7 semitones
        float inc1 = base_inc;
        float inc2 = base_inc * (1.0f + detune_amount);

        // TIMBRE controls pulse width for the square component
        // 0 = very narrow pulse, 0.5 = 50% duty cycle, 1 = wide pulse / sync-like
        float pulse_width = 0.05f + timbre_ * 0.9f;  // 5% to 95%

        // MORPH controls the variable saw shape
        // 0 = triangle, 0.5 = saw, 1 = saw with notch (more harmonics)
        float saw_shape = morph_;

        for (size_t i = 0; i < size; ++i) {
            // Advance phases
            phase1_ += inc1;
            phase2_ += inc2;
            if (phase1_ >= 1.0f) phase1_ -= 1.0f;
            if (phase2_ >= 1.0f) phase2_ -= 1.0f;

            // ===== TIMBRE: Variable Square =====
            // Pulse wave with variable width
            float square1 = (phase1_ < pulse_width) ? 1.0f : -1.0f;
            float square2 = (phase2_ < pulse_width) ? 1.0f : -1.0f;

            // Apply PolyBLEP for anti-aliasing
            square1 -= PolyBlep(phase1_, inc1);
            square1 += PolyBlep(std::fmod(phase1_ + (1.0f - pulse_width), 1.0f), inc1);
            square2 -= PolyBlep(phase2_, inc2);
            square2 += PolyBlep(std::fmod(phase2_ + (1.0f - pulse_width), 1.0f), inc2);

            // ===== MORPH: Variable Saw =====
            float saw1, saw2;
            if (saw_shape < 0.5f) {
                // Triangle to Saw (0 = triangle, 0.5 = saw)
                float tri1 = (phase1_ < 0.5f) ? (4.0f * phase1_ - 1.0f) : (3.0f - 4.0f * phase1_);
                float raw_saw1 = 2.0f * phase1_ - 1.0f;
                saw1 = tri1 * (1.0f - saw_shape * 2.0f) + raw_saw1 * (saw_shape * 2.0f);

                float tri2 = (phase2_ < 0.5f) ? (4.0f * phase2_ - 1.0f) : (3.0f - 4.0f * phase2_);
                float raw_saw2 = 2.0f * phase2_ - 1.0f;
                saw2 = tri2 * (1.0f - saw_shape * 2.0f) + raw_saw2 * (saw_shape * 2.0f);
            } else {
                // Saw with increasing notch (0.5 = saw, 1 = saw with deep notch)
                float notch_depth = (saw_shape - 0.5f) * 2.0f;
                float notch_pos = 0.5f;

                float raw_saw1 = 2.0f * phase1_ - 1.0f;
                float notch1 = 1.0f - notch_depth * std::exp(-50.0f * (phase1_ - notch_pos) * (phase1_ - notch_pos));
                saw1 = raw_saw1 * notch1;

                float raw_saw2 = 2.0f * phase2_ - 1.0f;
                float notch2 = 1.0f - notch_depth * std::exp(-50.0f * (phase2_ - notch_pos) * (phase2_ - notch_pos));
                saw2 = raw_saw2 * notch2;
            }

            // Apply PolyBLEP to saw
            saw1 -= PolyBlep(phase1_, inc1);
            saw2 -= PolyBlep(phase2_, inc2);

            // Mix the two waveform types (square and saw)
            // Main out: mixed, Aux: hardsync'd version
            float osc1 = square1 * 0.5f + saw1 * 0.5f;
            float osc2 = square2 * 0.5f + saw2 * 0.5f;

            // Combine two oscillators
            float sample = (osc1 + osc2) * 0.5f;

            // Soft limit
            sample = std::tanh(sample * 1.2f);

            if (out) {
                out[i] = sample;
            }

            // AUX: Sum of hardsync'd waveforms (more aggressive)
            if (aux) {
                float sync_sample = square1 * square2 * 0.5f + saw1 * saw2 * 0.5f;
                aux[i] = std::tanh(sync_sample);
            }
        }
    }

    static const char* GetName() {
        return "Virtual Analog";
    }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;

    float phase1_;
    float phase2_;

    float PolyBlep(float t, float dt) {
        if (t < dt) {
            t /= dt;
            return t + t - t * t - 1.0f;
        } else if (t > 1.0f - dt) {
            t = (t - 1.0f) / dt;
            return t * t + t + t + 1.0f;
        }
        return 0.0f;
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // VIRTUAL_ANALOG_ENGINE_H

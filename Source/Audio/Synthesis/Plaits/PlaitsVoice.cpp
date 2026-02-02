//
//  PlaitsVoice.cpp
//  Grainulator
//
//  Plaits synthesis voice wrapper implementation
//  Based on Mutable Instruments Plaits (MIT License)
//  Copyright 2016 Émilie Gillet
//

#include "PlaitsVoice.h"
#include <cstring>
#include <cmath>
#include <algorithm>

namespace Grainulator {

PlaitsVoice::PlaitsVoice()
    : sample_rate_(48000.0f)
    , current_engine_(0)
    , note_(60.0f)
    , harmonics_(0.5f)
    , timbre_(0.5f)
    , morph_(0.5f)
    , level_(0.8f)
    , trigger_state_(false)
    , harmonics_mod_amount_(0.0f)
    , timbre_mod_amount_(0.0f)
    , morph_mod_amount_(0.0f)
    , lpg_color_(0.5f)
    , lpg_decay_(0.5f)
{
}

PlaitsVoice::~PlaitsVoice() {
}

void PlaitsVoice::Init(float sample_rate) {
    sample_rate_ = sample_rate;

    // TODO: Initialize actual Plaits voice
    // voice_.Init();

    // Reset parameters
    current_engine_ = 0;
    note_ = 60.0f;
    harmonics_ = 0.5f;
    timbre_ = 0.5f;
    morph_ = 0.5f;
    level_ = 0.8f;
    trigger_state_ = false;
}

void PlaitsVoice::Render(float* out, float* aux, size_t size) {
    // TODO: This is a placeholder implementation using simple synthesis
    // Real implementation will call plaits::Voice::Render()

    // Calculate frequency from MIDI note
    float frequency = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);
    float phase_increment = frequency / sample_rate_;

    // Simple envelope (decay based on trigger state)
    static float envelope = 0.0f;
    static float phase = 0.0f;
    static float prev_trigger = false;

    // Trigger detection
    bool trigger_edge = trigger_state_ && !prev_trigger;
    prev_trigger = trigger_state_;

    for (size_t i = 0; i < size; ++i) {
        // Simple envelope with attack/release
        if (trigger_edge && i == 0) {
            envelope = 1.0f;
        }

        // Decay envelope
        float decay_rate = 0.9995f; // Adjust for longer/shorter decay
        envelope *= decay_rate;

        // Generate waveform based on engine selection
        float sample = 0.0f;

        switch (current_engine_ % 4) {
            case 0: // Sine wave
                sample = std::sin(phase * 2.0f * M_PI);
                break;
            case 1: // Saw wave
                sample = (phase * 2.0f) - 1.0f;
                break;
            case 2: // Square wave (PWM based on morph)
                sample = (phase < (0.5f + morph_ * 0.45f)) ? 1.0f : -1.0f;
                break;
            case 3: // Triangle wave
                sample = (phase < 0.5f)
                    ? (phase * 4.0f - 1.0f)
                    : (3.0f - phase * 4.0f);
                break;
        }

        // Apply harmonics (simple low-pass filtering effect)
        static float filtered = 0.0f;
        float cutoff = 0.1f + harmonics_ * 0.89f;
        filtered += cutoff * (sample - filtered);
        sample = filtered;

        // Apply timbre (waveshaping)
        float drive = 1.0f + timbre_ * 4.0f;
        sample = std::tanh(sample * drive) / std::tanh(drive);

        // Apply envelope and level
        sample *= envelope * level_ * 0.3f;

        if (out) {
            out[i] = sample;
        }
        if (aux) {
            // Aux output with different character (softer)
            aux[i] = sample * 0.7f;
        }

        // Advance phase
        // Apply slight FM based on morph parameter for interest
        float fm_amount = morph_ * 0.1f;
        phase += phase_increment * (1.0f + fm_amount * std::sin(phase * 8.0f * M_PI));

        while (phase >= 1.0f) {
            phase -= 1.0f;
        }
    }
}

void PlaitsVoice::SetEngine(int engine) {
    // Clamp to valid range (0-15 for 16 engines)
    current_engine_ = std::max(0, std::min(15, engine));

    // TODO: Actual engine switching
    // voice_.set_engine(current_engine_);
}

void PlaitsVoice::SetNote(float note) {
    note_ = std::max(0.0f, std::min(127.0f, note));
}

void PlaitsVoice::SetHarmonics(float value) {
    harmonics_ = std::max(0.0f, std::min(1.0f, value));
}

void PlaitsVoice::SetTimbre(float value) {
    timbre_ = std::max(0.0f, std::min(1.0f, value));
}

void PlaitsVoice::SetMorph(float value) {
    morph_ = std::max(0.0f, std::min(1.0f, value));
}

void PlaitsVoice::Trigger(bool state) {
    trigger_state_ = state;
}

void PlaitsVoice::SetLevel(float value) {
    level_ = std::max(0.0f, std::min(1.0f, value));
}

void PlaitsVoice::SetHarmonicsModAmount(float amount) {
    harmonics_mod_amount_ = std::max(0.0f, std::min(1.0f, amount));
}

void PlaitsVoice::SetTimbreModAmount(float amount) {
    timbre_mod_amount_ = std::max(0.0f, std::min(1.0f, amount));
}

void PlaitsVoice::SetMorphModAmount(float amount) {
    morph_mod_amount_ = std::max(0.0f, std::min(1.0f, amount));
}

void PlaitsVoice::SetLPGColor(float color) {
    lpg_color_ = std::max(0.0f, std::min(1.0f, color));
}

void PlaitsVoice::SetLPGDecay(float decay) {
    lpg_decay_ = std::max(0.0f, std::min(1.0f, decay));
}

} // namespace Grainulator

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
    // TODO: This is a placeholder implementation
    // Real implementation will call plaits::Voice::Render()

    // For now, generate a simple test tone (sine wave at note frequency)
    static float phase = 0.0f;
    float frequency = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);
    float phase_increment = frequency / sample_rate_;

    for (size_t i = 0; i < size; ++i) {
        float sample = std::sin(phase * 2.0f * M_PI) * level_ * 0.3f;

        if (out) {
            out[i] = sample;
        }
        if (aux) {
            aux[i] = sample * 0.5f; // Quieter on aux
        }

        phase += phase_increment;
        if (phase >= 1.0f) {
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

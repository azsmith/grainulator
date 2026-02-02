//
//  PlaitsVoice.cpp
//  Grainulator
//
//  Plaits synthesis voice wrapper implementation
//  Based on Mutable Instruments Plaits (MIT License)
//  Copyright 2016 Émilie Gillet
//

#include "PlaitsVoice.h"
#include "Engines/virtual_analog_engine.h"
#include "Engines/fm_engine.h"
#include "Engines/waveshaping_engine.h"
#include "Engines/grain_engine.h"
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
    , envelope_(0.0f)
    , prev_trigger_(false)
{
    // Allocate engines
    va_engine_ = new Engines::VirtualAnalogEngine();
    fm_engine_ = new Engines::FMEngine();
    ws_engine_ = new Engines::WaveshapingEngine();
    grain_engine_ = new Engines::GrainEngine();
}

PlaitsVoice::~PlaitsVoice() {
    delete static_cast<Engines::VirtualAnalogEngine*>(va_engine_);
    delete static_cast<Engines::FMEngine*>(fm_engine_);
    delete static_cast<Engines::WaveshapingEngine*>(ws_engine_);
    delete static_cast<Engines::GrainEngine*>(grain_engine_);
}

void PlaitsVoice::Init(float sample_rate) {
    sample_rate_ = sample_rate;

    // Initialize all engines
    static_cast<Engines::VirtualAnalogEngine*>(va_engine_)->Init(sample_rate);
    static_cast<Engines::FMEngine*>(fm_engine_)->Init(sample_rate);
    static_cast<Engines::WaveshapingEngine*>(ws_engine_)->Init(sample_rate);
    static_cast<Engines::GrainEngine*>(grain_engine_)->Init(sample_rate);

    // Reset parameters
    current_engine_ = 0;
    note_ = 60.0f;
    harmonics_ = 0.5f;
    timbre_ = 0.5f;
    morph_ = 0.5f;
    level_ = 0.8f;
    trigger_state_ = false;
    envelope_ = 0.0f;
    prev_trigger_ = false;
}

void PlaitsVoice::Render(float* out, float* aux, size_t size) {
    // Trigger detection for envelope
    bool trigger_edge = trigger_state_ && !prev_trigger_;
    prev_trigger_ = trigger_state_;

    // Create temporary buffers for engine output
    float temp_out[256];
    float temp_aux[256];

    // Process in chunks if needed
    size_t remaining = size;
    size_t offset = 0;

    while (remaining > 0) {
        size_t chunk = std::min(remaining, size_t(256));

        // Render from current engine
        RenderEngine(temp_out, temp_aux, chunk);

        // Apply envelope and level
        float attack_rate = 0.001f;  // Fast attack
        float decay_rate = 0.9997f;  // Adjustable decay based on lpg_decay_

        // Map lpg_decay to decay rate
        float decay = 0.9990f + lpg_decay_ * 0.0009f;

        for (size_t i = 0; i < chunk; ++i) {
            // Envelope processing
            if (trigger_edge && i == 0) {
                envelope_ = 1.0f;
            }

            // Decay envelope (unless gate is held and we're in sustain mode)
            if (!trigger_state_ || envelope_ > 0.99f) {
                envelope_ *= decay;
            }

            // Apply LPG-style filtering based on envelope
            // lpg_color: 0 = pure VCA, 1 = VCA + filter
            float lpg_amount = lpg_color_;
            float filter_env = 0.1f + envelope_ * 0.9f;

            // Simple one-pole lowpass as LPG
            static float lpg_state = 0.0f;
            float cutoff = lpg_amount * filter_env + (1.0f - lpg_amount);
            lpg_state += cutoff * (temp_out[i] - lpg_state);
            float filtered = lpg_state;

            // Mix between filtered and dry based on lpg_color
            float sample = temp_out[i] * (1.0f - lpg_amount * 0.5f) + filtered * lpg_amount * 0.5f;

            // Apply envelope and level
            sample *= envelope_ * level_;

            // Soft limiting
            sample = std::tanh(sample * 1.5f) * 0.67f;

            if (out) {
                out[offset + i] = sample;
            }

            // Aux output
            if (aux) {
                float aux_sample = temp_aux[i] * envelope_ * level_ * 0.7f;
                aux[offset + i] = std::tanh(aux_sample);
            }
        }

        remaining -= chunk;
        offset += chunk;
    }
}

void PlaitsVoice::RenderEngine(float* out, float* aux, size_t size) {
    // Update engine parameters
    switch (current_engine_) {
        case 0: // Virtual Analog
        case 1:
        case 2:
        case 3: {
            auto* va = static_cast<Engines::VirtualAnalogEngine*>(va_engine_);
            va->SetNote(note_);
            va->SetHarmonics(harmonics_);
            va->SetTimbre(timbre_);
            va->SetMorph(morph_);
            va->Render(out, aux, size);
            break;
        }

        case 4: // FM
        case 5: {
            auto* fm = static_cast<Engines::FMEngine*>(fm_engine_);
            fm->SetNote(note_);
            fm->SetHarmonics(harmonics_);
            fm->SetTimbre(timbre_);
            fm->SetMorph(morph_);
            fm->Render(out, aux, size);
            break;
        }

        case 6: // Waveshaping
        case 7: {
            auto* ws = static_cast<Engines::WaveshapingEngine*>(ws_engine_);
            ws->SetNote(note_);
            ws->SetHarmonics(harmonics_);
            ws->SetTimbre(timbre_);
            ws->SetMorph(morph_);
            ws->Render(out, aux, size);
            break;
        }

        case 8:  // Grain
        case 9:
        case 10:
        case 11: {
            auto* grain = static_cast<Engines::GrainEngine*>(grain_engine_);
            grain->SetNote(note_);
            grain->SetHarmonics(harmonics_);
            grain->SetTimbre(timbre_);
            grain->SetMorph(morph_);
            grain->Render(out, aux, size);
            break;
        }

        default: {
            // Fallback to Virtual Analog
            auto* va = static_cast<Engines::VirtualAnalogEngine*>(va_engine_);
            va->SetNote(note_);
            va->SetHarmonics(harmonics_);
            va->SetTimbre(timbre_);
            va->SetMorph(morph_);
            va->Render(out, aux, size);
            break;
        }
    }
}

void PlaitsVoice::SetEngine(int engine) {
    // Clamp to valid range (0-15 for 16 engines)
    current_engine_ = std::max(0, std::min(15, engine));
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

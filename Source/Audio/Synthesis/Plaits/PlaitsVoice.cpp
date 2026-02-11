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
#include "Engines/waveshaping_engine.h"
#include "Engines/fm_engine.h"
#include "Engines/formant_engine.h"
#include "Engines/harmonic_engine.h"
#include "Engines/wavetable_engine.h"
#include "Engines/chord_engine.h"
#include "Engines/speech_engine.h"
#include "Engines/grain_engine.h"
#include "Engines/noise_engine.h"
#include "Engines/string_engine.h"
#include "Engines/percussion_engine.h"
#include "Engines/sixop_fm_engine.h"
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
    , lpg_attack_(0.0f)
    , lpg_bypass_(false)
    , envelope_(0.0f)
    , envelope_target_(0.0f)
    , prev_trigger_(false)
    , trigger_count_(0)
    , lpg_filter_state_(0.0f)
    , previous_engine_(-1)
    , crossfade_position_(1.0f)
    , crossfade_increment_(0.0f)
{
    // Allocate engines
    va_engine_ = new Engines::VirtualAnalogEngine();
    ws_engine_ = new Engines::WaveshapingEngine();
    fm_engine_ = new Engines::FMEngine();
    formant_engine_ = new Engines::FormantEngine();
    harmonic_engine_ = new Engines::HarmonicEngine();
    wavetable_engine_ = new Engines::WavetableEngine();
    chord_engine_ = new Engines::ChordEngine();
    speech_engine_ = new Engines::SpeechEngine();
    grain_engine_ = new Engines::GrainEngine();
    noise_engine_ = new Engines::NoiseEngine();
    string_engine_ = new Engines::StringEngine();
    percussion_engine_ = new Engines::PercussionEngine();
    sixop_fm_engine_ = new Engines::SixOpFMEngine();
}

PlaitsVoice::~PlaitsVoice() {
    delete static_cast<Engines::VirtualAnalogEngine*>(va_engine_);
    delete static_cast<Engines::WaveshapingEngine*>(ws_engine_);
    delete static_cast<Engines::FMEngine*>(fm_engine_);
    delete static_cast<Engines::FormantEngine*>(formant_engine_);
    delete static_cast<Engines::HarmonicEngine*>(harmonic_engine_);
    delete static_cast<Engines::WavetableEngine*>(wavetable_engine_);
    delete static_cast<Engines::ChordEngine*>(chord_engine_);
    delete static_cast<Engines::SpeechEngine*>(speech_engine_);
    delete static_cast<Engines::GrainEngine*>(grain_engine_);
    delete static_cast<Engines::NoiseEngine*>(noise_engine_);
    delete static_cast<Engines::StringEngine*>(string_engine_);
    delete static_cast<Engines::PercussionEngine*>(percussion_engine_);
    delete static_cast<Engines::SixOpFMEngine*>(sixop_fm_engine_);
}

void PlaitsVoice::Init(float sample_rate) {
    sample_rate_ = sample_rate;

    // Initialize all engines
    static_cast<Engines::VirtualAnalogEngine*>(va_engine_)->Init(sample_rate);
    static_cast<Engines::WaveshapingEngine*>(ws_engine_)->Init(sample_rate);
    static_cast<Engines::FMEngine*>(fm_engine_)->Init(sample_rate);
    static_cast<Engines::FormantEngine*>(formant_engine_)->Init(sample_rate);
    static_cast<Engines::HarmonicEngine*>(harmonic_engine_)->Init(sample_rate);
    static_cast<Engines::WavetableEngine*>(wavetable_engine_)->Init(sample_rate);
    static_cast<Engines::ChordEngine*>(chord_engine_)->Init(sample_rate);
    static_cast<Engines::SpeechEngine*>(speech_engine_)->Init(sample_rate);
    static_cast<Engines::GrainEngine*>(grain_engine_)->Init(sample_rate);
    static_cast<Engines::NoiseEngine*>(noise_engine_)->Init(sample_rate);
    static_cast<Engines::StringEngine*>(string_engine_)->Init(sample_rate);
    static_cast<Engines::PercussionEngine*>(percussion_engine_)->Init(sample_rate);
    static_cast<Engines::SixOpFMEngine*>(sixop_fm_engine_)->Init(sample_rate);

    // Reset parameters
    current_engine_ = 0;
    note_ = 60.0f;
    harmonics_ = 0.5f;
    timbre_ = 0.5f;
    morph_ = 0.5f;
    level_ = 0.8f;
    trigger_state_ = false;
    envelope_ = 0.0f;
    envelope_target_ = 0.0f;
    prev_trigger_ = false;
    trigger_count_ = 0;
    lpg_filter_state_ = 0.0f;
    previous_engine_ = -1;
    crossfade_position_ = 1.0f;
    crossfade_increment_ = 0.0f;
}

void PlaitsVoice::Render(float* out, float* aux, size_t size) {
    // =========================================================================
    // PLAITS TRIGGER BEHAVIOR
    // =========================================================================
    // In real Plaits, the TRIG input is a trigger pulse (not a sustaining gate).
    // When triggered:
    //   - Engines 0-10: LPG envelope is struck and decays based on DECAY setting
    //   - Engines 11-15: Engine's internal exciter is triggered, LPG bypassed
    // The gate length (how long key is held) does NOT affect the sound!
    // =========================================================================

    // Detect trigger - check if any triggers are pending (handles fast repeated notes)
    bool should_trigger = trigger_count_ > 0;
    if (trigger_count_ > 0) {
        trigger_count_ = 0;  // Clear all pending triggers (we'll process one now)
    }
    prev_trigger_ = trigger_state_;

    // Check if this is a triggered/percussive engine (11-15)
    // These engines have their own internal envelopes and bypass the LPG
    bool is_triggered_engine = IsTriggeredEngine();

    // Trigger the appropriate engine on note-on
    if (should_trigger) {
        if (current_engine_ == 8) {
            // Engine 8: Granular Cloud
            auto* grain = static_cast<Engines::GrainEngine*>(grain_engine_);
            grain->Trigger();
        } else if (current_engine_ == 9 || current_engine_ == 10) {
            // Engines 9-10: Filtered Noise / Particle Noise
            auto* noise = static_cast<Engines::NoiseEngine*>(noise_engine_);
            noise->Trigger();
        } else if (current_engine_ == 11 || current_engine_ == 12) {
            // Engines 11-12: String/Modal physical models
            auto* string = static_cast<Engines::StringEngine*>(string_engine_);
            string->Trigger();
        } else if (current_engine_ >= 13 && current_engine_ <= 15) {
            // Engines 13-15: Percussion (kick, snare, hihat)
            auto* perc = static_cast<Engines::PercussionEngine*>(percussion_engine_);
            perc->Trigger();
        }

        // For ALL engines, strike the LPG envelope on trigger
        // (though it's bypassed for engines 11-15)
        envelope_ = 0.0f;
        envelope_target_ = 1.0f;
    }

    // Create temporary buffers for engine output (zero-initialized)
    float temp_out[256] = {0};
    float temp_aux[256] = {0};

    // Crossfade buffers (only used during engine transition)
    float xfade_out[256] = {0};
    float xfade_aux[256] = {0};
    bool is_crossfading = (previous_engine_ >= 0 && crossfade_position_ < 1.0f);

    // Process in chunks
    size_t remaining = size;
    size_t offset = 0;

    // Calculate LPG decay rate
    // Decay: 10ms (lpg_decay_=0) to 4s (lpg_decay_=1)
    float decay_time = 0.01f + lpg_decay_ * lpg_decay_ * 4.0f;
    float decay_coef = 1.0f - std::exp(-1.0f / (decay_time * sample_rate_));

    // Attack is very fast for Plaits-like behavior (vactrol response)
    float attack_time = 0.001f + lpg_attack_ * 0.05f;  // 1ms to 50ms
    float attack_coef = 1.0f - std::exp(-1.0f / (attack_time * sample_rate_));

    while (remaining > 0) {
        size_t chunk = std::min(remaining, size_t(256));

        // Render from current engine
        RenderEngine(temp_out, temp_aux, chunk);

        // If crossfading, also render from previous engine and blend
        if (is_crossfading) {
            RenderSpecificEngine(previous_engine_, xfade_out, xfade_aux, chunk);
            for (size_t i = 0; i < chunk; ++i) {
                float fade = std::min(1.0f, crossfade_position_);
                temp_out[i] = xfade_out[i] * (1.0f - fade) + temp_out[i] * fade;
                temp_aux[i] = xfade_aux[i] * (1.0f - fade) + temp_aux[i] * fade;
                crossfade_position_ += crossfade_increment_;
            }
            if (crossfade_position_ >= 1.0f) {
                previous_engine_ = -1;
                crossfade_position_ = 1.0f;
                is_crossfading = false;
            }
        }

        for (size_t i = 0; i < chunk; ++i) {
            float input_sample = temp_out[i];
            float processed_sample;

            if (lpg_bypass_) {
                // =============================================================
                // LPG BYPASS MODE (for testing)
                // =============================================================
                // Audio passes through with only level control, no envelope
                // This lets you hear the raw engine output
                // =============================================================
                processed_sample = input_sample * level_;

            } else if (is_triggered_engine) {
                // =============================================================
                // ENGINES 11-15: LPG BYPASSED
                // =============================================================
                // These engines (String, Modal, Bass Drum, Snare, Hi-Hat)
                // have their own internal decay envelopes.
                // We just pass the audio through with level control.
                // LEVEL CV acts as "accent" in real Plaits.
                // =============================================================

                processed_sample = input_sample * level_;

            } else {
                // =============================================================
                // ENGINES 0-10: LPG ACTIVE (Trigger-based decay)
                // =============================================================
                // The LPG envelope is struck on trigger and then decays.
                // It does NOT sustain while the gate is held!
                // This is the key difference from a traditional synth.
                // =============================================================

                // Update envelope - always decaying toward zero after attack
                if (envelope_ < envelope_target_) {
                    // Attack phase - rise quickly
                    envelope_ += attack_coef * (envelope_target_ - envelope_);
                    if (envelope_ > 0.99f) {
                        // Reached peak, now decay (target is always 0)
                        envelope_target_ = 0.0f;
                    }
                } else {
                    // Decay phase - fall toward zero
                    envelope_ += decay_coef * (envelope_target_ - envelope_);
                }

                // Clamp envelope
                envelope_ = std::max(0.0f, std::min(1.0f, envelope_));

                // Apply LPG (combined VCA + filter)
                if (lpg_color_ > 0.01f) {
                    // LPG mode: envelope controls both amplitude and filter cutoff
                    float env_squared = envelope_ * envelope_;
                    float base_cutoff = 0.02f;   // Very dark when closed
                    float max_cutoff = 0.95f;    // Bright when open
                    float cutoff = base_cutoff + env_squared * (max_cutoff - base_cutoff);

                    // Mix between full cutoff and envelope-controlled based on color
                    cutoff = 1.0f - lpg_color_ * (1.0f - cutoff);

                    // One-pole low-pass filter
                    lpg_filter_state_ += cutoff * (input_sample - lpg_filter_state_);
                    processed_sample = lpg_filter_state_;
                } else {
                    // Pure VCA mode
                    processed_sample = input_sample;
                }

                // Apply VCA (envelope always controls amplitude)
                processed_sample *= envelope_;
                processed_sample *= level_;
            }

            // Hard clamp to ±1.0 — saturation is handled by the master bus tanh
            processed_sample = std::max(-1.0f, std::min(1.0f, processed_sample));

            if (out) {
                out[offset + i] = processed_sample;
            }

            if (aux) {
                float aux_sample = temp_aux[i] * level_ * 0.7f;
                if (!lpg_bypass_ && !is_triggered_engine) {
                    aux_sample *= envelope_;
                }
                aux[offset + i] = std::max(-1.0f, std::min(1.0f, aux_sample));
            }
        }

        remaining -= chunk;
        offset += chunk;
    }
}

void PlaitsVoice::RenderEngine(float* out, float* aux, size_t size) {
    RenderSpecificEngine(current_engine_, out, aux, size);
}

void PlaitsVoice::RenderSpecificEngine(int engine, float* out, float* aux, size_t size) {
    // =========================================================================
    // PLAITS ENGINE MAPPING (17 engines)
    // =========================================================================
    // 0: Virtual Analog - Two detuned oscillators (pulse/saw)
    // 1: Waveshaper - Triangle through waveshaper and wavefolder
    // 2: Two-Op FM - Sine oscillators with phase modulation
    // 3: Granular Formant - VOSIM/Pulsar synthesis
    // 4: Harmonic - Additive with 24 harmonics
    // 5: Wavetable - 4 banks of 8x8 wavetables
    // 6: Chords - Four-note chord generator
    // 7: Speech - Formant/SAM/LPC synthesis
    // 8: Granular Cloud - Swarm of grains
    // 9: Filtered Noise - Clocked noise through filter
    // 10: Particle Noise - Dust through all-pass/band-pass
    // 11: String (Karplus-Strong) - TRIGGERED
    // 12: Modal Resonator - TRIGGERED
    // 13: Bass Drum - TRIGGERED
    // 14: Snare Drum - TRIGGERED
    // 15: Hi-Hat - TRIGGERED
    // 16: Six-Op FM - DX7-style 6-operator FM synthesis
    // =========================================================================

    // Apply modulation to parameters (modulation adds to base value, clamped 0-1)
    float mod_harmonics = std::max(0.0f, std::min(1.0f, harmonics_ + harmonics_mod_amount_));
    float mod_timbre = std::max(0.0f, std::min(1.0f, timbre_ + timbre_mod_amount_));
    float mod_morph = std::max(0.0f, std::min(1.0f, morph_ + morph_mod_amount_));

    switch (engine) {
        case 0: // Virtual Analog
        {
            auto* va = static_cast<Engines::VirtualAnalogEngine*>(va_engine_);
            va->SetNote(note_);
            va->SetHarmonics(mod_harmonics);  // Detuning
            va->SetTimbre(mod_timbre);        // Pulse width / shape
            va->SetMorph(mod_morph);          // Saw shape
            va->Render(out, aux, size);
            break;
        }

        case 1: // Waveshaper
        {
            auto* ws = static_cast<Engines::WaveshapingEngine*>(ws_engine_);
            ws->SetNote(note_);
            ws->SetHarmonics(mod_harmonics);  // Waveshaper selection
            ws->SetTimbre(mod_timbre);        // Wavefolder amount
            ws->SetMorph(mod_morph);          // Asymmetry
            ws->Render(out, aux, size);
            break;
        }

        case 2: // Two-Operator FM
        {
            auto* fm = static_cast<Engines::FMEngine*>(fm_engine_);
            fm->SetNote(note_);
            fm->SetHarmonics(mod_harmonics);  // Frequency ratio
            fm->SetTimbre(mod_timbre);        // Modulation index
            fm->SetMorph(mod_morph);          // Feedback
            fm->Render(out, aux, size);
            break;
        }

        case 3: // Granular Formant (VOSIM/Pulsar)
        {
            auto* formant = static_cast<Engines::FormantEngine*>(formant_engine_);
            formant->SetNote(note_);
            formant->SetHarmonics(mod_harmonics);  // Formant ratio
            formant->SetTimbre(mod_timbre);        // Formant frequency
            formant->SetMorph(mod_morph);          // Formant width
            formant->Render(out, aux, size);
            break;
        }

        case 4: // Harmonic (Additive)
        {
            auto* harmonic = static_cast<Engines::HarmonicEngine*>(harmonic_engine_);
            harmonic->SetNote(note_);
            harmonic->SetHarmonics(mod_harmonics);  // Number of bumps
            harmonic->SetTimbre(mod_timbre);        // Spectral centroid
            harmonic->SetMorph(mod_morph);          // Bump width
            harmonic->Render(out, aux, size);
            break;
        }

        case 5: // Wavetable
        {
            auto* wavetable = static_cast<Engines::WavetableEngine*>(wavetable_engine_);
            wavetable->SetNote(note_);
            wavetable->SetHarmonics(mod_harmonics);  // Bank selection
            wavetable->SetTimbre(mod_timbre);        // Y position (row)
            wavetable->SetMorph(mod_morph);          // X position (column)
            wavetable->Render(out, aux, size);
            break;
        }

        case 6: // Chords
        {
            auto* chord = static_cast<Engines::ChordEngine*>(chord_engine_);
            chord->SetNote(note_);
            chord->SetHarmonics(mod_harmonics);  // Chord type
            chord->SetTimbre(mod_timbre);        // Inversion
            chord->SetMorph(mod_morph);          // Waveform
            chord->Render(out, aux, size);
            break;
        }

        case 7: // Speech
        {
            auto* speech = static_cast<Engines::SpeechEngine*>(speech_engine_);
            speech->SetNote(note_);
            speech->SetHarmonics(mod_harmonics);  // Synthesis mode
            speech->SetTimbre(mod_timbre);        // Species (formant shift)
            speech->SetMorph(mod_morph);          // Vowel/phoneme
            speech->Render(out, aux, size);
            break;
        }

        case 8: // Granular Cloud
        {
            auto* grain = static_cast<Engines::GrainEngine*>(grain_engine_);
            grain->SetNote(note_);
            grain->SetHarmonics(mod_harmonics);  // Pitch randomization
            grain->SetTimbre(mod_timbre);        // Grain density
            grain->SetMorph(mod_morph);          // Grain duration/overlap
            grain->Render(out, aux, size);
            break;
        }

        case 9: // Filtered Noise
        {
            auto* noise = static_cast<Engines::NoiseEngine*>(noise_engine_);
            noise->SetMode(Engines::NoiseEngine::FILTERED_NOISE);
            noise->SetNote(note_);
            noise->SetHarmonics(mod_harmonics);  // Filter type (LP->BP->HP)
            noise->SetTimbre(mod_timbre);        // Clock frequency
            noise->SetMorph(mod_morph);          // Resonance
            noise->Render(out, aux, size);
            break;
        }

        case 10: // Particle Noise
        {
            auto* noise = static_cast<Engines::NoiseEngine*>(noise_engine_);
            noise->SetMode(Engines::NoiseEngine::PARTICLE_NOISE);
            noise->SetNote(note_);
            noise->SetHarmonics(mod_harmonics);  // Freq randomization
            noise->SetTimbre(mod_timbre);        // Particle density
            noise->SetMorph(mod_morph);          // Filter type
            noise->Render(out, aux, size);
            break;
        }

        // =====================================================================
        // TRIGGERED ENGINES (11-15) - These have their own internal envelopes
        // =====================================================================

        case 11: // String (Karplus-Strong)
        {
            auto* string = static_cast<Engines::StringEngine*>(string_engine_);
            string->SetMode(Engines::StringEngine::STRING_KARPLUS_STRONG);
            string->SetNote(note_);
            string->SetHarmonics(mod_harmonics);  // Inharmonicity / material
            string->SetTimbre(mod_timbre);        // Excitation brightness
            string->SetMorph(mod_morph);          // Decay time
            string->Render(out, aux, size);
            break;
        }

        case 12: // Modal Resonator
        {
            auto* string = static_cast<Engines::StringEngine*>(string_engine_);
            string->SetMode(Engines::StringEngine::MODAL_RESONATOR);
            string->SetNote(note_);
            string->SetHarmonics(mod_harmonics);  // Inharmonicity / material
            string->SetTimbre(mod_timbre);        // Brightness
            string->SetMorph(mod_morph);          // Decay time
            string->Render(out, aux, size);
            break;
        }

        case 13: // Bass Drum
        {
            auto* perc = static_cast<Engines::PercussionEngine*>(percussion_engine_);
            perc->SetPercussionType(Engines::PercussionEngine::KICK);
            perc->SetNote(note_);
            perc->SetHarmonics(mod_harmonics);  // Punch (pitch envelope amount)
            perc->SetTimbre(mod_timbre);        // Tone (brightness/drive)
            perc->SetMorph(mod_morph);          // Decay
            perc->Render(out, aux, size);
            break;
        }

        case 14: // Snare Drum
        {
            auto* perc = static_cast<Engines::PercussionEngine*>(percussion_engine_);
            perc->SetPercussionType(Engines::PercussionEngine::SNARE);
            perc->SetNote(note_);
            perc->SetHarmonics(mod_harmonics);  // Snare wire amount
            perc->SetTimbre(mod_timbre);        // Tone balance (body vs crack)
            perc->SetMorph(mod_morph);          // Decay
            perc->Render(out, aux, size);
            break;
        }

        case 15: // Hi-Hat
        {
            auto* perc = static_cast<Engines::PercussionEngine*>(percussion_engine_);
            perc->SetPercussionType(Engines::PercussionEngine::HIHAT_CLOSED);
            perc->SetNote(note_);
            perc->SetHarmonics(mod_harmonics);  // Metallic tone frequency
            perc->SetTimbre(mod_timbre);        // Open/closed (decay time)
            perc->SetMorph(mod_morph);          // Additional decay control
            perc->Render(out, aux, size);
            break;
        }

        case 16: // Six-Op FM
        {
            auto* sixop = static_cast<Engines::SixOpFMEngine*>(sixop_fm_engine_);
            sixop->SetNote(note_);
            sixop->SetHarmonics(mod_harmonics);  // Algorithm selection
            sixop->SetTimbre(mod_timbre);        // Modulation depth
            sixop->SetMorph(mod_morph);          // Operator balance
            sixop->Render(out, aux, size);
            break;
        }

        default: {
            // Fallback to Virtual Analog
            auto* va = static_cast<Engines::VirtualAnalogEngine*>(va_engine_);
            va->SetNote(note_);
            va->SetHarmonics(mod_harmonics);
            va->SetTimbre(mod_timbre);
            va->SetMorph(mod_morph);
            va->Render(out, aux, size);
            break;
        }
    }
}

void PlaitsVoice::SetEngine(int engine) {
    int new_engine = std::max(0, std::min(16, engine));
    if (new_engine != current_engine_) {
        // Start crossfade from old engine to new engine
        previous_engine_ = current_engine_;
        crossfade_position_ = 0.0f;
        // Crossfade over kCrossfadeDurationMs
        float crossfade_samples = (kCrossfadeDurationMs / 1000.0f) * sample_rate_;
        crossfade_increment_ = 1.0f / std::max(1.0f, crossfade_samples);
        current_engine_ = new_engine;
    }
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
    // Increment trigger count whenever gate goes high (handles fast repeated notes)
    if (state) {
        trigger_count_++;
    }
}

void PlaitsVoice::SetLevel(float value) {
    level_ = std::max(0.0f, std::min(1.0f, value));
}

void PlaitsVoice::SetHarmonicsModAmount(float amount) {
    // Allow bipolar modulation (-1 to +1 range)
    harmonics_mod_amount_ = std::max(-1.0f, std::min(1.0f, amount));
}

void PlaitsVoice::SetTimbreModAmount(float amount) {
    // Allow bipolar modulation (-1 to +1 range)
    timbre_mod_amount_ = std::max(-1.0f, std::min(1.0f, amount));
}

void PlaitsVoice::SetMorphModAmount(float amount) {
    // Allow bipolar modulation (-1 to +1 range)
    morph_mod_amount_ = std::max(-1.0f, std::min(1.0f, amount));
}

void PlaitsVoice::SetLPGColor(float color) {
    lpg_color_ = std::max(0.0f, std::min(1.0f, color));
}

void PlaitsVoice::SetLPGDecay(float decay) {
    lpg_decay_ = std::max(0.0f, std::min(1.0f, decay));
}

void PlaitsVoice::SetLPGAttack(float attack) {
    lpg_attack_ = std::max(0.0f, std::min(1.0f, attack));
}

void PlaitsVoice::SetLPGBypass(bool bypass) {
    lpg_bypass_ = bypass;
}

void PlaitsVoice::LoadUserWavetable(const float* data, int numSamples, int frameSize) {
    auto* wt = static_cast<Engines::WavetableEngine*>(wavetable_engine_);
    wt->LoadUserWavetable(data, numSamples, frameSize);
}

bool PlaitsVoice::IsPercussionEngine() const {
    // Engines 13-15 are the main percussion (kick, snare, hihat)
    return current_engine_ >= 13 && current_engine_ <= 15;
}

bool PlaitsVoice::IsTriggeredEngine() const {
    // Engines 11-15 are "triggered" engines with internal envelopes
    // (String, Modal, Bass Drum, Snare, Hi-Hat)
    return current_engine_ >= 11 && current_engine_ <= 15;
}

bool PlaitsVoice::IsGranularEngine() const {
    // Engines 8-10 use granular synthesis
    return current_engine_ >= 8 && current_engine_ <= 10;
}

} // namespace Grainulator

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

            // Soft limiting
            processed_sample = std::tanh(processed_sample * 1.5f) * 0.67f;

            if (out) {
                out[offset + i] = processed_sample;
            }

            if (aux) {
                float aux_sample = temp_aux[i] * level_ * 0.7f;
                if (!lpg_bypass_ && !is_triggered_engine) {
                    aux_sample *= envelope_;
                }
                aux[offset + i] = std::tanh(aux_sample);
            }
        }

        remaining -= chunk;
        offset += chunk;
    }
}

void PlaitsVoice::RenderEngine(float* out, float* aux, size_t size) {
    // =========================================================================
    // REAL PLAITS ENGINE MAPPING (16 engines)
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
    // =========================================================================

    switch (current_engine_) {
        case 0: // Virtual Analog
        {
            auto* va = static_cast<Engines::VirtualAnalogEngine*>(va_engine_);
            va->SetNote(note_);
            va->SetHarmonics(harmonics_);  // Detuning
            va->SetTimbre(timbre_);        // Pulse width / shape
            va->SetMorph(morph_);          // Saw shape
            va->Render(out, aux, size);
            break;
        }

        case 1: // Waveshaper
        {
            auto* ws = static_cast<Engines::WaveshapingEngine*>(ws_engine_);
            ws->SetNote(note_);
            ws->SetHarmonics(harmonics_);  // Waveshaper selection
            ws->SetTimbre(timbre_);        // Wavefolder amount
            ws->SetMorph(morph_);          // Asymmetry
            ws->Render(out, aux, size);
            break;
        }

        case 2: // Two-Operator FM
        {
            auto* fm = static_cast<Engines::FMEngine*>(fm_engine_);
            fm->SetNote(note_);
            fm->SetHarmonics(harmonics_);  // Frequency ratio
            fm->SetTimbre(timbre_);        // Modulation index
            fm->SetMorph(morph_);          // Feedback
            fm->Render(out, aux, size);
            break;
        }

        case 3: // Granular Formant (VOSIM/Pulsar)
        {
            auto* formant = static_cast<Engines::FormantEngine*>(formant_engine_);
            formant->SetNote(note_);
            formant->SetHarmonics(harmonics_);  // Formant ratio
            formant->SetTimbre(timbre_);        // Formant frequency
            formant->SetMorph(morph_);          // Formant width
            formant->Render(out, aux, size);
            break;
        }

        case 4: // Harmonic (Additive)
        {
            auto* harmonic = static_cast<Engines::HarmonicEngine*>(harmonic_engine_);
            harmonic->SetNote(note_);
            harmonic->SetHarmonics(harmonics_);  // Number of bumps
            harmonic->SetTimbre(timbre_);        // Spectral centroid
            harmonic->SetMorph(morph_);          // Bump width
            harmonic->Render(out, aux, size);
            break;
        }

        case 5: // Wavetable
        {
            auto* wavetable = static_cast<Engines::WavetableEngine*>(wavetable_engine_);
            wavetable->SetNote(note_);
            wavetable->SetHarmonics(harmonics_);  // Bank selection
            wavetable->SetTimbre(timbre_);        // Y position (row)
            wavetable->SetMorph(morph_);          // X position (column)
            wavetable->Render(out, aux, size);
            break;
        }

        case 6: // Chords
        {
            auto* chord = static_cast<Engines::ChordEngine*>(chord_engine_);
            chord->SetNote(note_);
            chord->SetHarmonics(harmonics_);  // Chord type
            chord->SetTimbre(timbre_);        // Inversion
            chord->SetMorph(morph_);          // Waveform
            chord->Render(out, aux, size);
            break;
        }

        case 7: // Speech
        {
            auto* speech = static_cast<Engines::SpeechEngine*>(speech_engine_);
            speech->SetNote(note_);
            speech->SetHarmonics(harmonics_);  // Synthesis mode
            speech->SetTimbre(timbre_);        // Species (formant shift)
            speech->SetMorph(morph_);          // Vowel/phoneme
            speech->Render(out, aux, size);
            break;
        }

        case 8: // Granular Cloud
        {
            auto* grain = static_cast<Engines::GrainEngine*>(grain_engine_);
            grain->SetNote(note_);
            grain->SetHarmonics(harmonics_);  // Pitch randomization
            grain->SetTimbre(timbre_);        // Grain density
            grain->SetMorph(morph_);          // Grain duration/overlap
            grain->Render(out, aux, size);
            break;
        }

        case 9: // Filtered Noise
        {
            auto* noise = static_cast<Engines::NoiseEngine*>(noise_engine_);
            noise->SetMode(Engines::NoiseEngine::FILTERED_NOISE);
            noise->SetNote(note_);
            noise->SetHarmonics(harmonics_);  // Filter type (LP->BP->HP)
            noise->SetTimbre(timbre_);        // Clock frequency
            noise->SetMorph(morph_);          // Resonance
            noise->Render(out, aux, size);
            break;
        }

        case 10: // Particle Noise
        {
            auto* noise = static_cast<Engines::NoiseEngine*>(noise_engine_);
            noise->SetMode(Engines::NoiseEngine::PARTICLE_NOISE);
            noise->SetNote(note_);
            noise->SetHarmonics(harmonics_);  // Freq randomization
            noise->SetTimbre(timbre_);        // Particle density
            noise->SetMorph(morph_);          // Filter type
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
            string->SetHarmonics(harmonics_);  // Inharmonicity / material
            string->SetTimbre(timbre_);        // Excitation brightness
            string->SetMorph(morph_);          // Decay time
            string->Render(out, aux, size);
            break;
        }

        case 12: // Modal Resonator
        {
            auto* string = static_cast<Engines::StringEngine*>(string_engine_);
            string->SetMode(Engines::StringEngine::MODAL_RESONATOR);
            string->SetNote(note_);
            string->SetHarmonics(harmonics_);  // Inharmonicity / material
            string->SetTimbre(timbre_);        // Brightness
            string->SetMorph(morph_);          // Decay time
            string->Render(out, aux, size);
            break;
        }

        case 13: // Bass Drum
        {
            auto* perc = static_cast<Engines::PercussionEngine*>(percussion_engine_);
            perc->SetPercussionType(Engines::PercussionEngine::KICK);
            perc->SetNote(note_);
            perc->SetHarmonics(harmonics_);  // Punch (pitch envelope amount)
            perc->SetTimbre(timbre_);        // Tone (brightness/drive)
            perc->SetMorph(morph_);          // Decay
            perc->Render(out, aux, size);
            break;
        }

        case 14: // Snare Drum
        {
            auto* perc = static_cast<Engines::PercussionEngine*>(percussion_engine_);
            perc->SetPercussionType(Engines::PercussionEngine::SNARE);
            perc->SetNote(note_);
            perc->SetHarmonics(harmonics_);  // Snare wire amount
            perc->SetTimbre(timbre_);        // Tone balance (body vs crack)
            perc->SetMorph(morph_);          // Decay
            perc->Render(out, aux, size);
            break;
        }

        case 15: // Hi-Hat
        {
            auto* perc = static_cast<Engines::PercussionEngine*>(percussion_engine_);
            perc->SetPercussionType(Engines::PercussionEngine::HIHAT_CLOSED);
            perc->SetNote(note_);
            perc->SetHarmonics(harmonics_);  // Metallic tone frequency
            perc->SetTimbre(timbre_);        // Open/closed (decay time)
            perc->SetMorph(morph_);          // Additional decay control
            perc->Render(out, aux, size);
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
    // Increment trigger count whenever gate goes high (handles fast repeated notes)
    if (state) {
        trigger_count_++;
    }
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

void PlaitsVoice::SetLPGAttack(float attack) {
    lpg_attack_ = std::max(0.0f, std::min(1.0f, attack));
}

void PlaitsVoice::SetLPGBypass(bool bypass) {
    lpg_bypass_ = bypass;
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

//
//  DaisyDrumVoice.cpp
//  Grainulator
//
//  DaisySP drum synthesis voice wrapper implementation
//

#include "DaisyDrumVoice.h"

#include "DaisySP/Utility/dsp.h"
#include "DaisySP/Drums/analogbassdrum.h"
#include "DaisySP/Drums/synthbassdrum.h"
#include "DaisySP/Drums/analogsnaredrum.h"
#include "DaisySP/Drums/synthsnaredrum.h"
#include "DaisySP/Drums/hihat.h"

#include <cmath>
#include <cstring>

namespace Grainulator {

// Concrete HiHat type: SquareNoise source, LinearVCA, no resonance
using DaisyHiHat = daisysp::HiHat<daisysp::SquareNoise, daisysp::LinearVCA, true>;

DaisyDrumVoice::DaisyDrumVoice()
    : sample_rate_(48000.f)
    , engine_(AnalogKick)
    , note_(36.f)
    , harmonics_(0.5f)
    , timbre_(0.5f)
    , morph_(0.5f)
    , level_(0.8f)
    , harmonics_mod_(0.f)
    , timbre_mod_(0.f)
    , morph_mod_(0.f)
    , trigger_state_(false)
    , prev_trigger_(false)
    , analog_kick_(nullptr)
    , synth_kick_(nullptr)
    , analog_snare_(nullptr)
    , synth_snare_(nullptr)
    , hihat_(nullptr)
{
    analog_kick_  = new daisysp::AnalogBassDrum();
    synth_kick_   = new daisysp::SyntheticBassDrum();
    analog_snare_ = new daisysp::AnalogSnareDrum();
    synth_snare_  = new daisysp::SyntheticSnareDrum();
    hihat_        = new DaisyHiHat();
}

DaisyDrumVoice::~DaisyDrumVoice() {
    delete static_cast<daisysp::AnalogBassDrum*>(analog_kick_);
    delete static_cast<daisysp::SyntheticBassDrum*>(synth_kick_);
    delete static_cast<daisysp::AnalogSnareDrum*>(analog_snare_);
    delete static_cast<daisysp::SyntheticSnareDrum*>(synth_snare_);
    delete static_cast<DaisyHiHat*>(hihat_);
}

void DaisyDrumVoice::Init(float sample_rate) {
    sample_rate_ = sample_rate;

    static_cast<daisysp::AnalogBassDrum*>(analog_kick_)->Init(sample_rate);
    static_cast<daisysp::SyntheticBassDrum*>(synth_kick_)->Init(sample_rate);
    static_cast<daisysp::AnalogSnareDrum*>(analog_snare_)->Init(sample_rate);
    static_cast<daisysp::SyntheticSnareDrum*>(synth_snare_)->Init(sample_rate);
    static_cast<DaisyHiHat*>(hihat_)->Init(sample_rate);

    // Set default frequencies
    float defaultFreq = daisysp::mtof(note_);
    static_cast<daisysp::AnalogBassDrum*>(analog_kick_)->SetFreq(defaultFreq);
    static_cast<daisysp::SyntheticBassDrum*>(synth_kick_)->SetFreq(defaultFreq);
    static_cast<daisysp::AnalogSnareDrum*>(analog_snare_)->SetFreq(defaultFreq);
    static_cast<daisysp::SyntheticSnareDrum*>(synth_snare_)->SetFreq(defaultFreq);
    static_cast<DaisyHiHat*>(hihat_)->SetFreq(daisysp::mtof(60.f));
}

void DaisyDrumVoice::Render(float* out, float* aux, size_t size) {
    // Edge-detect trigger (rising edge only)
    bool should_trigger = trigger_state_ && !prev_trigger_;
    prev_trigger_ = trigger_state_;

    // Apply modulation to base parameters
    float h = daisysp::fclamp(harmonics_ + harmonics_mod_, 0.f, 1.f);
    float t = daisysp::fclamp(timbre_ + timbre_mod_, 0.f, 1.f);
    float m = daisysp::fclamp(morph_ + morph_mod_, 0.f, 1.f);

    // Convert MIDI note to Hz
    float freq = daisysp::mtof(note_);

    // Map unified params to engine-specific setters
    switch (engine_) {
        case AnalogKick: {
            auto* e = static_cast<daisysp::AnalogBassDrum*>(analog_kick_);
            e->SetFreq(freq);
            e->SetTone(h);
            e->SetAttackFmAmount(t);
            e->SetDecay(m);
            e->SetAccent(level_);
            break;
        }
        case SyntheticKick: {
            auto* e = static_cast<daisysp::SyntheticBassDrum*>(synth_kick_);
            e->SetFreq(freq);
            e->SetTone(h);
            e->SetFmEnvelopeAmount(t);
            e->SetDecay(m);
            e->SetAccent(level_);
            break;
        }
        case AnalogSnare: {
            auto* e = static_cast<daisysp::AnalogSnareDrum*>(analog_snare_);
            e->SetFreq(freq);
            e->SetTone(h);
            e->SetSnappy(t);
            e->SetDecay(m);
            e->SetAccent(level_);
            break;
        }
        case SyntheticSnare: {
            auto* e = static_cast<daisysp::SyntheticSnareDrum*>(synth_snare_);
            e->SetFreq(freq);
            e->SetFmAmount(h);
            e->SetSnappy(t);
            e->SetDecay(m);
            e->SetAccent(level_);
            break;
        }
        case HiHat: {
            auto* e = static_cast<DaisyHiHat*>(hihat_);
            e->SetFreq(freq);
            e->SetTone(h);
            e->SetNoisiness(t);
            e->SetDecay(m);
            e->SetAccent(level_);
            break;
        }
        default:
            break;
    }

    // Process sample-by-sample
    for (size_t i = 0; i < size; ++i) {
        bool trig = (i == 0) && should_trigger;
        float sample = 0.f;

        switch (engine_) {
            case AnalogKick:
                sample = static_cast<daisysp::AnalogBassDrum*>(analog_kick_)->Process(trig);
                break;
            case SyntheticKick:
                sample = static_cast<daisysp::SyntheticBassDrum*>(synth_kick_)->Process(trig);
                break;
            case AnalogSnare:
                sample = static_cast<daisysp::AnalogSnareDrum*>(analog_snare_)->Process(trig);
                break;
            case SyntheticSnare:
                sample = static_cast<daisysp::SyntheticSnareDrum*>(synth_snare_)->Process(trig);
                break;
            case HiHat:
                sample = static_cast<DaisyHiHat*>(hihat_)->Process(trig);
                break;
            default:
                break;
        }

        // Hard clamp to ±1.0 — saturation is handled by the master bus tanh
        sample = std::max(-1.0f, std::min(1.0f, sample));

        if (out) out[i] = sample;
        if (aux) aux[i] = sample * 0.7f;
    }

    // Auto-clear trigger after processing
    if (should_trigger) {
        trigger_state_ = false;
    }
}

void DaisyDrumVoice::SetEngine(int engine) {
    if (engine >= 0 && engine < NumEngines) {
        engine_ = engine;
    }
}

void DaisyDrumVoice::SetNote(float note) {
    note_ = note;
}

void DaisyDrumVoice::SetHarmonics(float value) {
    harmonics_ = daisysp::fclamp(value, 0.f, 1.f);
}

void DaisyDrumVoice::SetTimbre(float value) {
    timbre_ = daisysp::fclamp(value, 0.f, 1.f);
}

void DaisyDrumVoice::SetMorph(float value) {
    morph_ = daisysp::fclamp(value, 0.f, 1.f);
}

void DaisyDrumVoice::Trigger(bool state) {
    trigger_state_ = state;
}

void DaisyDrumVoice::SetLevel(float value) {
    level_ = daisysp::fclamp(value, 0.f, 1.f);
}

void DaisyDrumVoice::SetHarmonicsMod(float amount) {
    harmonics_mod_ = amount;
}

void DaisyDrumVoice::SetTimbreMod(float amount) {
    timbre_mod_ = amount;
}

void DaisyDrumVoice::SetMorphMod(float amount) {
    morph_mod_ = amount;
}

} // namespace Grainulator

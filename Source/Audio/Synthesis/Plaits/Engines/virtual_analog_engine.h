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

#ifndef VIRTUAL_ANALOG_ENGINE_H
#define VIRTUAL_ANALOG_ENGINE_H

#include "../DSP/oscillator/oscillator.h"
#include <cmath>
#include <algorithm>

namespace Grainulator {
namespace Engines {

/// Virtual Analog synthesis engine
/// Produces classic analog waveforms with variable waveshaping and sync
class VirtualAnalogEngine {
public:
    VirtualAnalogEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.5f)
        , timbre_(0.5f)
        , morph_(0.5f)
    {
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;

        primary_osc_.Init();
        secondary_osc_.Init();
        sub_osc_.Init();

        lp_filter_.Init();
        hp_filter_.Init();
        dc_blocker_.Init();

        // Initialize parameter smoothing
        frequency_smoother_.Init();
    }

    /// Set the MIDI note (0-127, fractional allowed for pitch bend)
    void SetNote(float note) {
        note_ = note;
    }

    /// Set harmonics parameter (0-1)
    /// Controls the balance between sub-oscillator and main oscillator
    /// and affects filter brightness
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// Set timbre parameter (0-1)
    /// Morphs between different waveform combinations
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// Set morph parameter (0-1)
    /// Controls PWM for square wave, detune for other waveforms
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    /// Render audio samples
    void Render(float* out, float* aux, size_t size) {
        // Convert MIDI note to frequency
        float frequency = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);
        float normalized_frequency = frequency / sample_rate_;

        // Clamp frequency to prevent aliasing
        normalized_frequency = std::min(normalized_frequency, 0.45f);

        // Set oscillator frequencies
        primary_osc_.SetFrequency(normalized_frequency);

        // Secondary oscillator slightly detuned based on morph
        float detune = 1.0f + (morph_ - 0.5f) * 0.02f;
        secondary_osc_.SetFrequency(normalized_frequency * detune);

        // Sub oscillator one octave down
        sub_osc_.SetFrequency(normalized_frequency * 0.5f);

        // Set pulse width for square wave based on morph
        float pw = 0.5f + (morph_ - 0.5f) * 0.45f;
        primary_osc_.SetPulseWidth(pw);
        secondary_osc_.SetPulseWidth(pw);

        // Determine waveform based on timbre
        // 0.0-0.25: Saw
        // 0.25-0.5: Saw + Square
        // 0.5-0.75: Square
        // 0.75-1.0: Square + Triangle
        int primary_wave = DetermineWaveform(timbre_);
        int secondary_wave = DetermineSecondaryWaveform(timbre_);
        float wave_mix = GetWaveMix(timbre_);

        // Filter coefficient based on harmonics
        float filter_cutoff = 0.1f + harmonics_ * 0.8f;
        lp_filter_.SetCoefficient(filter_cutoff);

        for (size_t i = 0; i < size; ++i) {
            // Render primary oscillator with morph between waveforms
            float primary = primary_osc_.RenderMorph(primary_wave, secondary_wave, wave_mix);

            // Render secondary oscillator for thickness
            float secondary = secondary_osc_.RenderMorph(primary_wave, secondary_wave, wave_mix);

            // Render sub oscillator (always sine for smoothness)
            float sub = sub_osc_.Render(0);

            // Mix based on harmonics parameter
            // Low harmonics = more sub, high harmonics = more main
            float sub_level = (1.0f - harmonics_) * 0.7f;
            float main_level = 0.5f + harmonics_ * 0.3f;
            float secondary_level = morph_ * 0.3f;

            float sample = primary * main_level +
                          secondary * secondary_level +
                          sub * sub_level;

            // Apply low-pass filter based on harmonics
            sample = lp_filter_.Process(sample);

            // DC blocking
            sample = dc_blocker_.Process(sample);

            // Soft limiting
            sample = SoftLimit(sample);

            // Output
            if (out) {
                out[i] = sample;
            }

            // Aux output: high-passed version for variation
            if (aux) {
                float hp_sample = sample - hp_filter_.Process(sample);
                aux[i] = hp_sample;
            }
        }
    }

    /// Get the engine type/name
    static const char* GetName() {
        return "Virtual Analog";
    }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;

    DSP::PolyBlepOscillator primary_osc_;
    DSP::PolyBlepOscillator secondary_osc_;
    DSP::PolyBlepOscillator sub_osc_;

    DSP::OnePole lp_filter_;
    DSP::OnePole hp_filter_;
    DSP::DCBlocker dc_blocker_;
    DSP::OnePole frequency_smoother_;

    int DetermineWaveform(float timbre) {
        if (timbre < 0.33f) {
            return 2; // Saw
        } else if (timbre < 0.66f) {
            return 3; // Square
        } else {
            return 1; // Triangle
        }
    }

    int DetermineSecondaryWaveform(float timbre) {
        if (timbre < 0.33f) {
            return 3; // Saw -> Square transition
        } else if (timbre < 0.66f) {
            return 1; // Square -> Triangle transition
        } else {
            return 0; // Triangle -> Sine transition
        }
    }

    float GetWaveMix(float timbre) {
        // Get fractional position within each waveform zone
        float zone = timbre * 3.0f;
        return zone - std::floor(zone);
    }

    float SoftLimit(float x) {
        // Soft clipping using tanh
        const float threshold = 0.7f;
        if (x > threshold) {
            return threshold + (1.0f - threshold) * std::tanh((x - threshold) / (1.0f - threshold));
        } else if (x < -threshold) {
            return -threshold + (threshold - 1.0f) * std::tanh((-x - threshold) / (1.0f - threshold));
        }
        return x;
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // VIRTUAL_ANALOG_ENGINE_H

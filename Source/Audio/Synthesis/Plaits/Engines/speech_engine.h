//
//  speech_engine.h
//  Grainulator
//
//  Speech synthesis engine inspired by Mutable Instruments Plaits
//  Uses formant synthesis to create vowel and speech-like sounds
//
//  Note: Real Plaits uses pre-recorded phoneme LPC data for words like
//  "alpha", "red", "one". This implementation uses formant synthesis
//  which produces vowel-like sounds but not recognizable words.
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Émilie Gillet
//

#ifndef SPEECH_ENGINE_H
#define SPEECH_ENGINE_H

#include <cmath>
#include <algorithm>

namespace Grainulator {
namespace Engines {

/// Speech synthesis engine
/// Creates vowel and speech-like sounds using formant synthesis
class SpeechEngine {
public:
    static constexpr int kNumFormants = 4;
    static constexpr int kNumPhonemes = 16;

    // Extended phoneme set with vowels and approximated consonants
    // Format: {F1, F2, F3, F4} in Hz
    // Includes vowels, nasals, and approximated fricatives
    static constexpr float kPhonemeFormants[kNumPhonemes][kNumFormants] = {
        // Vowels
        {730, 1090, 2440, 3400},   // 0: AA (as in "father")
        {660, 1720, 2410, 3400},   // 1: AE (as in "cat")
        {520, 1190, 2390, 3400},   // 2: AH (as in "but")
        {390, 1990, 2550, 3400},   // 3: EH (as in "bed")
        {270, 2290, 3010, 3400},   // 4: IY (as in "beet")
        {300, 870, 2240, 3400},    // 5: IH (as in "bit")
        {570, 840, 2410, 3400},    // 6: AO (as in "bought")
        {440, 1020, 2240, 3400},   // 7: UH (as in "book")
        {300, 870, 2240, 3400},    // 8: UW (as in "boot")
        // Nasals and approximants (distinctive formant patterns)
        {270, 1000, 2200, 3400},   // 9: M/N nasal
        {350, 1300, 2300, 3400},   // 10: L approximant
        {300, 1400, 1600, 3400},   // 11: R approximant
        {280, 2500, 2900, 3400},   // 12: Y glide
        {300, 700, 2200, 3400},    // 13: W glide
        // Fricative-like (using noise mixing)
        {400, 1600, 2600, 3400},   // 14: S/SH-like (high freq noise)
        {350, 1200, 2400, 3400},   // 15: F/TH-like (noisy)
    };

    static constexpr float kPhonemeBandwidths[kNumFormants] = {60, 90, 150, 200};

    SpeechEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.5f)
        , timbre_(0.5f)
        , morph_(0.5f)
        , glottal_phase_(0.0f)
        , noise_state_(12345)
    {
        for (int i = 0; i < kNumFormants; ++i) {
            filter_state_[i] = 0.0f;
            filter_state2_[i] = 0.0f;
        }
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        glottal_phase_ = 0.0f;
        for (int i = 0; i < kNumFormants; ++i) {
            filter_state_[i] = 0.0f;
            filter_state2_[i] = 0.0f;
        }
    }

    void SetNote(float note) {
        note_ = note;
    }

    /// HARMONICS: Synthesis algorithm
    /// Formant synthesis -> SAM-like -> LPC-style vocoder
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// TIMBRE: Species / formant shift
    /// Low = giant (lower formants), Mid = human, High = chipmunk (higher formants)
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// MORPH: Phoneme selection
    /// Sweeps through 16 phonemes: vowels (AA, AE, AH, EH, IY, IH, AO, UH, UW),
    /// nasals/approximants (M/N, L, R, Y, W), and fricative-like sounds (S, F)
    /// Note: Unlike real Plaits, this doesn't produce recognizable words
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    void Render(float* out, float* aux, size_t size) {
        // Fundamental frequency from note
        float f0 = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);

        // Species shift (formant scaling) - timbre controls this
        // 0.5 = normal, 0 = giant (half freq), 1 = chipmunk (2x freq)
        float species_shift = std::pow(2.0f, (timbre_ - 0.5f) * 2.0f);

        // Get interpolated formant values based on morph (phoneme selection)
        float formants[kNumFormants];
        InterpolateFormants(formants, morph_);

        // Apply species shift
        for (int i = 0; i < kNumFormants; ++i) {
            formants[i] *= species_shift;
            formants[i] = std::min(formants[i], sample_rate_ * 0.45f);
        }

        // Determine how much noise vs voiced based on phoneme and harmonics
        // Phonemes 14-15 are fricative-like (more noise)
        float phoneme_idx = morph_ * (kNumPhonemes - 1);
        float fricative_amount = (phoneme_idx > 13.0f) ? (phoneme_idx - 13.0f) / 2.0f : 0.0f;
        fricative_amount = std::min(1.0f, fricative_amount);

        // Synthesis mode based on harmonics
        // 0 = fully voiced, 1 = mostly noise/whispered
        float base_noise_amount = harmonics_ * 0.5f;
        float noise_amount = base_noise_amount + fricative_amount * (1.0f - base_noise_amount);

        for (size_t i = 0; i < size; ++i) {
            // Generate glottal pulse (voiced excitation)
            glottal_phase_ += f0 / sample_rate_;
            if (glottal_phase_ >= 1.0f) glottal_phase_ -= 1.0f;

            // Glottal waveform - mixture of pulse and shaped wave
            float glottal;
            if (harmonics_ < 0.3f) {
                // Pure formant synthesis - use impulse train
                glottal = (glottal_phase_ < 0.1f) ? 1.0f : 0.0f;
            } else if (harmonics_ < 0.6f) {
                // SAM-like - shaped glottal pulse
                glottal = GlottalPulse(glottal_phase_);
            } else {
                // LPC-like - buzz
                glottal = std::sin(glottal_phase_ * 6.28318530718f);
            }

            // Generate noise for aspiration/fricatives
            float noise = GenerateNoise();

            // Mix voiced and unvoiced excitation
            float excitation = glottal * (1.0f - noise_amount) + noise * noise_amount;

            // Apply formant filters (parallel bank)
            float sample = 0.0f;
            for (int f = 0; f < kNumFormants; ++f) {
                float filtered = FormantFilter(excitation, f, formants[f], kPhonemeBandwidths[f]);
                // Weight formants (F1 and F2 are most important for vowels)
                // For fricatives, F3/F4 become more important
                float weight;
                if (fricative_amount > 0.3f) {
                    weight = (f < 2) ? 0.25f : 0.35f;
                } else {
                    weight = (f < 2) ? 0.4f : 0.2f;
                }
                sample += filtered * weight;
            }

            // Soft limit
            sample = std::tanh(sample * 2.5f);

            if (out) {
                out[i] = sample;
            }
            if (aux) {
                // Raw excitation to aux
                aux[i] = excitation * 0.5f;
            }
        }
    }

    static const char* GetName() {
        return "Speech";
    }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;

    float glottal_phase_;
    uint32_t noise_state_;

    // Per-formant filter state
    float filter_state_[kNumFormants];
    float filter_state2_[kNumFormants];

    void InterpolateFormants(float* out, float morph) {
        // Map morph 0-1 to phoneme index with interpolation
        float phoneme_pos = morph * (kNumPhonemes - 1);
        int phoneme0 = static_cast<int>(phoneme_pos);
        int phoneme1 = std::min(phoneme0 + 1, kNumPhonemes - 1);
        float frac = phoneme_pos - phoneme0;

        for (int i = 0; i < kNumFormants; ++i) {
            out[i] = kPhonemeFormants[phoneme0][i] * (1.0f - frac)
                   + kPhonemeFormants[phoneme1][i] * frac;
        }
    }

    float GlottalPulse(float phase) {
        // Rosenberg glottal pulse approximation
        if (phase < 0.4f) {
            // Opening phase
            float t = phase / 0.4f;
            return 3.0f * t * t - 2.0f * t * t * t;
        } else if (phase < 0.6f) {
            // Closing phase
            float t = (phase - 0.4f) / 0.2f;
            return 1.0f - t * t;
        } else {
            // Closed phase
            return 0.0f;
        }
    }

    float FormantFilter(float input, int index, float freq, float bandwidth) {
        // Simple 2-pole resonant filter for each formant
        float omega = 2.0f * 3.14159265f * freq / sample_rate_;
        float r = std::exp(-3.14159265f * bandwidth / sample_rate_);

        float cos_omega = std::cos(omega);

        // Direct form II transposed biquad
        float a1 = -2.0f * r * cos_omega;
        float a2 = r * r;

        float output = input - a1 * filter_state_[index] - a2 * filter_state2_[index];

        filter_state2_[index] = filter_state_[index];
        filter_state_[index] = output;

        return output * (1.0f - r);  // Normalize gain
    }

    float GenerateNoise() {
        noise_state_ = noise_state_ * 1664525 + 1013904223;
        return (static_cast<float>(noise_state_) / 2147483648.0f) - 1.0f;
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // SPEECH_ENGINE_H

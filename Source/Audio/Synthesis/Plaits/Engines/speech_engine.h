//
//  speech_engine.h
//  Grainulator
//
//  Speech synthesis engine inspired by Mutable Instruments Plaits
//  Three synthesis modes controlled by Harmonics:
//    0.0-0.33: Formant synthesis (impulse train through parallel resonators)
//    0.33-0.66: SAM-like (shaped glottal pulse + formants)
//    0.66-1.0: Word mode (formant filters sequenced through phoneme chains)
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Emilie Gillet
//

#ifndef SPEECH_ENGINE_H
#define SPEECH_ENGINE_H

#include <cmath>
#include <algorithm>
#include <cstring>

namespace Grainulator {
namespace Engines {

class SpeechEngine {
public:
    static constexpr int kNumFormants = 4;
    static constexpr int kNumPhonemes = 16;
    static constexpr int kNumWords = 8;
    static constexpr int kMaxWordLength = 8;  // max phonemes per word

    // Formant frequencies: {F1, F2, F3, F4} in Hz
    static constexpr float kPhonemeFormants[kNumPhonemes][kNumFormants] = {
        {730, 1090, 2440, 3400},   // 0: AA (father)
        {660, 1720, 2410, 3400},   // 1: AE (cat)
        {520, 1190, 2390, 3400},   // 2: AH (but)
        {390, 1990, 2550, 3400},   // 3: EH (bed)
        {270, 2290, 3010, 3400},   // 4: IY (beet)
        {300, 870, 2240, 3400},    // 5: IH (bit)
        {570, 840, 2410, 3400},    // 6: AO (bought)
        {440, 1020, 2240, 3400},   // 7: UH (book)
        {300, 870, 2240, 3400},    // 8: UW (boot)
        {270, 1000, 2200, 3400},   // 9: M/N nasal
        {350, 1300, 2300, 3400},   // 10: L approximant
        {300, 1400, 1600, 3400},   // 11: R approximant
        {280, 2500, 2900, 3400},   // 12: Y glide
        {300, 700, 2200, 3400},    // 13: W glide
        {400, 1600, 2600, 3400},   // 14: S/SH fricative
        {350, 1200, 2400, 3400},   // 15: F/TH fricative
    };

    static constexpr float kPhonemeBandwidths[kNumFormants] = {60, 90, 150, 200};

    // Per-phoneme amplitude (vowels loud, consonants shaped)
    static constexpr float kPhonemeAmplitude[kNumPhonemes] = {
        1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f,  // vowels: full
        0.6f, 0.7f, 0.7f, 0.5f, 0.5f,  // nasals/approximants/glides: reduced
        0.35f, 0.25f  // fricatives: quiet (mostly noise)
    };

    // Voiced/unvoiced mix per phoneme (0=voiced, 1=unvoiced)
    static constexpr float kPhonemeNoise[kNumPhonemes] = {
        0.02f, 0.02f, 0.02f, 0.02f, 0.02f, 0.02f, 0.02f, 0.02f, 0.02f,  // vowels: tiny breathiness
        0.08f, 0.06f, 0.10f, 0.06f, 0.12f,  // nasals/approximants/glides
        0.90f, 0.80f  // fricatives: mostly noise
    };

    // Word sequences: each word is a sequence of phoneme indices + duration weights
    struct WordEntry {
        int phonemes[kMaxWordLength];
        float durations[kMaxWordLength];  // relative duration weights
        int length;
    };

    // Pre-defined words as phoneme sequences
    static constexpr WordEntry kWords[kNumWords] = {
        // "one" = W-AH-N
        {{13, 2, 9, -1, -1, -1, -1, -1}, {0.15f, 0.55f, 0.30f, 0, 0, 0, 0, 0}, 3},
        // "two" = T-UW
        {{15, 8, -1, -1, -1, -1, -1, -1}, {0.20f, 0.80f, 0, 0, 0, 0, 0, 0}, 2},
        // "three" = TH-R-IY
        {{15, 11, 4, -1, -1, -1, -1, -1}, {0.15f, 0.15f, 0.70f, 0, 0, 0, 0, 0}, 3},
        // "four" = F-AO-R
        {{15, 6, 11, -1, -1, -1, -1, -1}, {0.15f, 0.55f, 0.30f, 0, 0, 0, 0, 0}, 3},
        // "five" = F-AA-IY-V
        {{15, 0, 4, 15, -1, -1, -1, -1}, {0.10f, 0.35f, 0.40f, 0.15f, 0, 0, 0, 0}, 4},
        // "alpha" = AE-L-F-AH
        {{1, 10, 15, 2, -1, -1, -1, -1}, {0.30f, 0.15f, 0.10f, 0.45f, 0, 0, 0, 0}, 4},
        // "red" = R-EH-D
        {{11, 3, 15, -1, -1, -1, -1, -1}, {0.15f, 0.55f, 0.30f, 0, 0, 0, 0, 0}, 3},
        // "hello" = H-EH-L-AO
        {{15, 3, 10, 6, -1, -1, -1, -1}, {0.08f, 0.32f, 0.15f, 0.45f, 0, 0, 0, 0}, 4},
    };

    SpeechEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.5f)
        , timbre_(0.5f)
        , morph_(0.5f)
        , glottal_phase_(0.0f)
        , noise_state_(12345)
        , word_phase_(0.0f)
        , current_noise_mix_(0.0f)
        , current_amplitude_(1.0f)
    {
        std::memset(filter_state_, 0, sizeof(filter_state_));
        std::memset(filter_state2_, 0, sizeof(filter_state2_));
        std::memset(word_filter_state_, 0, sizeof(word_filter_state_));
        std::memset(word_filter_state2_, 0, sizeof(word_filter_state2_));
        std::memset(current_formants_, 0, sizeof(current_formants_));
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        glottal_phase_ = 0.0f;
        word_phase_ = 0.0f;
        current_noise_mix_ = 0.0f;
        current_amplitude_ = 1.0f;
        std::memset(filter_state_, 0, sizeof(filter_state_));
        std::memset(filter_state2_, 0, sizeof(filter_state2_));
        std::memset(word_filter_state_, 0, sizeof(word_filter_state_));
        std::memset(word_filter_state2_, 0, sizeof(word_filter_state2_));
        std::memset(current_formants_, 0, sizeof(current_formants_));
    }

    void SetNote(float note) { note_ = note; }

    /// HARMONICS: Synthesis mode
    ///   0.0-0.33: Formant synthesis (impulse train through parallel resonators)
    ///   0.33-0.66: SAM-like (shaped glottal pulse)
    ///   0.66-1.0: Word mode (formant filters sequenced through phoneme chains)
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// TIMBRE: Species / formant shift
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// MORPH: In formant/SAM mode: phoneme selection
    ///        In Word mode: word selection
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    void Render(float* out, float* aux, size_t size) {
        if (harmonics_ > 0.66f) {
            RenderWords(out, aux, size);
        } else {
            RenderFormant(out, aux, size);
        }
    }

    static const char* GetName() { return "Speech"; }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;

    float glottal_phase_;
    uint32_t noise_state_;

    // Formant filter state (used by formant/SAM mode)
    float filter_state_[kNumFormants];
    float filter_state2_[kNumFormants];

    // Word mode filter state (separate to avoid interference)
    float word_filter_state_[kNumFormants];
    float word_filter_state2_[kNumFormants];

    // Word mode state
    float word_phase_;             // position within current word (0-1)
    float current_noise_mix_;      // smoothed voiced/unvoiced blend
    float current_amplitude_;      // smoothed phoneme amplitude
    float current_formants_[kNumFormants];  // smoothed formant targets

    // =========================================================================
    // Formant/SAM Mode Rendering (harmonics 0.0-0.66)
    // =========================================================================
    void RenderFormant(float* out, float* aux, size_t size) {
        float f0 = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);
        float species_shift = std::pow(2.0f, (timbre_ - 0.5f) * 2.0f);

        float formants[kNumFormants];
        InterpolateFormants(formants, morph_);
        for (int i = 0; i < kNumFormants; ++i) {
            formants[i] *= species_shift;
            formants[i] = std::min(formants[i], sample_rate_ * 0.45f);
        }

        float phoneme_idx = morph_ * (kNumPhonemes - 1);
        float fricative_amount = (phoneme_idx > 13.0f) ? (phoneme_idx - 13.0f) / 2.0f : 0.0f;
        fricative_amount = std::min(1.0f, fricative_amount);

        float base_noise_amount = harmonics_ * 0.5f;
        float noise_amount = base_noise_amount + fricative_amount * (1.0f - base_noise_amount);

        for (size_t i = 0; i < size; ++i) {
            glottal_phase_ += f0 / sample_rate_;
            if (glottal_phase_ >= 1.0f) glottal_phase_ -= 1.0f;

            float glottal;
            if (harmonics_ < 0.3f) {
                glottal = (glottal_phase_ < 0.1f) ? 1.0f : 0.0f;
            } else {
                glottal = GlottalPulse(glottal_phase_);
            }

            float noise = GenerateNoise();
            float excitation = glottal * (1.0f - noise_amount) + noise * noise_amount;

            float sample = 0.0f;
            for (int f = 0; f < kNumFormants; ++f) {
                float filtered = FormantFilter(excitation, f, formants[f], kPhonemeBandwidths[f]);
                float weight = (fricative_amount > 0.3f)
                    ? ((f < 2) ? 0.25f : 0.35f)
                    : ((f < 2) ? 0.4f : 0.2f);
                sample += filtered * weight;
            }

            sample = std::tanh(sample * 2.5f);
            if (out) out[i] = sample;
            if (aux) aux[i] = excitation * 0.5f;
        }
    }

    // =========================================================================
    // Word Mode Rendering (harmonics 0.66-1.0)
    // Uses the same parallel formant filter approach as formant mode, but
    // sequences through phoneme chains to produce word-like vocalizations.
    // =========================================================================
    void RenderWords(float* out, float* aux, size_t size) {
        float f0 = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);
        float species_shift = std::pow(2.0f, (timbre_ - 0.5f) * 2.0f);

        // Select word based on morph
        int word_idx = static_cast<int>(morph_ * (kNumWords - 1) + 0.5f);
        word_idx = std::max(0, std::min(kNumWords - 1, word_idx));
        const WordEntry& word = kWords[word_idx];

        // Fixed word duration ~500ms, independent of pitch
        float word_duration = 0.5f;
        float phase_inc = 1.0f / (sample_rate_ * word_duration);

        // Smoothing: ~5ms time constant for formants, ~3ms for amplitude
        float formant_smooth = 1.0f - std::exp(-1.0f / (0.005f * sample_rate_));
        float amp_smooth = 1.0f - std::exp(-1.0f / (0.003f * sample_rate_));

        for (size_t i = 0; i < size; ++i) {
            // Advance word phase
            word_phase_ += phase_inc;
            if (word_phase_ >= 1.0f) word_phase_ -= 1.0f;

            // Determine current phoneme from word sequence
            float cumulative = 0.0f;
            int phon_idx = 0;
            float phon_frac = 0.0f;
            for (int p = 0; p < word.length; ++p) {
                float next = cumulative + word.durations[p];
                if (word_phase_ < next || p == word.length - 1) {
                    phon_idx = p;
                    phon_frac = (word_phase_ - cumulative) / std::max(0.001f, word.durations[p]);
                    break;
                }
                cumulative = next;
            }

            // Get current and next phoneme indices
            int cur_phoneme = word.phonemes[phon_idx];
            int next_phoneme = word.phonemes[std::min(phon_idx + 1, word.length - 1)];
            if (cur_phoneme < 0) cur_phoneme = 0;
            if (next_phoneme < 0) next_phoneme = cur_phoneme;

            // Compute interpolated targets
            float target_formants[kNumFormants];
            for (int f = 0; f < kNumFormants; ++f) {
                float f_cur = kPhonemeFormants[cur_phoneme][f] * species_shift;
                float f_next = kPhonemeFormants[next_phoneme][f] * species_shift;
                target_formants[f] = f_cur + (f_next - f_cur) * phon_frac;
                target_formants[f] = std::min(target_formants[f], sample_rate_ * 0.45f);
            }

            float target_noise = kPhonemeNoise[cur_phoneme] + (kPhonemeNoise[next_phoneme] - kPhonemeNoise[cur_phoneme]) * phon_frac;
            float target_amp = kPhonemeAmplitude[cur_phoneme] + (kPhonemeAmplitude[next_phoneme] - kPhonemeAmplitude[cur_phoneme]) * phon_frac;

            // Smooth all parameters toward targets
            current_noise_mix_ += amp_smooth * (target_noise - current_noise_mix_);
            current_amplitude_ += amp_smooth * (target_amp - current_amplitude_);
            for (int f = 0; f < kNumFormants; ++f) {
                current_formants_[f] += formant_smooth * (target_formants[f] - current_formants_[f]);
            }

            // Generate excitation: glottal pulse (voiced) + noise (unvoiced)
            glottal_phase_ += f0 / sample_rate_;
            if (glottal_phase_ >= 1.0f) glottal_phase_ -= 1.0f;

            float glottal = GlottalPulse(glottal_phase_);
            float noise = GenerateNoise();
            float excitation = glottal * (1.0f - current_noise_mix_)
                             + noise * current_noise_mix_;

            // Apply parallel formant filters (same approach as formant mode)
            float sample = 0.0f;
            for (int f = 0; f < kNumFormants; ++f) {
                float filtered = WordFormantFilter(excitation, f, current_formants_[f], kPhonemeBandwidths[f]);
                float weight = (current_noise_mix_ > 0.4f)
                    ? ((f < 2) ? 0.25f : 0.35f)   // fricative: emphasize higher formants
                    : ((f < 2) ? 0.45f : 0.15f);   // voiced: emphasize F1/F2
                sample += filtered * weight;
            }

            // Apply phoneme amplitude envelope
            sample *= current_amplitude_;

            sample = std::tanh(sample * 2.5f);
            if (out) out[i] = sample;
            if (aux) aux[i] = excitation * 0.5f;
        }
    }

    // =========================================================================
    // Shared Helpers
    // =========================================================================
    void InterpolateFormants(float* out_formants, float morph) {
        float phoneme_pos = morph * (kNumPhonemes - 1);
        int phoneme0 = static_cast<int>(phoneme_pos);
        int phoneme1 = std::min(phoneme0 + 1, kNumPhonemes - 1);
        float frac = phoneme_pos - phoneme0;

        for (int i = 0; i < kNumFormants; ++i) {
            out_formants[i] = kPhonemeFormants[phoneme0][i] * (1.0f - frac)
                            + kPhonemeFormants[phoneme1][i] * frac;
        }
    }

    float GlottalPulse(float phase) {
        if (phase < 0.4f) {
            float t = phase / 0.4f;
            return 3.0f * t * t - 2.0f * t * t * t;
        } else if (phase < 0.6f) {
            float t = (phase - 0.4f) / 0.2f;
            return 1.0f - t * t;
        }
        return 0.0f;
    }

    // Formant filter for formant/SAM mode
    float FormantFilter(float input, int index, float freq, float bandwidth) {
        float omega = 2.0f * 3.14159265f * freq / sample_rate_;
        float r = std::exp(-3.14159265f * bandwidth / sample_rate_);
        float cos_omega = std::cos(omega);
        float a1 = -2.0f * r * cos_omega;
        float a2 = r * r;
        float output = input - a1 * filter_state_[index] - a2 * filter_state2_[index];
        filter_state2_[index] = filter_state_[index];
        filter_state_[index] = output;
        return output * (1.0f - r);
    }

    // Separate formant filter for word mode (independent state)
    float WordFormantFilter(float input, int index, float freq, float bandwidth) {
        float omega = 2.0f * 3.14159265f * freq / sample_rate_;
        float r = std::exp(-3.14159265f * bandwidth / sample_rate_);
        float cos_omega = std::cos(omega);
        float a1 = -2.0f * r * cos_omega;
        float a2 = r * r;
        float output = input - a1 * word_filter_state_[index] - a2 * word_filter_state2_[index];
        word_filter_state2_[index] = word_filter_state_[index];
        word_filter_state_[index] = output;
        return output * (1.0f - r);
    }

    float GenerateNoise() {
        noise_state_ = noise_state_ * 1664525 + 1013904223;
        return (static_cast<float>(noise_state_) / 2147483648.0f) - 1.0f;
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // SPEECH_ENGINE_H

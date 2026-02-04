//
//  string_engine.h
//  Grainulator
//
//  String and Modal synthesis engine inspired by Mutable Instruments Plaits
//  Implements Karplus-Strong string synthesis and modal resonator
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Émilie Gillet
//

#ifndef STRING_ENGINE_H
#define STRING_ENGINE_H

#include <cmath>
#include <algorithm>
#include <cstring>

namespace Grainulator {
namespace Engines {

/// Karplus-Strong string synthesis and Modal resonator engine
/// Creates realistic plucked string and resonant body sounds
class StringEngine {
public:
    static constexpr int kMaxDelayLength = 4096;
    static constexpr int kNumModes = 24;  // Number of modal resonator modes

    enum Mode {
        STRING_KARPLUS_STRONG = 0,  // Classic Karplus-Strong
        MODAL_RESONATOR = 1          // Modal/physical modeling
    };

    StringEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.5f)
        , timbre_(0.5f)
        , morph_(0.5f)
        , mode_(STRING_KARPLUS_STRONG)
        , delay_write_index_(0)
        , exciter_level_(0.0f)
        , dust_density_(0.0f)
        , noise_state_(12345)
        , damping_state_(0.0f)
        , allpass_z1_(0.0f)
        , allpass_z2_(0.0f)
    {
        std::memset(delay_line_, 0, sizeof(delay_line_));
        std::memset(mode_state_, 0, sizeof(mode_state_));
        std::memset(mode_velocity_, 0, sizeof(mode_velocity_));
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        delay_write_index_ = 0;
        exciter_level_ = 0.0f;

        std::memset(delay_line_, 0, sizeof(delay_line_));
        std::memset(mode_state_, 0, sizeof(mode_state_));
        std::memset(mode_velocity_, 0, sizeof(mode_velocity_));

        // Initialize noise state
        noise_state_ = 12345;
        damping_state_ = 0.0f;
        allpass_z1_ = 0.0f;
        allpass_z2_ = 0.0f;
    }

    void SetNote(float note) {
        note_ = note;
    }

    /// HARMONICS: Inharmonicity / material type
    /// String mode: Pure string -> metallic/stiff
    /// Modal mode: String -> Bar -> Bell/Membrane
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// TIMBRE: Excitation brightness
    /// Controls the spectral content of the initial excitation (dark to bright)
    /// High values also add continuous "dust" excitation
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// MORPH: Decay time / damping
    /// Low = fast decay (muted), High = long sustain (ringing)
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    /// Set synthesis mode (string or modal)
    void SetMode(Mode mode) {
        mode_ = mode;
    }

    /// Trigger the string/resonator with an excitation
    void Trigger() {
        exciter_level_ = 1.0f;

        if (mode_ == STRING_KARPLUS_STRONG) {
            // Fill delay line with filtered noise for string excitation
            FillExcitation();
        } else {
            // For modal, excite all modes with random phases and amplitudes
            for (int i = 0; i < kNumModes; ++i) {
                // Random initial phase for each mode (0 to 2*pi)
                mode_state_[i] = (GenerateNoise() + 1.0f) * 3.14159265f;

                // Initial amplitude - lower modes get more energy
                // Higher modes get progressively less to sound natural
                float mode_amp = 1.0f / (1.0f + i * 0.15f);
                // Add some randomness to make it sound more natural
                mode_amp *= 0.7f + 0.3f * (GenerateNoise() + 1.0f) * 0.5f;
                mode_velocity_[i] = mode_amp;
            }
        }
    }

    void Render(float* out, float* aux, size_t size) {
        if (mode_ == STRING_KARPLUS_STRONG) {
            RenderString(out, aux, size);
        } else {
            RenderModal(out, aux, size);
        }
    }

    static const char* GetName() {
        return "String/Modal";
    }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;
    Mode mode_;

    // Karplus-Strong delay line
    float delay_line_[kMaxDelayLength];
    int delay_write_index_;

    // Modal resonator state
    float mode_state_[kNumModes];      // Position
    float mode_velocity_[kNumModes];   // Velocity

    // Exciter
    float exciter_level_;
    float dust_density_;

    // Noise and filter state
    uint32_t noise_state_;
    float damping_state_;      // For Karplus-Strong damping filter
    float allpass_z1_;         // Allpass filter state for inharmonicity
    float allpass_z2_;         // Second allpass state

    float GenerateNoise() {
        // Linear congruential generator (more reliable than xorshift for this use)
        noise_state_ = noise_state_ * 1664525 + 1013904223;
        return (static_cast<float>(noise_state_) / 2147483648.0f) - 1.0f;
    }

    void FillExcitation() {
        // Calculate delay length from note (one period of the fundamental)
        float freq = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);
        int delay_length = static_cast<int>(sample_rate_ / freq);
        delay_length = std::min(delay_length, kMaxDelayLength - 1);
        delay_length = std::max(delay_length, 2);

        // TIMBRE controls excitation brightness:
        // Low timbre = dark pluck (like thumb), High = bright pluck (like nail/pick)
        // We use a lowpass filter on the noise, with cutoff controlled by timbre
        float brightness = timbre_;

        // Lowpass filter coefficient: higher = brighter (less filtering)
        // Range 0.3 to 0.95 ensures we always get some signal through
        float lp_coef = 0.3f + brightness * 0.65f;

        // Pre-warm the filter by running a few samples so it doesn't start at 0
        float lp_state = 0.0f;
        for (int i = 0; i < 10; ++i) {
            float noise = GenerateNoise();
            lp_state = lp_state + lp_coef * (noise - lp_state);
        }

        // Fill the entire delay line with one burst of filtered noise
        // This represents the initial "pluck" energy distribution
        for (int i = 0; i < delay_length; ++i) {
            float noise = GenerateNoise();

            // Simple one-pole lowpass filter
            lp_state = lp_state + lp_coef * (noise - lp_state);

            // Shape the excitation envelope - quick attack, full sustain for pluck
            float env = 1.0f;
            int attack_samples = std::max(1, delay_length / 20);  // Faster attack (5%)
            if (i < attack_samples) {
                env = static_cast<float>(i + 1) / static_cast<float>(attack_samples);
            }

            // Store with good amplitude - the feedback loop will handle decay
            delay_line_[i] = lp_state * env * 0.9f;
        }

        // Clear the rest of the buffer
        for (int i = delay_length; i < kMaxDelayLength; ++i) {
            delay_line_[i] = 0.0f;
        }

        // Set write index to end of filled data so read position starts at beginning
        // Read position = write_index - delay_length, so this makes it read from index 0
        delay_write_index_ = delay_length;
        damping_state_ = 0.0f;
        allpass_z1_ = 0.0f;
        allpass_z2_ = 0.0f;
    }

    void RenderString(float* out, float* aux, size_t size) {
        // Calculate delay parameters from pitch
        float freq = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);
        float delay_samples = sample_rate_ / freq;

        // Clamp delay length
        delay_samples = std::min(delay_samples, static_cast<float>(kMaxDelayLength - 2));
        delay_samples = std::max(delay_samples, 2.0f);

        int delay_int = static_cast<int>(delay_samples);
        float delay_frac = delay_samples - delay_int;

        // MORPH: Decay/sustain control
        // Higher morph = longer sustain, lower = more damping
        // The feedback coefficient determines how much energy is retained per cycle
        // Range: 0.97 (very short, muted) to 0.9999 (very long, ringing)
        float feedback = 0.97f + morph_ * 0.0299f;  // 0.97 to 0.9999

        // TIMBRE: Brightness (damping filter coefficient)
        // Classic Karplus-Strong uses averaging filter: out = (sample + prev) / 2
        // We vary the mix ratio to control how quickly high frequencies decay
        // Higher coef = brighter sound, lower = darker/warmer
        // Range: 0.05 (extremely dark/muted) to 0.99 (extremely bright/harsh)
        float damping_coef = 0.05f + timbre_ * 0.94f;  // 0.05 to 0.99

        // HARMONICS: Inharmonicity (stiffness) via allpass filter
        // Adds pitch-dependent delay that makes higher harmonics sharp (like piano/bell)
        // Range: 0 (pure harmonic string) to 0.95 (extreme stiffness, very bell-like)
        float allpass_coef = harmonics_ * 0.95f;  // 0 to 0.95

        for (size_t i = 0; i < size; ++i) {
            // Read from delay line at the correct position (one period behind write position)
            int read_pos = delay_write_index_ - delay_int;
            if (read_pos < 0) read_pos += kMaxDelayLength;

            int read_pos_prev = read_pos - 1;
            if (read_pos_prev < 0) read_pos_prev += kMaxDelayLength;

            // Fractional delay interpolation for accurate pitch
            float sample = delay_line_[read_pos] * (1.0f - delay_frac)
                         + delay_line_[read_pos_prev] * delay_frac;

            // Lowpass damping filter (one-pole IIR)
            // This is the key to the plucked string sound - removes high frequencies over time
            // Low coef = very dark (heavy smoothing), high coef = bright (follows input)
            // Using recursive filter so the effect accumulates dramatically
            damping_state_ = sample * damping_coef + damping_state_ * (1.0f - damping_coef);
            float filtered = damping_state_;

            // Optional allpass filter for inharmonicity (stiff string effect)
            // This makes higher harmonics slightly sharp, like a real piano string
            if (allpass_coef > 0.01f) {
                // First-order allpass: y[n] = coef * (x[n] - y[n-1]) + x[n-1]
                float allpass_out = allpass_coef * (filtered - allpass_z2_) + allpass_z1_;
                allpass_z1_ = filtered;
                allpass_z2_ = allpass_out;
                filtered = allpass_out;
            }

            // Apply feedback and write back to delay line
            // This is the core of Karplus-Strong: filtered output feeds back into the delay
            float feedback_sample = filtered * feedback;

            // Write the filtered+feedback signal back to delay line
            delay_line_[delay_write_index_] = feedback_sample;

            // Advance write pointer (circular buffer)
            delay_write_index_ = (delay_write_index_ + 1) % kMaxDelayLength;

            // Decay exciter level tracker
            exciter_level_ *= 0.9999f;

            // Output the sample (before feedback processing for cleaner sound)
            if (out) {
                out[i] = sample * 0.8f;  // Slight gain reduction
            }
            if (aux) {
                // Aux outputs the filtered signal for potential stereo processing
                aux[i] = filtered * 0.8f;
            }
        }
    }

    void RenderModal(float* out, float* aux, size_t size) {
        // Base frequency
        float base_freq = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);

        // Calculate modal frequencies based on inharmonicity
        // Harmonics controls the material: 0 = string-like, 1 = bell-like
        float ratios[kNumModes];
        CalculateModeRatios(ratios);

        // MORPH: Decay time - higher = longer sustain
        // Per-sample decay coefficient (0.9995 to 0.99995)
        float base_decay = 0.9995f + morph_ * 0.00045f;

        // TIMBRE: Brightness - affects amplitude of higher modes
        float brightness = timbre_;

        for (size_t i = 0; i < size; ++i) {
            float sample = 0.0f;
            float aux_sample = 0.0f;

            // Sum all modes using simple sine oscillators with decay
            for (int m = 0; m < kNumModes; ++m) {
                float freq = base_freq * ratios[m];

                // Skip modes above Nyquist
                if (freq > sample_rate_ * 0.45f) continue;

                // Phase increment for this mode's frequency
                float phase_inc = 2.0f * 3.14159265f * freq / sample_rate_;

                // Update phase (mode_state_ stores phase)
                mode_state_[m] += phase_inc;
                if (mode_state_[m] > 6.28318530718f) {
                    mode_state_[m] -= 6.28318530718f;
                }

                // Generate sine at this phase
                float sine = std::sin(mode_state_[m]);

                // Decay rate (higher modes decay faster)
                float mode_decay = base_decay - (m * 0.00005f);
                mode_decay = std::max(0.999f, mode_decay);

                // Apply decay to amplitude (mode_velocity_ stores amplitude)
                mode_velocity_[m] *= mode_decay;

                // Amplitude weighting (higher modes quieter, affected by brightness)
                // With low brightness, higher modes are attenuated more
                float amp_weight = 1.0f / (1.0f + m * (1.0f - brightness) * 0.3f);

                float mode_output = sine * mode_velocity_[m] * amp_weight;
                sample += mode_output;

                // Odd modes to aux for stereo spread
                if (m % 2 == 1) {
                    aux_sample += mode_output;
                }
            }

            // Normalize (24 modes, but higher ones are quieter)
            sample *= 0.12f;
            aux_sample *= 0.2f;

            // Soft limit
            sample = std::tanh(sample);
            aux_sample = std::tanh(aux_sample);

            if (out) {
                out[i] = sample;
            }
            if (aux) {
                aux[i] = aux_sample;
            }
        }

        // Decay exciter level tracker
        exciter_level_ *= 0.999f;
    }

    void CalculateModeRatios(float* ratios) {
        // Calculate frequency ratios for modal synthesis
        // Harmonics parameter morphs between different materials:
        // 0.0 = ideal string (harmonic series: 1, 2, 3, 4...)
        // 0.5 = stiff string/bar (slightly inharmonic)
        // 1.0 = circular membrane/bell (very inharmonic)

        float inharm = harmonics_;

        for (int m = 0; m < kNumModes; ++m) {
            float n = static_cast<float>(m + 1);

            if (inharm < 0.33f) {
                // String-like: harmonic series with slight stiffness
                float stiffness = inharm * 3.0f;
                ratios[m] = n * std::sqrt(1.0f + stiffness * n * n * 0.0001f);
            } else if (inharm < 0.66f) {
                // Bar/marimba-like: n^2 relationship
                float bar_amount = (inharm - 0.33f) * 3.0f;
                float string_ratio = n;
                float bar_ratio = n * n * 0.5f;
                ratios[m] = string_ratio * (1.0f - bar_amount) + bar_ratio * bar_amount;
            } else {
                // Bell/membrane-like: complex inharmonic ratios
                float bell_amount = (inharm - 0.66f) * 3.0f;
                // Approximate circular membrane modes
                float membrane_ratios[] = {
                    1.000f, 1.594f, 2.136f, 2.296f, 2.653f, 2.918f,
                    3.156f, 3.501f, 3.600f, 3.652f, 4.060f, 4.154f,
                    4.480f, 4.610f, 4.903f, 5.132f, 5.276f, 5.404f,
                    5.579f, 5.820f, 5.906f, 6.153f, 6.202f, 6.415f
                };
                float bar_ratio = n * n * 0.5f;
                ratios[m] = bar_ratio * (1.0f - bell_amount)
                          + membrane_ratios[m] * bell_amount;
            }
        }
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // STRING_ENGINE_H

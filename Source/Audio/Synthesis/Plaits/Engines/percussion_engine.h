//
//  percussion_engine.h
//  Grainulator
//
//  Percussion synthesis engine inspired by Mutable Instruments Plaits
//  Synthesizes kicks, snares, hihats, and other percussion
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Émilie Gillet
//

#ifndef PERCUSSION_ENGINE_H
#define PERCUSSION_ENGINE_H

#include <cmath>
#include <algorithm>

namespace Grainulator {
namespace Engines {

/// Percussion synthesis engine
/// Creates analog-style drum sounds
class PercussionEngine {
public:
    enum PercussionType {
        KICK = 0,
        SNARE = 1,
        HIHAT_CLOSED = 2,
        HIHAT_OPEN = 3,
        TOM = 4,
        CLAP = 5
    };

    PercussionEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.5f)
        , timbre_(0.5f)
        , morph_(0.0f)
        , percussion_type_(KICK)
        , noise_state_(12345)
    {
        ResetAllState();
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        ResetAllState();
    }

    void ResetAllState() {
        // Kick state
        kick_phase_ = 0.0f;
        kick_pitch_env_ = 0.0f;
        kick_amp_env_ = 0.0f;

        // Snare state
        snare_phase_ = 0.0f;
        snare_pitch_env_ = 0.0f;
        snare_amp_env_ = 0.0f;
        snare_noise_state_ = 0.0f;

        // Hihat state
        hihat_phase1_ = 0.0f;
        hihat_phase2_ = 0.0f;
        hihat_phase3_ = 0.0f;
        hihat_amp_env_ = 0.0f;
        hihat_hp_state_ = 0.0f;

        // Tom state
        tom_phase_ = 0.0f;
        tom_pitch_env_ = 0.0f;
        tom_amp_env_ = 0.0f;

        // Clap state
        clap_amp_env_ = 0.0f;
        clap_count_ = 0;
        clap_timer_ = 0;
    }

    void SetNote(float note) {
        note_ = note;
    }

    /// HARMONICS: Per-drum character parameter
    /// Kick: Punch (pitch envelope amount)
    /// Snare: Snare wire amount vs body
    /// Hihat: Metallic tone frequency
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// TIMBRE: Per-drum tone/color parameter
    /// Kick: Tone (decay time, brightness)
    /// Snare: Tone balance (low body vs high crack)
    /// Hihat: Open/closed (decay time)
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// MORPH: Decay control for all percussion
    /// Adjusts the overall amplitude envelope decay
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    /// Set the percussion type directly (called by PlaitsVoice based on engine selection)
    void SetPercussionType(PercussionType type) {
        percussion_type_ = type;
    }

    /// Trigger a new drum hit
    void Trigger() {
        switch (percussion_type_) {
            case KICK:
                kick_phase_ = 0.0f;
                kick_pitch_env_ = 1.0f;
                kick_amp_env_ = 1.0f;
                break;
            case SNARE:
                snare_phase_ = 0.0f;
                snare_pitch_env_ = 1.0f;
                snare_amp_env_ = 1.0f;
                break;
            case HIHAT_CLOSED:
            case HIHAT_OPEN:
                hihat_phase1_ = 0.0f;
                hihat_phase2_ = 0.13f;
                hihat_phase3_ = 0.37f;
                hihat_amp_env_ = 1.0f;
                break;
            case TOM:
                tom_phase_ = 0.0f;
                tom_pitch_env_ = 1.0f;
                tom_amp_env_ = 1.0f;
                break;
            case CLAP:
                clap_amp_env_ = 1.0f;
                clap_count_ = 0;
                clap_timer_ = 0;
                break;
        }
    }

    void Render(float* out, float* aux, size_t size) {
        for (size_t i = 0; i < size; ++i) {
            float sample = 0.0f;

            switch (percussion_type_) {
                case KICK:
                    sample = RenderKick();
                    break;
                case SNARE:
                    sample = RenderSnare();
                    break;
                case HIHAT_CLOSED:
                    sample = RenderHihat(false);
                    break;
                case HIHAT_OPEN:
                    sample = RenderHihat(true);
                    break;
                case TOM:
                    sample = RenderTom();
                    break;
                case CLAP:
                    sample = RenderClap();
                    break;
            }

            if (out) {
                out[i] = sample;
            }
            if (aux) {
                aux[i] = sample * 0.7f;
            }
        }
    }

    static const char* GetName() {
        return "Percussion";
    }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;
    PercussionType percussion_type_;

    // Noise generator
    uint32_t noise_state_;

    // Kick drum state
    float kick_phase_;
    float kick_pitch_env_;
    float kick_amp_env_;

    // Snare drum state
    float snare_phase_;
    float snare_pitch_env_;
    float snare_amp_env_;
    float snare_noise_state_;

    // Hihat state
    float hihat_phase1_;
    float hihat_phase2_;
    float hihat_phase3_;
    float hihat_amp_env_;
    float hihat_hp_state_;

    // Tom state
    float tom_phase_;
    float tom_pitch_env_;
    float tom_amp_env_;

    // Clap state
    float clap_amp_env_;
    int clap_count_;
    int clap_timer_;

    float RenderKick() {
        // Classic 808-style kick drum
        // Base frequency around 50 Hz with pitch sweep from ~150-400 Hz

        // Base frequency - the fundamental bass tone (around 50 Hz for deep kick)
        float base_freq = 50.0f;

        // HARMONICS: Pitch envelope amount (punch)
        // Controls how much higher the initial pitch starts (0 = subtle, 1 = aggressive click)
        // Range: start at 1.5x to 4x the base frequency
        float pitch_sweep = 0.5f + harmonics_ * 2.5f;  // 1.5x to 4x
        float freq = base_freq * (1.0f + kick_pitch_env_ * pitch_sweep);

        // VERY fast pitch decay for 808-style punch (reaches base freq in ~10-20ms)
        // This is key to getting the characteristic "thump" sound
        float pitch_decay_rate = 0.992f - harmonics_ * 0.004f;  // Faster with more punch
        kick_pitch_env_ *= pitch_decay_rate;

        // Sine oscillator for the body
        kick_phase_ += freq / sample_rate_;
        if (kick_phase_ >= 1.0f) kick_phase_ -= 1.0f;

        float sine = std::sin(kick_phase_ * 6.28318530718f);

        // MORPH: Tone / saturation
        // Low = clean sub bass, High = more drive and harmonics
        float drive = 1.0f + morph_ * 2.0f;
        float shaped = std::tanh(sine * drive);

        // TIMBRE: Decay control
        // Higher timbre = longer decay (boomy), Lower = tight/punchy
        float amp_decay = 0.9985f + timbre_ * 0.0012f;  // ~50ms to ~500ms decay
        kick_amp_env_ *= amp_decay;

        // Apply envelope
        float sample = shaped * kick_amp_env_;

        return sample * 0.95f;
    }

    float RenderSnare() {
        // Snare: tuned body + noise (snare wires)
        float base_freq = 180.0f + note_ * 1.5f;

        // Body with pitch envelope
        float freq = base_freq * (1.0f + snare_pitch_env_ * 0.5f);
        snare_pitch_env_ *= 0.95f;

        snare_phase_ += freq / sample_rate_;
        if (snare_phase_ >= 1.0f) snare_phase_ -= 1.0f;

        // Two resonant modes for body
        float body = std::sin(snare_phase_ * 6.28318530718f);
        body += std::sin(snare_phase_ * 1.5f * 6.28318530718f) * 0.5f;

        // Noise for snare wires
        float noise = GenerateNoise();

        // Simple highpass on noise
        snare_noise_state_ = 0.85f * snare_noise_state_ + 0.15f * noise;
        noise = noise - snare_noise_state_;

        // HARMONICS: Snare wire amount (body vs noise balance)
        // Low = more body (tom-like), High = more snare wires
        float body_level = 0.7f - harmonics_ * 0.5f;
        float noise_level = 0.3f + harmonics_ * 0.5f;

        // TIMBRE: Tone balance (low body emphasis vs high crack)
        // Affects frequency balance of the noise
        float hp_coef = 0.7f + timbre_ * 0.25f;  // Higher = brighter snare
        snare_noise_state_ = hp_coef * snare_noise_state_ + (1.0f - hp_coef) * noise;

        float sample = body * body_level + noise * noise_level;

        // MORPH: Decay control
        float decay = 0.997f + morph_ * 0.0025f;  // 0.997 to 0.9995
        snare_amp_env_ *= decay;

        sample *= snare_amp_env_;

        return std::tanh(sample * 1.8f) * 0.85f;
    }

    float RenderHihat(bool /* open - ignored, use timbre instead */) {
        // Hihat: metallic square waves + filtered noise
        // 808-style: 6 square wave oscillators at inharmonic ratios, ring modulated

        // HARMONICS: Metallic tone frequency
        // Low = darker/lower tone, High = brighter/higher metallic sound
        float base_freq = 200.0f + harmonics_ * 300.0f;

        // Six square oscillators with inharmonic ratios (like 808 hihat)
        // These specific ratios create the characteristic metallic sound
        float freq1 = base_freq * 1.0f;
        float freq2 = base_freq * 1.3420f;
        float freq3 = base_freq * 1.6170f;
        float freq4 = base_freq * 1.9265f;
        float freq5 = base_freq * 2.5028f;
        float freq6 = base_freq * 2.6637f;

        hihat_phase1_ += freq1 / sample_rate_;
        hihat_phase2_ += freq2 / sample_rate_;
        hihat_phase3_ += freq3 / sample_rate_;

        if (hihat_phase1_ >= 1.0f) hihat_phase1_ -= 1.0f;
        if (hihat_phase2_ >= 1.0f) hihat_phase2_ -= 1.0f;
        if (hihat_phase3_ >= 1.0f) hihat_phase3_ -= 1.0f;

        // Square waves (just using 3 for efficiency but mixing with extra harmonics)
        float sq1 = (hihat_phase1_ < 0.5f) ? 1.0f : -1.0f;
        float sq2 = (hihat_phase2_ < 0.5f) ? 1.0f : -1.0f;
        float sq3 = (hihat_phase3_ < 0.5f) ? 1.0f : -1.0f;

        // Ring modulate pairs then sum (creates complex metallic spectrum)
        float metallic = (sq1 * sq2 + sq2 * sq3 + sq1 * sq3) * 0.33f;

        // Add bandpassed noise for shimmer
        float noise = GenerateNoise();

        // Mix metallic and noise - more noise for natural feel
        float sample = metallic * 0.5f + noise * 0.5f;

        // Gentle highpass to remove low end (hihats are high frequency)
        // Using a gentler coefficient to not kill the signal
        float hp_coef = 0.8f;
        float hp_out = sample - hihat_hp_state_;
        hihat_hp_state_ += (1.0f - hp_coef) * hp_out;
        sample = hp_out;

        // TIMBRE: Open/closed character (main decay control)
        // Low = tight/closed (~20ms), High = open/ringy (~500ms)
        // MORPH: Fine-tune decay
        float decay_time_ms = 20.0f + timbre_ * 400.0f + morph_ * 200.0f;
        float decay = 1.0f - (1.0f / (decay_time_ms * sample_rate_ / 1000.0f));
        decay = std::max(0.99f, std::min(0.9999f, decay));
        hihat_amp_env_ *= decay;

        // Apply envelope with some attack shaping
        sample *= hihat_amp_env_;

        // Output with decent gain
        return std::tanh(sample * 2.0f) * 0.8f;
    }

    float RenderTom() {
        // Tom: similar to kick but higher pitched, less pitch sweep
        float base_freq = 80.0f + note_ * 2.0f;

        // Subtle pitch envelope
        float pitch_mult = 1.0f + tom_pitch_env_ * (0.5f + harmonics_ * 1.0f);
        float freq = base_freq * pitch_mult;

        tom_pitch_env_ *= 0.98f;

        tom_phase_ += freq / sample_rate_;
        if (tom_phase_ >= 1.0f) tom_phase_ -= 1.0f;

        float sine = std::sin(tom_phase_ * 6.28318530718f);

        // Slight distortion
        float sample = std::tanh(sine * (1.2f + harmonics_ * 0.8f));

        // Envelope
        float decay = 0.9992f + timbre_ * 0.0006f;
        tom_amp_env_ *= decay;

        sample *= tom_amp_env_;

        return sample * 0.85f;
    }

    float RenderClap() {
        // Clap: multiple filtered noise bursts
        float noise = GenerateNoise();

        // Bandpass filter the noise
        // Simple resonant filter approximation
        float sample = noise * 0.5f;

        clap_timer_++;

        if (clap_count_ < 4) {
            // Multiple bursts
            int burst_length = static_cast<int>(sample_rate_ * 0.012f);
            int gap_length = static_cast<int>(sample_rate_ * 0.025f);

            if (clap_timer_ < burst_length) {
                sample = noise * clap_amp_env_;
            } else if (clap_timer_ >= burst_length + gap_length) {
                clap_timer_ = 0;
                clap_count_++;
                clap_amp_env_ *= 0.75f;
            } else {
                sample = 0.0f;  // Gap between bursts
            }
        } else {
            // Final decay tail
            sample = noise * clap_amp_env_;
        }

        // Overall envelope decay
        float decay = 0.999f + timbre_ * 0.0008f;
        clap_amp_env_ *= decay;

        return std::tanh(sample * 2.0f) * 0.8f;
    }

    float GenerateNoise() {
        noise_state_ = noise_state_ * 1664525 + 1013904223;
        return (static_cast<float>(noise_state_) / 2147483648.0f) - 1.0f;
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // PERCUSSION_ENGINE_H

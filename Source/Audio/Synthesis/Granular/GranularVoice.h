//
//  GranularVoice.h
//  Grainulator
//
//  Granular synthesis voice (Mangl/MGlut-style)
//  Based on justmat's Mangl for Norns and SuperCollider's GrainBuf
//

#ifndef GRANULARVOICE_H
#define GRANULARVOICE_H

#include "ReelBuffer.h"
#include "Grain.h"
#include "MoogLadders/LadderFilterBase.h"
#include "MoogLadders/HuovilainenModel.h"
#include "MoogLadders/StilsonModel.h"
#include "MoogLadders/MicrotrackerModel.h"
#include "MoogLadders/KrajeskiModel.h"
#include "MoogLadders/MusicDSPModel.h"
#include "MoogLadders/OberheimVariationModel.h"
#include "MoogLadders/ImprovedModel.h"
#include "MoogLadders/RKSimulationModel.h"
#include "MoogLadders/HyperionModel.h"
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <memory>

namespace Grainulator {

/// Maximum number of concurrent grains per voice
static constexpr size_t kMaxGrainsPerVoice = 64;

/// Granular synthesis voice (Mangl/MGlut-style)
///
/// Key concepts (matching SuperCollider GrainBuf):
/// - POSITION: Phasor that advances through buffer based on SPEED
/// - SPEED: How fast the phasor moves (1.0 = realtime, 0 = frozen, negative = reverse)
/// - PITCH: Playback rate within each grain (affects pitch, 1.0 = normal, 2.0 = +1 octave)
/// - SIZE: Duration of each grain in seconds
/// - DENSITY: How many grains per second (Impulse trigger rate)
/// - JITTER: Random position offset per grain
/// - SPREAD: Random pan per grain
///
class GranularVoice {
public:
    enum class FilterModel {
        Huovilainen = 0,
        Stilson,
        Microtracker,
        Krajeski,
        MusicDSP,
        OberheimVariation,
        Improved,
        RKSimulation,
        Hyperion,
        Count
    };

    GranularVoice()
        : sample_rate_(48000.0f)
        , buffer_(nullptr)
        // Core Mangl parameters
        , position_(0.0f)       // Phasor position (0-1)
        , speed_(1.0f)          // Phasor rate (1.0 = realtime)
        , pitch_(1.0f)          // Grain playback rate (1.0 = normal pitch)
        , size_(0.1f)           // Grain size in SECONDS (0.001 - 0.5)
        , density_(20.0f)       // Grain trigger rate in Hz (0-512)
        , jitter_(0.0f)         // Position jitter in SECONDS (0-0.5)
        , spread_(0.0f)         // Stereo spread (0-1)
        , pan_(0.0f)            // Base pan position (-1 to +1)
        , gain_(0.8f)           // Volume (linear)
        , cutoff_(20000.0f)     // Filter cutoff Hz
        , q_(0.0f)              // Filter resonance (0-1)
        , filter_model_(FilterModel::Stilson)
        , reverse_grains_(false)
        , morph_(0.0f)          // Per-grain randomization amount
        , send_(0.0f)           // Effect send level (0-1)
        , envscale_(1.0f)       // Envelope time scale in seconds
        , window_type_(WindowType::Hanning)  // Grain envelope shape
        , decay_rate_(5.0f)    // Envelope decay rate (1.0 - 10.0)
        // Modulation inputs
        , speed_mod_(0.0f)
        , pitch_mod_(0.0f)
        , size_mod_(0.0f)
        , density_mod_(0.0f)
        , filter_mod_(0.0f)
        // Loop points (optional)
        , loop_in_(0.0f)
        , loop_out_(1.0f)
        , loop_enabled_(false)
        // Internal state
        , freeze_(false)
        , gate_(false)
        , grain_timer_(0.0f)
        , grain_interval_(0.0f)
        , num_active_grains_(0)
        , envelope_level_(0.0f)
    {
        // Initialize all grains as inactive
        for (size_t i = 0; i < kMaxGrainsPerVoice; ++i) {
            grains_[i].Reset();
        }
        CalculateGrainInterval();
        CreateFilterInstances();
        UpdateFilterParameters();
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        grain_timer_ = 0.0f;
        CalculateGrainInterval();
        CreateFilterInstances();
        UpdateFilterParameters();
    }

    // ========== Buffer Management ==========

    void SetBuffer(ReelBuffer* buffer) {
        buffer_ = buffer;
        position_ = 0.0f;
    }

    ReelBuffer* GetBuffer() const { return buffer_; }

    // ========== Core Parameters (Mangl/MGlut-style) ==========

    /// POSITION: Current phasor position (0.0 - 1.0)
    void SetPosition(float value) {
        position_ = std::max(0.0f, std::min(1.0f, value));
    }
    float GetPosition() const { return position_; }

    /// Seek to a specific position (like MGlut seek command)
    void Seek(float position) {
        position_ = std::max(0.0f, std::min(1.0f, position));
    }

    /// SPEED: Phasor rate (-2.0 to +2.0)
    /// Controls how fast position advances through buffer
    /// 1.0 = realtime/100% (position takes buf_dur to go 0→1)
    /// 0.0 = frozen/0%
    /// negative = reverse
    void SetSpeed(float value) {
        speed_ = std::max(-2.0f, std::min(2.0f, value));
    }
    float GetSpeed() const { return speed_; }

    /// PITCH: Grain playback rate (0.25 to 4.0, or use SetPitchSemitones)
    /// This is the 'rate' parameter in GrainBuf
    /// 1.0 = normal, 2.0 = +1 octave, 0.5 = -1 octave
    void SetPitch(float ratio) {
        pitch_ = std::max(0.25f, std::min(4.0f, ratio));
    }
    float GetPitch() const { return pitch_; }

    /// Set pitch in semitones (-24 to +24), hard quantized to whole steps
    void SetPitchSemitones(float semitones) {
        semitones = std::round(semitones);  // Hard quantize to whole semitones
        semitones = std::max(-24.0f, std::min(24.0f, semitones));
        pitch_ = std::pow(2.0f, semitones / 12.0f);
    }

    /// SIZE: Grain duration in SECONDS (0.001 - 3.0)
    void SetSize(float seconds) {
        size_ = std::max(0.001f, std::min(3.0f, seconds));
    }
    float GetSize() const { return size_; }

    /// Set size in milliseconds (1 - 3000)
    void SetSizeMs(float ms) {
        SetSize(ms / 1000.0f);
    }

    /// DENSITY: Grain trigger rate in Hz (0.1 - 512)
    void SetDensity(float hz) {
        density_ = std::max(0.1f, std::min(512.0f, hz));
        CalculateGrainInterval();
    }
    float GetDensity() const { return density_; }

    /// JITTER: Random position offset per grain in SECONDS (0 - 0.5)
    void SetJitter(float seconds) {
        jitter_ = std::max(0.0f, std::min(0.5f, seconds));
    }
    float GetJitter() const { return jitter_; }

    /// Set jitter in milliseconds (0 - 500)
    void SetJitterMs(float ms) {
        SetJitter(ms / 1000.0f);
    }

    /// SPREAD: Stereo spread - random pan per grain (0.0 - 1.0)
    void SetSpread(float value) {
        spread_ = std::max(0.0f, std::min(1.0f, value));
    }
    float GetSpread() const { return spread_; }

    /// PAN: Base pan position (-1.0 to +1.0)
    void SetPan(float value) {
        pan_ = std::max(-1.0f, std::min(1.0f, value));
    }
    float GetPan() const { return pan_; }

    /// GAIN: Volume (0.0 - 2.0 linear)
    void SetGain(float value) {
        gain_ = std::max(0.0f, std::min(2.0f, value));
    }
    float GetGain() const { return gain_; }

    /// FILTER CUTOFF: Low-pass filter cutoff in Hz (20 - 20000)
    void SetCutoff(float hz) {
        cutoff_ = std::max(20.0f, std::min(20000.0f, hz));
        UpdateFilterParameters();
    }
    float GetCutoff() const { return cutoff_; }

    /// FILTER Q: Filter resonance (0.0 - 1.0)
    void SetQ(float value) {
        q_ = std::max(0.0f, std::min(1.0f, value));
        UpdateFilterParameters();
    }
    float GetQ() const { return q_; }

    /// FILTER MODEL: Select which Moog ladder implementation to use.
    void SetFilterModel(FilterModel model) {
        filter_model_ = model;
        CreateFilterInstances();
        UpdateFilterParameters();
    }

    void SetFilterModelIndex(int index) {
        const int maxIndex = static_cast<int>(FilterModel::Count) - 1;
        index = std::max(0, std::min(maxIndex, index));
        SetFilterModel(static_cast<FilterModel>(index));
    }

    FilterModel GetFilterModel() const { return filter_model_; }

    /// GRAIN DIRECTION: false = forward, true = reverse
    void SetReverseGrains(bool reverse) { reverse_grains_ = reverse; }
    bool GetReverseGrains() const { return reverse_grains_; }

    /// MORPH: Per-grain randomization amount (0.0 - 1.0)
    /// Higher values increase the chance of random reverse/pitch/spread/jitter per grain.
    void SetMorphAmount(float value) {
        morph_ = std::max(0.0f, std::min(1.0f, value));
    }
    float GetMorphAmount() const { return morph_; }

    /// SEND: Effect send level (0.0 - 1.0)
    void SetSend(float value) {
        send_ = std::max(0.0f, std::min(1.0f, value));
    }
    float GetSend() const { return send_; }

    // ========== Modulation Inputs (bipolar -1 to +1) ==========

    /// Set speed modulation amount (bipolar)
    void SetSpeedMod(float mod) {
        speed_mod_ = std::max(-1.0f, std::min(1.0f, mod));
    }

    /// Set pitch modulation amount (bipolar, in semitones range)
    void SetPitchMod(float mod) {
        pitch_mod_ = std::max(-1.0f, std::min(1.0f, mod));
    }

    /// Set size modulation amount (bipolar)
    void SetSizeMod(float mod) {
        size_mod_ = std::max(-1.0f, std::min(1.0f, mod));
    }

    /// Set density modulation amount (bipolar)
    void SetDensityMod(float mod) {
        density_mod_ = std::max(-1.0f, std::min(1.0f, mod));
    }

    /// Set filter cutoff modulation amount (bipolar)
    void SetFilterMod(float mod) {
        filter_mod_ = std::max(-1.0f, std::min(1.0f, mod));
    }

    /// Get effective speed with modulation applied
    float GetEffectiveSpeed() const {
        // Modulation adds ±2 to speed range
        return std::max(-2.0f, std::min(2.0f, speed_ + speed_mod_ * 2.0f));
    }

    /// Get effective pitch with modulation applied
    float GetEffectivePitch() const {
        // Modulation adds ±1 octave (±12 semitones)
        float mod_semitones = pitch_mod_ * 12.0f;
        float mod_ratio = std::pow(2.0f, mod_semitones / 12.0f);
        return std::max(0.25f, std::min(4.0f, pitch_ * mod_ratio));
    }

    /// Get effective size with modulation applied
    float GetEffectiveSize() const {
        // Modulation scales size by ±50%
        float scale = 1.0f + size_mod_ * 0.5f;
        return std::max(0.001f, std::min(3.0f, size_ * scale));
    }

    /// Get effective density with modulation applied
    float GetEffectiveDensity() const {
        // Modulation scales density by ±200%
        float scale = 1.0f + density_mod_ * 2.0f;
        return std::max(0.1f, std::min(512.0f, density_ * scale));
    }

    /// Get effective filter cutoff with modulation applied
    float GetEffectiveCutoff() const {
        // Modulation adds ±4 octaves to cutoff
        float mod_octaves = filter_mod_ * 4.0f;
        float mod_ratio = std::pow(2.0f, mod_octaves);
        return std::max(20.0f, std::min(20000.0f, cutoff_ * mod_ratio));
    }

    /// ENVSCALE: Voice envelope time scale in seconds (0.001 - 9.0)
    void SetEnvScale(float seconds) {
        envscale_ = std::max(0.001f, std::min(9.0f, seconds));
    }
    float GetEnvScale() const { return envscale_; }

    /// WINDOW: Grain envelope shape
    void SetWindowType(WindowType type) {
        window_type_ = type;
    }
    WindowType GetWindowType() const { return window_type_; }

    /// Set window type by integer index (for UI control)
    /// 0=Hanning, 1=Gaussian, 2=Trapezoid, 3=Triangle, 4=Tukey, 5=Pluck, 6=PluckSoft, 7=ExpDecay
    void SetWindowTypeIndex(int index) {
        switch (index) {
            case 0: window_type_ = WindowType::Hanning; break;
            case 1: window_type_ = WindowType::Gaussian; break;
            case 2: window_type_ = WindowType::Trapezoid; break;
            case 3: window_type_ = WindowType::Triangle; break;
            case 4: window_type_ = WindowType::Tukey; break;
            case 5: window_type_ = WindowType::Pluck; break;
            case 6: window_type_ = WindowType::PluckSoft; break;
            case 7: window_type_ = WindowType::ExpDecay; break;
            default: window_type_ = WindowType::Hanning; break;
        }
    }

    /// DECAY: Envelope decay rate for pluck/decay envelopes (0.1 - 15.0)
    /// Lower = slower decay (longer tail), Higher = faster decay (shorter tail)
    void SetDecayRate(float rate) {
        decay_rate_ = std::max(0.1f, std::min(15.0f, rate));
    }
    float GetDecayRate() const { return decay_rate_; }

    // ========== Loop Points ==========

    void SetLoopIn(float position) {
        loop_in_ = std::max(0.0f, std::min(1.0f, position));
        if (loop_in_ > loop_out_) loop_in_ = loop_out_;
    }
    float GetLoopIn() const { return loop_in_; }

    void SetLoopOut(float position) {
        loop_out_ = std::max(0.0f, std::min(1.0f, position));
        if (loop_out_ < loop_in_) loop_out_ = loop_in_;
    }
    float GetLoopOut() const { return loop_out_; }

    void SetLoopEnabled(bool enabled) { loop_enabled_ = enabled; }
    bool GetLoopEnabled() const { return loop_enabled_; }

    // ========== Voice Control ==========

    /// GATE: Enable/disable grain generation
    void SetGate(bool gate) { gate_ = gate; }
    bool GetGate() const { return gate_; }

    /// FREEZE: Stop phasor advancement (grains still trigger from current position)
    void SetFreeze(bool freeze) { freeze_ = freeze; }
    bool GetFreeze() const { return freeze_; }

    /// Legacy compatibility
    void SetPlaying(bool playing) { SetGate(playing); }
    bool IsPlaying() const { return gate_; }

    // ========== Audio Processing ==========

    /// Render audio output
    void Render(float* out_left, float* out_right, size_t num_frames) {
        if (!buffer_ || buffer_->GetLength() == 0) {
            // No buffer loaded - output silence
            for (size_t i = 0; i < num_frames; ++i) {
                out_left[i] = 0.0f;
                out_right[i] = 0.0f;
            }
            return;
        }

        float buffer_length = static_cast<float>(buffer_->GetLength());
        float buffer_duration = buffer_length / sample_rate_;

        // Calculate envelope coefficient for gate on/off (ASR envelope like MGlut)
        float env_coef = 1.0f - std::exp(-1.0f / (envscale_ * sample_rate_));

        for (size_t i = 0; i < num_frames; ++i) {
            // Update voice envelope based on gate state
            float env_target = gate_ ? 1.0f : 0.0f;
            envelope_level_ += env_coef * (env_target - envelope_level_);

            // Get effective modulated values
            float effective_speed = GetEffectiveSpeed();
            float effective_density = GetEffectiveDensity();

            // Advance phasor position (like SC's Phasor.kr)
            // Rate = speed / buffer_duration (so at speed=1, takes buf_dur to go 0→1)
            if (!freeze_ && gate_) {
                float phasor_rate = effective_speed / (buffer_duration * sample_rate_);
                position_ += phasor_rate;

                // Wrap position
                if (loop_enabled_) {
                    float loop_length = loop_out_ - loop_in_;
                    if (loop_length > 0.001f) {
                        if (effective_speed > 0.0f && position_ >= loop_out_) {
                            position_ = loop_in_ + std::fmod(position_ - loop_in_, loop_length);
                        } else if (effective_speed < 0.0f && position_ < loop_in_) {
                            position_ = loop_out_ - std::fmod(loop_in_ - position_, loop_length);
                        }
                    }
                } else {
                    while (position_ >= 1.0f) position_ -= 1.0f;
                    while (position_ < 0.0f) position_ += 1.0f;
                }
            }

            // Trigger grains at density rate (like SC's Impulse.kr)
            // Recalculate interval based on modulated density
            float mod_grain_interval = (effective_density <= 0.1f) ? sample_rate_ * 10.0f : sample_rate_ / effective_density;
            if (gate_ && effective_density > 0.0f) {
                grain_timer_ += 1.0f;
                if (grain_timer_ >= mod_grain_interval) {
                    SpawnGrain();
                    grain_timer_ = 0.0f;
                }
            }

            // Render all active grains
            float sample_l = 0.0f;
            float sample_r = 0.0f;
            num_active_grains_ = 0;

            for (size_t g = 0; g < kMaxGrainsPerVoice; ++g) {
                Grain& grain = grains_[g];
                if (!grain.active) continue;

                num_active_grains_++;

                // Get grain envelope amplitude (Hanning window)
                float env = grain.GetEnvelopeAmplitude();

                // Read from buffer at grain's current position
                // Position wraps within buffer
                float read_pos = std::fmod(grain.position, buffer_length);
                if (read_pos < 0.0f) read_pos += buffer_length;

                // 4-point Hermite interpolation for quality pitched playback
                size_t idx0 = static_cast<size_t>(read_pos);
                size_t buf_len = static_cast<size_t>(buffer_length);
                size_t idx_m1 = (idx0 > 0) ? idx0 - 1 : buf_len - 1;
                size_t idx1 = (idx0 + 1) % buf_len;
                size_t idx2 = (idx0 + 2) % buf_len;
                float frac = read_pos - static_cast<float>(idx0);

                // Hermite cubic for left channel
                float y0L = buffer_->GetSampleInt(0, idx_m1);
                float y1L = buffer_->GetSampleInt(0, idx0);
                float y2L = buffer_->GetSampleInt(0, idx1);
                float y3L = buffer_->GetSampleInt(0, idx2);
                float c0L = y1L;
                float c1L = 0.5f * (y2L - y0L);
                float c2L = y0L - 2.5f * y1L + 2.0f * y2L - 0.5f * y3L;
                float c3L = 0.5f * (y3L - y0L) + 1.5f * (y1L - y2L);
                float samp_l = ((c3L * frac + c2L) * frac + c1L) * frac + c0L;

                // Hermite cubic for right channel
                float y0R = buffer_->GetSampleInt(1, idx_m1);
                float y1R = buffer_->GetSampleInt(1, idx0);
                float y2R = buffer_->GetSampleInt(1, idx1);
                float y3R = buffer_->GetSampleInt(1, idx2);
                float c0R = y1R;
                float c1R = 0.5f * (y2R - y0R);
                float c2R = y0R - 2.5f * y1R + 2.0f * y2R - 0.5f * y3R;
                float c3R = 0.5f * (y3R - y0R) + 1.5f * (y1R - y2R);
                float samp_r = ((c3R * frac + c2R) * frac + c1R) * frac + c0R;

                // Apply grain envelope
                samp_l *= env;
                samp_r *= env;

                // Apply pan (equal power)
                float pan_l, pan_r;
                grain.GetPanGains(pan_l, pan_r);
                sample_l += samp_l * pan_l;
                sample_r += samp_r * pan_r;

                // Advance grain playback position by pitch rate
                // This is how GrainBuf works - pitch affects playback rate within grain
                grain.position += grain.pitch_ratio;
                if (grain.position >= buffer_length || grain.position < 0.0f) {
                    grain.position = std::fmod(grain.position, buffer_length);
                    if (grain.position < 0.0f) grain.position += buffer_length;
                }

                // Advance grain envelope phase
                grain.phase += 1.0f / grain.duration_samples;
                if (grain.phase >= 1.0f) {
                    grain.active = false;
                }
            }

            // Apply voice envelope
            sample_l *= envelope_level_;
            sample_r *= envelope_level_;

            // Apply gain
            sample_l *= gain_;
            sample_r *= gain_;

            // Apply 4-pole Moog-style ladder low-pass filter with modulation
            float effective_cutoff = GetEffectiveCutoff();
            if (effective_cutoff < 19500.0f) {
                ApplyFilterWithCutoff(sample_l, sample_r, effective_cutoff);
            }

            // Soft clip output
            out_left[i] = std::tanh(sample_l);
            out_right[i] = std::tanh(sample_r);
        }
    }

    size_t GetNumActiveGrains() const { return num_active_grains_; }

    // ========== Legacy compatibility methods ==========
    void SetSlide(float value) { SetPosition(value); }
    void SetGeneSize(float seconds) { SetSize(seconds); }
    void SetMorph(float value) { SetMorphAmount(value); }
    void SetVarispeed(float value) { SetSpeed(value); }
    void SetFilterCutoff(float hz) { SetCutoff(hz); }
    void SetFilterResonance(float value) { SetQ(value); }
    void SetLevel(float level) { SetGain(level); }
    void SetActiveSplice(size_t) {}
    size_t GetActiveSplice() const { return 0; }

private:
    float sample_rate_;
    ReelBuffer* buffer_;

    // Core Mangl parameters
    float position_;    // Phasor position (0-1)
    float speed_;       // Phasor rate
    float pitch_;       // Grain playback rate
    float size_;        // Grain size in seconds
    float density_;     // Grain trigger rate in Hz
    float jitter_;      // Position jitter in seconds
    float spread_;      // Stereo spread
    float pan_;         // Base pan
    float gain_;        // Volume (linear)
    float cutoff_;      // Filter cutoff
    float q_;           // Filter resonance
    FilterModel filter_model_; // Active Moog ladder implementation
    bool reverse_grains_; // Reverse playback direction for spawned grains
    float morph_;       // Per-grain randomization amount
    float send_;        // Effect send
    float envscale_;    // Envelope time
    WindowType window_type_;  // Grain envelope shape
    float decay_rate_;  // Envelope decay rate for pluck/decay envelopes

    // Modulation inputs (bipolar -1 to +1)
    float speed_mod_;
    float pitch_mod_;
    float size_mod_;
    float density_mod_;
    float filter_mod_;

    // Loop points
    float loop_in_;
    float loop_out_;
    bool loop_enabled_;

    // State
    bool freeze_;
    bool gate_;
    float grain_timer_;
    float grain_interval_;
    float envelope_level_;

    // Grain pool
    Grain grains_[kMaxGrainsPerVoice];
    size_t num_active_grains_;

    // Selected filter instances, one per stereo channel.
    std::unique_ptr<LadderFilterBase> filter_l_;
    std::unique_ptr<LadderFilterBase> filter_r_;

    // Simple noise generator
    uint32_t noise_state_ = 12345;

    float GenerateRandom() {
        noise_state_ = noise_state_ * 1664525 + 1013904223;
        return static_cast<float>(noise_state_) / 4294967296.0f;
    }

    float GenerateRandomBipolar() {
        return GenerateRandom() * 2.0f - 1.0f;
    }

    void CalculateGrainInterval() {
        if (density_ <= 0.1f) {
            grain_interval_ = sample_rate_ * 10.0f;  // Very slow
        } else {
            grain_interval_ = sample_rate_ / density_;
        }
    }

    void SpawnGrain() {
        if (!buffer_) return;

        // Find an inactive grain slot
        size_t slot = kMaxGrainsPerVoice;
        for (size_t i = 0; i < kMaxGrainsPerVoice; ++i) {
            if (!grains_[i].active) {
                slot = i;
                break;
            }
        }

        // If no free slot, steal oldest grain
        if (slot >= kMaxGrainsPerVoice) {
            float oldest_phase = 0.0f;
            for (size_t i = 0; i < kMaxGrainsPerVoice; ++i) {
                if (grains_[i].phase > oldest_phase) {
                    oldest_phase = grains_[i].phase;
                    slot = i;
                }
            }
        }

        if (slot >= kMaxGrainsPerVoice) return;

        float buffer_length = static_cast<float>(buffer_->GetLength());
        float buffer_duration = buffer_length / sample_rate_;

        // Calculate grain start position
        // Base position from phasor (0-1), converted to samples
        float grain_position = position_ * buffer_length;

        const bool morphEnabled = morph_ > 0.0f;
        const auto morphActivate = [this, morphEnabled]() -> bool {
            return morphEnabled && (GenerateRandom() < morph_);
        };
        const bool morphJitterActive = morphActivate();
        const bool morphSpreadActive = morphActivate();
        const bool morphReverseActive = morphActivate();
        const bool morphPitchActive = morphActivate();

        // Apply jitter (random offset in samples)
        // MGlut: jitter_sig = TRand(-jitter/buf_dur, jitter/buf_dur)
        // We have jitter in seconds, convert to normalized then to samples
        float effectiveJitter = jitter_;
        if (morphJitterActive) {
            // Add jitter even when base jitter is low; tops out near 250ms at full morph.
            const float morphJitterSeconds = 0.01f + morph_ * 0.24f;
            effectiveJitter = std::max(effectiveJitter, morphJitterSeconds);
        }
        if (effectiveJitter > 0.0f) {
            float jitter_normalized = effectiveJitter / buffer_duration;
            float jitter_offset = GenerateRandomBipolar() * jitter_normalized * buffer_length;
            grain_position += jitter_offset;

            // Wrap within buffer
            while (grain_position >= buffer_length) grain_position -= buffer_length;
            while (grain_position < 0.0f) grain_position += buffer_length;
        }

        // Grain duration in samples (use modulated size)
        float effective_size = GetEffectiveSize();
        float duration_samples = effective_size * sample_rate_;

        // Initialize grain
        Grain& grain = grains_[slot];
        grain.active = true;
        grain.position = grain_position;
        grain.position_start = grain_position;
        grain.phase = 0.0f;
        grain.duration_samples = duration_samples;

        // Use modulated pitch as base
        float grainPitchRatio = GetEffectivePitch();
        if (morphPitchActive) {
            // Discrete octave choices for morph pitch: unison, -1 octave, +1 octave.
            const float octaveChoices[3] = {1.0f, 0.5f, 2.0f};
            const int choiceIndex = static_cast<int>(GenerateRandom() * 3.0f);
            grainPitchRatio *= octaveChoices[std::min(choiceIndex, 2)];
        }
        grainPitchRatio = std::max(0.125f, std::min(8.0f, grainPitchRatio));

        const bool grainReverse = reverse_grains_ || morphReverseActive;
        grain.pitch_ratio = grainReverse ? -grainPitchRatio : grainPitchRatio;  // GrainBuf rate parameter
        grain.amplitude = 1.0f;
        grain.window_type = window_type_;  // Use voice's envelope setting
        grain.decay_rate = decay_rate_;    // Use voice's decay rate

        // Apply pan with spread
        // MGlut: pan_sig = TRand(-spread, spread)
        float grain_pan = pan_;
        float effectiveSpread = spread_;
        if (morphSpreadActive) {
            // Morph can force wider spatial variance even when spread is low.
            const float morphSpreadAmount = 0.35f + morph_ * 0.65f;
            effectiveSpread = std::max(effectiveSpread, morphSpreadAmount);
        }
        if (effectiveSpread > 0.0f) {
            grain_pan += GenerateRandomBipolar() * effectiveSpread;
            grain_pan = std::max(-1.0f, std::min(1.0f, grain_pan));
        }
        grain.pan = grain_pan;
    }

    std::unique_ptr<LadderFilterBase> CreateFilterInstance(FilterModel model) const {
        switch (model) {
            case FilterModel::Huovilainen: return std::make_unique<HuovilainenMoog>(sample_rate_);
            case FilterModel::Stilson: return std::make_unique<StilsonMoog>(sample_rate_);
            case FilterModel::Microtracker: return std::make_unique<MicrotrackerMoog>(sample_rate_);
            case FilterModel::Krajeski: return std::make_unique<KrajeskiMoog>(sample_rate_);
            case FilterModel::MusicDSP: return std::make_unique<MusicDSPMoog>(sample_rate_);
            case FilterModel::OberheimVariation: return std::make_unique<OberheimVariationMoog>(sample_rate_);
            case FilterModel::Improved: return std::make_unique<ImprovedMoog>(sample_rate_);
            case FilterModel::RKSimulation: return std::make_unique<RKSimulationMoog>(sample_rate_);
            case FilterModel::Hyperion: return std::make_unique<HyperionMoog>(sample_rate_);
            case FilterModel::Count: break;
        }

        return std::make_unique<HyperionMoog>(sample_rate_);
    }

    void CreateFilterInstances() {
        filter_l_ = CreateFilterInstance(filter_model_);
        filter_r_ = CreateFilterInstance(filter_model_);
    }

    void UpdateFilterParameters() {
        if (!filter_l_ || !filter_r_) return;

        // Model-specific stability limits.
        float cutoffLimit = 0.45f;
        float resonanceMax = 1.0f;
        switch (filter_model_) {
            case FilterModel::Huovilainen:        cutoffLimit = 0.38f; resonanceMax = 0.74f; break;
            case FilterModel::Stilson:            cutoffLimit = 0.45f; resonanceMax = 0.95f; break;
            case FilterModel::Microtracker:       cutoffLimit = 0.45f; resonanceMax = 0.92f; break;
            case FilterModel::Krajeski:           cutoffLimit = 0.45f; resonanceMax = 0.93f; break;
            case FilterModel::MusicDSP:           cutoffLimit = 0.42f; resonanceMax = 0.88f; break;
            case FilterModel::OberheimVariation:  cutoffLimit = 0.40f; resonanceMax = 0.86f; break;
            case FilterModel::Improved:           cutoffLimit = 0.40f; resonanceMax = 0.82f; break;
            case FilterModel::RKSimulation:       cutoffLimit = 0.35f; resonanceMax = 0.55f; break;
            case FilterModel::Hyperion:           cutoffLimit = 0.42f; resonanceMax = 0.88f; break;
            case FilterModel::Count: break;
        }

        const float nyquist = sample_rate_ * 0.5f;
        const float safeCutoff = std::max(20.0f, std::min(cutoff_, nyquist * cutoffLimit));
        const float safeResonance = std::max(0.0f, std::min(q_, resonanceMax));

        filter_l_->SetCutoff(safeCutoff);
        filter_r_->SetCutoff(safeCutoff);
        filter_l_->SetResonance(safeResonance);
        filter_r_->SetResonance(safeResonance);
    }

    void ApplyFilter(float& sample_l, float& sample_r) {
        ApplyFilterWithCutoff(sample_l, sample_r, cutoff_);
    }

    void ApplyFilterWithCutoff(float& sample_l, float& sample_r, float cutoff) {
        if (!filter_l_ || !filter_r_) return;

        // Model-specific stability limits
        float cutoffLimit = 0.45f;
        switch (filter_model_) {
            case FilterModel::Huovilainen:        cutoffLimit = 0.38f; break;
            case FilterModel::Stilson:            cutoffLimit = 0.45f; break;
            case FilterModel::Microtracker:       cutoffLimit = 0.45f; break;
            case FilterModel::Krajeski:           cutoffLimit = 0.45f; break;
            case FilterModel::MusicDSP:           cutoffLimit = 0.42f; break;
            case FilterModel::OberheimVariation:  cutoffLimit = 0.40f; break;
            case FilterModel::Improved:           cutoffLimit = 0.40f; break;
            case FilterModel::RKSimulation:       cutoffLimit = 0.35f; break;
            case FilterModel::Hyperion:           cutoffLimit = 0.42f; break;
            case FilterModel::Count: break;
        }

        const float nyquist = sample_rate_ * 0.5f;
        const float safeCutoff = std::max(20.0f, std::min(cutoff, nyquist * cutoffLimit));

        // Update filter cutoff for modulation
        filter_l_->SetCutoff(safeCutoff);
        filter_r_->SetCutoff(safeCutoff);

        sample_l = std::max(-8.0f, std::min(8.0f, sample_l));
        sample_r = std::max(-8.0f, std::min(8.0f, sample_r));
        filter_l_->Process(&sample_l, 1);
        filter_r_->Process(&sample_r, 1);

        // Guard against unstable states and denormals in some ladder variants.
        if (!std::isfinite(sample_l) || !std::isfinite(sample_r)) {
            sample_l = 0.0f;
            sample_r = 0.0f;
            CreateFilterInstances();
            UpdateFilterParameters();
            return;
        }

        sample_l = std::tanh(sample_l * 0.5f) * 2.0f;
        sample_r = std::tanh(sample_r * 0.5f) * 2.0f;
        if (std::fabs(sample_l) < 1.0e-20f) sample_l = 0.0f;
        if (std::fabs(sample_r) < 1.0e-20f) sample_r = 0.0f;
    }
};

} // namespace Grainulator

#endif // GRANULARVOICE_H

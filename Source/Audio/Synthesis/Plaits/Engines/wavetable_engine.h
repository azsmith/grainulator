//
//  wavetable_engine.h
//  Grainulator
//
//  Wavetable synthesis engine inspired by Mutable Instruments Plaits
//  Interpolates between different waveforms in a 2D table
//  Supports custom user wavetable loading (bank 4)
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Emilie Gillet
//

#ifndef WAVETABLE_ENGINE_H
#define WAVETABLE_ENGINE_H

#include <cmath>
#include <algorithm>
#include <cstring>

namespace Grainulator {
namespace Engines {

class WavetableEngine {
public:
    static constexpr int kTableSize = 256;
    static constexpr int kNumWaveforms = 8;
    static constexpr int kNumBanks = 5;       // 4 built-in + 1 user
    static constexpr int kUserBank = 4;

    WavetableEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.0f)
        , timbre_(0.5f)
        , morph_(0.5f)
        , phase_(0.0f)
        , has_user_wavetable_(false)
    {
        GenerateWavetables();
        // Initialize user bank to sine
        for (int r = 0; r < kNumWaveforms; ++r) {
            for (int c = 0; c < kNumWaveforms; ++c) {
                for (int s = 0; s < kTableSize; ++s) {
                    float ph = static_cast<float>(s) / kTableSize;
                    wavetables_[kUserBank][r][c][s] = std::sin(ph * 6.28318530718f);
                }
            }
        }
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        phase_ = 0.0f;
    }

    void SetNote(float note) { note_ = note; }

    /// HARMONICS: Selects wavetable bank
    /// 0.0-0.39: Banks 0-3 interpolated
    /// 0.4-0.79: Banks 0-3 non-interpolated (discrete)
    /// 0.8-1.0: User bank (4) interpolated
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// TIMBRE: Row index (Y axis)
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// MORPH: Column index (X axis)
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    /// Load user wavetable from raw float samples.
    /// Samples are sliced into 256-sample frames and distributed across 8x8 grid.
    /// @param data  Raw float samples, normalized -1.0 to 1.0
    /// @param num_samples  Total number of samples
    /// @param frame_size  Samples per waveform frame (default 256, or 0 for auto)
    void LoadUserWavetable(const float* data, int num_samples, int frame_size = 0) {
        if (!data || num_samples < kTableSize) return;

        if (frame_size <= 0) frame_size = kTableSize;
        int num_frames = num_samples / frame_size;
        int total_slots = kNumWaveforms * kNumWaveforms; // 64

        for (int slot = 0; slot < total_slots; ++slot) {
            int row = slot / kNumWaveforms;
            int col = slot % kNumWaveforms;

            // Map slot to source frame (wrap if fewer frames than slots)
            int src_frame = (num_frames > total_slots)
                ? static_cast<int>(static_cast<float>(slot) / total_slots * num_frames)
                : slot % num_frames;
            int src_offset = src_frame * frame_size;

            // Resample source frame to kTableSize
            for (int s = 0; s < kTableSize; ++s) {
                float src_pos = static_cast<float>(s) / kTableSize * frame_size;
                int idx0 = static_cast<int>(src_pos);
                float frac = src_pos - idx0;
                int idx1 = idx0 + 1;

                float s0 = (src_offset + idx0 < num_samples)
                    ? data[src_offset + idx0] : 0.0f;
                float s1 = (src_offset + idx1 < num_samples)
                    ? data[src_offset + idx1] : s0;

                wavetables_[kUserBank][row][col][s] = s0 * (1.0f - frac) + s1 * frac;
            }
        }

        has_user_wavetable_ = true;
    }

    bool HasUserWavetable() const { return has_user_wavetable_; }

    void Render(float* out, float* aux, size_t size) {
        float freq = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);
        float phase_inc = freq / sample_rate_;

        // Bank selection from harmonics
        int bank;
        bool interpolate;
        if (harmonics_ >= 0.8f && has_user_wavetable_) {
            // User wavetable bank
            bank = kUserBank;
            interpolate = true;
        } else if (harmonics_ >= 0.8f) {
            // No user wavetable loaded, fall back to bank 3
            bank = 3;
            interpolate = true;
        } else {
            int bank_idx = static_cast<int>(harmonics_ * 7.99f);
            interpolate = (bank_idx < 4);
            bank = bank_idx % 4;
        }

        float wave_x = morph_ * (kNumWaveforms - 1);
        float wave_y = timbre_ * (kNumWaveforms - 1);

        int wx0 = static_cast<int>(wave_x);
        int wx1 = std::min(wx0 + 1, kNumWaveforms - 1);
        float wx_frac = wave_x - wx0;

        int wy0 = static_cast<int>(wave_y);
        int wy1 = std::min(wy0 + 1, kNumWaveforms - 1);
        float wy_frac = wave_y - wy0;

        for (size_t i = 0; i < size; ++i) {
            float sample;

            if (interpolate) {
                float s00 = ReadWavetable(bank, wy0, wx0, phase_);
                float s01 = ReadWavetable(bank, wy0, wx1, phase_);
                float s10 = ReadWavetable(bank, wy1, wx0, phase_);
                float s11 = ReadWavetable(bank, wy1, wx1, phase_);

                float s0 = s00 * (1.0f - wx_frac) + s01 * wx_frac;
                float s1 = s10 * (1.0f - wx_frac) + s11 * wx_frac;

                sample = s0 * (1.0f - wy_frac) + s1 * wy_frac;
            } else {
                sample = ReadWavetable(bank, wy0, wx0, phase_);
            }

            phase_ += phase_inc;
            if (phase_ >= 1.0f) phase_ -= 1.0f;

            if (out) out[i] = sample;
            if (aux) {
                float lofi = std::floor(sample * 16.0f) / 16.0f;
                aux[i] = lofi;
            }
        }
    }

    static const char* GetName() { return "Wavetable"; }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;
    float phase_;
    bool has_user_wavetable_;

    // Wavetables: [bank][row][column][sample]
    // 5 banks x 8 rows x 8 columns x 256 samples
    float wavetables_[kNumBanks][kNumWaveforms][kNumWaveforms][kTableSize];

    void GenerateWavetables() {
        for (int row = 0; row < kNumWaveforms; ++row)
            for (int col = 0; col < kNumWaveforms; ++col)
                GenerateHarmonicWave(0, row, col);

        for (int row = 0; row < kNumWaveforms; ++row)
            for (int col = 0; col < kNumWaveforms; ++col)
                GenerateFormantWave(1, row, col);

        for (int row = 0; row < kNumWaveforms; ++row)
            for (int col = 0; col < kNumWaveforms; ++col)
                GenerateWaveshapedWave(2, row, col);

        for (int row = 0; row < kNumWaveforms; ++row)
            for (int col = 0; col < kNumWaveforms; ++col)
                GenerateDigitalWave(3, row, col);
    }

    void GenerateHarmonicWave(int bank, int row, int col) {
        int num_harmonics = 1 + row * 2;
        float odd_even = static_cast<float>(col) / (kNumWaveforms - 1);

        for (int s = 0; s < kTableSize; ++s) {
            float phase = static_cast<float>(s) / kTableSize;
            float sample = 0.0f;

            for (int h = 1; h <= num_harmonics; ++h) {
                float amp = 1.0f / h;
                if (h % 2 == 0) amp *= odd_even;
                else amp *= (1.0f - odd_even * 0.5f);
                sample += std::sin(phase * h * 6.28318530718f) * amp;
            }

            wavetables_[bank][row][col][s] = sample * 0.5f;
        }
    }

    void GenerateFormantWave(int bank, int row, int col) {
        float formant_freq = 2.0f + row * 2.0f;
        float width = 0.1f + col * 0.1f;

        for (int s = 0; s < kTableSize; ++s) {
            float phase = static_cast<float>(s) / kTableSize;
            float window = 0.5f - 0.5f * std::cos(phase * 6.28318530718f);
            window = std::pow(window, width);
            float formant = std::sin(phase * formant_freq * 6.28318530718f);
            wavetables_[bank][row][col][s] = formant * window;
        }
    }

    void GenerateWaveshapedWave(int bank, int row, int col) {
        float fold = 1.0f + col * 0.5f;

        for (int s = 0; s < kTableSize; ++s) {
            float phase = static_cast<float>(s) / kTableSize;
            float sample;

            if (row < 3) sample = std::sin(phase * 6.28318530718f);
            else if (row < 5) sample = (phase < 0.5f) ? (4.0f * phase - 1.0f) : (3.0f - 4.0f * phase);
            else sample = 2.0f * phase - 1.0f;

            sample *= fold;
            while (sample > 1.0f || sample < -1.0f) {
                if (sample > 1.0f) sample = 2.0f - sample;
                if (sample < -1.0f) sample = -2.0f - sample;
            }

            wavetables_[bank][row][col][s] = sample;
        }
    }

    void GenerateDigitalWave(int bank, int row, int col) {
        int bits = 2 + row;
        float levels = std::pow(2.0f, bits);
        float distortion = col * 0.5f;

        for (int s = 0; s < kTableSize; ++s) {
            float phase = static_cast<float>(s) / kTableSize;

            if (distortion > 0.0f) {
                if (phase < 0.5f)
                    phase = phase * (1.0f + distortion) / (0.5f + distortion * 0.5f);
                else
                    phase = (phase - 0.5f) * (1.0f - distortion * 0.5f) / 0.5f + 0.5f + distortion * 0.25f;
                phase = std::fmod(phase, 1.0f);
            }

            float sample = std::sin(phase * 6.28318530718f);
            sample = std::floor(sample * levels) / levels;
            wavetables_[bank][row][col][s] = sample;
        }
    }

    float ReadWavetable(int bank, int row, int col, float phase) {
        float pos = phase * kTableSize;
        int idx0 = static_cast<int>(pos) % kTableSize;
        int idx1 = (idx0 + 1) % kTableSize;
        float frac = pos - std::floor(pos);

        return wavetables_[bank][row][col][idx0] * (1.0f - frac)
             + wavetables_[bank][row][col][idx1] * frac;
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // WAVETABLE_ENGINE_H

//
//  wavetable_engine.h
//  Grainulator
//
//  Wavetable synthesis engine inspired by Mutable Instruments Plaits
//  Interpolates between different waveforms in a 2D table
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Émilie Gillet
//

#ifndef WAVETABLE_ENGINE_H
#define WAVETABLE_ENGINE_H

#include <cmath>
#include <algorithm>

namespace Grainulator {
namespace Engines {

/// Wavetable synthesis engine
/// Provides 2D wavetable morphing with multiple banks
class WavetableEngine {
public:
    static constexpr int kTableSize = 256;
    static constexpr int kNumWaveforms = 8;

    WavetableEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.0f)
        , timbre_(0.5f)
        , morph_(0.5f)
        , phase_(0.0f)
    {
        GenerateWavetables();
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        phase_ = 0.0f;
    }

    void SetNote(float note) {
        note_ = note;
    }

    /// HARMONICS: Selects wavetable bank
    /// Banks 0-3: Interpolated wavetables
    /// Banks 4-7: Non-interpolated (discrete steps)
    /// Bank A: Additive (sine harmonics, organ)
    /// Bank B: Formant/waveshaper-derived
    /// Bank C: Shruthi-1/Ambika samples
    /// Bank D: Semi-random permutation
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// TIMBRE: Row index - typically sorted by brightness
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// MORPH: Column index - character/waveshape variation
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    void Render(float* out, float* aux, size_t size) {
        float freq = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);
        float phase_inc = freq / sample_rate_;

        // Select bank and interpolation mode
        int bank = static_cast<int>(harmonics_ * 7.99f);
        bool interpolate = (bank < 4);
        bank = bank % 4;

        // Get waveform indices based on timbre (Y) and morph (X)
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
                // Bilinear interpolation between 4 waveforms
                float s00 = ReadWavetable(bank, wy0, wx0, phase_);
                float s01 = ReadWavetable(bank, wy0, wx1, phase_);
                float s10 = ReadWavetable(bank, wy1, wx0, phase_);
                float s11 = ReadWavetable(bank, wy1, wx1, phase_);

                float s0 = s00 * (1.0f - wx_frac) + s01 * wx_frac;
                float s1 = s10 * (1.0f - wx_frac) + s11 * wx_frac;

                sample = s0 * (1.0f - wy_frac) + s1 * wy_frac;
            } else {
                // Discrete selection (no interpolation)
                sample = ReadWavetable(bank, wy0, wx0, phase_);
            }

            // Advance phase
            phase_ += phase_inc;
            if (phase_ >= 1.0f) phase_ -= 1.0f;

            if (out) {
                out[i] = sample;
            }
            if (aux) {
                // Lo-fi version for aux (reduced bit depth simulation)
                float lofi = std::floor(sample * 16.0f) / 16.0f;
                aux[i] = lofi;
            }
        }
    }

    static const char* GetName() {
        return "Wavetable";
    }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;
    float phase_;

    // Wavetables: [bank][row][column][sample]
    // We'll generate 4 banks x 8 rows x 8 columns = 32 unique waveforms per bank
    float wavetables_[4][kNumWaveforms][kNumWaveforms][kTableSize];

    void GenerateWavetables() {
        // Bank 0: Harmonic series (organ-like)
        for (int row = 0; row < kNumWaveforms; ++row) {
            for (int col = 0; col < kNumWaveforms; ++col) {
                GenerateHarmonicWave(0, row, col);
            }
        }

        // Bank 1: Formant-like waves
        for (int row = 0; row < kNumWaveforms; ++row) {
            for (int col = 0; col < kNumWaveforms; ++col) {
                GenerateFormantWave(1, row, col);
            }
        }

        // Bank 2: Waveshaped/folded waves
        for (int row = 0; row < kNumWaveforms; ++row) {
            for (int col = 0; col < kNumWaveforms; ++col) {
                GenerateWaveshapedWave(2, row, col);
            }
        }

        // Bank 3: Digital/glitchy waves
        for (int row = 0; row < kNumWaveforms; ++row) {
            for (int col = 0; col < kNumWaveforms; ++col) {
                GenerateDigitalWave(3, row, col);
            }
        }
    }

    void GenerateHarmonicWave(int bank, int row, int col) {
        // Row controls number of harmonics (1-16)
        // Col controls odd/even harmonic balance
        int num_harmonics = 1 + row * 2;
        float odd_even = static_cast<float>(col) / (kNumWaveforms - 1);

        for (int s = 0; s < kTableSize; ++s) {
            float phase = static_cast<float>(s) / kTableSize;
            float sample = 0.0f;

            for (int h = 1; h <= num_harmonics; ++h) {
                float amp = 1.0f / h;  // Natural rolloff

                // Odd/even balance
                if (h % 2 == 0) {
                    amp *= odd_even;
                } else {
                    amp *= (1.0f - odd_even * 0.5f);
                }

                sample += std::sin(phase * h * 6.28318530718f) * amp;
            }

            wavetables_[bank][row][col][s] = sample * 0.5f;
        }
    }

    void GenerateFormantWave(int bank, int row, int col) {
        // Row controls formant frequency
        // Col controls formant width
        float formant_freq = 2.0f + row * 2.0f;
        float width = 0.1f + col * 0.1f;

        for (int s = 0; s < kTableSize; ++s) {
            float phase = static_cast<float>(s) / kTableSize;

            // Window function
            float window = 0.5f - 0.5f * std::cos(phase * 6.28318530718f);
            window = std::pow(window, width);

            // Formant
            float formant = std::sin(phase * formant_freq * 6.28318530718f);

            wavetables_[bank][row][col][s] = formant * window;
        }
    }

    void GenerateWaveshapedWave(int bank, int row, int col) {
        // Row controls base waveform
        // Col controls folding amount
        float fold = 1.0f + col * 0.5f;

        for (int s = 0; s < kTableSize; ++s) {
            float phase = static_cast<float>(s) / kTableSize;
            float sample;

            // Base waveform based on row
            if (row < 3) {
                sample = std::sin(phase * 6.28318530718f);
            } else if (row < 5) {
                sample = (phase < 0.5f) ? (4.0f * phase - 1.0f) : (3.0f - 4.0f * phase);
            } else {
                sample = 2.0f * phase - 1.0f;
            }

            // Wavefold
            sample *= fold;
            while (sample > 1.0f || sample < -1.0f) {
                if (sample > 1.0f) sample = 2.0f - sample;
                if (sample < -1.0f) sample = -2.0f - sample;
            }

            wavetables_[bank][row][col][s] = sample;
        }
    }

    void GenerateDigitalWave(int bank, int row, int col) {
        // Row controls bit depth
        // Col controls phase distortion
        int bits = 2 + row;
        float levels = std::pow(2.0f, bits);
        float distortion = col * 0.5f;

        for (int s = 0; s < kTableSize; ++s) {
            float phase = static_cast<float>(s) / kTableSize;

            // Phase distortion
            if (distortion > 0.0f) {
                if (phase < 0.5f) {
                    phase = phase * (1.0f + distortion) / (0.5f + distortion * 0.5f);
                } else {
                    phase = (phase - 0.5f) * (1.0f - distortion * 0.5f) / 0.5f + 0.5f + distortion * 0.25f;
                }
                phase = std::fmod(phase, 1.0f);
            }

            float sample = std::sin(phase * 6.28318530718f);

            // Bit reduction
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

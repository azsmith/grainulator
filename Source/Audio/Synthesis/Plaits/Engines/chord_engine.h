//
//  chord_engine.h
//  Grainulator
//
//  Chord synthesis engine inspired by Mutable Instruments Plaits
//  Generates four-note chords with various waveforms
//
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Émilie Gillet
//

#ifndef CHORD_ENGINE_H
#define CHORD_ENGINE_H

#include <cmath>
#include <algorithm>

namespace Grainulator {
namespace Engines {

/// Chord synthesis engine
/// Generates four-note chords with selectable voicings and waveforms
class ChordEngine {
public:
    static constexpr int kNumVoices = 4;

    // Chord types (semitone intervals from root)
    static constexpr int kChordIntervals[][4] = {
        {0, 4, 7, 12},    // Major
        {0, 3, 7, 12},    // Minor
        {0, 4, 7, 11},    // Major 7
        {0, 3, 7, 10},    // Minor 7
        {0, 4, 7, 10},    // Dominant 7
        {0, 3, 6, 10},    // Diminished 7
        {0, 4, 8, 12},    // Augmented
        {0, 5, 7, 12},    // Sus4
        {0, 2, 7, 12},    // Sus2
        {0, 7, 12, 19},   // Power chord (5ths)
        {0, 4, 7, 14},    // Add9
        {0, 3, 7, 14},    // Minor add9
    };
    static constexpr int kNumChordTypes = 12;

    ChordEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.5f)
        , timbre_(0.5f)
        , morph_(0.5f)
    {
        for (int i = 0; i < kNumVoices; ++i) {
            phases_[i] = 0.0f;
        }
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        for (int i = 0; i < kNumVoices; ++i) {
            phases_[i] = static_cast<float>(i) * 0.25f;  // Spread initial phases
        }
    }

    void SetNote(float note) {
        note_ = note;
    }

    /// HARMONICS: Chord type selection
    /// Major, Minor, 7ths, Sus, Power chords, etc.
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// TIMBRE: Chord inversion
    /// Root position through 3rd inversion
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// MORPH: Waveform selection
    /// Sine -> Triangle -> Saw -> Square
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    void Render(float* out, float* aux, size_t size) {
        // Select chord type
        int chord_index = static_cast<int>(harmonics_ * (kNumChordTypes - 0.01f));
        chord_index = std::min(chord_index, kNumChordTypes - 1);

        // Get chord intervals
        const int* intervals = kChordIntervals[chord_index];

        // Calculate inversion offset (timbre controls)
        int inversion = static_cast<int>(timbre_ * 3.99f);  // 0-3 inversions

        // Calculate frequencies for each voice
        float freqs[kNumVoices];
        for (int v = 0; v < kNumVoices; ++v) {
            int interval = intervals[v];

            // Apply inversion - shift lower notes up an octave
            if (v < inversion) {
                interval += 12;
            }

            float voice_note = note_ + interval;
            freqs[v] = 440.0f * std::pow(2.0f, (voice_note - 69.0f) / 12.0f);
        }

        for (size_t i = 0; i < size; ++i) {
            float sample = 0.0f;
            float aux_sample = 0.0f;

            for (int v = 0; v < kNumVoices; ++v) {
                // Update phase
                phases_[v] += freqs[v] / sample_rate_;
                if (phases_[v] >= 1.0f) phases_[v] -= 1.0f;

                // Generate waveform based on morph
                float voice_sample = GenerateWaveform(phases_[v], morph_);

                // Root note slightly louder
                float level = (v == 0) ? 0.35f : 0.25f;
                sample += voice_sample * level;

                // Stereo spread - odd voices to aux
                if (v % 2 == 1) {
                    aux_sample += voice_sample * level;
                }
            }

            // Soft limit
            sample = std::tanh(sample * 1.2f);
            aux_sample = std::tanh(aux_sample * 1.5f);

            if (out) {
                out[i] = sample;
            }
            if (aux) {
                aux[i] = aux_sample;
            }
        }
    }

    static const char* GetName() {
        return "Chords";
    }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;

    float phases_[kNumVoices];

    float GenerateWaveform(float phase, float morph) {
        // Morph between waveforms:
        // 0.0-0.25: Sine
        // 0.25-0.5: Triangle
        // 0.5-0.75: Saw
        // 0.75-1.0: Square

        if (morph < 0.25f) {
            // Sine
            return std::sin(phase * 6.28318530718f);
        } else if (morph < 0.5f) {
            // Triangle (with crossfade from sine)
            float sine = std::sin(phase * 6.28318530718f);
            float tri = (phase < 0.5f) ? (4.0f * phase - 1.0f) : (3.0f - 4.0f * phase);
            float blend = (morph - 0.25f) * 4.0f;
            return sine * (1.0f - blend) + tri * blend;
        } else if (morph < 0.75f) {
            // Saw (with crossfade from triangle)
            float tri = (phase < 0.5f) ? (4.0f * phase - 1.0f) : (3.0f - 4.0f * phase);
            float saw = 2.0f * phase - 1.0f;
            float blend = (morph - 0.5f) * 4.0f;
            return tri * (1.0f - blend) + saw * blend;
        } else {
            // Square (with crossfade from saw)
            float saw = 2.0f * phase - 1.0f;
            float square = (phase < 0.5f) ? 1.0f : -1.0f;
            float blend = (morph - 0.75f) * 4.0f;
            return saw * (1.0f - blend) + square * blend;
        }
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // CHORD_ENGINE_H

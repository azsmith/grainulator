//
//  sixop_fm_engine.h
//  Grainulator
//
//  6-operator FM synthesis engine inspired by the Yamaha DX7
//  Provides 32 algorithms with per-operator frequency ratios,
//  feedback, and a simplified envelope system.
//
//  Parameters:
//    Harmonics: Algorithm selection (32 algorithms)
//    Timbre:    Modulation depth / brightness
//    Morph:     Operator balance / character
//

#ifndef SIXOP_FM_ENGINE_H
#define SIXOP_FM_ENGINE_H

#include <cmath>
#include <algorithm>
#include <cstring>

namespace Grainulator {
namespace Engines {

class SixOpFMEngine {
public:
    static constexpr int kNumOperators = 6;
    static constexpr int kNumAlgorithms = 32;
    static constexpr float kTwoPi = 2.0f * 3.14159265358979323846f;

    // Algorithm routing: each algorithm defines which ops modulate which
    // Bit layout per algorithm: array of 6 entries, each is a bitmask of which
    // operators feed INTO this operator as modulators, plus a carrier flag
    struct Algorithm {
        uint8_t modulators[kNumOperators]; // bitmask: bit i = op i modulates this op
        uint8_t carriers;                  // bitmask: which ops are carriers (summed to output)
        uint8_t feedback_op;               // which operator has self-feedback (0-5, or 0xFF=none)
    };

    SixOpFMEngine()
        : sample_rate_(48000.0f)
        , note_(60.0f)
        , harmonics_(0.0f)
        , timbre_(0.5f)
        , morph_(0.5f)
    {
        std::memset(phase_, 0, sizeof(phase_));
        std::memset(output_, 0, sizeof(output_));
        std::memset(prev_output_, 0, sizeof(prev_output_));
        InitAlgorithms();
        InitDefaultRatios();
    }

    void Init(float sample_rate) {
        sample_rate_ = sample_rate;
        std::memset(phase_, 0, sizeof(phase_));
        std::memset(output_, 0, sizeof(output_));
        std::memset(prev_output_, 0, sizeof(prev_output_));
    }

    void SetNote(float note) { note_ = note; }

    /// HARMONICS: Algorithm selection (0.0-1.0 maps to 32 algorithms)
    void SetHarmonics(float harmonics) {
        harmonics_ = std::max(0.0f, std::min(1.0f, harmonics));
    }

    /// TIMBRE: Overall modulation depth / brightness
    void SetTimbre(float timbre) {
        timbre_ = std::max(0.0f, std::min(1.0f, timbre));
    }

    /// MORPH: Operator balance - shifts energy between operators
    void SetMorph(float morph) {
        morph_ = std::max(0.0f, std::min(1.0f, morph));
    }

    void Render(float* out, float* aux, size_t size) {
        float freq = 440.0f * std::pow(2.0f, (note_ - 69.0f) / 12.0f);

        // Select algorithm
        int algo_idx = static_cast<int>(harmonics_ * (kNumAlgorithms - 1) + 0.5f);
        algo_idx = std::max(0, std::min(kNumAlgorithms - 1, algo_idx));
        const Algorithm& algo = algorithms_[algo_idx];

        // Modulation index scales with timbre (0 to ~12)
        float mod_depth = timbre_ * timbre_ * 12.0f;

        // Morph controls operator level balance
        // Low morph = only lower operators active, high = all active
        float op_levels[kNumOperators];
        ComputeOperatorLevels(morph_, op_levels);

        // Feedback amount (from the designated feedback operator)
        float feedback = 0.5f + timbre_ * 1.5f;

        for (size_t i = 0; i < size; ++i) {
            // Compute each operator (from op 5 down to op 0 for proper modulation order)
            // In DX7 convention, op 6 (index 5) is typically the deepest modulator
            for (int op = kNumOperators - 1; op >= 0; --op) {
                float phase_mod = 0.0f;

                // Sum modulation from all operators that feed into this one
                for (int mod_op = 0; mod_op < kNumOperators; ++mod_op) {
                    if (algo.modulators[op] & (1 << mod_op)) {
                        // Use previous frame's output for modulators computed after this op
                        float mod_val = (mod_op > op) ? prev_output_[mod_op] : output_[mod_op];
                        phase_mod += mod_val * mod_depth * op_levels[mod_op];
                    }
                }

                // Self-feedback
                if (algo.feedback_op == op) {
                    phase_mod += prev_output_[op] * feedback;
                }

                // Compute operator output
                float op_freq = freq * ratios_[op];
                float phase_inc = op_freq / sample_rate_;
                phase_[op] += phase_inc;
                if (phase_[op] >= 1.0f) phase_[op] -= 1.0f;

                output_[op] = std::sin(kTwoPi * phase_[op] + phase_mod) * op_levels[op];
            }

            // Sum carrier operators
            float sample = 0.0f;
            int num_carriers = 0;
            for (int op = 0; op < kNumOperators; ++op) {
                if (algo.carriers & (1 << op)) {
                    sample += output_[op];
                    num_carriers++;
                }
            }

            // Normalize by number of carriers
            if (num_carriers > 1) {
                sample /= std::sqrt(static_cast<float>(num_carriers));
            }

            // Store for next frame's feedback
            std::memcpy(prev_output_, output_, sizeof(output_));

            if (out) out[i] = sample * 0.7f;
            if (aux) {
                // Aux: modulator sum (non-carrier operators)
                float mod_sum = 0.0f;
                for (int op = 0; op < kNumOperators; ++op) {
                    if (!(algo.carriers & (1 << op))) {
                        mod_sum += output_[op];
                    }
                }
                aux[i] = mod_sum * 0.3f;
            }
        }
    }

    static const char* GetName() { return "Six-Op FM"; }

private:
    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;

    float phase_[kNumOperators];
    float output_[kNumOperators];
    float prev_output_[kNumOperators];
    float ratios_[kNumOperators];

    Algorithm algorithms_[kNumAlgorithms];

    void ComputeOperatorLevels(float morph, float* levels) {
        // Morph sweeps through operator configurations:
        // 0.0 = ops 1-2 dominant (simple), 1.0 = all ops active (complex)
        for (int i = 0; i < kNumOperators; ++i) {
            float threshold = static_cast<float>(i) / (kNumOperators - 1);
            float dist = morph - threshold * 0.8f;
            if (dist < 0.0f) {
                levels[i] = std::max(0.05f, 1.0f + dist * 4.0f);
            } else {
                levels[i] = 1.0f;
            }
        }
    }

    void InitDefaultRatios() {
        // Classic DX7-style frequency ratios
        ratios_[0] = 1.0f;   // Op 1: fundamental
        ratios_[1] = 1.0f;   // Op 2: fundamental
        ratios_[2] = 2.0f;   // Op 3: octave
        ratios_[3] = 3.0f;   // Op 4: fifth above octave
        ratios_[4] = 4.0f;   // Op 5: two octaves
        ratios_[5] = 1.0f;   // Op 6: fundamental (common modulator)
    }

    void InitAlgorithms() {
        // Initialize all algorithms based on DX7 algorithm charts
        // Notation: Op indices 0-5 correspond to DX7 ops 1-6
        // modulators[i] = bitmask of which ops modulate op i
        // carriers = bitmask of which ops go to output

        // Algorithm 1: [6→5→4→3→2→1]  (serial chain)
        // Classic brass/organ sound
        algorithms_[0] = {{0, 1, 2, 4, 8, 16}, 0x01, 5};

        // Algorithm 2: [6→5→4→3→2→1] with 6 feedback, 5+6→4
        // Similar to 1 but with split modulation
        algorithms_[1] = {{0, 1, 2, 4, 24, 0}, 0x01, 5};

        // Algorithm 3: [6→5→4→3] + [2→1], carriers: 1
        algorithms_[2] = {{2, 0, 0, 4, 8, 16}, 0x01, 5};

        // Algorithm 4: [6→5] + [4→3→2→1], carriers: 1
        algorithms_[3] = {{0, 1, 2, 4, 0, 16}, 0x01, 5};

        // Algorithm 5: [6→5→4] + [3→2→1], carriers: 1,4
        // Classic electric piano
        algorithms_[4] = {{0, 1, 4, 0, 8, 16}, 0x09, 5};

        // Algorithm 6: [6→5] + [4→3] + [2→1], carriers: 1,3,5
        algorithms_[5] = {{2, 0, 0, 8, 0, 16}, 0x15, 5};

        // Algorithm 7: [6→5→4→3→2] + 1, carriers: 1,2
        // Clavinet-like
        algorithms_[6] = {{0, 0, 2, 4, 8, 16}, 0x03, 5};

        // Algorithm 8: [6→5→4→3] + [2] + 1, carriers: 1,2,3
        algorithms_[7] = {{0, 0, 0, 4, 8, 16}, 0x07, 5};

        // Algorithm 9: [6→5→4] + [3→2] + 1, carriers: 1,2,4
        algorithms_[8] = {{0, 0, 4, 0, 8, 16}, 0x0B, 5};

        // Algorithm 10: [6→5] + [4→3→2] + 1, carriers: 1,2
        algorithms_[9] = {{0, 0, 2, 4, 0, 16}, 0x03, 5};

        // Algorithm 11: [6→5→4] + 3 + 2 + 1, carriers: 1,2,3,4
        algorithms_[10] = {{0, 0, 0, 0, 8, 16}, 0x0F, 5};

        // Algorithm 12: [6→5] + 4 + 3 + 2 + 1, carriers: 1,2,3,4,5
        algorithms_[11] = {{0, 0, 0, 0, 0, 16}, 0x1F, 5};

        // Algorithm 13: [6] + 5 + 4 + 3 + 2 + 1, carriers: all
        // Pure additive
        algorithms_[12] = {{0, 0, 0, 0, 0, 0}, 0x3F, 5};

        // Algorithm 14: [5→4→3→2→1] + 6fb, carriers: 1
        algorithms_[13] = {{0, 1, 2, 4, 8, 0}, 0x01, 5};

        // Algorithm 15: [6→5] + [4→3] + [2→1], carriers: 1
        // Split modulator pairs
        algorithms_[14] = {{2, 0, 0, 8, 0, 16}, 0x01, 5};

        // Algorithm 16: [3→2] + [6→5→4→1], carriers: 1
        algorithms_[15] = {{8, 0, 4, 0, 8, 16}, 0x01, 5};

        // Algorithm 17: [6→1] + [5→1] + [4→1] + [3→2→1], carriers: 1
        // Many modulators to one carrier
        algorithms_[16] = {{0x3C, 4, 0, 0, 0, 0}, 0x01, 5};

        // Algorithm 18: [6→5→1] + [4→3→1] + [2→1], carriers: 1
        algorithms_[17] = {{0x16, 0, 0, 8, 0, 16}, 0x01, 5};

        // Algorithm 19: [6→5→4→1] + [3→2→1], carriers: 1,4
        // Detuned pair
        algorithms_[18] = {{0x0C, 4, 0, 0, 8, 16}, 0x09, 5};

        // Algorithm 20: [6→1,2,3] + [5→4], carriers: 1,2,3,4
        algorithms_[19] = {{32, 32, 32, 16, 0, 0}, 0x0F, 5};

        // Algorithm 21: [6→1,2,3] + 4 + 5, carriers: 1,2,3,4,5
        algorithms_[20] = {{32, 32, 32, 0, 0, 0}, 0x1F, 5};

        // Algorithm 22: [6→1,2,3,4,5], carriers: all 1-5
        // One modulator, five carriers
        algorithms_[21] = {{32, 32, 32, 32, 32, 0}, 0x1F, 5};

        // Algorithm 23: [5→4] + [6→1,2,3], carriers: 1,2,3,4
        algorithms_[22] = {{32, 32, 32, 16, 0, 0}, 0x0F, 5};

        // Algorithm 24: [6→5] + [6→4] + [6→3] + 2 + 1, carriers: 1,2,3,4,5
        algorithms_[23] = {{0, 0, 32, 32, 32, 0}, 0x1F, 5};

        // Algorithm 25: 6 + 5 + [4→3] + [2→1], carriers: 1,3,5,6
        algorithms_[24] = {{2, 0, 0, 8, 0, 0}, 0x31, 5};

        // Algorithm 26: [6→5] + 4 + [3→2] + 1, carriers: 1,2,4,5
        algorithms_[25] = {{0, 4, 0, 0, 0, 16}, 0x1B, 5};

        // Algorithm 27: [4→3] + [6→5] + 2 + 1, carriers: 1,2,3,5
        algorithms_[26] = {{0, 0, 0, 8, 0, 16}, 0x17, 5};

        // Algorithm 28: [5→4→3] + [6→2→1], carriers: 1,3
        algorithms_[27] = {{2, 32, 0, 4, 8, 0}, 0x05, 5};

        // Algorithm 29: [6→5→4] + [3→2] + 1, carriers: 1,2,4
        algorithms_[28] = {{0, 4, 0, 0, 8, 16}, 0x0B, 5};

        // Algorithm 30: [6→5→4→3] + 2 + 1, carriers: 1,2,3
        algorithms_[29] = {{0, 0, 0, 4, 8, 16}, 0x07, 5};

        // Algorithm 31: 6 + 5 + 4 + 3 + 2 + 1, carriers: all (pure additive)
        // With op6 feedback for warmth
        algorithms_[30] = {{0, 0, 0, 0, 0, 0}, 0x3F, 5};

        // Algorithm 32: [6fb] + 5 + 4 + 3 + 2 + 1, carriers: all
        // Additive with one feedback oscillator for noise/breath
        algorithms_[31] = {{0, 0, 0, 0, 0, 0}, 0x3F, 5};
    }
};

} // namespace Engines
} // namespace Grainulator

#endif // SIXOP_FM_ENGINE_H

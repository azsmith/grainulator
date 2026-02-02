//
//  oscillator.h
//  Grainulator
//
//  Band-limited oscillator using PolyBLEP anti-aliasing
//  Based on Mutable Instruments code (MIT License)
//  Copyright 2016 Émilie Gillet
//

#ifndef OSCILLATOR_H
#define OSCILLATOR_H

#include <cmath>
#include <algorithm>

namespace Grainulator {
namespace DSP {

/// PolyBLEP correction for band-limited waveforms
/// Removes aliasing artifacts from discontinuities
class PolyBlepOscillator {
public:
    PolyBlepOscillator() : phase_(0.0f), frequency_(0.0f), pw_(0.5f) {}

    void Init() {
        phase_ = 0.0f;
        frequency_ = 0.0f;
        pw_ = 0.5f;
        previous_pw_ = 0.5f;
        high_ = false;
    }

    void SetFrequency(float frequency) {
        frequency_ = frequency;
    }

    void SetPulseWidth(float pw) {
        previous_pw_ = pw_;
        pw_ = std::max(0.05f, std::min(0.95f, pw));
    }

    /// Render a single sample of the specified waveform
    /// type: 0=sine, 1=triangle, 2=saw, 3=square
    float Render(int type) {
        float sample = 0.0f;

        switch (type) {
            case 0: // Sine
                sample = RenderSine();
                break;
            case 1: // Triangle
                sample = RenderTriangle();
                break;
            case 2: // Saw
                sample = RenderSaw();
                break;
            case 3: // Square
                sample = RenderSquare();
                break;
            default:
                sample = RenderSaw();
                break;
        }

        // Advance phase
        phase_ += frequency_;
        if (phase_ >= 1.0f) {
            phase_ -= 1.0f;
        }

        return sample;
    }

    /// Render a buffer of samples
    void Render(int type, float* out, size_t size) {
        for (size_t i = 0; i < size; ++i) {
            out[i] = Render(type);
        }
    }

    /// Render with variable mix between two waveforms
    float RenderMorph(int type_a, int type_b, float mix) {
        float sample_a = 0.0f;
        float sample_b = 0.0f;

        // Store phase for second render
        float saved_phase = phase_;

        switch (type_a) {
            case 0: sample_a = SineAtPhase(phase_); break;
            case 1: sample_a = TriangleAtPhase(phase_); break;
            case 2: sample_a = SawAtPhase(phase_, frequency_); break;
            case 3: sample_a = SquareAtPhase(phase_, frequency_); break;
        }

        switch (type_b) {
            case 0: sample_b = SineAtPhase(phase_); break;
            case 1: sample_b = TriangleAtPhase(phase_); break;
            case 2: sample_b = SawAtPhase(phase_, frequency_); break;
            case 3: sample_b = SquareAtPhase(phase_, frequency_); break;
        }

        // Advance phase
        phase_ += frequency_;
        if (phase_ >= 1.0f) {
            phase_ -= 1.0f;
        }

        return sample_a + mix * (sample_b - sample_a);
    }

private:
    float phase_;
    float frequency_;
    float pw_;
    float previous_pw_;
    bool high_;

    // PolyBLEP correction function
    // t should be between 0 and 1 (phase within one sample of discontinuity)
    inline float PolyBlep(float t, float dt) const {
        if (t < dt) {
            t /= dt;
            return t + t - t * t - 1.0f;
        } else if (t > 1.0f - dt) {
            t = (t - 1.0f) / dt;
            return t * t + t + t + 1.0f;
        }
        return 0.0f;
    }

    float RenderSine() {
        return std::sin(phase_ * 2.0f * 3.14159265358979323846f);
    }

    float SineAtPhase(float phase) {
        return std::sin(phase * 2.0f * 3.14159265358979323846f);
    }

    float RenderTriangle() {
        float sample;
        if (phase_ < 0.5f) {
            sample = 4.0f * phase_ - 1.0f;
        } else {
            sample = 3.0f - 4.0f * phase_;
        }
        return sample;
    }

    float TriangleAtPhase(float phase) {
        if (phase < 0.5f) {
            return 4.0f * phase - 1.0f;
        } else {
            return 3.0f - 4.0f * phase;
        }
    }

    float RenderSaw() {
        float sample = 2.0f * phase_ - 1.0f;
        sample -= PolyBlep(phase_, frequency_);
        return sample;
    }

    float SawAtPhase(float phase, float frequency) {
        float sample = 2.0f * phase - 1.0f;
        sample -= PolyBlep(phase, frequency);
        return sample;
    }

    float RenderSquare() {
        float sample = phase_ < pw_ ? 1.0f : -1.0f;

        // Apply PolyBLEP at rising edge
        sample += PolyBlep(phase_, frequency_);

        // Apply PolyBLEP at falling edge
        float t2 = phase_ - pw_;
        if (t2 < 0.0f) t2 += 1.0f;
        sample -= PolyBlep(t2, frequency_);

        return sample;
    }

    float SquareAtPhase(float phase, float frequency) {
        float sample = phase < pw_ ? 1.0f : -1.0f;
        sample += PolyBlep(phase, frequency);
        float t2 = phase - pw_;
        if (t2 < 0.0f) t2 += 1.0f;
        sample -= PolyBlep(t2, frequency);
        return sample;
    }
};

/// Simple parameter interpolator for smooth transitions
class ParameterInterpolator {
public:
    ParameterInterpolator() : value_(0.0f), increment_(0.0f) {}

    void Init(float value, float target, size_t size) {
        value_ = value;
        increment_ = (target - value) / static_cast<float>(size);
    }

    float Next() {
        float v = value_;
        value_ += increment_;
        return v;
    }

    float value() const { return value_; }

private:
    float value_;
    float increment_;
};

/// One-pole low-pass filter
class OnePole {
public:
    OnePole() : state_(0.0f), coefficient_(0.5f) {}

    void Init() {
        state_ = 0.0f;
        coefficient_ = 0.5f;
    }

    void SetCoefficient(float coefficient) {
        coefficient_ = coefficient;
    }

    void SetFrequency(float frequency, float sample_rate) {
        // Simple approximation for low frequencies
        float f = frequency / sample_rate;
        coefficient_ = f < 0.5f ? f * 2.0f : 0.99f;
    }

    float Process(float input) {
        state_ += coefficient_ * (input - state_);
        return state_;
    }

private:
    float state_;
    float coefficient_;
};

/// DC blocker filter
class DCBlocker {
public:
    DCBlocker() : x1_(0.0f), y1_(0.0f), coefficient_(0.995f) {}

    void Init() {
        x1_ = 0.0f;
        y1_ = 0.0f;
    }

    void SetCoefficient(float coefficient) {
        coefficient_ = coefficient;
    }

    float Process(float input) {
        float y = input - x1_ + coefficient_ * y1_;
        x1_ = input;
        y1_ = y;
        return y;
    }

private:
    float x1_;
    float y1_;
    float coefficient_;
};

} // namespace DSP
} // namespace Grainulator

#endif // OSCILLATOR_H

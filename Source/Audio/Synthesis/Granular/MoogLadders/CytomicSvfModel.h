// CytomicSvf - State Variable Filter based on Andy Simper's Cytomic design
// Linear trapezoidal optimized SVF (2-pole / 12 dB/oct)
// Based on technical paper: http://cytomic.com/files/dsp/SvfLinearTrapOptimised2.pdf
//
// Original implementations by Matthijs Hollemans and Fred Anton Corvest (MIT)
// Adapted for Grainulator LadderFilterBase interface
//
// This is a 2-pole filter (12 dB/oct), not a 4-pole ladder. It provides a
// different, cleaner character — unconditionally stable, zero level issues,
// near-zero CPU. Supports LP, HP, BP, Notch modes.

#pragma once

#ifndef CYTOMIC_SVF_MODEL_H
#define CYTOMIC_SVF_MODEL_H

#include "LadderFilterBase.h"
#include <cmath>
#include <algorithm>

class CytomicSvfMoog : public LadderFilterBase
{
public:

    enum FilterMode { LP, HP, BP, NOTCH };

    CytomicSvfMoog(float sampleRate) : LadderFilterBase(sampleRate)
    {
        ic1eq_ = 0.0f;
        ic2eq_ = 0.0f;
        g_ = 0.0f;
        k_ = 0.0f;
        a1_ = 0.0f;
        a2_ = 0.0f;
        a3_ = 0.0f;
        m0_ = 0.0f;
        m1_ = 0.0f;
        m2_ = 1.0f;
        mode_ = LP;

        SetCutoff(1000.0f);
        SetResonance(0.1f);
    }

    virtual ~CytomicSvfMoog() {}

    virtual void Process(float* samples, uint32_t n) noexcept override
    {
        for (uint32_t s = 0; s < n; ++s)
        {
            float v0 = samples[s];
            float v3 = v0 - ic2eq_;
            float v1 = a1_ * ic1eq_ + a2_ * v3;
            float v2 = ic2eq_ + a2_ * ic1eq_ + a3_ * v3;
            ic1eq_ = 2.0f * v1 - ic1eq_;
            ic2eq_ = 2.0f * v2 - ic2eq_;
            samples[s] = m0_ * v0 + m1_ * v1 + m2_ * v2;
        }
    }

    virtual void SetCutoff(float c) override
    {
        cutoff = c;
        updateCoefficients();
    }

    virtual void SetResonance(float r) override
    {
        resonance = r;
        updateCoefficients();
    }

    void SetFilterMode(FilterMode mode)
    {
        mode_ = mode;
        updateMixCoefficients();
    }

private:

    float ic1eq_, ic2eq_;
    float g_, k_, a1_, a2_, a3_;
    float m0_, m1_, m2_;
    FilterMode mode_;

    void updateCoefficients()
    {
        // Clamp cutoff to valid range
        float freq = std::max(20.0f, std::min(cutoff, sampleRate * 0.49f));

        // Bilinear transform prewarp
        g_ = std::tan(static_cast<float>(M_PI) * freq / sampleRate);

        // Map resonance 0-1 to Q via exponential curve
        // r=0 → Q=0.5 (gentle), r=1 → Q=20 (strong resonance)
        float Q = 0.5f * std::exp(resonance * 3.6889f); // exp(3.6889) ≈ 40, so Q goes 0.5 to 20
        k_ = 1.0f / Q;

        // Core SVF coefficients
        a1_ = 1.0f / (1.0f + g_ * (g_ + k_));
        a2_ = g_ * a1_;
        a3_ = g_ * a2_;

        updateMixCoefficients();
    }

    void updateMixCoefficients()
    {
        switch (mode_)
        {
            case LP:
                m0_ = 0.0f; m1_ = 0.0f; m2_ = 1.0f;
                break;
            case HP:
                m0_ = 1.0f; m1_ = -k_; m2_ = -1.0f;
                break;
            case BP:
                m0_ = 0.0f; m1_ = k_; m2_ = 0.0f;
                break;
            case NOTCH:
                m0_ = 1.0f; m1_ = -k_; m2_ = 0.0f;
                break;
        }
    }
};

#endif // CYTOMIC_SVF_MODEL_H

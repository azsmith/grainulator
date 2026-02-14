// DaisyLadder - Huovilainen New Moog (HNM) model, adapted for Grainulator
// Based on DaisySP ladder filter by Richard van Hoesel (CMJ June 2006)
// Ported from Audio Library for Teensy / Infrasonic Audio LLC
//
// Copyright (c) 2021, Richard van Hoesel
// Copyright (c) 2024, Infrasonic Audio LLC
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#pragma once

#ifndef DAISY_LADDER_MODEL_H
#define DAISY_LADDER_MODEL_H

#include "LadderFilterBase.h"
#include <cmath>
#include <algorithm>
#include <array>

class DaisyLadderMoog : public LadderFilterBase
{
public:

    enum FilterMode { LP24, LP12, BP24, BP12, HP24, HP12 };

    DaisyLadderMoog(float sampleRate) : LadderFilterBase(sampleRate)
    {
        sr_int_recip_ = 1.0f / (sampleRate * kInterpolation);
        alpha_ = 1.0f;
        K_ = 1.0f;
        Qadjust_ = 1.0f;
        oldinput_ = 0.0f;
        mode_ = LP24;

        std::fill(std::begin(z0_), std::end(z0_), 0.0f);
        std::fill(std::begin(z1_), std::end(z1_), 0.0f);

        pbg_ = 0.5f;
        drive_ = 0.5f;
        drive_scaled_ = 0.5f;

        SetCutoff(5000.0f);
        SetResonance(0.1f);
    }

    virtual ~DaisyLadderMoog() {}

    virtual void Process(float* samples, uint32_t n) noexcept override
    {
        for (uint32_t s = 0; s < n; ++s)
        {
            float input = samples[s] * drive_scaled_;
            float total = 0.0f;
            float interp = 0.0f;

            for (int os = 0; os < kInterpolation; os++)
            {
                float in_interp = interp * oldinput_ + (1.0f - interp) * input;
                float u = in_interp - (z1_[3] - pbg_ * in_interp) * K_ * Qadjust_;
                u = fast_tanh(u);

                float stage1 = LPF(u, 0);
                float stage2 = LPF(stage1, 1);
                float stage3 = LPF(stage2, 2);
                float stage4 = LPF(stage3, 3);

                total += weightedSum({u, stage1, stage2, stage3, stage4})
                         * kInterpolationRecip;
                interp += kInterpolationRecip;
            }

            oldinput_ = input;
            samples[s] = total;
        }
    }

    virtual void SetCutoff(float c) override
    {
        cutoff = c;
        float freq = std::max(5.0f, std::min(c, sampleRate * 0.425f));
        float wc = freq * 2.0f * kPi * sr_int_recip_;
        float wc2 = wc * wc;
        alpha_ = 0.9892f * wc - 0.4324f * wc2 + 0.1381f * wc * wc2
                 - 0.0202f * wc2 * wc2;
        Qadjust_ = 1.006f + 0.0536f * wc - 0.095f * wc2 - 0.05f * wc2 * wc2;
    }

    virtual void SetResonance(float r) override
    {
        resonance = r;
        // Map 0-1 to K 0-4 (supports up to 1.8 for self-oscillation)
        r = std::max(0.0f, std::min(r, kMaxResonance));
        K_ = 4.0f * r;
    }

    void SetFilterMode(FilterMode mode) { mode_ = mode; }

    void SetPassbandGain(float pbg)
    {
        pbg_ = std::max(0.0f, std::min(pbg, 0.5f));
        SetInputDrive(drive_);
    }

    void SetInputDrive(float drv)
    {
        drive_ = std::max(0.0f, drv);
        if (drive_ > 1.0f)
        {
            drive_ = std::min(drive_, 4.0f);
            drive_scaled_ = 1.0f + (drive_ - 1.0f) * (1.0f - pbg_);
        }
        else
        {
            drive_scaled_ = drive_;
        }
    }

private:

    static constexpr int kInterpolation = 4;
    static constexpr float kInterpolationRecip = 1.0f / kInterpolation;
    static constexpr float kMaxResonance = 1.8f;
    static constexpr float kPi = 3.14159265358979323846f;

    float sr_int_recip_;
    float alpha_;
    float z0_[4];
    float z1_[4];
    float K_;
    float Qadjust_;
    float pbg_;
    float drive_, drive_scaled_;
    float oldinput_;
    FilterMode mode_;

    static inline float fast_tanh(float x)
    {
        if (x > 3.0f) return 1.0f;
        if (x < -3.0f) return -1.0f;
        float x2 = x * x;
        return x * (27.0f + x2) / (27.0f + 9.0f * x2);
    }

    inline float LPF(float s, int i)
    {
        float ft = s * 0.76923077f + 0.23076923f * z0_[i] - z1_[i];
        ft = ft * alpha_ + z1_[i];
        z1_[i] = ft;
        z0_[i] = s;
        return ft;
    }

    float weightedSum(const std::array<float, 5>& st)
    {
        switch (mode_)
        {
            case LP24: return st[4];
            case LP12: return st[2];
            case BP24: return (st[2] + st[4]) * 4.0f - st[3] * 8.0f;
            case BP12: return (st[1] - st[2]) * 2.0f;
            case HP24: return st[0] + st[4] - (st[1] + st[3]) * 4.0f + st[2] * 6.0f;
            case HP12: return st[0] + st[2] - st[1] * 2.0f;
            default: return 0.0f;
        }
    }
};

#endif // DAISY_LADDER_MODEL_H

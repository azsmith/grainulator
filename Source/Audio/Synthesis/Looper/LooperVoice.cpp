//
//  LooperVoice.cpp
//  Grainulator
//
//  MLR/MLRE-inspired stereo looper voice.
//

#include "LooperVoice.h"
#include "Granular/ReelBuffer.h"

#include <algorithm>
#include <cmath>

namespace Grainulator {

LooperVoice::LooperVoice()
    : sampleRate_(48000.0f)
    , buffer_(nullptr)
    , isPlaying_(false)
    , reverse_(false)
    , rate_(1.0f)
    , level_(1.0f)
    , loopStart_(0.0f)
    , loopEnd_(1.0f)
    , playheadSamples_(0.0f) {
}

void LooperVoice::Init(float sampleRate) {
    sampleRate_ = std::max(1.0f, sampleRate);
    playheadSamples_ = 0.0f;
}

void LooperVoice::SetBuffer(ReelBuffer* buffer) {
    buffer_ = buffer;
    playheadSamples_ = 0.0f;
}

void LooperVoice::SetPosition(float normalizedPosition) {
    if (!buffer_ || buffer_->GetLength() == 0) {
        playheadSamples_ = 0.0f;
        return;
    }
    const float clamped = std::clamp(normalizedPosition, 0.0f, 1.0f);
    const float maxIndex = static_cast<float>(buffer_->GetLength() - 1);
    playheadSamples_ = clamped * maxIndex;
}

float LooperVoice::GetPosition() const {
    if (!buffer_ || buffer_->GetLength() == 0) {
        return 0.0f;
    }
    const float maxIndex = std::max(1.0f, static_cast<float>(buffer_->GetLength() - 1));
    return std::clamp(playheadSamples_ / maxIndex, 0.0f, 1.0f);
}

void LooperVoice::SetLoopStart(float normalized) {
    loopStart_ = std::clamp(normalized, 0.0f, 1.0f);
    if (loopStart_ > loopEnd_) {
        loopStart_ = loopEnd_;
    }
}

void LooperVoice::SetLoopEnd(float normalized) {
    loopEnd_ = std::clamp(normalized, 0.0f, 1.0f);
    if (loopEnd_ < loopStart_) {
        loopEnd_ = loopStart_;
    }
}

void LooperVoice::SetRate(float rate) {
    rate_ = std::clamp(rate, 0.125f, 4.0f);
}

void LooperVoice::SetLevel(float level) {
    level_ = std::clamp(level, 0.0f, 2.0f);
}

void LooperVoice::TriggerCut(int cutIndex, int cutCount) {
    if (!buffer_ || buffer_->GetLength() == 0 || cutCount <= 0) {
        return;
    }
    const int clampedIndex = std::clamp(cutIndex, 0, cutCount - 1);
    const float slicePos = static_cast<float>(clampedIndex) / static_cast<float>(cutCount);
    const float segment = std::max(0.001f, loopEnd_ - loopStart_);
    const float target = loopStart_ + segment * slicePos;
    SetPosition(target);
}

void LooperVoice::WrapPlayhead(float loopStartSample, float loopEndSample) {
    const float loopLength = loopEndSample - loopStartSample;
    if (loopLength <= 1.0f) {
        playheadSamples_ = loopStartSample;
        return;
    }

    while (playheadSamples_ >= loopEndSample) {
        playheadSamples_ -= loopLength;
    }
    while (playheadSamples_ < loopStartSample) {
        playheadSamples_ += loopLength;
    }
}

void LooperVoice::Render(float* outLeft, float* outRight, size_t numFrames) {
    if (!outLeft || !outRight) {
        return;
    }

    if (!buffer_ || buffer_->GetLength() == 0 || !isPlaying_) {
        for (size_t i = 0; i < numFrames; ++i) {
            outLeft[i] = 0.0f;
            outRight[i] = 0.0f;
        }
        return;
    }

    const float maxIndex = static_cast<float>(buffer_->GetLength() - 1);
    const float loopStartSample = std::clamp(loopStart_, 0.0f, 1.0f) * maxIndex;
    const float loopEndSample = std::clamp(loopEnd_, 0.0f, 1.0f) * maxIndex;
    const float loopLength = loopEndSample - loopStartSample;
    if (loopLength <= 1.0f) {
        for (size_t i = 0; i < numFrames; ++i) {
            outLeft[i] = 0.0f;
            outRight[i] = 0.0f;
        }
        return;
    }

    WrapPlayhead(loopStartSample, loopEndSample);

    const float sourceRate = std::max(1.0f, buffer_->GetSampleRate());
    const float sampleRateScale = sourceRate / sampleRate_;
    const float direction = reverse_ ? -1.0f : 1.0f;
    const float step = direction * rate_ * sampleRateScale;

    // Short crossfade at loop seam to suppress clicks.
    const float crossfadeSamples = std::min(128.0f, std::max(8.0f, loopLength * 0.1f));

    for (size_t i = 0; i < numFrames; ++i) {
        float left = buffer_->GetSample(0, playheadSamples_);
        float right = buffer_->GetSample(1, playheadSamples_);

        if (step > 0.0f && playheadSamples_ >= (loopEndSample - crossfadeSamples)) {
            const float fade = std::clamp((playheadSamples_ - (loopEndSample - crossfadeSamples)) / crossfadeSamples, 0.0f, 1.0f);
            const float wrappedPos = loopStartSample + (playheadSamples_ - (loopEndSample - crossfadeSamples));
            const float wrappedL = buffer_->GetSample(0, wrappedPos);
            const float wrappedR = buffer_->GetSample(1, wrappedPos);
            left = left * (1.0f - fade) + wrappedL * fade;
            right = right * (1.0f - fade) + wrappedR * fade;
        } else if (step < 0.0f && playheadSamples_ <= (loopStartSample + crossfadeSamples)) {
            const float fade = std::clamp(((loopStartSample + crossfadeSamples) - playheadSamples_) / crossfadeSamples, 0.0f, 1.0f);
            const float wrappedPos = loopEndSample - ((loopStartSample + crossfadeSamples) - playheadSamples_);
            const float wrappedL = buffer_->GetSample(0, wrappedPos);
            const float wrappedR = buffer_->GetSample(1, wrappedPos);
            left = left * (1.0f - fade) + wrappedL * fade;
            right = right * (1.0f - fade) + wrappedR * fade;
        }

        outLeft[i] = left * level_;
        outRight[i] = right * level_;

        playheadSamples_ += step;
        WrapPlayhead(loopStartSample, loopEndSample);
    }
}

} // namespace Grainulator

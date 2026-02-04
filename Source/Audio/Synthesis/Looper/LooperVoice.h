//
//  LooperVoice.h
//  Grainulator
//
//  MLR/MLRE-inspired stereo looper voice.
//

#ifndef LOOPERVOICE_H
#define LOOPERVOICE_H

#include <cstddef>

namespace Grainulator {

class ReelBuffer;

class LooperVoice {
public:
    LooperVoice();

    void Init(float sampleRate);
    void SetBuffer(ReelBuffer* buffer);
    ReelBuffer* GetBuffer() const { return buffer_; }

    void Render(float* outLeft, float* outRight, size_t numFrames);

    void SetPlaying(bool playing) { isPlaying_ = playing; }
    bool IsPlaying() const { return isPlaying_; }

    void SetPosition(float normalizedPosition);
    float GetPosition() const;

    void SetLoopStart(float normalized);
    void SetLoopEnd(float normalized);
    float GetLoopStart() const { return loopStart_; }
    float GetLoopEnd() const { return loopEnd_; }

    void SetRate(float rate);
    float GetRate() const { return rate_; }

    void SetReverse(bool reverse) { reverse_ = reverse; }
    bool GetReverse() const { return reverse_; }

    void SetLevel(float level);
    float GetLevel() const { return level_; }

    void TriggerCut(int cutIndex, int cutCount = 8);

private:
    void WrapPlayhead(float loopStartSample, float loopEndSample);

    float sampleRate_;
    ReelBuffer* buffer_;
    bool isPlaying_;
    bool reverse_;
    float rate_;
    float level_;
    float loopStart_;
    float loopEnd_;
    float playheadSamples_;
};

} // namespace Grainulator

#endif // LOOPERVOICE_H

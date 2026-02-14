//
//  MasterCompressor.h
//  Grainulator
//
//  Feed-forward compressor/limiter for the master bus.
//  Based on Giannoulis, Massberg & Reiss (2012) — log-domain gain computer
//  with smooth branching peak detector and soft knee.
//

#ifndef MASTERCOMPRESSOR_H
#define MASTERCOMPRESSOR_H

#include <cmath>
#include <algorithm>
#include <atomic>

namespace Grainulator {

class MasterCompressor {
public:
    MasterCompressor();

    void prepare(float sampleRate);
    void reset();

    // Per-sample stereo processing (inline in the master output loop)
    void processSample(float& left, float& right);

    // All parameters normalized 0–1
    void setThreshold(float v);      // 0–1 → -60 to 0 dB
    void setRatio(float v);          // 0–1 → 1:1 to 20:1
    void setAttack(float v);         // 0–1 → 0.1 to 100 ms  (log taper)
    void setRelease(float v);        // 0–1 → 10 to 1000 ms   (log taper)
    void setKnee(float v);           // 0–1 → 0 to 12 dB
    void setMakeupGain(float v);     // 0–1 → 0 to 40 dB
    void setMix(float v);            // 0–1 → dry/wet for parallel compression
    void setLimiterEnabled(bool v);
    void setAutoMakeup(bool v);
    void setEnabled(bool v);

    float getThreshold() const   { return m_threshold; }
    float getRatio() const       { return m_ratio; }
    float getAttack() const      { return m_attack; }
    float getRelease() const     { return m_release; }
    float getKnee() const        { return m_knee; }
    float getMakeupGain() const  { return m_makeupGain; }
    float getMix() const         { return m_mix; }
    bool  isLimiterEnabled() const { return m_limiterEnabled; }
    bool  isAutoMakeup() const   { return m_autoMakeup; }
    bool  isEnabled() const      { return m_enabled; }

    // Thread-safe metering (audio thread writes, UI thread reads)
    float getGainReductionDb() const {
        return m_gainReductionDb.load(std::memory_order_relaxed);
    }

private:
    // Gain computer: Giannoulis soft-knee, log domain
    // Returns gain reduction in dB (positive = compressing)
    float computeGainReduction(float inputDb) const;

    // Compute auto-makeup gain based on threshold and ratio
    float computeAutoMakeupDb() const;

    // Recompute ballistic coefficients from attack/release times
    void updateCoefficients();

    // Parameter mapping helpers
    float thresholdDb() const;   // Map 0–1 → -60..0
    float ratioValue() const;    // Map 0–1 → 1..20
    float attackMs() const;      // Map 0–1 → 0.1..100 (log)
    float releaseMs() const;     // Map 0–1 → 10..1000 (log)
    float kneeDb() const;        // Map 0–1 → 0..12
    float makeupDb() const;      // Map 0–1 → 0..40

    // Parameters (normalized 0–1)
    float m_threshold   = 0.75f;   // -15 dB
    float m_ratio       = 0.158f;  // ~4:1
    float m_attack      = 0.37f;   // ~5 ms (log taper)
    float m_release     = 0.46f;   // ~100 ms (log taper)
    float m_knee        = 0.5f;    // 6 dB
    float m_makeupGain  = 0.0f;    // 0 dB
    float m_mix         = 1.0f;    // 100% wet
    bool  m_limiterEnabled = true;
    bool  m_autoMakeup     = false;
    bool  m_enabled        = false;

    // Ballistic coefficients
    float m_attackCoeff  = 0.0f;
    float m_releaseCoeff = 0.0f;

    // Envelope follower state (dB domain)
    float m_envelopeDb = -120.0f;

    float m_sampleRate = 48000.0f;

    // Thread-safe metering
    std::atomic<float> m_gainReductionDb{0.0f};
};

} // namespace Grainulator

#endif // MASTERCOMPRESSOR_H

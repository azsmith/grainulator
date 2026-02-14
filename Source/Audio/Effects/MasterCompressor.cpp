//
//  MasterCompressor.cpp
//  Grainulator
//
//  Feed-forward compressor/limiter for the master bus.
//  Algorithm: Giannoulis, Massberg & Reiss (2012) —
//  log-domain gain computer with smooth branching peak detector.
//

#include "MasterCompressor.h"

namespace Grainulator {

MasterCompressor::MasterCompressor() {
    updateCoefficients();
}

void MasterCompressor::prepare(float sampleRate) {
    m_sampleRate = sampleRate;
    reset();
}

void MasterCompressor::reset() {
    m_envelopeDb = -120.0f;
    m_gainReductionDb.store(0.0f, std::memory_order_relaxed);
    updateCoefficients();
}

// ─────────────────────────────────────────────────────────────
// Per-sample stereo processing
// ─────────────────────────────────────────────────────────────

void MasterCompressor::processSample(float& left, float& right) {
    if (!m_enabled) return;

    // 1. Stereo-linked peak detection (linear → dB)
    float peak = std::max(std::abs(left), std::abs(right));
    float inputDb = (peak > 1e-6f)
        ? 20.0f * std::log10(peak)
        : -120.0f;

    // 2. Smooth branching envelope follower (dB domain)
    //    Attack when input rises above envelope, release when it falls.
    float coeff = (inputDb > m_envelopeDb) ? m_attackCoeff : m_releaseCoeff;
    m_envelopeDb = coeff * m_envelopeDb + (1.0f - coeff) * inputDb;

    // 3. Gain computer (log domain, soft knee)
    float gr = computeGainReduction(m_envelopeDb);

    // 4. Makeup gain
    float makeup = m_autoMakeup ? computeAutoMakeupDb() : makeupDb();
    float totalGainDb = -gr + makeup;
    float gainLinear = std::pow(10.0f, totalGainDb * 0.05f);

    // 5. Apply with dry/wet mix (parallel compression)
    if (m_mix >= 0.999f) {
        left  *= gainLinear;
        right *= gainLinear;
    } else {
        float wet = m_mix;
        float dry = 1.0f - wet;
        left  = left  * dry + left  * gainLinear * wet;
        right = right * dry + right * gainLinear * wet;
    }

    // 6. Brickwall limiter (simple clamp at 0 dBFS)
    if (m_limiterEnabled) {
        left  = std::max(-1.0f, std::min(1.0f, left));
        right = std::max(-1.0f, std::min(1.0f, right));
    }

    // 7. Update metering (relaxed store — UI reads periodically)
    m_gainReductionDb.store(gr, std::memory_order_relaxed);
}

// ─────────────────────────────────────────────────────────────
// Giannoulis soft-knee gain computer
// ─────────────────────────────────────────────────────────────

float MasterCompressor::computeGainReduction(float inputDb) const {
    float thresh = thresholdDb();
    float ratio  = ratioValue();
    float knee   = kneeDb();
    float slope  = 1.0f - (1.0f / ratio);

    float overshoot = inputDb - thresh;
    float kneeHalf  = knee * 0.5f;

    if (overshoot <= -kneeHalf) {
        // Below threshold: no compression
        return 0.0f;
    }
    if (overshoot >= kneeHalf || knee < 0.01f) {
        // Above knee (or hard knee): full compression
        return slope * overshoot;
    }
    // Inside knee: quadratic interpolation
    float x = overshoot + kneeHalf;
    return slope * (x * x) / (2.0f * knee);
}

float MasterCompressor::computeAutoMakeupDb() const {
    // Approximate static gain reduction at threshold for auto-makeup.
    // For a signal sitting right at threshold, gain reduction ≈ 0,
    // so we estimate based on expected gain reduction at a reference level.
    float thresh = thresholdDb();
    float ratio  = ratioValue();
    float slope  = 1.0f - (1.0f / ratio);
    // Compensate for half the expected GR at threshold
    return -thresh * slope * 0.5f;
}

// ─────────────────────────────────────────────────────────────
// Coefficient calculation
// ─────────────────────────────────────────────────────────────

void MasterCompressor::updateCoefficients() {
    // 1-pole IIR time constants: coeff = exp(-1 / (time_sec * sampleRate))
    float atkSec = attackMs() * 0.001f;
    float relSec = releaseMs() * 0.001f;

    m_attackCoeff  = std::exp(-1.0f / (atkSec * m_sampleRate));
    m_releaseCoeff = std::exp(-1.0f / (relSec * m_sampleRate));
}

// ─────────────────────────────────────────────────────────────
// Parameter setters
// ─────────────────────────────────────────────────────────────

static inline float clamp01(float v) {
    return std::max(0.0f, std::min(1.0f, v));
}

void MasterCompressor::setThreshold(float v) {
    m_threshold = clamp01(v);
}

void MasterCompressor::setRatio(float v) {
    m_ratio = clamp01(v);
}

void MasterCompressor::setAttack(float v) {
    m_attack = clamp01(v);
    updateCoefficients();
}

void MasterCompressor::setRelease(float v) {
    m_release = clamp01(v);
    updateCoefficients();
}

void MasterCompressor::setKnee(float v) {
    m_knee = clamp01(v);
}

void MasterCompressor::setMakeupGain(float v) {
    m_makeupGain = clamp01(v);
}

void MasterCompressor::setMix(float v) {
    m_mix = clamp01(v);
}

void MasterCompressor::setLimiterEnabled(bool v) {
    m_limiterEnabled = v;
}

void MasterCompressor::setAutoMakeup(bool v) {
    m_autoMakeup = v;
}

void MasterCompressor::setEnabled(bool v) {
    m_enabled = v;
}

// ─────────────────────────────────────────────────────────────
// Parameter mapping (normalized 0–1 → real units)
// ─────────────────────────────────────────────────────────────

float MasterCompressor::thresholdDb() const {
    // 0 → -60 dB,  1 → 0 dB  (linear mapping)
    return -60.0f + m_threshold * 60.0f;
}

float MasterCompressor::ratioValue() const {
    // 0 → 1:1,  1 → 20:1  (linear mapping)
    return 1.0f + m_ratio * 19.0f;
}

float MasterCompressor::attackMs() const {
    // 0 → 0.1 ms,  1 → 100 ms  (logarithmic taper)
    return 0.1f * std::pow(1000.0f, m_attack);
}

float MasterCompressor::releaseMs() const {
    // 0 → 10 ms,  1 → 1000 ms  (logarithmic taper)
    return 10.0f * std::pow(100.0f, m_release);
}

float MasterCompressor::kneeDb() const {
    // 0 → 0 dB (hard),  1 → 12 dB (soft)
    return m_knee * 12.0f;
}

float MasterCompressor::makeupDb() const {
    // 0 → 0 dB,  1 → 40 dB
    return m_makeupGain * 40.0f;
}

} // namespace Grainulator

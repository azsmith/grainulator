# Compressor/Limiter Integration Plan for Grainulator

## The Landscape: What's Out There

### Academic Foundation

The gold standard reference is Giannoulis, Massberg & Reiss (2012) — "Digital Dynamic Range Compressor Design — A Tutorial and Analysis" (JAES Vol. 60, No. 6). Their key recommendations:

- Feed-forward topology over feedback — more stable, predictable, supports lookahead
- Log-domain level detection placed after the gain computer — produces smooth envelopes with no attack lag and variable knee width
- Decoupled peak detector — separates attack and release circuits for cleaner behavior
- Source code and audio examples are available from Queen Mary University's digital music lab

### Best Open Source Implementations to Study/Adapt

| Project | License | Language | Best For | Notes |
|---------|---------|----------|----------|-------|
| Airwindows (Pressure6, ButterComp2, Dynamics2) | MIT | C++ | Musical bus compressor | Idiosyncratic but excellent DSP. Pressure6 is explicitly designed for 2-bus duties. Zero latency. |
| sndfilter (velipso) | 0BSD | C | Clean reference implementation | Compressor extracted from Chromium's WebAudio DynamicsCompressorKernel. Very readable, minimal dependencies. |
| CTAGDRC (p-hlp) | GPL-3.0 | C++ (JUCE) | Complete reference with lookahead | Directly implements Giannoulis paper. Excellent documentation. GPL means you can study but not copy verbatim. |
| ChowDSP (chowdsp_utils) | GPL-3.0 | C++ | Compressor building blocks | Has chowdsp::compressor namespace with ballistic coefficients, level detectors. Modern C++ design. |
| SimpleCompressor (Daniel Rudrich) | GPL-3.0 | C++ | Lookahead limiter technique | Pioneered the "fade-in gain reduction" approach to lookahead that CTAGDRC also uses — much better than naive input delay. |
| ChunkWare SimpleComp | Public Domain | C++ | Teaching/starting point | Classic musicdsp.org classes. Envelope detector + simple peak compressor. Very minimal but functional. |

**License verdict:** For Grainulator's MIT license, safest bets are Airwindows (MIT), sndfilter (0BSD), and ChunkWare (public domain) for actual code adaptation. Use the GPL projects as algorithmic references only — implement from the paper, not their code.

## Recommended Architecture for Grainulator

### Phase 1: Master Bus Limiter/Compressor

This should live at the very end of the signal chain in `Source/Audio/Mixer/`, after all channel mixing and the existing master filter.

#### Signal Flow

```
Channel Outputs -> Mixer Sum -> Master Filter (existing) -> Master Compressor/Limiter -> DAC Output
```

#### C++ Class Design

```cpp
// Source/Audio/Effects/MasterCompressor.h
class MasterCompressor {
public:
    struct Parameters {
        float thresholdDb    = 0.0f;    // -60 to 0 dB
        float ratio          = 1.0f;    // 1:1 to inf:1
        float attackMs       = 10.0f;   // 0.1 to 100 ms
        float releaseMs      = 100.0f;  // 10 to 1000 ms
        float kneeDb         = 6.0f;    // 0 (hard) to 20 dB (soft)
        float makeupGainDb   = 0.0f;    // 0 to 40 dB
        float mixPercent     = 100.0f;  // 0 to 100 (dry/wet for parallel compression)
        bool  limiterEnabled = true;    // Brickwall limiter at 0dBFS post-compressor
        bool  autoMakeup     = false;
        float lookaheadMs    = 0.0f;    // 0 = off, typically 1-5ms when on
    };

    void prepare(float sampleRate, int blockSize);
    void process(float* leftChannel, float* rightChannel, int numSamples);
    void setParameters(const Parameters& p);

    // Metering (read from Swift for UI)
    float getGainReductionDb() const;
    float getInputLevelDb() const;
    float getOutputLevelDb() const;

private:
    // Gain computer (Giannoulis feed-forward, log domain)
    float computeGain(float inputDb) const;

    // Level detector (smooth branching peak detector)
    float detectLevel(float inputDb);

    // Lookahead delay buffer (circular)
    float lookaheadBufferL_[MAX_LOOKAHEAD_SAMPLES];
    float lookaheadBufferR_[MAX_LOOKAHEAD_SAMPLES];
    int   lookaheadWritePos_ = 0;

    // Ballistics state
    float envelopeState_ = 0.0f;
    float attackCoeff_   = 0.0f;
    float releaseCoeff_  = 0.0f;

    // Computed from parameters
    float slope_ = 0.0f;  // (1 - 1/ratio)
    float sampleRate_ = 44100.0f;

    // Metering (atomic for thread-safe reads)
    std::atomic<float> gainReductionDb_{0.0f};
    std::atomic<float> inputLevelDb_{-100.0f};
    std::atomic<float> outputLevelDb_{-100.0f};
};
```

#### Core Algorithm (per-sample, log domain)

The heart of the compressor follows the Giannoulis recommended design:

```cpp
void MasterCompressor::process(float* L, float* R, int numSamples) {
    for (int i = 0; i < numSamples; ++i) {
        // 1. LEVEL DETECTION (peak, stereo linked)
        float inputPeak = std::max(std::abs(L[i]), std::abs(R[i]));
        float inputDb = (inputPeak > 1e-6f) ? 20.0f * std::log10f(inputPeak) : -120.0f;

        // 2. GAIN COMPUTER (log domain, soft knee)
        float gainDb = computeGain(inputDb);

        // 3. BALLISTICS (smooth branching peak detector)
        float smoothedGainDb = detectLevel(gainDb);

        // 4. APPLY GAIN (convert back to linear)
        float gainLinear = std::pow(10.0f, smoothedGainDb * 0.05f);

        // 5. MAKEUP GAIN
        float makeupLinear = std::pow(10.0f, params_.makeupGainDb * 0.05f);

        // 6. MIX (parallel compression support)
        float wet = params_.mixPercent * 0.01f;
        float dryL = L[i], dryR = R[i];

        L[i] = dryL * (1.0f - wet) + (dryL * gainLinear * makeupLinear) * wet;
        R[i] = dryR * (1.0f - wet) + (dryR * gainLinear * makeupLinear) * wet;

        // 7. BRICKWALL LIMITER (simple clamp at 0dBFS)
        if (params_.limiterEnabled) {
            L[i] = std::clamp(L[i], -1.0f, 1.0f);
            R[i] = std::clamp(R[i], -1.0f, 1.0f);
        }

        // 8. UPDATE METERING
        gainReductionDb_.store(smoothedGainDb, std::memory_order_relaxed);
    }
}

float MasterCompressor::computeGain(float inputDb) const {
    // Giannoulis soft-knee gain computer
    float overshoot = inputDb - params_.thresholdDb;
    float kneeHalf = params_.kneeDb * 0.5f;

    if (overshoot <= -kneeHalf) {
        return 0.0f; // Below threshold, no compression
    }
    if (overshoot >= kneeHalf) {
        return -slope_ * overshoot; // Above knee, full compression
    }
    // In knee region: second-order interpolation
    float x = overshoot + kneeHalf;
    return -0.5f * slope_ * (x * x) / params_.kneeDb;
}

float MasterCompressor::detectLevel(float gainDb) {
    // Smooth branching peak detector
    float coeff = (gainDb < envelopeState_) ? attackCoeff_ : releaseCoeff_;
    envelopeState_ = coeff * envelopeState_ + (1.0f - coeff) * gainDb;
    return envelopeState_;
}
```

#### Coefficient Calculation

```cpp
void MasterCompressor::prepare(float sampleRate, int blockSize) {
    sampleRate_ = sampleRate;
    updateCoefficients();
}

void MasterCompressor::updateCoefficients() {
    slope_ = 1.0f - (1.0f / params_.ratio);

    // Attack: time constant for 1-pole IIR
    // exp(-1 / (time_in_seconds * sample_rate))
    float attackSec = params_.attackMs * 0.001f;
    attackCoeff_ = std::exp(-1.0f / (attackSec * sampleRate_));

    float releaseSec = params_.releaseMs * 0.001f;
    releaseCoeff_ = std::exp(-1.0f / (releaseSec * sampleRate_));
}
```

## Integration Points in Your Codebase

Based on the project structure:

1. **New files:** `Source/Audio/Effects/MasterCompressor.h` and `.cpp`
2. **Mixer integration:** In the mixer's final output stage (likely in `Source/Audio/Mixer/`), call `masterCompressor_.process(leftBus, rightBus, numSamples)` after summing all channels and applying master filter
3. **Swift bridge:** Expose parameters through `AudioEngineBridge.h` so the SwiftUI layer can drive the controls
4. **Command queue:** Use the existing lock-free command queue pattern to send parameter changes from the UI thread

### SwiftUI Controls

Recommended control set for the master compressor view (could be a tab in the existing effects section):

- **Threshold** knob (-60 to 0 dB)
- **Ratio** knob (1:1 to inf:1, with detents at 2, 4, 8, 20, inf)
- **Attack** knob (0.1 to 100 ms, logarithmic taper)
- **Release** knob (10 to 1000 ms, logarithmic taper)
- **Knee** knob (0 to 20 dB)
- **Makeup** knob (0 to 40 dB)
- **Mix** knob (0-100%, for parallel compression)
- **GR Meter** — animated gain reduction display
- **Limiter** toggle
- **Auto Makeup** toggle

## Phase 2: Per-Channel Compressor

Once the master bus compressor is working, per-channel compression is architecturally straightforward because there are already insert effects routing in the mixer.

### Design Differences from Master

The per-channel compressor should be lighter weight since multiple instances run simultaneously (one per mixer channel). Key differences:

- No lookahead (saves latency and memory per channel)
- Mono detection (each channel processes independently unless stereo-linked)
- Sidechain HP filter option — very useful for preventing bass-heavy synth patches from triggering over-compression. A simple first-order HP at 60-150Hz on the sidechain is standard.
- Possibly simpler UI — threshold, ratio, attack/release, makeup only

```cpp
// Lighter per-channel version
class ChannelCompressor {
public:
    struct Parameters {
        float thresholdDb  = 0.0f;
        float ratio        = 1.0f;
        float attackMs     = 10.0f;
        float releaseMs    = 100.0f;
        float kneeDb       = 6.0f;
        float makeupGainDb = 0.0f;
        float sidechainHPFreq = 0.0f; // 0 = off, 60-300 Hz typical
    };

    void prepare(float sampleRate);
    void process(float* channel, int numSamples);  // Mono processing
    void setParameters(const Parameters& p);
    float getGainReductionDb() const;

private:
    float computeGain(float inputDb) const;
    float detectLevel(float gainDb);

    // Sidechain highpass (1-pole)
    float sidechainHP(float input);
    float hpState_ = 0.0f;
    float hpCoeff_ = 0.0f;

    float envelopeState_ = 0.0f;
    float attackCoeff_ = 0.0f;
    float releaseCoeff_ = 0.0f;
    float slope_ = 0.0f;
    float sampleRate_ = 44100.0f;
};
```

### Mixer Integration

```
Channel Source -> Channel Gain -> Insert Effects -> Channel Compressor -> Pan/Mute/Solo -> Master Bus
```

## Grainulator-Specific Considerations

### Grain Cloud Protection

The granular engine can produce extreme and unpredictable amplitude spikes — dense grain clouds with high density and small size can suddenly peak at very high levels. A fast-attack limiter on the granular voice output (separate from the master compressor) is worth considering. This would be a minimal, zero-latency limiter with:

- Fixed threshold at -1 dBFS
- Instantaneous attack
- Fast release (5-20ms)
- No user controls (always-on safety limiter)

### Plaits/Rings Engine Levels

The Mutable Instruments engines have varying output levels. Per-channel compression helps normalize these before they hit the master bus.

### Conversational Control API

The existing HTTP API on port 4850 should expose the compressor parameters:

```
POST /api/mixer/master/compressor
{
  "threshold": -12.0,
  "ratio": 4.0,
  "attack_ms": 5.0,
  "release_ms": 100.0
}
```

## Recommended Approach

### What to study but NOT copy (GPL):
- **CTAGDRC** — best documentation of the full Giannoulis algorithm with lookahead
- **ChowDSP** — excellent modern C++ patterns for DSP
- **SimpleCompressor (Rudrich)** — the fade-in lookahead technique

### What you CAN adapt (MIT / 0BSD / Public Domain):
- **Airwindows Pressure6** — MIT licensed, bus compressor purpose-built
- **Airwindows ButterComp2** — MIT, simpler and more transparent compressor character
- **sndfilter compressor.c** — 0BSD license, derived from Chromium's WebAudio
- **ChunkWare SimpleComp** — public domain C++ classes for envelope detection and basic compression

### Implementation order:
1. Start with the algorithm from the Giannoulis paper — well-documented, produces clean professional results
2. Use sndfilter as a code reference for the cleanest C implementation
3. Add a brickwall safety limiter at the master output (simple hard clip at 0dBFS as starting point, then upgrade to proper lookahead limiter)
4. Study Airwindows Pressure6 for the musical "glue" compressor character — may want to offer both transparent and characterful modes
5. Add per-channel compression once the master bus is solid

## Key References

- Giannoulis et al. (2012) — "Digital Dynamic Range Compressor Design" (JAES Vol. 60, No. 6)
- Airwindows source — GitHub (MIT)
- sndfilter — GitHub (0BSD)
- CTAGDRC — GitHub (GPL-3.0, reference only)
- ChunkWare SimpleComp — musicdsp.org
- Daniel Rudrich Lookahead Technique — GitHub docs

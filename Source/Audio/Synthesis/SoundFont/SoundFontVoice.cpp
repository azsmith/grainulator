//
//  SoundFontVoice.cpp
//  Grainulator
//
//  SoundFont (.sf2) polyphonic sample player voice
//  Uses TinySoundFont (MIT License) by Bernhard Schelling
//

#define TSF_IMPLEMENTATION
#include "tsf.h"

#include "SoundFontVoice.h"
#include <cstring>
#include <cmath>
#include <algorithm>

namespace Grainulator {

SoundFontVoice::SoundFontVoice()
    : m_sampleRate(48000.0f)
    , m_tsfActive(nullptr)
    , m_tsfLoading(nullptr)
    , m_swapPending(false)
    , m_pendingFree(nullptr)
    , m_currentPreset(0)
    , m_level(0.8f)
    , m_attack(0.0f)
    , m_decay(0.0f)
    , m_sustain(1.0f)
    , m_release(0.1f)
    , m_filterCutoff(1.0f)
    , m_filterResonance(0.0f)
    , m_tuning(0.0f)
    , m_maxPolyphony(32)
    , m_filterStateL(0.0f)
    , m_filterStateR(0.0f)
    , m_renderBuffer(nullptr)
    , m_renderBufferSize(0)
{
}

SoundFontVoice::~SoundFontVoice() {
    if (m_tsfActive) {
        tsf_close(static_cast<tsf*>(m_tsfActive));
        m_tsfActive = nullptr;
    }
    if (m_tsfLoading) {
        tsf_close(static_cast<tsf*>(m_tsfLoading));
        m_tsfLoading = nullptr;
    }
    if (m_pendingFree) {
        tsf_close(static_cast<tsf*>(m_pendingFree));
        m_pendingFree = nullptr;
    }
    delete[] m_renderBuffer;
    m_renderBuffer = nullptr;
}

void SoundFontVoice::Init(float sample_rate) {
    m_sampleRate = sample_rate;
    m_filterStateL = 0.0f;
    m_filterStateR = 0.0f;

    // Pre-allocate render buffer for typical max buffer size (2048 stereo frames)
    m_renderBufferSize = 4096;
    m_renderBuffer = new float[m_renderBufferSize];
    std::memset(m_renderBuffer, 0, m_renderBufferSize * sizeof(float));
}

void SoundFontVoice::CheckSwap() {
    if (m_swapPending.load(std::memory_order_acquire)) {
        // Free any previously pending old instance
        // (This deferred free happens on the audio thread but only for an
        //  instance that was already swapped out in a prior Render call.
        //  The tsf_close is lightweight — it just calls free() on a few
        //  allocations. In practice this is safe because it happens at most
        //  once per SF2 load, not per buffer. If this becomes a concern,
        //  move to a lock-free free-list checked by a background timer.)
        if (m_pendingFree) {
            tsf_close(static_cast<tsf*>(m_pendingFree));
            m_pendingFree = nullptr;
        }

        // Swap: save old active for deferred free, install new
        m_pendingFree = m_tsfActive;
        m_tsfActive = m_tsfLoading;
        m_tsfLoading = nullptr;
        m_swapPending.store(false, std::memory_order_release);
    }
}

bool SoundFontVoice::LoadSoundFont(const char* filePath) {
    // This runs on a background thread — allocations are fine here.
    tsf* newTsf = tsf_load_filename(filePath);
    if (!newTsf) {
        return false;
    }

    // Configure for stereo unweaved output at engine sample rate
    tsf_set_output(newTsf, TSF_STEREO_UNWEAVED, static_cast<int>(m_sampleRate), 0.0f);

    // Pre-allocate voice pool to avoid allocations during note_on
    tsf_set_max_voices(newTsf, m_maxPolyphony);

    // Pre-create channel 0 so render is safe from a different thread
    tsf_channel_set_presetindex(newTsf, 0, m_currentPreset);
    tsf_channel_set_volume(newTsf, 0, m_level);
    tsf_channel_set_tuning(newTsf, 0, m_tuning);

    // Signal audio thread to swap
    m_tsfLoading = newTsf;
    m_swapPending.store(true, std::memory_order_release);

    return true;
}

void SoundFontVoice::UnloadSoundFont() {
    // Create an empty placeholder to swap in (effectively unloading)
    m_tsfLoading = nullptr;
    m_swapPending.store(true, std::memory_order_release);
}

bool SoundFontVoice::IsLoaded() const {
    return m_tsfActive != nullptr;
}

void SoundFontVoice::FreeTsf(void* tsfPtr) {
    if (tsfPtr) {
        tsf_close(static_cast<tsf*>(tsfPtr));
    }
}

// --- Preset management ---

void SoundFontVoice::SetPreset(int presetIndex) {
    m_currentPreset = presetIndex;
    tsf* f = static_cast<tsf*>(m_tsfActive);
    if (f) {
        // Use channel-based API: set preset on channel 0
        tsf_channel_set_presetindex(f, 0, presetIndex);
    }
}

int SoundFontVoice::GetPresetCount() const {
    tsf* f = static_cast<tsf*>(m_tsfActive);
    return f ? tsf_get_presetcount(f) : 0;
}

const char* SoundFontVoice::GetPresetName(int index) const {
    tsf* f = static_cast<tsf*>(m_tsfActive);
    return f ? tsf_get_presetname(f, index) : "";
}

// --- Note control ---

void SoundFontVoice::NoteOn(int note, float velocity) {
    tsf* f = static_cast<tsf*>(m_tsfActive);
    if (f) {
        tsf_channel_note_on(f, 0, note, velocity);
    }
}

void SoundFontVoice::NoteOff(int note) {
    tsf* f = static_cast<tsf*>(m_tsfActive);
    if (f) {
        tsf_channel_note_off(f, 0, note);
    }
}

void SoundFontVoice::AllNotesOff() {
    tsf* f = static_cast<tsf*>(m_tsfActive);
    if (f) {
        tsf_channel_sounds_off_all(f, 0);
    }
}

int SoundFontVoice::GetActiveVoiceCount() const {
    tsf* f = static_cast<tsf*>(m_tsfActive);
    return f ? tsf_active_voice_count(f) : 0;
}

// --- Parameters ---

void SoundFontVoice::SetLevel(float value) {
    m_level = std::clamp(value, 0.0f, 1.0f);
    tsf* f = static_cast<tsf*>(m_tsfActive);
    if (f) {
        tsf_channel_set_volume(f, 0, m_level);
    }
}

void SoundFontVoice::SetAttack(float value) {
    m_attack = std::clamp(value, 0.0f, 1.0f);
    // TSF doesn't expose per-channel ADSR override directly.
    // Attack/Decay/Sustain/Release are baked into the SF2 preset generators.
    // These params are stored for state snapshot and future envelope override.
}

void SoundFontVoice::SetDecay(float value) {
    m_decay = std::clamp(value, 0.0f, 1.0f);
}

void SoundFontVoice::SetSustain(float value) {
    m_sustain = std::clamp(value, 0.0f, 1.0f);
}

void SoundFontVoice::SetRelease(float value) {
    m_release = std::clamp(value, 0.0f, 1.0f);
}

void SoundFontVoice::SetFilterCutoff(float value) {
    m_filterCutoff = std::clamp(value, 0.0f, 1.0f);
}

void SoundFontVoice::SetFilterResonance(float value) {
    m_filterResonance = std::clamp(value, 0.0f, 1.0f);
}

void SoundFontVoice::SetTuning(float semitones) {
    m_tuning = std::clamp(semitones, -24.0f, 24.0f);
    tsf* f = static_cast<tsf*>(m_tsfActive);
    if (f) {
        // TSF tuning is in semitones relative to standard tuning
        tsf_channel_set_tuning(f, 0, m_tuning);
    }
}

void SoundFontVoice::SetMaxPolyphony(int voices) {
    m_maxPolyphony = std::clamp(voices, 1, 64);
    tsf* f = static_cast<tsf*>(m_tsfActive);
    if (f) {
        tsf_set_max_voices(f, m_maxPolyphony);
    }
}

// --- Render ---

void SoundFontVoice::Render(float* out_left, float* out_right, size_t size) {
    // Check for pending SoundFont swap
    CheckSwap();

    tsf* f = static_cast<tsf*>(m_tsfActive);
    if (!f || size == 0) {
        std::memset(out_left, 0, size * sizeof(float));
        std::memset(out_right, 0, size * sizeof(float));
        return;
    }

    // Ensure render buffer is large enough (stereo unweaved: L then R)
    const size_t needed = size * 2;
    if (needed > m_renderBufferSize) {
        // This allocation should never happen during normal operation
        // because Init() pre-allocates for kMaxBufferSize (2048).
        // But guard against it just in case.
        delete[] m_renderBuffer;
        m_renderBufferSize = needed;
        m_renderBuffer = new float[m_renderBufferSize];
    }

    // TSF_STEREO_UNWEAVED: first `size` floats are left, next `size` are right
    std::memset(m_renderBuffer, 0, needed * sizeof(float));
    tsf_render_float(f, m_renderBuffer, static_cast<int>(size), 0);

    const float* srcL = m_renderBuffer;
    const float* srcR = m_renderBuffer + size;

    // Apply post-render one-pole low-pass filter if cutoff < 1.0
    if (m_filterCutoff < 0.999f) {
        // Map normalized cutoff (0-1) to frequency coefficient
        // 0.0 → ~20Hz, 1.0 → ~20kHz (bypass)
        const float freq = 20.0f * std::pow(1000.0f, m_filterCutoff);
        const float w = 2.0f * 3.14159265f * freq / m_sampleRate;
        const float coeff = std::clamp(w / (1.0f + w), 0.0f, 1.0f);

        for (size_t i = 0; i < size; ++i) {
            m_filterStateL += coeff * (srcL[i] - m_filterStateL);
            m_filterStateR += coeff * (srcR[i] - m_filterStateR);
            out_left[i] = m_filterStateL;
            out_right[i] = m_filterStateR;
        }
    } else {
        // No filter — direct copy
        std::memcpy(out_left, srcL, size * sizeof(float));
        std::memcpy(out_right, srcR, size * sizeof(float));
    }
}

} // namespace Grainulator

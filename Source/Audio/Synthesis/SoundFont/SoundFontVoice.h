//
//  SoundFontVoice.h
//  Grainulator
//
//  SoundFont (.sf2) polyphonic sample player voice
//  Uses TinySoundFont (MIT License) by Bernhard Schelling
//

#ifndef SOUNDFONTVOICE_H
#define SOUNDFONTVOICE_H

#include <cstddef>
#include <atomic>

namespace Grainulator {

class SoundFontVoice {
public:
    SoundFontVoice();
    ~SoundFontVoice();

    void Init(float sample_rate);

    // Block-based stereo render (matches engine voice pattern)
    void Render(float* out_left, float* out_right, size_t size);

    // SF2 file loading — MUST be called OFF the audio thread.
    // Atomically swaps the active TSF instance when ready.
    bool LoadSoundFont(const char* filePath);
    void UnloadSoundFont();
    bool IsLoaded() const;

    // Preset selection (0 to GetPresetCount()-1)
    void SetPreset(int presetIndex);
    int  GetPreset() const { return m_currentPreset; }
    int  GetPresetCount() const;
    const char* GetPresetName(int index) const;

    // Polyphonic note control
    void NoteOn(int note, float velocity);   // velocity 0.0–1.0
    void NoteOff(int note);
    void AllNotesOff();

    // Active voice count (for metering/diagnostics)
    int GetActiveVoiceCount() const;

    // Parameters (all 0.0–1.0 normalized unless noted)
    void SetLevel(float value);
    void SetAttack(float value);
    void SetDecay(float value);
    void SetSustain(float value);
    void SetRelease(float value);
    void SetFilterCutoff(float value);
    void SetFilterResonance(float value);
    void SetTuning(float semitones);       // -24 to +24
    void SetMaxPolyphony(int voices);      // 1–64, default 32

private:
    float m_sampleRate;

    // Double-buffered TSF: audio thread reads m_tsfActive,
    // loader thread writes m_tsfLoading then sets m_swapPending.
    void* m_tsfActive;
    void* m_tsfLoading;
    std::atomic<bool> m_swapPending;

    // Old instance pending deferred free (set by audio thread after swap)
    void* m_pendingFree;

    // Parameter state
    int   m_currentPreset;
    float m_level;
    float m_attack, m_decay, m_sustain, m_release;
    float m_filterCutoff, m_filterResonance;
    float m_tuning;
    int   m_maxPolyphony;

    // Simple one-pole low-pass filter state (post-TSF)
    float m_filterStateL;
    float m_filterStateR;

    // Interleaved render buffer for TSF (stereo unweaved)
    float* m_renderBuffer;
    size_t m_renderBufferSize;

    // Apply the pending TSF swap if flagged (called at top of Render)
    void CheckSwap();

    // Free a TSF instance safely (called off audio thread)
    static void FreeTsf(void* tsf);

    SoundFontVoice(const SoundFontVoice&) = delete;
    SoundFontVoice& operator=(const SoundFontVoice&) = delete;
};

} // namespace Grainulator
#endif

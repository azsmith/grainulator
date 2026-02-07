//
//  WavSamplerVoice.h
//  Grainulator
//
//  WAV-based polyphonic sample player voice for mx.samples instruments.
//  Loads directories of WAV files with mx.samples naming convention:
//    {midiNote}.{dynamicLayer}.{totalDynamics}.{variation}.{isRelease}.wav
//  Provides velocity-layered, round-robin multi-sample playback with
//  pitch interpolation, ADSR envelope, and post-render filter.
//

#ifndef WAVSAMPLERVOICE_H
#define WAVSAMPLERVOICE_H

#include <cstddef>
#include <cstdint>
#include <atomic>

namespace Grainulator {

// --- Sample data structures (built during load, read-only on audio thread) ---

struct WavSample {
    float* data;            // Interleaved stereo PCM (even mono is stored as stereo)
    size_t frameCount;      // Total frames
    int sampleRate;         // Original sample rate
    int rootNote;           // MIDI note this sample was recorded at
    int dynamicLayer;       // 0-based dynamic layer index
    int totalDynamics;      // How many dynamic layers exist for this note
    int variation;          // Round-robin variation index (0-based)
    bool isRelease;         // True if this is a release/tail sample
};

struct SampleMap {
    WavSample* samples;         // All loaded samples (owned)
    int sampleCount;            // Total number of loaded samples
    size_t totalMemoryBytes;    // Total memory used by sample data

    // Lookup acceleration: for each MIDI note (0-127), store index range
    // into sorted samples array. -1 means no samples for this note.
    struct NoteEntry {
        int firstSampleIndex;   // Index into samples[]
        int sampleCount;        // Number of samples at this note
    };
    NoteEntry noteTable[128];

    // Instrument name (derived from directory name)
    char instrumentName[256];
};

// --- Polyphonic voice slot ---

struct SamplerVoiceSlot {
    enum class State : uint8_t { Off, Attack, Decay, Sustain, Release };

    State state;
    int note;               // MIDI note being played
    float velocity;         // 0.0-1.0
    float playbackRate;     // Pitch-shifted playback rate
    double playhead;        // Current position in sample (fractional frames)
    const WavSample* sample;// Pointer to the sample being played

    // ADSR envelope state
    float envLevel;         // Current envelope level (0.0-1.0)
    float envPhase;         // Time in current envelope phase (seconds)

    // Timestamp for voice stealing (lower = older)
    uint64_t startTime;
};

// --- Main voice class ---

class WavSamplerVoice {
public:
    WavSamplerVoice();
    ~WavSamplerVoice();

    void Init(float sample_rate);

    // Block-based stereo render (matches engine voice pattern)
    void Render(float* out_left, float* out_right, size_t size);

    // Load all WAVs from a directory — MUST be called OFF the audio thread.
    // Parses mx.samples filename convention, builds sample map,
    // atomically swaps when ready.
    bool LoadFromDirectory(const char* dirPath);
    void Unload();
    bool IsLoaded() const;
    const char* GetInstrumentName() const;

    // Polyphonic note control
    void NoteOn(int note, float velocity);   // velocity 0.0-1.0
    void NoteOff(int note);
    void AllNotesOff();

    // Active voice count (for metering/diagnostics)
    int GetActiveVoiceCount() const;

    // Parameters (all 0.0-1.0 normalized unless noted)
    void SetLevel(float value);
    void SetAttack(float value);
    void SetDecay(float value);
    void SetSustain(float value);
    void SetRelease(float value);
    void SetFilterCutoff(float value);
    void SetFilterResonance(float value);
    void SetTuning(float semitones);       // -24 to +24
    void SetMaxPolyphony(int voices);      // 1-32, default 16

private:
    static constexpr int kMaxVoices = 32;

    float m_sampleRate;

    // Double-buffered SampleMap: audio thread reads m_mapActive,
    // loader thread writes m_mapLoading then sets m_swapPending.
    SampleMap* m_mapActive;
    SampleMap* m_mapLoading;
    std::atomic<bool> m_swapPending;
    SampleMap* m_pendingFree;   // Old map awaiting deferred free

    // Polyphonic voice pool (pre-allocated, no audio-thread allocs)
    SamplerVoiceSlot m_voices[kMaxVoices];
    int m_maxPolyphony;
    uint64_t m_voiceCounter;    // Monotonic counter for voice age

    // Round-robin state per note
    int m_roundRobin[128];

    // Parameter state
    float m_level;
    float m_attack, m_decay, m_sustain, m_release;
    float m_filterCutoff, m_filterResonance;
    float m_tuning;

    // Post-render one-pole low-pass filter state
    float m_filterStateL;
    float m_filterStateR;

    // Apply the pending SampleMap swap if flagged (called at top of Render)
    void CheckSwap();

    // Free a SampleMap and all its sample data
    static void FreeSampleMap(SampleMap* map);

    // Find the best sample for a given note + velocity from the active map
    const WavSample* FindSample(int note, float velocity);

    // Find a free voice slot, or steal the oldest
    int AllocateVoice();

    // Compute playback rate for pitch shifting
    float ComputePlaybackRate(int targetNote, int rootNote, int sampleRate) const;

    // Advance ADSR envelope for a voice slot, returns current level
    float AdvanceEnvelope(SamplerVoiceSlot& voice, float dt);

    WavSamplerVoice(const WavSamplerVoice&) = delete;
    WavSamplerVoice& operator=(const WavSamplerVoice&) = delete;
};

} // namespace Grainulator
#endif

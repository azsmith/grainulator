//
//  PlaitsVoice.h
//  Grainulator
//
//  Plaits synthesis voice wrapper
//  Based on Mutable Instruments Plaits (MIT License)
//  Copyright 2016 Émilie Gillet
//

#ifndef PLAITSVOICE_H
#define PLAITSVOICE_H

#include <cstdint>
#include <cstddef>

namespace Grainulator {

/// Plaits synthesis voice wrapper
/// Provides a simplified interface to the Mutable Instruments Plaits engine
class PlaitsVoice {
public:
    PlaitsVoice();
    ~PlaitsVoice();

    // Initialization
    void Init(float sample_rate);

    // Audio rendering
    // Renders audio into output buffers
    // out: main output buffer
    // aux: auxiliary output buffer (optional, can be nullptr)
    // size: number of samples to render
    void Render(float* out, float* aux, size_t size);

    // Engine selection (0-16 for the 17 models)
    void SetEngine(int engine);
    int GetEngine() const { return current_engine_; }

    // Note control (MIDI note number, 0-127, fractional allowed)
    void SetNote(float note);

    // Parameter control (all 0.0-1.0 range)
    void SetHarmonics(float value);
    void SetTimbre(float value);
    void SetMorph(float value);

    // Trigger/Gate
    void Trigger(bool state);

    // Level/Accent (0.0-1.0)
    void SetLevel(float value);

    // Modulation amounts (how much modulation affects each parameter)
    void SetHarmonicsModAmount(float amount);
    void SetTimbreModAmount(float amount);
    void SetMorphModAmount(float amount);

    // LPG (Low-Pass Gate) control
    void SetLPGColor(float color);      // 0.0 = VCA only, 1.0 = VCA + LP filter
    void SetLPGDecay(float decay);      // 0.0 = short, 1.0 = long decay
    void SetLPGAttack(float attack);    // 0.0 = instant, 1.0 = slow attack

    // LPG Bypass (for testing) - when true, audio passes through without LPG processing
    void SetLPGBypass(bool bypass);
    bool GetLPGBypass() const { return lpg_bypass_; }

    // Custom wavetable loading (passed through to WavetableEngine)
    void LoadUserWavetable(const float* data, int numSamples, int frameSize = 0);

private:
    float sample_rate_;
    int current_engine_;

    // Current parameter values
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;
    float level_;
    bool trigger_state_;

    // Modulation amounts
    float harmonics_mod_amount_;
    float timbre_mod_amount_;
    float morph_mod_amount_;

    // LPG parameters
    float lpg_color_;
    float lpg_decay_;
    float lpg_attack_;
    bool lpg_bypass_;  // When true, bypass LPG entirely (for testing)

    // Envelope state
    float envelope_;
    float envelope_target_;
    bool prev_trigger_;
    int trigger_count_;  // Counts pending triggers (for fast repeated notes)

    // LPG filter state
    float lpg_filter_state_;

    // Engine crossfade state
    int previous_engine_;           // Engine we're fading from (-1 = none)
    float crossfade_position_;      // 0.0 = old engine, 1.0 = new engine
    float crossfade_increment_;     // Per-sample crossfade speed
    static constexpr float kCrossfadeDurationMs = 30.0f;

    // Engine instances (using void* to avoid header dependencies)
    void* va_engine_;         // VirtualAnalogEngine (0)
    void* ws_engine_;         // WaveshapingEngine (1)
    void* fm_engine_;         // FMEngine (2)
    void* formant_engine_;    // FormantEngine (3)
    void* harmonic_engine_;   // HarmonicEngine (4)
    void* wavetable_engine_;  // WavetableEngine (5)
    void* chord_engine_;      // ChordEngine (6)
    void* speech_engine_;     // SpeechEngine (7)
    void* grain_engine_;      // GrainEngine (8)
    void* noise_engine_;      // NoiseEngine (9, 10)
    void* string_engine_;     // StringEngine (11, 12)
    void* percussion_engine_; // PercussionEngine (13, 14, 15)
    void* sixop_fm_engine_;   // SixOpFMEngine (16)

    // Internal render helpers
    void RenderEngine(float* out, float* aux, size_t size);
    void RenderSpecificEngine(int engine, float* out, float* aux, size_t size);

    // Check if current engine is percussion (kick, snare, hihat)
    bool IsPercussionEngine() const;

    // Check if current engine is a triggered engine (11-15) with internal envelope
    // These engines bypass the LPG and manage their own decay
    bool IsTriggeredEngine() const;

    // Check if current engine is granular (8-10)
    bool IsGranularEngine() const;

    // Prevent copying
    PlaitsVoice(const PlaitsVoice&) = delete;
    PlaitsVoice& operator=(const PlaitsVoice&) = delete;
};

} // namespace Grainulator

#endif // PLAITSVOICE_H

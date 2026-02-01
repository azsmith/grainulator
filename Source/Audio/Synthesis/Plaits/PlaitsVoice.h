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

    // Engine selection (0-15 for the 16 models)
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
    void SetLPGColor(float color);     // 0.0 = LP, 1.0 = VCA
    void SetLPGDecay(float decay);      // 0.0-1.0

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

    // TODO: Add actual Plaits voice instance
    // plaits::Voice voice_;

    // Prevent copying
    PlaitsVoice(const PlaitsVoice&) = delete;
    PlaitsVoice& operator=(const PlaitsVoice&) = delete;
};

} // namespace Grainulator

#endif // PLAITSVOICE_H

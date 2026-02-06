//
//  DaisyDrumVoice.h
//  Grainulator
//
//  DaisySP drum synthesis voice wrapper
//  Wraps 5 drum models from DaisySP (MIT License)
//  Original DSP by Émilie Gillet, ported by Electrosmith
//

#ifndef DAISYDRUMVOICE_H
#define DAISYDRUMVOICE_H

#include <cstddef>

namespace Grainulator {

class DaisyDrumVoice {
public:
    enum Engine {
        AnalogKick = 0,
        SyntheticKick,
        AnalogSnare,
        SyntheticSnare,
        HiHat,
        NumEngines
    };

    DaisyDrumVoice();
    ~DaisyDrumVoice();

    void Init(float sample_rate);

    // Block-based render (matches PlaitsVoice signature)
    // aux can be nullptr; drums are mono, aux gets an attenuated copy
    void Render(float* out, float* aux, size_t size);

    // Engine selection (0–4)
    void SetEngine(int engine);
    int  GetEngine() const { return engine_; }

    // Frequency via MIDI note (converted to Hz internally)
    void SetNote(float note);

    // Unified parameter interface (all 0.0–1.0)
    void SetHarmonics(float value);   // Param A: tone/character
    void SetTimbre(float value);      // Param B: color/brightness
    void SetMorph(float value);       // Param C: decay/snappiness

    // Trigger (true = strike the drum)
    void Trigger(bool state);

    // Accent/velocity (0.0–1.0)
    void SetLevel(float value);

    // Modulation amounts (for clock mod routing)
    void SetHarmonicsMod(float amount);
    void SetTimbreMod(float amount);
    void SetMorphMod(float amount);

private:
    float sample_rate_;
    int   engine_;
    float note_;
    float harmonics_, timbre_, morph_;
    float level_;
    float harmonics_mod_, timbre_mod_, morph_mod_;
    bool  trigger_state_;
    bool  prev_trigger_;

    // DaisySP engine instances (void* to avoid header leakage)
    void* analog_kick_;
    void* synth_kick_;
    void* analog_snare_;
    void* synth_snare_;
    void* hihat_;

    DaisyDrumVoice(const DaisyDrumVoice&) = delete;
    DaisyDrumVoice& operator=(const DaisyDrumVoice&) = delete;
};

} // namespace Grainulator
#endif

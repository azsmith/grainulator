//
//  RingsVoice.h
//  Grainulator
//
//  Mutable Instruments Rings-inspired resonator voice wrapper.
//

#ifndef RINGSVOICE_H
#define RINGSVOICE_H

#include <cstddef>
#include <cstdint>

#include "rings/dsp/part.h"
#include "rings/dsp/strummer.h"
#include "rings/dsp/performance_state.h"
#include "rings/dsp/patch.h"

namespace Grainulator {

class RingsVoice {
public:
    RingsVoice();

    void Init(float sample_rate);

    void NoteOn(int midiNote, int velocity);
    void NoteOff(int midiNote);

    void SetNote(float midiNote);
    void SetStructure(float value);
    void SetBrightness(float value);
    void SetDamping(float value);
    void SetPosition(float value);
    void SetModel(int modelIndex);
    void SetLevel(float value);

    // Extended parameters
    void SetPolyphony(int polyphony);       // 1, 2, or 4
    void SetChord(int chord);               // 0-10 (11 chords)
    void SetFM(float fm);                   // 0-1, maps to ±24 semitones
    void SetInternalExciter(bool internal);

    // Render with external excitation input
    void Render(const float* in, float* out, float* aux, size_t size);

    // Modulation (adds to base value, clamped to 0-0.9995)
    void SetStructureMod(float amount);
    void SetBrightnessMod(float amount);
    void SetDampingMod(float amount);
    void SetPositionMod(float amount);

private:
    static constexpr size_t kRenderBlockSize = rings::kMaxBlockSize;

    float sample_rate_;
    float note_;
    float level_;
    bool trigger_pending_;

    rings::Part part_;
    rings::Strummer strummer_;
    rings::Patch patch_;
    rings::Patch base_patch_;
    rings::PerformanceState performance_;

    float input_buffer_[kRenderBlockSize];
    float render_l_[kRenderBlockSize];
    float render_r_[kRenderBlockSize];
    uint16_t reverb_buffer_[32768];

    // Extended parameter state
    int chord_;              // 0-10, default 0
    float fm_;               // 0-1, default 0
    bool internal_exciter_;  // default true

    // Modulation amounts (0-1, added to base patch values)
    float structure_mod_;
    float brightness_mod_;
    float damping_mod_;
    float position_mod_;
};

} // namespace Grainulator

#endif // RINGSVOICE_H

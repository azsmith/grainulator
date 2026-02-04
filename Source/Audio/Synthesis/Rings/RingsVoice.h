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
    void Render(float* out, float* aux, size_t size);

    void NoteOn(int midiNote, int velocity);
    void NoteOff(int midiNote);

    void SetNote(float midiNote);
    void SetStructure(float value);
    void SetBrightness(float value);
    void SetDamping(float value);
    void SetPosition(float value);
    void SetModel(int modelIndex);
    void SetLevel(float value);

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
};

} // namespace Grainulator

#endif // RINGSVOICE_H

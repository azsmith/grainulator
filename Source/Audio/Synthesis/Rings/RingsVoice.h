//
//  RingsVoice.h
//  Grainulator
//
//  Mutable Instruments Rings-inspired resonator voice wrapper.
//

#ifndef RINGSVOICE_H
#define RINGSVOICE_H

#include <atomic>
#include <cstddef>
#include <cstdint>

#include "rings/dsp/part.h"
#include "rings/dsp/strummer.h"
#include "rings/dsp/performance_state.h"
#include "rings/dsp/patch.h"
#include "rings/dsp/string_synth_part.h"

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
    void SetFM(float fm);                   // 0-1, maps to ±48 semitones
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
    static constexpr int kMaxNoteQueue = 8;
    static constexpr int kEasterEggModelOffset = 6;  // Models 6-11 use StringSynthPart

    struct NoteEvent {
        float note;
        float excitation_gain;  // Velocity-derived, scales exciter input
    };

    float sample_rate_;
    float note_;
    float level_;               // Output gain (LEVEL knob only)
    float excitation_gain_;     // Velocity-derived, scales exciter input

    // Note event queue — allows multiple NoteOns between Render() calls
    // so each gets its own strum in a separate render block.
    NoteEvent note_queue_[kMaxNoteQueue];
    int note_queue_head_;
    int note_queue_tail_;
    int note_queue_count_;

    rings::Part part_;
    rings::Strummer strummer_;
    rings::Patch patch_;
    rings::Patch base_patch_;
    rings::PerformanceState performance_;

    float input_buffer_[kRenderBlockSize];
    float render_l_[kRenderBlockSize];
    float render_r_[kRenderBlockSize];
    uint16_t reverb_buffer_[32768];

    // Easter egg: polyphonic string synth (shares reverb_buffer_ with Part)
    rings::StringSynthPart string_synth_part_;
    bool use_string_synth_;  // true when model >= kEasterEggModelOffset

    // Extended parameter state
    int chord_;              // 0-10, default 0
    float fm_;               // 0-1, default 0
    bool internal_exciter_;  // default true

    // Deferred model/polyphony changes — set from UI thread, applied on audio thread
    // to avoid racing with Part::Process/ConfigureResonators.
    std::atomic<int> pending_polyphony_{-1};  // -1 = no change pending
    std::atomic<int> pending_model_{-1};      // -1 = no change pending

    // Modulation amounts (0-1, added to base patch values)
    float structure_mod_;
    float brightness_mod_;
    float damping_mod_;
    float position_mod_;
};

} // namespace Grainulator

#endif // RINGSVOICE_H

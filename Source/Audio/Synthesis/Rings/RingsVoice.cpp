//
//  RingsVoice.cpp
//  Grainulator
//
//  Mutable Instruments Rings-inspired resonator voice wrapper.
//

#include "RingsVoice.h"

#include <algorithm>
#include <cstring>

namespace Grainulator {

RingsVoice::RingsVoice()
    : sample_rate_(48000.0f)
    , note_(48.0f)
    , level_(0.8f)
    , note_queue_head_(0)
    , note_queue_tail_(0)
    , note_queue_count_(0)
    , chord_(0)
    , fm_(0.0f)
    , internal_exciter_(true)
    , structure_mod_(0.0f)
    , brightness_mod_(0.0f)
    , damping_mod_(0.0f)
    , position_mod_(0.0f) {
    std::memset(input_buffer_, 0, sizeof(input_buffer_));
    std::memset(render_l_, 0, sizeof(render_l_));
    std::memset(render_r_, 0, sizeof(render_r_));
    std::memset(reverb_buffer_, 0, sizeof(reverb_buffer_));

    std::memset(&base_patch_, 0, sizeof(base_patch_));
    std::memset(&patch_, 0, sizeof(patch_));
    std::memset(&performance_, 0, sizeof(performance_));

    base_patch_.structure = 0.4f;
    base_patch_.brightness = 0.7f;
    base_patch_.damping = 0.8f;
    base_patch_.position = 0.3f;
    patch_ = base_patch_;
}

void RingsVoice::Init(float sample_rate) {
    sample_rate_ = sample_rate;
    std::memset(reverb_buffer_, 0, sizeof(reverb_buffer_));

    part_.Init(reverb_buffer_);
    part_.set_polyphony(2);
    part_.set_model(rings::RESONATOR_MODEL_MODAL);

    // Rings models are tuned for 48k processing with 24-sample control blocks.
    const float controlRate = 48000.0f / static_cast<float>(kRenderBlockSize);
    strummer_.Init(0.01f, controlRate);

    note_queue_head_ = 0;
    note_queue_tail_ = 0;
    note_queue_count_ = 0;
    patch_ = base_patch_;
}

void RingsVoice::Render(const float* in, float* out, float* aux, size_t size) {
    if (!out || !aux) {
        return;
    }

    size_t rendered = 0;
    while (rendered < size) {
        const size_t block = std::min(kRenderBlockSize, size - rendered);

        // Copy input buffer (external excitation or zeros)
        if (in) {
            std::memcpy(input_buffer_, in + rendered, block * sizeof(float));
        } else {
            std::memset(input_buffer_, 0, block * sizeof(float));
        }
        std::memset(render_l_, 0, sizeof(render_l_));
        std::memset(render_r_, 0, sizeof(render_r_));

        // Apply modulation to patch (base + mod, clamped)
        patch_.structure = std::clamp(base_patch_.structure + structure_mod_, 0.0f, 0.9995f);
        patch_.brightness = std::clamp(base_patch_.brightness + brightness_mod_, 0.0f, 0.9995f);
        patch_.damping = std::clamp(base_patch_.damping + damping_mod_, 0.0f, 0.9995f);
        patch_.position = std::clamp(base_patch_.position + position_mod_, 0.0f, 0.9995f);

        // Pop a queued note event if available — each gets its own strum
        bool strum = false;
        if (note_queue_count_ > 0) {
            NoteEvent ev = note_queue_[note_queue_head_];
            note_queue_head_ = (note_queue_head_ + 1) % kMaxNoteQueue;
            note_queue_count_--;
            note_ = ev.note;
            level_ = ev.level;
            strum = true;
        }

        performance_.note = note_;
        performance_.tonic = 0.0f;
        performance_.fm = fm_ * 48.0f - 24.0f;  // Map 0-1 to ±24 semitones
        performance_.chord = std::clamp(chord_, 0, rings::kNumChords - 1);
        performance_.strum = strum;
        performance_.internal_exciter = internal_exciter_;
        performance_.internal_strum = false;

        strummer_.Process(input_buffer_, block, &performance_);

        // Force strum through for explicit NoteOn events — the Strummer's
        // inhibit timer blocks rapid re-triggers (10ms debounce), which
        // swallows polyphonic notes from the sequencer/MIDI.
        if (strum) {
            performance_.strum = true;
        }

        part_.Process(performance_, patch_, input_buffer_, render_l_, render_r_, block);

        for (size_t i = 0; i < block; ++i) {
            out[rendered + i] = render_l_[i] * level_;
            aux[rendered + i] = render_r_[i] * level_;
        }

        rendered += block;
    }
}

void RingsVoice::NoteOn(int midiNote, int velocity) {
    float note = std::clamp(static_cast<float>(midiNote), 0.0f, 127.0f);
    float accent = std::clamp(static_cast<float>(velocity) / 127.0f, 0.0f, 1.0f);
    float level = std::max(0.2f, accent);

    if (note_queue_count_ < kMaxNoteQueue) {
        note_queue_[note_queue_tail_] = { note, level };
        note_queue_tail_ = (note_queue_tail_ + 1) % kMaxNoteQueue;
        note_queue_count_++;
    }

    // Keep note_/level_ updated for non-strum render blocks
    note_ = note;
    level_ = level;
}

void RingsVoice::NoteOff(int midiNote) {
    (void)midiNote;
}

void RingsVoice::SetNote(float midiNote) {
    note_ = std::clamp(midiNote, 0.0f, 127.0f);
}

void RingsVoice::SetStructure(float value) {
    base_patch_.structure = std::clamp(value, 0.0f, 0.9995f);
    patch_.structure = base_patch_.structure;
}

void RingsVoice::SetBrightness(float value) {
    base_patch_.brightness = std::clamp(value, 0.0f, 0.9995f);
    patch_.brightness = base_patch_.brightness;
}

void RingsVoice::SetDamping(float value) {
    base_patch_.damping = std::clamp(value, 0.0f, 0.9995f);
    patch_.damping = base_patch_.damping;
}

void RingsVoice::SetPosition(float value) {
    base_patch_.position = std::clamp(value, 0.0f, 0.9995f);
    patch_.position = base_patch_.position;
}

void RingsVoice::SetModel(int modelIndex) {
    const int clamped = std::clamp(modelIndex, 0, static_cast<int>(rings::RESONATOR_MODEL_LAST) - 1);
    part_.set_model(static_cast<rings::ResonatorModel>(clamped));
}

void RingsVoice::SetLevel(float value) {
    level_ = std::clamp(value, 0.0f, 1.0f);
}

void RingsVoice::SetStructureMod(float amount) {
    // Allow bipolar modulation (-1 to +1 range)
    structure_mod_ = std::max(-1.0f, std::min(1.0f, amount));
}

void RingsVoice::SetBrightnessMod(float amount) {
    // Allow bipolar modulation (-1 to +1 range)
    brightness_mod_ = std::max(-1.0f, std::min(1.0f, amount));
}

void RingsVoice::SetDampingMod(float amount) {
    // Allow bipolar modulation (-1 to +1 range)
    damping_mod_ = std::max(-1.0f, std::min(1.0f, amount));
}

void RingsVoice::SetPositionMod(float amount) {
    // Allow bipolar modulation (-1 to +1 range)
    position_mod_ = std::max(-1.0f, std::min(1.0f, amount));
}

void RingsVoice::SetPolyphony(int polyphony) {
    // Part supports 1, 2, or 4
    if (polyphony == 2) {
        part_.set_polyphony(2);
    } else if (polyphony >= 4) {
        part_.set_polyphony(4);
    } else {
        part_.set_polyphony(1);
    }
}

void RingsVoice::SetChord(int chord) {
    chord_ = std::max(0, std::min(chord, rings::kNumChords - 1));
}

void RingsVoice::SetFM(float fm) {
    fm_ = std::max(0.0f, std::min(1.0f, fm));
}

void RingsVoice::SetInternalExciter(bool internal) {
    internal_exciter_ = internal;
}

} // namespace Grainulator

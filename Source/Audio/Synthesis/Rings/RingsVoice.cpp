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
    , trigger_pending_(false) {
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
    part_.set_polyphony(1);
    part_.set_model(rings::RESONATOR_MODEL_MODAL);

    // Rings models are tuned for 48k processing with 24-sample control blocks.
    const float controlRate = 48000.0f / static_cast<float>(kRenderBlockSize);
    strummer_.Init(0.01f, controlRate);

    trigger_pending_ = false;
    patch_ = base_patch_;
}

void RingsVoice::Render(float* out, float* aux, size_t size) {
    if (!out || !aux) {
        return;
    }

    size_t rendered = 0;
    while (rendered < size) {
        const size_t block = std::min(kRenderBlockSize, size - rendered);

        std::memset(input_buffer_, 0, sizeof(input_buffer_));
        std::memset(render_l_, 0, sizeof(render_l_));
        std::memset(render_r_, 0, sizeof(render_r_));

        performance_.note = note_;
        performance_.tonic = 0.0f;
        performance_.fm = 0.0f;
        performance_.chord = std::clamp(
            static_cast<int>(patch_.structure * static_cast<float>(rings::kNumChords - 1)),
            0,
            rings::kNumChords - 1
        );
        performance_.strum = trigger_pending_;
        performance_.internal_exciter = true;
        performance_.internal_strum = false;

        strummer_.Process(input_buffer_, block, &performance_);
        part_.Process(performance_, patch_, input_buffer_, render_l_, render_r_, block);

        trigger_pending_ = false;

        for (size_t i = 0; i < block; ++i) {
            out[rendered + i] = render_l_[i] * level_;
            aux[rendered + i] = render_r_[i] * level_;
        }

        rendered += block;
    }
}

void RingsVoice::NoteOn(int midiNote, int velocity) {
    SetNote(static_cast<float>(midiNote));
    const float accent = std::clamp(static_cast<float>(velocity) / 127.0f, 0.0f, 1.0f);
    SetLevel(std::max(0.2f, accent));
    trigger_pending_ = true;
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

} // namespace Grainulator

//
//  PlaitsVoice.cpp
//  Grainulator
//
//  Wrapper around the original Mutable Instruments Plaits voice path.
//

#include "PlaitsVoice.h"

#include "plaits_upstream/dsp/dsp.h"
#include "plaits_upstream/dsp/voice.h"
#include "plaits_upstream/user_data.h"
#include "stmlib/utils/buffer_allocator.h"

#include <algorithm>
#include <cmath>

namespace Grainulator {

namespace {
constexpr int kMinEngine = 0;
constexpr int kMaxEngine = 23;
constexpr int kTriggerPulseBlocks = 2;
constexpr int kRetriggerLowBlocks = 1;
constexpr int kSixOpEngineMin = 2;
constexpr int kSixOpEngineMax = 4;
constexpr int kSixOpPatchCount = 32;
static_assert(plaits::kBlockSize == 12, "Plaits block size changed; update kInternalBlockSize.");
}

PlaitsVoice::PlaitsVoice()
    : sample_rate_(48000.0f)
    , note_(60.0f)
    , harmonics_(0.5f)
    , timbre_(0.5f)
    , morph_(0.5f)
    , level_(0.8f)
    , harmonics_mod_amount_(0.0f)
    , timbre_mod_amount_(0.0f)
    , morph_mod_amount_(0.0f)
    , lpg_color_(0.0f)
    , lpg_decay_(0.5f)
    , lpg_attack_(0.0f)
    , lpg_bypass_(false)
    , gate_state_(false)
    , trigger_pulse_blocks_(0)
    , retrigger_pending_(false)
    , release_pending_(false)
    , force_low_blocks_(0)
    , current_engine_(8)
    , six_op_custom_enabled_(false)
    , six_op_custom_bank_loaded_(false)
    , six_op_custom_patch_index_(0)
    , six_op_custom_bank_{}
    , six_op_custom_slots_active_(false)
    , block_out_{}
    , block_aux_{}
    , block_read_index_(kInternalBlockSize)
{
    allocator_ = std::make_unique<stmlib::BufferAllocator>();
    voice_ = std::make_unique<plaits::Voice>();
    allocator_->Init(voice_allocator_buffer_.data(), voice_allocator_buffer_.size());
    voice_->Init(allocator_.get());
}

PlaitsVoice::~PlaitsVoice() = default;

void PlaitsVoice::Init(float sample_rate) {
    sample_rate_ = std::max(1.0f, sample_rate);

    allocator_->Init(voice_allocator_buffer_.data(), voice_allocator_buffer_.size());
    voice_->Init(allocator_.get());

    note_ = 60.0f;
    harmonics_ = 0.5f;
    timbre_ = 0.5f;
    morph_ = 0.5f;
    level_ = 0.8f;
    harmonics_mod_amount_ = 0.0f;
    timbre_mod_amount_ = 0.0f;
    morph_mod_amount_ = 0.0f;
    lpg_color_ = 0.0f;
    lpg_decay_ = 0.5f;
    lpg_attack_ = 0.0f;
    lpg_bypass_ = false;
    gate_state_ = false;
    trigger_pulse_blocks_ = 0;
    retrigger_pending_ = false;
    release_pending_ = false;
    force_low_blocks_ = 0;
    current_engine_ = 8;
    six_op_custom_enabled_ = false;
    six_op_custom_bank_loaded_ = false;
    six_op_custom_patch_index_ = 0;
    six_op_custom_bank_.fill(0);
    six_op_custom_slots_active_ = false;
    plaits::ClearDesktopUserDataSlot(2);
    plaits::ClearDesktopUserDataSlot(3);
    plaits::ClearDesktopUserDataSlot(4);
    block_out_.fill(0.0f);
    block_aux_.fill(0.0f);
    block_read_index_ = kInternalBlockSize;
}

void PlaitsVoice::Render(float* out, float* aux, size_t size) {
    if (!out && !aux) {
        return;
    }

    for (size_t i = 0; i < size; ++i) {
        if (block_read_index_ >= kInternalBlockSize) {
            renderNextBlock();
            block_read_index_ = 0;
        }
        if (out) {
            out[i] = block_out_[block_read_index_];
        }
        if (aux) {
            aux[i] = block_aux_[block_read_index_];
        }
        ++block_read_index_;
    }
}

void PlaitsVoice::SetEngine(int engine) {
    current_engine_ = std::clamp(engine, kMinEngine, kMaxEngine);
    applySixOpUserDataState();
}

void PlaitsVoice::SetNote(float note) {
    note_ = std::clamp(note, 0.0f, 127.0f);
}

void PlaitsVoice::SetHarmonics(float value) {
    harmonics_ = std::clamp(value, 0.0f, 1.0f);
    if (current_engine_ >= kSixOpEngineMin && current_engine_ <= kSixOpEngineMax) {
        const int quantized_index = std::clamp(
            static_cast<int>(std::lround(harmonics_ * static_cast<float>(kSixOpPatchCount - 1))),
            0,
            kSixOpPatchCount - 1);
        six_op_custom_patch_index_ = quantized_index;
        harmonics_ = static_cast<float>(quantized_index) / static_cast<float>(kSixOpPatchCount - 1);
    }
}

void PlaitsVoice::SetTimbre(float value) {
    timbre_ = std::clamp(value, 0.0f, 1.0f);
}

void PlaitsVoice::SetMorph(float value) {
    morph_ = std::clamp(value, 0.0f, 1.0f);
}

void PlaitsVoice::Trigger(bool state) {
    if (!state) {
        gate_state_ = false;
        release_pending_ = true;
        return;
    }

    if (release_pending_ || gate_state_ || trigger_pulse_blocks_ > 0 || force_low_blocks_ > 0) {
        retrigger_pending_ = true;
    }
    trigger_pulse_blocks_ = std::max(trigger_pulse_blocks_, kTriggerPulseBlocks);
    gate_state_ = true;
    release_pending_ = false;
}

void PlaitsVoice::SetLevel(float value) {
    level_ = std::clamp(value, 0.0f, 1.0f);
}

void PlaitsVoice::SetHarmonicsModAmount(float amount) {
    harmonics_mod_amount_ = std::clamp(amount, -1.0f, 1.0f);
}

void PlaitsVoice::SetTimbreModAmount(float amount) {
    timbre_mod_amount_ = std::clamp(amount, -1.0f, 1.0f);
}

void PlaitsVoice::SetMorphModAmount(float amount) {
    morph_mod_amount_ = std::clamp(amount, -1.0f, 1.0f);
}

void PlaitsVoice::SetLPGColor(float color) {
    lpg_color_ = std::clamp(color, 0.0f, 1.0f);
}

void PlaitsVoice::SetLPGDecay(float decay) {
    lpg_decay_ = std::clamp(decay, 0.0f, 1.0f);
}

void PlaitsVoice::SetLPGAttack(float attack) {
    lpg_attack_ = std::clamp(attack, 0.0f, 1.0f);
    (void)lpg_attack_;
}

void PlaitsVoice::SetLPGBypass(bool bypass) {
    lpg_bypass_ = bypass;
}

void PlaitsVoice::SetSixOpCustomEnabled(bool enabled) {
    six_op_custom_enabled_ = enabled;
    applySixOpUserDataState();
}

void PlaitsVoice::SetSixOpCustomPatchIndex(int index) {
    six_op_custom_patch_index_ = std::clamp(index, 0, kSixOpPatchCount - 1);
    harmonics_ = static_cast<float>(six_op_custom_patch_index_) / static_cast<float>(kSixOpPatchCount - 1);
}

bool PlaitsVoice::LoadSixOpCustomBank(const uint8_t* data, size_t size) {
    if (data == nullptr || size < six_op_custom_bank_.size()) {
        return false;
    }
    std::copy_n(data, six_op_custom_bank_.size(), six_op_custom_bank_.begin());
    six_op_custom_bank_loaded_ = true;
    applySixOpUserDataState(true);
    return true;
}

void PlaitsVoice::ClearSixOpCustomBank() {
    six_op_custom_bank_.fill(0);
    six_op_custom_bank_loaded_ = false;
    applySixOpUserDataState();
}

void PlaitsVoice::LoadUserWavetable(const float* data, int numSamples, int frameSize) {
    (void)data;
    (void)numSamples;
    (void)frameSize;
}

void PlaitsVoice::applySixOpUserDataState(bool force_reload) {
    const bool should_enable_custom_slots =
        six_op_custom_enabled_ &&
        six_op_custom_bank_loaded_;

    if (should_enable_custom_slots && !six_op_custom_slots_active_) {
        plaits::SetDesktopUserDataSlot(2, six_op_custom_bank_.data(), six_op_custom_bank_.size());
        plaits::SetDesktopUserDataSlot(3, six_op_custom_bank_.data(), six_op_custom_bank_.size());
        plaits::SetDesktopUserDataSlot(4, six_op_custom_bank_.data(), six_op_custom_bank_.size());
        six_op_custom_slots_active_ = true;
        if (voice_) {
            voice_->ReloadUserData();
        }
    } else if (!should_enable_custom_slots && six_op_custom_slots_active_) {
        plaits::ClearDesktopUserDataSlot(2);
        plaits::ClearDesktopUserDataSlot(3);
        plaits::ClearDesktopUserDataSlot(4);
        six_op_custom_slots_active_ = false;
        if (voice_) {
            voice_->ReloadUserData();
        }
    } else if (force_reload && should_enable_custom_slots && six_op_custom_slots_active_) {
        plaits::SetDesktopUserDataSlot(2, six_op_custom_bank_.data(), six_op_custom_bank_.size());
        plaits::SetDesktopUserDataSlot(3, six_op_custom_bank_.data(), six_op_custom_bank_.size());
        plaits::SetDesktopUserDataSlot(4, six_op_custom_bank_.data(), six_op_custom_bank_.size());
        if (voice_) {
            voice_->ReloadUserData();
        }
    }
}

void PlaitsVoice::renderNextBlock() {
    const bool timbre_mod_patched = std::fabs(timbre_mod_amount_) > 1.0e-6f;
    const bool morph_mod_patched = std::fabs(morph_mod_amount_) > 1.0e-6f;

    // Upstream Plaits DSP is calibrated for 48kHz.
    const float rate_correction_semitones = 12.0f * std::log2(48000.0f / sample_rate_);

    plaits::Patch patch{};
    patch.note = note_ + rate_correction_semitones;
    patch.harmonics = harmonics_;
    patch.timbre = timbre_;
    patch.morph = morph_;
    patch.frequency_modulation_amount = 0.0f;
    patch.timbre_modulation_amount = timbre_mod_patched ? 1.0f : 0.0f;
    patch.morph_modulation_amount = morph_mod_patched ? 1.0f : 0.0f;
    patch.engine = current_engine_;
    patch.decay = lpg_decay_;
    patch.lpg_colour = lpg_color_;

    plaits::Modulations modulations{};
    modulations.engine = 0.0f;
    modulations.note = 0.0f;
    modulations.frequency = 0.0f;
    modulations.harmonics = harmonics_mod_amount_;
    modulations.timbre = timbre_mod_amount_;
    modulations.morph = morph_mod_amount_;
    if (retrigger_pending_ && force_low_blocks_ == 0 && (gate_state_ || trigger_pulse_blocks_ > 0)) {
        force_low_blocks_ = kRetriggerLowBlocks;
    }
    if (force_low_blocks_ > 0) {
        modulations.trigger = 0.0f;
    } else {
        modulations.trigger = (gate_state_ || trigger_pulse_blocks_ > 0) ? 1.0f : 0.0f;
    }
    modulations.level = level_;

    modulations.frequency_patched = false;
    modulations.timbre_patched = timbre_mod_patched;
    modulations.morph_patched = morph_mod_patched;
    modulations.trigger_patched = !lpg_bypass_;
    modulations.level_patched = false;

    plaits::Voice::Frame frames[plaits::kBlockSize] = {};
    voice_->Render(patch, modulations, frames, plaits::kBlockSize);

    for (size_t i = 0; i < kInternalBlockSize; ++i) {
        block_out_[i] = std::clamp(
            (static_cast<float>(frames[i].out) / 32768.0f) * level_,
            -1.0f,
            1.0f);
        block_aux_[i] = std::clamp(
            (static_cast<float>(frames[i].aux) / 32768.0f) * level_,
            -1.0f,
            1.0f);
    }

    if (force_low_blocks_ > 0) {
        --force_low_blocks_;
        if (force_low_blocks_ == 0 && retrigger_pending_) {
            retrigger_pending_ = false;
            trigger_pulse_blocks_ = std::max(trigger_pulse_blocks_, kTriggerPulseBlocks);
        }
    } else if (trigger_pulse_blocks_ > 0) {
        --trigger_pulse_blocks_;
    }
}

} // namespace Grainulator

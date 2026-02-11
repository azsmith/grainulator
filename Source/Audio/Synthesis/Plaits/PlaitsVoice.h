//
//  PlaitsVoice.h
//  Grainulator
//
//  Wrapper around the original Mutable Instruments Plaits DSP voice.
//

#ifndef PLAITSVOICE_H
#define PLAITSVOICE_H

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>

namespace stmlib {
class BufferAllocator;
}

namespace plaits {
class Voice;
}

namespace Grainulator {

class PlaitsVoice {
public:
    PlaitsVoice();
    ~PlaitsVoice();

    void Init(float sample_rate);
    void Render(float* out, float* aux, size_t size);

    // Plaits alternate firmware model range: 0-23.
    void SetEngine(int engine);
    int GetEngine() const { return current_engine_; }

    void SetNote(float note);
    void SetHarmonics(float value);
    void SetTimbre(float value);
    void SetMorph(float value);
    void Trigger(bool state);
    void SetLevel(float value);

    // External modulation offsets from the host modulation matrix.
    void SetHarmonicsModAmount(float amount);
    void SetTimbreModAmount(float amount);
    void SetMorphModAmount(float amount);

    void SetLPGColor(float color);
    void SetLPGDecay(float decay);
    void SetLPGAttack(float attack);
    void SetLPGBypass(bool bypass);
    bool GetLPGBypass() const { return lpg_bypass_; }

    void SetSixOpCustomEnabled(bool enabled);
    bool IsSixOpCustomEnabled() const { return six_op_custom_enabled_; }
    void SetSixOpCustomPatchIndex(int index);
    bool LoadSixOpCustomBank(const uint8_t* data, size_t size);
    void ClearSixOpCustomBank();

    // Upstream Plaits uses user-data flashes rather than raw float wavetables.
    // This is currently kept as a no-op to preserve API compatibility.
    void LoadUserWavetable(const float* data, int numSamples, int frameSize = 0);

private:
    static constexpr size_t kVoiceBufferSize = 65536;
    static constexpr size_t kInternalBlockSize = 12;

    float sample_rate_;
    float note_;
    float harmonics_;
    float timbre_;
    float morph_;
    float level_;
    float harmonics_mod_amount_;
    float timbre_mod_amount_;
    float morph_mod_amount_;
    float lpg_color_;
    float lpg_decay_;
    float lpg_attack_;
    bool lpg_bypass_;
    bool gate_state_;
    int trigger_pulse_blocks_;
    bool retrigger_pending_;
    bool release_pending_;
    int force_low_blocks_;
    int current_engine_;
    bool six_op_custom_enabled_;
    bool six_op_custom_bank_loaded_;
    int six_op_custom_patch_index_;
    std::array<uint8_t, 32 * 128> six_op_custom_bank_;
    bool six_op_custom_slots_active_;
    std::array<float, kInternalBlockSize> block_out_;
    std::array<float, kInternalBlockSize> block_aux_;
    size_t block_read_index_;

    std::array<char, kVoiceBufferSize> voice_allocator_buffer_;
    std::unique_ptr<stmlib::BufferAllocator> allocator_;
    std::unique_ptr<plaits::Voice> voice_;
    void applySixOpUserDataState(bool force_reload = false);
    void renderNextBlock();

    PlaitsVoice(const PlaitsVoice&) = delete;
    PlaitsVoice& operator=(const PlaitsVoice&) = delete;
};

} // namespace Grainulator

#endif // PLAITSVOICE_H

//
//  AudioEngine.cpp
//  Grainulator
//
//  Main C++ audio engine implementation with polyphony
//

#include "AudioEngine.h"
#include "Plaits/PlaitsVoice.h"
#include "Granular/GranularVoice.h"
#include "Granular/ReelBuffer.h"
#include "Rings/RingsVoice.h"
#include "Looper/LooperVoice.h"
#include "DaisyDrums/DaisyDrumVoice.h"
#include "SoundFont/SoundFontVoice.h"
#include "SoundFont/WavSamplerVoice.h"
// Moog ladder filter models for master filter
#include "Granular/MoogLadders/LadderFilterBase.h"
#include "Granular/MoogLadders/HuovilainenModel.h"
#include "Granular/MoogLadders/StilsonModel.h"
#include "Granular/MoogLadders/MicrotrackerModel.h"
#include "Granular/MoogLadders/KrajeskiModel.h"
#include "Granular/MoogLadders/MusicDSPModel.h"
#include "Granular/MoogLadders/OberheimVariationModel.h"
#include "Granular/MoogLadders/ImprovedModel.h"
#include "Granular/MoogLadders/RKSimulationModel.h"
#include "Granular/MoogLadders/HyperionModel.h"
#include <cstring>
#include <cmath>
#include <algorithm>
#include <chrono>
#include <thread>

#if defined(__APPLE__)
#include <pthread.h>
#endif

#if defined(__x86_64__) || defined(__i386__)
#include <xmmintrin.h>  // _MM_SET_FLUSH_ZERO_MODE
#include <pmmintrin.h>  // _MM_SET_DENORMALS_ZERO_MODE
#endif

// ARM64 flushes denormals to zero by default — no extra includes needed.

namespace Grainulator {

// Level meter smoothing: ~50ms decay at 48kHz with 512-sample buffers
// smoothed = current * kMeterDecay + target * (1 - kMeterDecay)
constexpr float kMeterDecay = 0.95f;
constexpr float kMeterAttack = 1.0f - kMeterDecay;

AudioEngine::AudioEngine()
    : m_sampleRate(kSampleRate)
    , m_bufferSize(512)
    , m_initialized(false)
    , m_currentSampleTime(0)
    , m_cpuLoad(0.0f)
    , m_activeGrains(0)
    , m_voiceCounter(0)
    , m_currentEngine(8)
    , m_currentRingsModel(0)
    , m_harmonics(0.5f)
    , m_timbre(0.5f)
    , m_morph(0.5f)
    , m_plaitsLevel(0.8f)
    , m_plaitsFrequency(0.0f)
    , m_plaitsSixOpCustomEnabled(false)
    , m_plaitsSixOpCustomPatchIndex(0)
    , m_lpgColor(0.0f)
    , m_lpgDecay(0.5f)
    , m_lpgAttack(0.0f)
    , m_lpgBypass(false)
    , m_ringsStructure(0.3f)
    , m_ringsBrightness(0.4f)
    , m_ringsDamping(0.39f)
    , m_ringsPosition(0.97f)
    , m_ringsLevel(0.8f)
    , m_ringsPolyphony(2)
    , m_ringsChord(0)
    , m_ringsFM(0.0f)
    , m_ringsExciterSource(-1)
    , m_currentDaisyDrumEngine(0)
    , m_daisyDrumHarmonics(0.5f)
    , m_daisyDrumTimbre(0.5f)
    , m_daisyDrumMorph(0.5f)
    , m_daisyDrumLevel(0.8f)
    , m_drumSeqLevel{0.8f, 0.8f, 0.8f, 0.8f}
    , m_drumSeqHarmonics{0.5f, 0.5f, 0.5f, 0.5f}
    , m_drumSeqTimbre{0.5f, 0.5f, 0.5f, 0.5f}
    , m_drumSeqMorph{0.5f, 0.5f, 0.5f, 0.5f}
    , m_samplerMode(SamplerMode::SoundFont)
    , m_samplerAttack(0.0f)
    , m_samplerDecay(0.0f)
    , m_samplerSustain(1.0f)
    , m_samplerRelease(0.1f)
    , m_samplerFilterCutoff(1.0f)
    , m_samplerFilterResonance(0.0f)
    , m_samplerTuning(0.5f)
    , m_samplerLevel(0.8f)
    , m_activeGranularVoice(0)
    // Mangl-style granular parameters
    , m_granularSpeed(1.0f)
    , m_granularPitch(0.0f)
    , m_granularSize(100.0f)
    , m_granularDensity(20.0f)
    , m_granularJitter(0.0f)
    , m_granularSpread(0.0f)
    , m_granularPan(0.0f)
    , m_granularFilterCutoff(20000.0f)
    , m_granularFilterQ(0.5f)
    , m_granularGain(0.8f)
    , m_granularSend(0.0f)
    , m_granularEnvelope(0)  // 0 = Hanning (default)
    // Effects parameters
    , m_delayTime(0.3f)
    , m_delayFeedback(0.4f)
    , m_delayMix(0.0f)
    , m_delayHeadMode(0.86f)   // default to 1+2+3 mode
    , m_delayWow(0.5f)
    , m_delayFlutter(0.5f)
    , m_delayTone(0.45f)
    , m_delaySync(false)
    , m_delayTempoBPM(120.0f)
    , m_delaySubdivision(0.375f) // quarter-note slot in 9-step table
    , m_reverbSize(0.5f)
    , m_reverbDamping(0.5f)
    , m_reverbMix(0.0f)
    , m_delayBufferL(nullptr)
    , m_delayBufferR(nullptr)
    , m_delayWritePos(0)
    , m_delayTimeSmoothed(0.095f)
    , m_tapeWowPhase(0.0f)
    , m_tapeFlutterPhase(0.0f)
    , m_tapeDrift(0.0f)
    , m_tapeFeedbackLP(0.0f)
    , m_tapeFeedbackHPIn(0.0f)
    , m_tapeFeedbackHPOut(0.0f)
    , m_tapeToneL(0.0f)
    , m_tapeToneR(0.0f)
    , m_tapeNoiseState(0x12345678u)
    , m_sendBufferAL(nullptr)
    , m_sendBufferAR(nullptr)
    , m_sendBufferBL(nullptr)
    , m_sendBufferBR(nullptr)
    , m_scheduledReadIndex(0)
    , m_scheduledWriteIndex(0)
{
    // Initialize processing buffers
    m_processingBuffer[0] = nullptr;
    m_processingBuffer[1] = nullptr;
    m_voiceBuffer[0] = nullptr;
    m_voiceBuffer[1] = nullptr;

    // Zero exciter buffers
    std::memset(m_ringsExciterBufferL, 0, sizeof(m_ringsExciterBufferL));
    std::memset(m_ringsExciterBufferR, 0, sizeof(m_ringsExciterBufferR));

    // Zero scope buffers
    std::memset(m_scopeBuffer, 0, sizeof(m_scopeBuffer));

    // Initialize effects buffers to nullptr
    for (size_t i = 0; i < kNumCombs; ++i) {
        m_combBuffersL[i] = nullptr;
        m_combBuffersR[i] = nullptr;
        m_combPos[i] = 0;
        m_combFilters[i] = 0.0f;
        m_combFiltersR[i] = 0.0f;
    }
    for (size_t i = 0; i < kNumAllpasses; ++i) {
        m_allpassBuffersL[i] = nullptr;
        m_allpassBuffersR[i] = nullptr;
        m_allpassPos[i] = 0;
    }

    // Initialize voice state
    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        m_voiceNote[i] = -1;  // -1 = free
        m_voiceTrackId[i] = 0;
        m_voiceAge[i] = 0;
    }

    // Initialize mixer state
    for (int i = 0; i < kNumMixerChannels; ++i) {
        m_channelGain[i] = 1.0f;  // Unity gain
        m_channelGainSmoothed[i] = 1.0f;
        m_channelPan[i] = 0.0f;   // Center
        m_channelPanSmoothed[i] = 0.0f;
        m_channelSendA[i] = 0.0f;
        m_channelSendASmoothed[i] = 0.0f;
        m_channelSendB[i] = 0.0f;
        m_channelSendBSmoothed[i] = 0.0f;
        m_channelDelaySamples[i] = 0;
        m_channelDelayWritePos[i] = 0;
        m_channelDelayBufferL[i].fill(0.0f);
        m_channelDelayBufferR[i].fill(0.0f);
        m_channelMute[i] = false;
        m_channelSolo[i] = false;
        m_channelLevels[i].store(0.0f);
    }
    m_masterGain = 1.0f;  // Default master at unity
    m_masterGainSmoothed = 1.0f;
    m_masterLevelL.store(0.0f);
    m_masterLevelR.store(0.0f);

    // Initialize master filter defaults
    m_masterFilterCutoff = 20000.0f;   // Wide open by default
    m_masterFilterResonance = 0.0f;    // No resonance by default
    m_masterFilterModel = 2;           // Stilson model by default

    // Initialize master clock
    m_clockBPM.store(120.0f);
    m_clockRunning.store(false);
    m_clockSwing = 0.0f;
    m_clockStartSample = 0;

    // Initialize clock outputs
    for (int i = 0; i < kNumClockOutputs; ++i) {
        m_clockOutputs[i].mode = 0;              // Clock mode
        m_clockOutputs[i].waveform = 0;          // Gate
        m_clockOutputs[i].divisionIndex = 9;    // x1
        m_clockOutputs[i].level = 1.0f;
        m_clockOutputs[i].offset = 0.0f;
        m_clockOutputs[i].phase = 0.0f;
        m_clockOutputs[i].width = 0.5f;
        m_clockOutputs[i].destination = 0;       // None
        m_clockOutputs[i].modulationAmount = 0.5f;
        m_clockOutputs[i].muted = false;
        m_clockOutputs[i].slowMode = false;
        m_clockOutputs[i].phaseAccumulator = 0.0;
        m_clockOutputs[i].currentValue = 0.0f;
        m_clockOutputs[i].sampleHoldValue = 0.0f;
        m_clockOutputs[i].smoothedRandomValue = 0.0f;
        m_clockOutputs[i].randomTarget = 0.0f;
        m_clockOutputs[i].randomState = 0x12345678u + static_cast<uint32_t>(i * 12345);
        m_clockOutputs[i].lastPhaseForSH = 0.0;
        m_clockOutputValues[i].store(0.0f);
    }

    // Initialize modulation values
    for (int i = 0; i < static_cast<int>(ModulationDestination::NumDestinations); ++i) {
        m_modulationValues[i] = 0.0f;
    }
}

AudioEngine::~AudioEngine() {
    shutdown();
}

bool AudioEngine::initialize(int sampleRate, int bufferSize) {
    if (m_initialized.load()) {
        return false;
    }

    // Flush denormalized floats to zero to prevent CPU spikes in recursive
    // filters (reverb, delay feedback, master filter). ARM64 does this by
    // default; x86 needs explicit MXCSR flags.
#if defined(__x86_64__) || defined(__i386__)
    _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_ON);
    _MM_SET_DENORMALS_ZERO_MODE(_MM_DENORMALS_ZERO_ON);
#endif

    m_sampleRate = sampleRate;
    m_bufferSize = bufferSize;
    m_currentSampleTime.store(0, std::memory_order_relaxed);
    m_cachedBlockSampleTime.store(-1, std::memory_order_relaxed);
    m_cachedBlockFrames.store(0, std::memory_order_relaxed);
    m_cachedRenderInProgress.store(false, std::memory_order_relaxed);
    m_renderingBlockSampleTime.store(-1, std::memory_order_relaxed);
    m_renderingBlockFrames.store(0, std::memory_order_relaxed);
    m_cachedLegacyBlockSampleTime.store(-1, std::memory_order_relaxed);
    m_cachedLegacyBlockFrames.store(0, std::memory_order_relaxed);
    m_cachedLegacyRenderInProgress.store(false, std::memory_order_relaxed);
    m_renderingLegacyBlockSampleTime.store(-1, std::memory_order_relaxed);
    m_renderingLegacyBlockFrames.store(0, std::memory_order_relaxed);
    m_externalSendRoutingEnabled = false;
    m_scheduledReadIndex.store(0, std::memory_order_relaxed);
    m_scheduledWriteIndex.store(0, std::memory_order_relaxed);

    // Allocate processing buffers
    m_processingBuffer[0] = new float[kMaxBufferSize];
    m_processingBuffer[1] = new float[kMaxBufferSize];
    m_voiceBuffer[0] = new float[kMaxBufferSize];
    m_voiceBuffer[1] = new float[kMaxBufferSize];

    // Clear buffers
    std::memset(m_processingBuffer[0], 0, kMaxBufferSize * sizeof(float));
    std::memset(m_processingBuffer[1], 0, kMaxBufferSize * sizeof(float));
    std::memset(m_voiceBuffer[0], 0, kMaxBufferSize * sizeof(float));
    std::memset(m_voiceBuffer[1], 0, kMaxBufferSize * sizeof(float));

    // Initialize all Plaits voices
    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        m_plaitsVoices[i] = std::make_unique<PlaitsVoice>();
        m_plaitsVoices[i]->Init(static_cast<float>(sampleRate));
        m_voiceNote[i] = -1;
        m_voiceTrackId[i] = 0;
        m_voiceAge[i] = 0;
    }
    m_ringsVoice = std::make_unique<RingsVoice>();
    m_ringsVoice->Init(static_cast<float>(sampleRate));

    // Initialize DaisyDrum voice (manual control from synth tab)
    m_daisyDrumVoice = std::make_unique<DaisyDrumVoice>();
    m_daisyDrumVoice->Init(static_cast<float>(sampleRate));

    // Initialize drum sequencer voices (4 dedicated lanes)
    {
        const int drumSeqEngines[kNumDrumSeqLanes] = {
            DaisyDrumVoice::AnalogKick,      // Lane 0
            DaisyDrumVoice::SyntheticKick,    // Lane 1
            DaisyDrumVoice::AnalogSnare,      // Lane 2
            DaisyDrumVoice::HiHat             // Lane 3
        };
        for (int i = 0; i < kNumDrumSeqLanes; ++i) {
            m_drumSeqVoices[i] = std::make_unique<DaisyDrumVoice>();
            m_drumSeqVoices[i]->Init(static_cast<float>(sampleRate));
            m_drumSeqVoices[i]->SetEngine(drumSeqEngines[i]);
            m_drumSeqVoices[i]->SetLevel(m_drumSeqLevel[i]);
            m_drumSeqVoices[i]->SetHarmonics(m_drumSeqHarmonics[i]);
            m_drumSeqVoices[i]->SetTimbre(m_drumSeqTimbre[i]);
            m_drumSeqVoices[i]->SetMorph(m_drumSeqMorph[i]);
        }
    }

    // Initialize SoundFont sampler voice
    m_soundFontVoice = std::make_unique<SoundFontVoice>();
    m_soundFontVoice->Init(static_cast<float>(sampleRate));

    // Initialize WAV sampler voice (mx.samples)
    m_wavSamplerVoice = std::make_unique<WavSamplerVoice>();
    m_wavSamplerVoice->Init(static_cast<float>(sampleRate));
    m_samplerMode = SamplerMode::SoundFont;

    // Initialize granular voices
    for (int i = 0; i < kNumGranularVoices; ++i) {
        m_granularVoices[i] = std::make_unique<GranularVoice>();
        m_granularVoices[i]->Init(static_cast<float>(sampleRate));
    }
    for (int i = 0; i < kNumLooperVoices; ++i) {
        m_looperVoices[i] = std::make_unique<LooperVoice>();
        m_looperVoices[i]->Init(static_cast<float>(sampleRate));
    }

    // Create the first reel buffer (others created on demand)
    m_reelBuffers[0] = std::make_unique<ReelBuffer>();

    // Assign first buffer to first granular voice
    if (m_granularVoices[0] && m_reelBuffers[0]) {
        m_granularVoices[0]->SetBuffer(m_reelBuffers[0].get());
    }

    // Initialize effects
    initEffects();

    // Initialize master filter
    initMasterFilter();

    m_initialized.store(true);
    return true;
}

void AudioEngine::shutdown() {
    if (!m_initialized.load()) {
        return;
    }

    stopMultiChannelProcessing();

    // Cleanup Plaits voices
    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        m_plaitsVoices[i].reset();
    }
    m_ringsVoice.reset();

    // Cleanup granular/looper voices and buffers
    for (int i = 0; i < kNumGranularVoices; ++i) {
        m_granularVoices[i].reset();
    }
    for (int i = 0; i < kNumLooperVoices; ++i) {
        m_looperVoices[i].reset();
    }
    for (int i = 0; i < 32; ++i) {
        m_reelBuffers[i].reset();
    }

    // Free processing buffers
    if (m_processingBuffer[0]) {
        delete[] m_processingBuffer[0];
        m_processingBuffer[0] = nullptr;
    }
    if (m_processingBuffer[1]) {
        delete[] m_processingBuffer[1];
        m_processingBuffer[1] = nullptr;
    }
    if (m_voiceBuffer[0]) {
        delete[] m_voiceBuffer[0];
        m_voiceBuffer[0] = nullptr;
    }
    if (m_voiceBuffer[1]) {
        delete[] m_voiceBuffer[1];
        m_voiceBuffer[1] = nullptr;
    }

    // Cleanup effects
    cleanupEffects();

    m_scheduledReadIndex.store(0, std::memory_order_relaxed);
    m_scheduledWriteIndex.store(0, std::memory_order_relaxed);
    m_cachedBlockSampleTime.store(-1, std::memory_order_relaxed);
    m_cachedBlockFrames.store(0, std::memory_order_relaxed);
    m_cachedRenderInProgress.store(false, std::memory_order_relaxed);
    m_renderingBlockSampleTime.store(-1, std::memory_order_relaxed);
    m_renderingBlockFrames.store(0, std::memory_order_relaxed);
    m_cachedLegacyBlockSampleTime.store(-1, std::memory_order_relaxed);
    m_cachedLegacyBlockFrames.store(0, std::memory_order_relaxed);
    m_cachedLegacyRenderInProgress.store(false, std::memory_order_relaxed);
    m_renderingLegacyBlockSampleTime.store(-1, std::memory_order_relaxed);
    m_renderingLegacyBlockFrames.store(0, std::memory_order_relaxed);
    m_externalSendRoutingEnabled = false;

    m_initialized.store(false);
}

int AudioEngine::allocateVoice(int note, uint8_t trackId) {
    // First, check if this note is already playing BY THE SAME TRACK - retrigger same voice
    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        if (m_voiceNote[i] == note && m_voiceTrackId[i] == trackId) {
            return i;
        }
    }

    // Find a free voice
    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        if (m_voiceNote[i] == -1) {
            return i;
        }
    }

    // No free voices - steal the oldest one
    int oldestVoice = 0;
    uint32_t oldestAge = m_voiceAge[0];
    for (int i = 1; i < kNumPlaitsVoices; ++i) {
        if (m_voiceAge[i] < oldestAge) {
            oldestAge = m_voiceAge[i];
            oldestVoice = i;
        }
    }
    return oldestVoice;
}

void AudioEngine::noteOn(int note, int velocity) {
    noteOnTarget(note, velocity, static_cast<uint8_t>(NoteTarget::TargetBoth), 0);
}

void AudioEngine::noteOff(int note) {
    noteOffTarget(note, static_cast<uint8_t>(NoteTarget::TargetBoth), 0);
}

void AudioEngine::noteOnTarget(int note, int velocity, uint8_t targetMask) {
    noteOnTarget(note, velocity, targetMask, 0);
}

void AudioEngine::noteOnTarget(int note, int velocity, uint8_t targetMask, uint8_t trackId) {
    if (!m_initialized.load()) return;

    if ((targetMask & static_cast<uint8_t>(NoteTarget::TargetPlaits)) != 0) {
        int voiceIndex = allocateVoice(note, trackId);
        if (voiceIndex >= 0 && voiceIndex < kNumPlaitsVoices) {
            auto& voice = m_plaitsVoices[voiceIndex];
            if (voice) {
                // Set up the voice
                voice->SetNote(static_cast<float>(note));
                voice->SetLevel(static_cast<float>(velocity) / 127.0f);

                // Apply shared parameters
                voice->SetEngine(m_currentEngine);
                voice->SetHarmonics(m_harmonics);
                voice->SetTimbre(m_timbre);
                voice->SetMorph(m_morph);
                voice->SetLPGColor(m_lpgColor);
                voice->SetLPGDecay(m_lpgDecay);
                voice->SetLPGAttack(m_lpgAttack);
                voice->SetLPGBypass(m_lpgBypass);

                // Trigger the voice
                voice->Trigger(true);

                // Update voice state
                m_voiceNote[voiceIndex] = note;
                m_voiceTrackId[voiceIndex] = trackId;
                m_voiceAge[voiceIndex] = ++m_voiceCounter;
            }
        }
    }

    if ((targetMask & static_cast<uint8_t>(NoteTarget::TargetRings)) != 0 && m_ringsVoice) {
        m_ringsVoice->NoteOn(note, velocity);
    }

    if ((targetMask & static_cast<uint8_t>(NoteTarget::TargetDaisyDrum)) != 0 && m_daisyDrumVoice) {
        m_daisyDrumVoice->SetNote(static_cast<float>(note));
        m_daisyDrumVoice->SetLevel(static_cast<float>(velocity) / 127.0f);
        m_daisyDrumVoice->SetEngine(m_currentDaisyDrumEngine);
        m_daisyDrumVoice->SetHarmonics(m_daisyDrumHarmonics);
        m_daisyDrumVoice->SetTimbre(m_daisyDrumTimbre);
        m_daisyDrumVoice->SetMorph(m_daisyDrumMorph);
        m_daisyDrumVoice->Trigger(true);
    }

    // Drum sequencer lanes (bits 3-6)
    for (int lane = 0; lane < kNumDrumSeqLanes; ++lane) {
        uint8_t laneBit = 1 << (3 + lane);
        if ((targetMask & laneBit) != 0 && m_drumSeqVoices[lane]) {
            m_drumSeqVoices[lane]->SetNote(static_cast<float>(note));
            m_drumSeqVoices[lane]->SetLevel(static_cast<float>(velocity) / 127.0f);
            m_drumSeqVoices[lane]->SetHarmonics(m_drumSeqHarmonics[lane]);
            m_drumSeqVoices[lane]->SetTimbre(m_drumSeqTimbre[lane]);
            m_drumSeqVoices[lane]->SetMorph(m_drumSeqMorph[lane]);
            m_drumSeqVoices[lane]->Trigger(true);
        }
    }

    // Sampler (bit 7) — routes to active sampler mode
    if ((targetMask & static_cast<uint8_t>(NoteTarget::TargetSampler)) != 0) {
        float vel = static_cast<float>(velocity) / 127.0f;
        if ((m_samplerMode == SamplerMode::WavSampler || m_samplerMode == SamplerMode::Sfz) && m_wavSamplerVoice) {
            m_wavSamplerVoice->NoteOn(note, vel);
        } else if (m_soundFontVoice) {
            m_soundFontVoice->NoteOn(note, vel);
        }
    }
}

void AudioEngine::noteOffTarget(int note, uint8_t targetMask) {
    noteOffTarget(note, targetMask, 0);
}

void AudioEngine::noteOffTarget(int note, uint8_t targetMask, uint8_t trackId) {
    if (!m_initialized.load()) return;

    if ((targetMask & static_cast<uint8_t>(NoteTarget::TargetRings)) != 0 && m_ringsVoice) {
        m_ringsVoice->NoteOff(note);
    }

    if ((targetMask & static_cast<uint8_t>(NoteTarget::TargetDaisyDrum)) != 0 && m_daisyDrumVoice) {
        m_daisyDrumVoice->Trigger(false);
    }

    // Drum sequencer lanes (bits 3-6)
    for (int lane = 0; lane < kNumDrumSeqLanes; ++lane) {
        uint8_t laneBit = 1 << (3 + lane);
        if ((targetMask & laneBit) != 0 && m_drumSeqVoices[lane]) {
            m_drumSeqVoices[lane]->Trigger(false);
        }
    }

    // Sampler (bit 7) — routes to active sampler mode
    if ((targetMask & static_cast<uint8_t>(NoteTarget::TargetSampler)) != 0) {
        if ((m_samplerMode == SamplerMode::WavSampler || m_samplerMode == SamplerMode::Sfz) && m_wavSamplerVoice) {
            m_wavSamplerVoice->NoteOff(note);
        } else if (m_soundFontVoice) {
            m_soundFontVoice->NoteOff(note);
        }
    }

    if ((targetMask & static_cast<uint8_t>(NoteTarget::TargetPlaits)) == 0) {
        return;
    }

    // Find the voice playing this note FROM THE SAME TRACK and release it
    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        if (m_voiceNote[i] == note && m_voiceTrackId[i] == trackId) {
            if (m_plaitsVoices[i]) {
                m_plaitsVoices[i]->Trigger(false);
            }
            m_voiceNote[i] = -1;
            break;
        }
    }
}

bool AudioEngine::enqueueScheduledEvent(const ScheduledNoteEvent& event) {
    while (m_scheduledWriteLock.test_and_set(std::memory_order_acquire)) {
        // UI/control thread only; tiny spin is acceptable and keeps audio thread lock-free.
    }

    const uint32_t write = m_scheduledWriteIndex.load(std::memory_order_relaxed);
    const uint32_t nextWrite = (write + 1) % kScheduledEventCapacity;
    const uint32_t read = m_scheduledReadIndex.load(std::memory_order_acquire);

    if (nextWrite == read) {
        // Queue full: drop newest event to avoid blocking the audio thread.
        m_scheduledWriteLock.clear(std::memory_order_release);
        return false;
    }

    m_scheduledEvents[write] = event;
    m_scheduledWriteIndex.store(nextWrite, std::memory_order_release);
    m_scheduledWriteLock.clear(std::memory_order_release);
    return true;
}

void AudioEngine::scheduleNoteOn(int note, int velocity, uint64_t sampleTime) {
    scheduleNoteOnTarget(note, velocity, sampleTime, static_cast<uint8_t>(NoteTarget::TargetBoth));
}

void AudioEngine::scheduleNoteOff(int note, uint64_t sampleTime) {
    scheduleNoteOffTarget(note, sampleTime, static_cast<uint8_t>(NoteTarget::TargetBoth));
}

void AudioEngine::scheduleNoteOnTarget(int note, int velocity, uint64_t sampleTime, uint8_t targetMask) {
    scheduleNoteOnTargetTagged(note, velocity, sampleTime, targetMask, 0);
}

void AudioEngine::scheduleNoteOffTarget(int note, uint64_t sampleTime, uint8_t targetMask) {
    scheduleNoteOffTargetTagged(note, sampleTime, targetMask, 0);
}

void AudioEngine::scheduleNoteOnTargetTagged(int note, int velocity, uint64_t sampleTime, uint8_t targetMask, uint8_t trackId) {
    if (!m_initialized.load()) return;

    const int clampedNote = std::max(0, std::min(note, 127));
    const int clampedVelocity = std::max(1, std::min(velocity, 127));

    ScheduledNoteEvent event;
    event.sampleTime = sampleTime;
    event.note = static_cast<uint8_t>(clampedNote);
    event.velocity = static_cast<uint8_t>(clampedVelocity);
    event.isNoteOn = true;
    event.targetMask = targetMask == 0 ? static_cast<uint8_t>(NoteTarget::TargetBoth) : targetMask;
    event.trackId = trackId;
    enqueueScheduledEvent(event);
}

void AudioEngine::scheduleNoteOffTargetTagged(int note, uint64_t sampleTime, uint8_t targetMask, uint8_t trackId) {
    if (!m_initialized.load()) return;

    const int clampedNote = std::max(0, std::min(note, 127));

    ScheduledNoteEvent event;
    event.sampleTime = sampleTime;
    event.note = static_cast<uint8_t>(clampedNote);
    event.velocity = 0;
    event.isNoteOn = false;
    event.targetMask = targetMask == 0 ? static_cast<uint8_t>(NoteTarget::TargetBoth) : targetMask;
    event.trackId = trackId;
    enqueueScheduledEvent(event);
}

void AudioEngine::clearScheduledNotes() {
    while (m_scheduledWriteLock.test_and_set(std::memory_order_acquire)) {
    }
    // Consume everything currently queued.
    const uint32_t write = m_scheduledWriteIndex.load(std::memory_order_relaxed);
    m_scheduledReadIndex.store(write, std::memory_order_release);
    m_scheduledWriteLock.clear(std::memory_order_release);
}

uint64_t AudioEngine::getCurrentSampleTime() const {
    return m_currentSampleTime.load(std::memory_order_relaxed);
}

void AudioEngine::process(float** inputBuffers, float** outputBuffers, int numChannels, int numFrames) {
    if (!m_initialized.load()) {
        // Not initialized - output silence
        for (int ch = 0; ch < numChannels; ++ch) {
            std::memset(outputBuffers[ch], 0, numFrames * sizeof(float));
        }
        return;
    }

    if (numFrames > kMaxBufferSize) {
        // Hosts can request larger render quanta. Process in fixed-size chunks so
        // timing/sample counters continue to advance instead of returning silence.
        const int clampedChannels = std::min(numChannels, kMaxOutputChannels);
        int frameOffset = 0;
        while (frameOffset < numFrames) {
            const int chunkFrames = std::min(kMaxBufferSize, numFrames - frameOffset);
            for (int ch = 0; ch < clampedChannels; ++ch) {
                m_chunkOutputPtrs[ch] = outputBuffers[ch] + frameOffset;
            }
            process(inputBuffers, m_chunkOutputPtrs, clampedChannels, chunkFrames);
            frameOffset += chunkFrames;
        }
        return;
    }

    // Process master clock and update modulation values
    processClockOutputs(numFrames);
    applyModulation();

    const uint64_t bufferStartSample = m_currentSampleTime.load(std::memory_order_relaxed);
    const uint64_t bufferEndSample = bufferStartSample + static_cast<uint64_t>(numFrames);

    // Pop all queued note events that fall within this buffer.
    // Events can arrive out-of-order (e.g., different tracks scheduling future note-offs),
    // so collect due events and keep future events for later.
    std::array<ScheduledNoteEvent, kScheduledEventCapacity> dueEvents{};
    int dueEventCount = 0;

    uint32_t read = m_scheduledReadIndex.load(std::memory_order_relaxed);
    const uint32_t write = m_scheduledWriteIndex.load(std::memory_order_acquire);
    std::array<ScheduledNoteEvent, kScheduledEventCapacity> futureEvents{};
    int futureEventCount = 0;

    while (read != write && (dueEventCount + futureEventCount) < static_cast<int>(kScheduledEventCapacity)) {
        const ScheduledNoteEvent event = m_scheduledEvents[read];

        if (event.sampleTime < bufferEndSample) {
            dueEvents[dueEventCount] = event;
            if (dueEvents[dueEventCount].sampleTime < bufferStartSample) {
                dueEvents[dueEventCount].sampleTime = bufferStartSample;
            }
            ++dueEventCount;
        } else {
            futureEvents[futureEventCount] = event;
            ++futureEventCount;
        }

        read = (read + 1) % kScheduledEventCapacity;
    }

    m_scheduledReadIndex.store(read, std::memory_order_release);

    for (int i = 0; i < futureEventCount; ++i) {
        enqueueScheduledEvent(futureEvents[i]);
    }

    auto eventComesAfter = [](const ScheduledNoteEvent& lhs, const ScheduledNoteEvent& rhs) -> bool {
        if (lhs.sampleTime != rhs.sampleTime) {
            return lhs.sampleTime > rhs.sampleTime;
        }
        // For same-sample events, process note-off before note-on so 100% gate
        // lengths still produce a deterministic retrigger edge.
        if (lhs.isNoteOn != rhs.isNoteOn) {
            return lhs.isNoteOn && !rhs.isNoteOn;
        }
        return false;
    };

    // Insertion sort — no allocations, O(n^2) is fine for small event counts
    for (int i = 1; i < dueEventCount; ++i) {
        ScheduledNoteEvent key = dueEvents[i];
        int j = i - 1;
        while (j >= 0 && eventComesAfter(dueEvents[j], key)) {
            dueEvents[j + 1] = dueEvents[j];
            --j;
        }
        dueEvents[j + 1] = key;
    }

    // Check if any channel is soloed
    bool anySoloed = false;
    for (int i = 0; i < kNumMixerChannels; ++i) {
        if (m_channelSolo[i]) {
            anySoloed = true;
            break;
        }
    }

    float channelPeaks[kNumMixerChannels] = {0.0f};
    float masterPeakL = 0.0f;
    float masterPeakR = 0.0f;
    int totalActiveGrains = 0;
    std::memset(m_lastSendBusAL, 0, numFrames * sizeof(float));
    std::memset(m_lastSendBusAR, 0, numFrames * sizeof(float));
    std::memset(m_lastSendBusBL, 0, numFrames * sizeof(float));
    std::memset(m_lastSendBusBR, 0, numFrames * sizeof(float));

    auto renderChunk = [&](int frameOffset, int frameCount) {
        if (frameCount <= 0) return;

        auto applyChannelDelay = [&](int channel, float inputL, float inputR, float& delayedL, float& delayedR) {
            const int bufferLen = kMaxChannelDelaySamples + 1;
            int writePos = m_channelDelayWritePos[channel];
            int delaySamples = std::clamp(m_channelDelaySamples[channel], 0, kMaxChannelDelaySamples);
            int readPos = writePos - delaySamples;
            if (readPos < 0) {
                readPos += bufferLen;
            }

            m_channelDelayBufferL[channel][writePos] = inputL;
            m_channelDelayBufferR[channel][writePos] = inputR;
            delayedL = m_channelDelayBufferL[channel][readPos];
            delayedR = m_channelDelayBufferR[channel][readPos];

            writePos++;
            if (writePos >= bufferLen) {
                writePos = 0;
            }
            m_channelDelayWritePos[channel] = writePos;
        };

        // Clear main processing and send buffers for this chunk.
        std::memset(m_processingBuffer[0], 0, frameCount * sizeof(float));
        std::memset(m_processingBuffer[1], 0, frameCount * sizeof(float));
        std::memset(m_sendBufferAL, 0, frameCount * sizeof(float));
        std::memset(m_sendBufferAR, 0, frameCount * sizeof(float));
        std::memset(m_sendBufferBL, 0, frameCount * sizeof(float));
        std::memset(m_sendBufferBR, 0, frameCount * sizeof(float));

        // Smooth mixer parameters toward targets (~10ms time constant)
        // Prevents zipper noise from instantaneous gain/pan/send changes
        {
            const float kSmoothAlpha = 1.0f - std::exp(-static_cast<float>(frameCount) / (0.010f * static_cast<float>(m_sampleRate)));
            for (int ch = 0; ch < kNumMixerChannels; ++ch) {
                m_channelGainSmoothed[ch] += (m_channelGain[ch] - m_channelGainSmoothed[ch]) * kSmoothAlpha;
                m_channelPanSmoothed[ch] += (m_channelPan[ch] - m_channelPanSmoothed[ch]) * kSmoothAlpha;
                m_channelSendASmoothed[ch] += (m_channelSendA[ch] - m_channelSendASmoothed[ch]) * kSmoothAlpha;
                m_channelSendBSmoothed[ch] += (m_channelSendB[ch] - m_channelSendBSmoothed[ch]) * kSmoothAlpha;
            }
            m_masterGainSmoothed += (m_masterGain - m_masterGainSmoothed) * kSmoothAlpha;
        }

        // ========== Channel 0: Plaits ==========
        {
            int ch = 0;
            bool shouldPlay = !m_channelMute[ch] && (!anySoloed || m_channelSolo[ch]);

            std::memset(m_voiceBuffer[0], 0, frameCount * sizeof(float));
            std::memset(m_voiceBuffer[1], 0, frameCount * sizeof(float));

            for (int v = 0; v < kNumPlaitsVoices; ++v) {
                if (m_plaitsVoices[v]) {
                    std::memset(m_tempVoiceL, 0, frameCount * sizeof(float));
                    std::memset(m_tempVoiceR, 0, frameCount * sizeof(float));
                    m_plaitsVoices[v]->Render(m_tempVoiceL, m_tempVoiceR, frameCount);
                    for (int i = 0; i < frameCount; ++i) {
                        m_voiceBuffer[0][i] += m_tempVoiceL[i];
                        m_voiceBuffer[1][i] += m_tempVoiceR[i];
                    }
                }
            }

            // Normalize voice sum by configured polyphony.
            const float kPlaitsVoiceNorm = 1.0f / std::sqrt(static_cast<float>(std::max(1, kNumPlaitsVoices)));
            for (int i = 0; i < frameCount; ++i) {
                m_voiceBuffer[0][i] *= kPlaitsVoiceNorm;
                m_voiceBuffer[1][i] *= kPlaitsVoiceNorm;
            }

            // Record from Plaits (channel 0) pre-mixer
            processRecordingForChannel(0, m_voiceBuffer[0], m_voiceBuffer[1], frameCount);

            // Scope capture: Channel 0 (Plaits) — mono mix
            {
                size_t wi = m_scopeWriteIndex.load(std::memory_order_relaxed);
                for (int i = 0; i < frameCount; ++i) {
                    m_scopeBuffer[0][(wi + i) % kScopeBufferSize] = (m_voiceBuffer[0][i] + m_voiceBuffer[1][i]) * 0.5f;
                }
            }

            // Capture for Rings exciter if Plaits is the source (channel 0)
            if (m_ringsExciterSource == 0) {
                std::memcpy(m_ringsExciterBufferL, m_voiceBuffer[0], frameCount * sizeof(float));
                std::memcpy(m_ringsExciterBufferR, m_voiceBuffer[1], frameCount * sizeof(float));
            }

            float gain = m_channelGainSmoothed[ch];
            float pan = m_channelPanSmoothed[ch];
            float sendA = m_channelSendASmoothed[ch];
            float sendB = m_channelSendBSmoothed[ch];
            float panL = std::cos((pan + 1.0f) * 0.25f * 3.14159265f);
            float panR = std::sin((pan + 1.0f) * 0.25f * 3.14159265f);

            for (int i = 0; i < frameCount; ++i) {
                float mono = (m_voiceBuffer[0][i] + m_voiceBuffer[1][i]) * 0.5f * gain;
                float outL = mono * panL;
                float outR = mono * panR;
                float delayedL = 0.0f;
                float delayedR = 0.0f;
                applyChannelDelay(ch, outL, outR, delayedL, delayedR);

                channelPeaks[ch] = std::max(channelPeaks[ch], std::abs(mono));

                if (shouldPlay) {
                    m_processingBuffer[0][i] += delayedL;
                    m_processingBuffer[1][i] += delayedR;
                }

                const int outputIndex = frameOffset + i;
                const float sendAL = delayedL * sendA;
                const float sendAR = delayedR * sendA;
                const float sendBL = delayedL * sendB;
                const float sendBR = delayedR * sendB;
                m_sendBufferAL[i] += sendAL;
                m_sendBufferAR[i] += sendAR;
                m_sendBufferBL[i] += sendBL;
                m_sendBufferBR[i] += sendBR;
                m_lastSendBusAL[outputIndex] += sendAL;
                m_lastSendBusAR[outputIndex] += sendAR;
                m_lastSendBusBL[outputIndex] += sendBL;
                m_lastSendBusBR[outputIndex] += sendBR;
            }
        }

        // ========== Channel 1: Rings ==========
        {
            int ch = 1;
            bool shouldPlay = !m_channelMute[ch] && (!anySoloed || m_channelSolo[ch]);

            std::memset(m_voiceBuffer[0], 0, frameCount * sizeof(float));
            std::memset(m_voiceBuffer[1], 0, frameCount * sizeof(float));
            if (m_ringsVoice) {
                // Mix exciter buffer to mono for Rings input (Part expects mono in)
                float exciterMono[kMaxBufferSize];
                if (m_ringsExciterSource >= 0) {
                    for (int i = 0; i < frameCount; ++i) {
                        exciterMono[i] = (m_ringsExciterBufferL[i] + m_ringsExciterBufferR[i]) * 0.5f;
                    }
                } else {
                    std::memset(exciterMono, 0, frameCount * sizeof(float));
                }
                m_ringsVoice->Render(exciterMono, m_voiceBuffer[0], m_voiceBuffer[1], frameCount);
            }

            // Record from Rings (channel 1) pre-mixer
            processRecordingForChannel(1, m_voiceBuffer[0], m_voiceBuffer[1], frameCount);

            // Scope capture: Channel 1 (Rings) — mono mix
            {
                size_t wi = m_scopeWriteIndex.load(std::memory_order_relaxed);
                for (int i = 0; i < frameCount; ++i) {
                    m_scopeBuffer[1][(wi + i) % kScopeBufferSize] = (m_voiceBuffer[0][i] + m_voiceBuffer[1][i]) * 0.5f;
                }
            }

            float gain = m_channelGainSmoothed[ch];
            float pan = m_channelPanSmoothed[ch];
            float sendA = m_channelSendASmoothed[ch];
            float sendB = m_channelSendBSmoothed[ch];
            float panL = std::cos((pan + 1.0f) * 0.25f * 3.14159265f);
            float panR = std::sin((pan + 1.0f) * 0.25f * 3.14159265f);

            for (int i = 0; i < frameCount; ++i) {
                float sampleL = m_voiceBuffer[0][i] * gain;
                float sampleR = m_voiceBuffer[1][i] * gain;
                float outL = sampleL * panL;
                float outR = sampleR * panR;
                float delayedL = 0.0f;
                float delayedR = 0.0f;
                applyChannelDelay(ch, outL, outR, delayedL, delayedR);

                channelPeaks[ch] = std::max(channelPeaks[ch], std::max(std::abs(sampleL), std::abs(sampleR)));

                if (shouldPlay) {
                    m_processingBuffer[0][i] += delayedL;
                    m_processingBuffer[1][i] += delayedR;
                }

                const int outputIndex = frameOffset + i;
                const float sendAL = delayedL * sendA;
                const float sendAR = delayedR * sendA;
                const float sendBL = delayedL * sendB;
                const float sendBR = delayedR * sendB;
                m_sendBufferAL[i] += sendAL;
                m_sendBufferAR[i] += sendAR;
                m_sendBufferBL[i] += sendBL;
                m_sendBufferBR[i] += sendBR;
                m_lastSendBusAL[outputIndex] += sendAL;
                m_lastSendBusAR[outputIndex] += sendAR;
                m_lastSendBusBL[outputIndex] += sendBL;
                m_lastSendBusBR[outputIndex] += sendBR;
            }
        }

        // ========== Channels 2-5: Track voices ==========
        totalActiveGrains = 0;
        for (int trackIndex = 0; trackIndex < kNumGranularVoices; ++trackIndex) {
            int ch = trackIndex + 2;
            bool shouldPlay = !m_channelMute[ch] && (!anySoloed || m_channelSolo[ch]);

            std::memset(m_voiceBuffer[0], 0, frameCount * sizeof(float));
            std::memset(m_voiceBuffer[1], 0, frameCount * sizeof(float));

            const bool isLooperTrack = (trackIndex == 1 || trackIndex == 2);
            if (isLooperTrack) {
                const int looperIndex = trackIndex - 1;
                if (looperIndex >= 0 && looperIndex < kNumLooperVoices && m_looperVoices[looperIndex]) {
                    m_looperVoices[looperIndex]->Render(m_voiceBuffer[0], m_voiceBuffer[1], frameCount);
                }
            } else if (m_granularVoices[trackIndex]) {
                m_granularVoices[trackIndex]->Render(m_voiceBuffer[0], m_voiceBuffer[1], frameCount);
                totalActiveGrains += static_cast<int>(m_granularVoices[trackIndex]->GetNumActiveGrains());
            }

            // Record from track voice (channel ch) pre-mixer
            processRecordingForChannel(ch, m_voiceBuffer[0], m_voiceBuffer[1], frameCount);

            // Scope capture: Channels 2-5 (track voices) — mono mix
            {
                size_t wi = m_scopeWriteIndex.load(std::memory_order_relaxed);
                for (int i = 0; i < frameCount; ++i) {
                    m_scopeBuffer[ch][(wi + i) % kScopeBufferSize] = (m_voiceBuffer[0][i] + m_voiceBuffer[1][i]) * 0.5f;
                }
            }

            // Capture for Rings exciter (ch maps to exciter source: 2=Gran1, 3=Loop1, 4=Loop2, 5=Gran4)
            if (m_ringsExciterSource == ch) {
                std::memcpy(m_ringsExciterBufferL, m_voiceBuffer[0], frameCount * sizeof(float));
                std::memcpy(m_ringsExciterBufferR, m_voiceBuffer[1], frameCount * sizeof(float));
            }

            float gain = m_channelGainSmoothed[ch];
            float pan = m_channelPanSmoothed[ch];
            float sendA = m_channelSendASmoothed[ch];
            float sendB = m_channelSendBSmoothed[ch];
            float panL = std::cos((pan + 1.0f) * 0.25f * 3.14159265f);
            float panR = std::sin((pan + 1.0f) * 0.25f * 3.14159265f);

            for (int i = 0; i < frameCount; ++i) {
                float sampleL = m_voiceBuffer[0][i] * gain;
                float sampleR = m_voiceBuffer[1][i] * gain;
                float outL = sampleL * panL;
                float outR = sampleR * panR;
                float delayedL = 0.0f;
                float delayedR = 0.0f;
                applyChannelDelay(ch, outL, outR, delayedL, delayedR);

                channelPeaks[ch] = std::max(channelPeaks[ch], std::max(std::abs(sampleL), std::abs(sampleR)));

                if (shouldPlay) {
                    m_processingBuffer[0][i] += delayedL;
                    m_processingBuffer[1][i] += delayedR;
                }

                const int outputIndex = frameOffset + i;
                const float sendAL = delayedL * sendA;
                const float sendAR = delayedR * sendA;
                const float sendBL = delayedL * sendB;
                const float sendBR = delayedR * sendB;
                m_sendBufferAL[i] += sendAL;
                m_sendBufferAR[i] += sendAR;
                m_sendBufferBL[i] += sendBL;
                m_sendBufferBR[i] += sendBR;
                m_lastSendBusAL[outputIndex] += sendAL;
                m_lastSendBusAR[outputIndex] += sendAR;
                m_lastSendBusBL[outputIndex] += sendBL;
                m_lastSendBusBR[outputIndex] += sendBR;
            }
        }

        // ========== Channel 6: DaisyDrum ==========
        {
            int ch = 6;
            bool shouldPlay = !m_channelMute[ch] && (!anySoloed || m_channelSolo[ch]);

            std::memset(m_voiceBuffer[0], 0, frameCount * sizeof(float));
            std::memset(m_voiceBuffer[1], 0, frameCount * sizeof(float));
            if (m_daisyDrumVoice) {
                m_daisyDrumVoice->Render(m_voiceBuffer[0], nullptr, frameCount);
                // Mono → stereo (duplicate to both channels)
                std::memcpy(m_voiceBuffer[1], m_voiceBuffer[0], frameCount * sizeof(float));
            }

            // Render drum sequencer voices and sum into the same buffer
            // Scale lanes by 1/sqrt(4) = 0.5 to prevent clipping when all hit together
            {
                constexpr float kDrumLaneNorm = 0.5f;
                for (int lane = 0; lane < kNumDrumSeqLanes; ++lane) {
                    if (m_drumSeqVoices[lane]) {
                        std::memset(m_tempDrumSeq, 0, frameCount * sizeof(float));
                        m_drumSeqVoices[lane]->Render(m_tempDrumSeq, nullptr, frameCount);
                        // Record per-lane: channel 7=Kick, 8=SynthKick, 9=Snare, 10=HiHat
                        processRecordingForChannel(7 + lane, m_tempDrumSeq, m_tempDrumSeq, frameCount);
                        for (int i = 0; i < frameCount; ++i) {
                            m_voiceBuffer[0][i] += m_tempDrumSeq[i] * kDrumLaneNorm;
                            m_voiceBuffer[1][i] += m_tempDrumSeq[i] * kDrumLaneNorm;
                        }
                    }
                }
            }

            // Record from DaisyDrum + all drum lanes mixed (channel 6) pre-mixer
            processRecordingForChannel(6, m_voiceBuffer[0], m_voiceBuffer[1], frameCount);

            // Scope capture: Channel 6 (DaisyDrum) — mono mix
            {
                size_t wi = m_scopeWriteIndex.load(std::memory_order_relaxed);
                for (int i = 0; i < frameCount; ++i) {
                    m_scopeBuffer[6][(wi + i) % kScopeBufferSize] = (m_voiceBuffer[0][i] + m_voiceBuffer[1][i]) * 0.5f;
                }
            }

            // Capture for Rings exciter (channel 6 = Drums)
            if (m_ringsExciterSource == 6) {
                std::memcpy(m_ringsExciterBufferL, m_voiceBuffer[0], frameCount * sizeof(float));
                std::memcpy(m_ringsExciterBufferR, m_voiceBuffer[1], frameCount * sizeof(float));
            }

            float gain = m_channelGainSmoothed[ch];
            float pan = m_channelPanSmoothed[ch];
            float sendA = m_channelSendASmoothed[ch];
            float sendB = m_channelSendBSmoothed[ch];
            float panL = std::cos((pan + 1.0f) * 0.25f * 3.14159265f);
            float panR = std::sin((pan + 1.0f) * 0.25f * 3.14159265f);

            for (int i = 0; i < frameCount; ++i) {
                float sampleL = m_voiceBuffer[0][i] * gain;
                float sampleR = m_voiceBuffer[1][i] * gain;
                float outL = sampleL * panL;
                float outR = sampleR * panR;
                float delayedL = 0.0f;
                float delayedR = 0.0f;
                applyChannelDelay(ch, outL, outR, delayedL, delayedR);

                channelPeaks[ch] = std::max(channelPeaks[ch], std::max(std::abs(sampleL), std::abs(sampleR)));

                if (shouldPlay) {
                    m_processingBuffer[0][i] += delayedL;
                    m_processingBuffer[1][i] += delayedR;
                }

                const int outputIndex = frameOffset + i;
                const float sendAL = delayedL * sendA;
                const float sendAR = delayedR * sendA;
                const float sendBL = delayedL * sendB;
                const float sendBR = delayedR * sendB;
                m_sendBufferAL[i] += sendAL;
                m_sendBufferAR[i] += sendAR;
                m_sendBufferBL[i] += sendBL;
                m_sendBufferBR[i] += sendBR;
                m_lastSendBusAL[outputIndex] += sendAL;
                m_lastSendBusAR[outputIndex] += sendAR;
                m_lastSendBusBL[outputIndex] += sendBL;
                m_lastSendBusBR[outputIndex] += sendBR;
            }
        }

        // ========== Channel 7: Sampler (SoundFont or WAV) ==========
        {
            int ch = 7;
            bool shouldPlay = !m_channelMute[ch] && (!anySoloed || m_channelSolo[ch]);

            std::memset(m_voiceBuffer[0], 0, frameCount * sizeof(float));
            std::memset(m_voiceBuffer[1], 0, frameCount * sizeof(float));
            if (m_samplerMode == SamplerMode::WavSampler || m_samplerMode == SamplerMode::Sfz) {
                if (m_wavSamplerVoice) {
                    // Always call Render — it handles CheckSwap internally
                    m_wavSamplerVoice->Render(m_voiceBuffer[0], m_voiceBuffer[1], frameCount);
                }
            } else {
                if (m_soundFontVoice) {
                    // Always call Render — it handles CheckSwap internally
                    // and outputs silence if no SoundFont is active yet
                    m_soundFontVoice->Render(m_voiceBuffer[0], m_voiceBuffer[1], frameCount);
                }
            }

            // Record from Sampler (channel 11) pre-mixer
            processRecordingForChannel(11, m_voiceBuffer[0], m_voiceBuffer[1], frameCount);

            // Scope capture: Channel 7 (Sampler) — mono mix
            {
                size_t wi = m_scopeWriteIndex.load(std::memory_order_relaxed);
                for (int i = 0; i < frameCount; ++i) {
                    m_scopeBuffer[7][(wi + i) % kScopeBufferSize] = (m_voiceBuffer[0][i] + m_voiceBuffer[1][i]) * 0.5f;
                }
            }

            // Capture for Rings exciter (source 11 = Sampler)
            if (m_ringsExciterSource == 11) {
                std::memcpy(m_ringsExciterBufferL, m_voiceBuffer[0], frameCount * sizeof(float));
                std::memcpy(m_ringsExciterBufferR, m_voiceBuffer[1], frameCount * sizeof(float));
            }

            float gain = m_channelGainSmoothed[ch];
            float pan = m_channelPanSmoothed[ch];
            float sendA = m_channelSendASmoothed[ch];
            float sendB = m_channelSendBSmoothed[ch];
            float panL = std::cos((pan + 1.0f) * 0.25f * 3.14159265f);
            float panR = std::sin((pan + 1.0f) * 0.25f * 3.14159265f);

            for (int i = 0; i < frameCount; ++i) {
                float sampleL = m_voiceBuffer[0][i] * gain;
                float sampleR = m_voiceBuffer[1][i] * gain;
                float outL = sampleL * panL;
                float outR = sampleR * panR;
                float delayedL = 0.0f;
                float delayedR = 0.0f;
                applyChannelDelay(ch, outL, outR, delayedL, delayedR);

                channelPeaks[ch] = std::max(channelPeaks[ch], std::max(std::abs(sampleL), std::abs(sampleR)));

                if (shouldPlay) {
                    m_processingBuffer[0][i] += delayedL;
                    m_processingBuffer[1][i] += delayedR;
                }

                const int outputIndex = frameOffset + i;
                const float sendAL = delayedL * sendA;
                const float sendAR = delayedR * sendA;
                const float sendBL = delayedL * sendB;
                const float sendBR = delayedR * sendB;
                m_sendBufferAL[i] += sendAL;
                m_sendBufferAR[i] += sendAR;
                m_sendBufferBL[i] += sendBL;
                m_sendBufferBR[i] += sendBR;
                m_lastSendBusAL[outputIndex] += sendAL;
                m_lastSendBusAR[outputIndex] += sendAR;
                m_lastSendBusBL[outputIndex] += sendBL;
                m_lastSendBusBR[outputIndex] += sendBR;
            }
        }

        // ========== Process external input recording ==========
        processExternalInputRecording(frameCount);

        // ========== Process Internal Effects (disabled when external send routing is active) ==========
        if (!m_externalSendRoutingEnabled) {
            for (int i = 0; i < frameCount; ++i) {
                float wetL = m_sendBufferAL[i];
                float wetR = m_sendBufferAR[i];

                if (m_delayMix > 0.001f) {
                    processDelay(wetL, wetR);
                }

                if (m_reverbMix > 0.001f) {
                    processReverb(wetL, wetR);
                }

                m_processingBuffer[0][i] += wetL;
                m_processingBuffer[1][i] += wetR;
            }
        }

        // ========== Final Processing + output ==========
        for (int i = 0; i < frameCount; ++i) {
            // Apply master filter before gain
            float sampleL = m_processingBuffer[0][i];
            float sampleR = m_processingBuffer[1][i];
            processMasterFilter(sampleL, sampleR);

            // Apply smoothed master gain
            sampleL *= m_masterGainSmoothed;
            sampleR *= m_masterGainSmoothed;

            // Soft clip
            m_processingBuffer[0][i] = std::tanh(sampleL);
            m_processingBuffer[1][i] = std::tanh(sampleR);

            masterPeakL = std::max(masterPeakL, std::abs(m_processingBuffer[0][i]));
            masterPeakR = std::max(masterPeakR, std::abs(m_processingBuffer[1][i]));
        }

        // Master capture (recording to file via Swift)
        if (m_masterCaptureActive.load(std::memory_order_relaxed)) {
            m_masterCaptureRing.write(m_processingBuffer[0], m_processingBuffer[1], frameCount);
        }

        // Scope capture: Channel 8 (Master) — mono mix of final output
        {
            size_t wi = m_scopeWriteIndex.load(std::memory_order_relaxed);
            for (int i = 0; i < frameCount; ++i) {
                m_scopeBuffer[8][(wi + i) % kScopeBufferSize] = (m_processingBuffer[0][i] + m_processingBuffer[1][i]) * 0.5f;
            }
        }

        // Note: Clock scope capture is done per-sample in processClockOutputs()

        // Advance scope write index
        {
            size_t wi = m_scopeWriteIndex.load(std::memory_order_relaxed);
            m_scopeWriteIndex.store((wi + frameCount) % kScopeBufferSize, std::memory_order_release);
        }

        for (int ch = 0; ch < numChannels; ++ch) {
            std::memcpy(
                outputBuffers[ch] + frameOffset,
                m_processingBuffer[ch % 2],
                frameCount * sizeof(float)
            );
        }
    };

    int cursorFrame = 0;
    int eventIndex = 0;
    while (eventIndex < dueEventCount) {
        const uint64_t eventSample = dueEvents[eventIndex].sampleTime;
        const int eventFrame = static_cast<int>(std::min<uint64_t>(numFrames, eventSample - bufferStartSample));

        if (eventFrame > cursorFrame) {
            renderChunk(cursorFrame, eventFrame - cursorFrame);
            cursorFrame = eventFrame;
        }

        while (eventIndex < dueEventCount && dueEvents[eventIndex].sampleTime == eventSample) {
            const ScheduledNoteEvent& event = dueEvents[eventIndex];
            if (event.isNoteOn) {
                noteOnTarget(static_cast<int>(event.note), static_cast<int>(event.velocity), event.targetMask, event.trackId);
            } else {
                noteOffTarget(static_cast<int>(event.note), event.targetMask, event.trackId);
            }
            ++eventIndex;
        }
    }

    if (cursorFrame < numFrames) {
        renderChunk(cursorFrame, numFrames - cursorFrame);
    }

    // Update channel level meters (with smoothing)
    for (int i = 0; i < kNumMixerChannels; ++i) {
        float current = m_channelLevels[i].load();
        float target = channelPeaks[i];
        if (target > current) {
            m_channelLevels[i].store(target);
        } else {
            m_channelLevels[i].store(current * kMeterDecay + target * kMeterAttack);
        }
    }

    float currentL = m_masterLevelL.load();
    float currentR = m_masterLevelR.load();
    m_masterLevelL.store(masterPeakL > currentL ? masterPeakL : currentL * kMeterDecay + masterPeakL * kMeterAttack);
    m_masterLevelR.store(masterPeakR > currentR ? masterPeakR : currentR * kMeterDecay + masterPeakR * kMeterAttack);

    m_activeGrains.store(totalActiveGrains);
    m_currentSampleTime.store(bufferEndSample, std::memory_order_relaxed);

}

void AudioEngine::processMultiChannel(float** channelBuffers, int numFrames) {
    // Multi-channel output for AU plugin hosting
    // Outputs 6 separate stereo channels without mixing or effects
    // All mixing, effects, and routing are handled by Swift-side AVAudioEngine

    if (!m_initialized.load()) {
        // Not initialized - output silence
        for (int ch = 0; ch < kNumMixerChannels * 2; ++ch) {
            if (channelBuffers[ch]) {
                std::memset(channelBuffers[ch], 0, numFrames * sizeof(float));
            }
        }
        return;
    }

    if (numFrames > kMaxBufferSize) {
        // Same strategy as legacy process(): split large host quanta so render
        // continues and m_currentSampleTime advances.
        int frameOffset = 0;
        while (frameOffset < numFrames) {
            const int chunkFrames = std::min(kMaxBufferSize, numFrames - frameOffset);
            float* chunkBuffers[kNumMixerChannels * 2];
            for (int ch = 0; ch < kNumMixerChannels * 2; ++ch) {
                chunkBuffers[ch] = channelBuffers[ch] + frameOffset;
            }
            processMultiChannel(chunkBuffers, chunkFrames);
            frameOffset += chunkFrames;
        }
        return;
    }

    // Process master clock and update modulation values (still needed for voice modulation)
    processClockOutputs(numFrames);
    applyModulation();

    const uint64_t bufferStartSample = m_currentSampleTime.load(std::memory_order_relaxed);
    const uint64_t bufferEndSample = bufferStartSample + static_cast<uint64_t>(numFrames);

    // Process scheduled note events.
    // Events can be out-of-order, so collect due events and retain future ones.
    std::array<ScheduledNoteEvent, kScheduledEventCapacity> dueEvents{};
    int dueEventCount = 0;

    uint32_t read = m_scheduledReadIndex.load(std::memory_order_relaxed);
    const uint32_t write = m_scheduledWriteIndex.load(std::memory_order_acquire);
    std::array<ScheduledNoteEvent, kScheduledEventCapacity> futureEvents{};
    int futureEventCount = 0;

    while (read != write && (dueEventCount + futureEventCount) < static_cast<int>(kScheduledEventCapacity)) {
        const ScheduledNoteEvent event = m_scheduledEvents[read];

        if (event.sampleTime < bufferEndSample) {
            dueEvents[dueEventCount] = event;
            if (dueEvents[dueEventCount].sampleTime < bufferStartSample) {
                dueEvents[dueEventCount].sampleTime = bufferStartSample;
            }
            ++dueEventCount;
        } else {
            futureEvents[futureEventCount] = event;
            ++futureEventCount;
        }

        read = (read + 1) % kScheduledEventCapacity;
    }

    m_scheduledReadIndex.store(read, std::memory_order_release);

    for (int i = 0; i < futureEventCount; ++i) {
        enqueueScheduledEvent(futureEvents[i]);
    }

    auto eventComesAfter = [](const ScheduledNoteEvent& lhs, const ScheduledNoteEvent& rhs) -> bool {
        if (lhs.sampleTime != rhs.sampleTime) {
            return lhs.sampleTime > rhs.sampleTime;
        }
        if (lhs.isNoteOn != rhs.isNoteOn) {
            return lhs.isNoteOn && !rhs.isNoteOn;
        }
        return false;
    };

    // Insertion sort — no allocations, O(n^2) is fine for small event counts
    for (int i = 1; i < dueEventCount; ++i) {
        ScheduledNoteEvent key = dueEvents[i];
        int j = i - 1;
        while (j >= 0 && eventComesAfter(dueEvents[j], key)) {
            dueEvents[j + 1] = dueEvents[j];
            --j;
        }
        dueEvents[j + 1] = key;
    }

    float channelPeaks[kNumMixerChannels] = {0.0f};
    int totalActiveGrains = 0;

    // Lambda to render a chunk of audio for all channels
    auto renderChunk = [&](int frameOffset, int frameCount) {
        if (frameCount <= 0) return;

        // ========== Channel 0: Plaits (buffers 0, 1) ==========
        {
            std::memset(m_voiceBuffer[0], 0, frameCount * sizeof(float));
            std::memset(m_voiceBuffer[1], 0, frameCount * sizeof(float));

            for (int v = 0; v < kNumPlaitsVoices; ++v) {
                if (m_plaitsVoices[v]) {
                    std::memset(m_tempVoiceL, 0, frameCount * sizeof(float));
                    std::memset(m_tempVoiceR, 0, frameCount * sizeof(float));
                    m_plaitsVoices[v]->Render(m_tempVoiceL, m_tempVoiceR, frameCount);
                    for (int i = 0; i < frameCount; ++i) {
                        m_voiceBuffer[0][i] += m_tempVoiceL[i];
                        m_voiceBuffer[1][i] += m_tempVoiceR[i];
                    }
                }
            }

            // Normalize voice sum by configured polyphony.
            const float kPlaitsVoiceNorm = 1.0f / std::sqrt(static_cast<float>(std::max(1, kNumPlaitsVoices)));
            for (int i = 0; i < frameCount; ++i) {
                m_voiceBuffer[0][i] *= kPlaitsVoiceNorm;
                m_voiceBuffer[1][i] *= kPlaitsVoiceNorm;
            }

            // Record from Plaits (channel 0) pre-output
            processRecordingForChannel(0, m_voiceBuffer[0], m_voiceBuffer[1], frameCount);

            // Capture for Rings exciter if Plaits is the source (channel 0)
            if (m_ringsExciterSource == 0) {
                std::memcpy(m_ringsExciterBufferL, m_voiceBuffer[0], frameCount * sizeof(float));
                std::memcpy(m_ringsExciterBufferR, m_voiceBuffer[1], frameCount * sizeof(float));
            }

            // Copy to output buffers (no mixing/effects)
            if (channelBuffers[0]) {
                std::memcpy(channelBuffers[0] + frameOffset, m_voiceBuffer[0], frameCount * sizeof(float));
            }
            if (channelBuffers[1]) {
                std::memcpy(channelBuffers[1] + frameOffset, m_voiceBuffer[1], frameCount * sizeof(float));
            }

            // Update metering
            for (int i = 0; i < frameCount; ++i) {
                float mono = (m_voiceBuffer[0][i] + m_voiceBuffer[1][i]) * 0.5f;
                channelPeaks[0] = std::max(channelPeaks[0], std::abs(mono));
            }
        }

        // ========== Channel 1: Rings (buffers 2, 3) ==========
        {
            std::memset(m_voiceBuffer[0], 0, frameCount * sizeof(float));
            std::memset(m_voiceBuffer[1], 0, frameCount * sizeof(float));

            if (m_ringsVoice) {
                // Mix exciter buffer to mono for Rings input (Part expects mono in)
                float exciterMono[kMaxBufferSize];
                if (m_ringsExciterSource >= 0) {
                    for (int i = 0; i < frameCount; ++i) {
                        exciterMono[i] = (m_ringsExciterBufferL[i] + m_ringsExciterBufferR[i]) * 0.5f;
                    }
                } else {
                    std::memset(exciterMono, 0, frameCount * sizeof(float));
                }
                m_ringsVoice->Render(exciterMono, m_voiceBuffer[0], m_voiceBuffer[1], frameCount);
            }

            // Record from Rings (channel 1) pre-output
            processRecordingForChannel(1, m_voiceBuffer[0], m_voiceBuffer[1], frameCount);

            if (channelBuffers[2]) {
                std::memcpy(channelBuffers[2] + frameOffset, m_voiceBuffer[0], frameCount * sizeof(float));
            }
            if (channelBuffers[3]) {
                std::memcpy(channelBuffers[3] + frameOffset, m_voiceBuffer[1], frameCount * sizeof(float));
            }

            for (int i = 0; i < frameCount; ++i) {
                float peak = std::max(std::abs(m_voiceBuffer[0][i]), std::abs(m_voiceBuffer[1][i]));
                channelPeaks[1] = std::max(channelPeaks[1], peak);
            }
        }

        // ========== Channels 2-5: Granular/Looper voices (buffers 4-11) ==========
        for (int trackIndex = 0; trackIndex < kNumGranularVoices; ++trackIndex) {
            int bufferBaseIndex = (trackIndex + 2) * 2;  // 4, 6, 8, 10

            std::memset(m_voiceBuffer[0], 0, frameCount * sizeof(float));
            std::memset(m_voiceBuffer[1], 0, frameCount * sizeof(float));

            const bool isLooperTrack = (trackIndex == 1 || trackIndex == 2);
            if (isLooperTrack) {
                const int looperIndex = trackIndex - 1;
                if (looperIndex >= 0 && looperIndex < kNumLooperVoices && m_looperVoices[looperIndex]) {
                    m_looperVoices[looperIndex]->Render(m_voiceBuffer[0], m_voiceBuffer[1], frameCount);
                }
            } else if (m_granularVoices[trackIndex]) {
                m_granularVoices[trackIndex]->Render(m_voiceBuffer[0], m_voiceBuffer[1], frameCount);
                totalActiveGrains += static_cast<int>(m_granularVoices[trackIndex]->GetNumActiveGrains());
            }

            // Record from track voice (channel trackIndex+2) pre-output
            processRecordingForChannel(trackIndex + 2, m_voiceBuffer[0], m_voiceBuffer[1], frameCount);

            // Capture for Rings exciter (ch maps to exciter source: 2=Gran1, 3=Loop1, 4=Loop2, 5=Gran4)
            if (m_ringsExciterSource == trackIndex + 2) {
                std::memcpy(m_ringsExciterBufferL, m_voiceBuffer[0], frameCount * sizeof(float));
                std::memcpy(m_ringsExciterBufferR, m_voiceBuffer[1], frameCount * sizeof(float));
            }

            if (channelBuffers[bufferBaseIndex]) {
                std::memcpy(channelBuffers[bufferBaseIndex] + frameOffset, m_voiceBuffer[0], frameCount * sizeof(float));
            }
            if (channelBuffers[bufferBaseIndex + 1]) {
                std::memcpy(channelBuffers[bufferBaseIndex + 1] + frameOffset, m_voiceBuffer[1], frameCount * sizeof(float));
            }

            int channelIndex = trackIndex + 2;
            for (int i = 0; i < frameCount; ++i) {
                float peak = std::max(std::abs(m_voiceBuffer[0][i]), std::abs(m_voiceBuffer[1][i]));
                channelPeaks[channelIndex] = std::max(channelPeaks[channelIndex], peak);
            }
        }

        // ========== Channel 6: DaisyDrum (buffers 12, 13) ==========
        {
            std::memset(m_voiceBuffer[0], 0, frameCount * sizeof(float));
            std::memset(m_voiceBuffer[1], 0, frameCount * sizeof(float));

            if (m_daisyDrumVoice) {
                m_daisyDrumVoice->Render(m_voiceBuffer[0], nullptr, frameCount);
                // Mono → stereo
                std::memcpy(m_voiceBuffer[1], m_voiceBuffer[0], frameCount * sizeof(float));
            }

            // Render drum sequencer voices and sum into the same buffer
            // Scale lanes by 1/sqrt(4) = 0.5 to prevent clipping when all hit together
            {
                constexpr float kDrumLaneNorm = 0.5f;
                for (int lane = 0; lane < kNumDrumSeqLanes; ++lane) {
                    if (m_drumSeqVoices[lane]) {
                        std::memset(m_tempDrumSeq, 0, frameCount * sizeof(float));
                        m_drumSeqVoices[lane]->Render(m_tempDrumSeq, nullptr, frameCount);
                        // Record per-lane: channel 7=Kick, 8=SynthKick, 9=Snare, 10=HiHat
                        processRecordingForChannel(7 + lane, m_tempDrumSeq, m_tempDrumSeq, frameCount);
                        for (int i = 0; i < frameCount; ++i) {
                            m_voiceBuffer[0][i] += m_tempDrumSeq[i] * kDrumLaneNorm;
                            m_voiceBuffer[1][i] += m_tempDrumSeq[i] * kDrumLaneNorm;
                        }
                    }
                }
            }

            // Record from DaisyDrum + all drum lanes mixed (channel 6) pre-output
            processRecordingForChannel(6, m_voiceBuffer[0], m_voiceBuffer[1], frameCount);

            // Capture for Rings exciter (channel 6 = Drums)
            if (m_ringsExciterSource == 6) {
                std::memcpy(m_ringsExciterBufferL, m_voiceBuffer[0], frameCount * sizeof(float));
                std::memcpy(m_ringsExciterBufferR, m_voiceBuffer[1], frameCount * sizeof(float));
            }

            if (channelBuffers[12]) {
                std::memcpy(channelBuffers[12] + frameOffset, m_voiceBuffer[0], frameCount * sizeof(float));
            }
            if (channelBuffers[13]) {
                std::memcpy(channelBuffers[13] + frameOffset, m_voiceBuffer[1], frameCount * sizeof(float));
            }

            for (int i = 0; i < frameCount; ++i) {
                float peak = std::max(std::abs(m_voiceBuffer[0][i]), std::abs(m_voiceBuffer[1][i]));
                channelPeaks[6] = std::max(channelPeaks[6], peak);
            }
        }

        // ========== Channel 7: Sampler (SoundFont or WAV, buffers 14, 15) ==========
        {
            std::memset(m_voiceBuffer[0], 0, frameCount * sizeof(float));
            std::memset(m_voiceBuffer[1], 0, frameCount * sizeof(float));

            if (m_samplerMode == SamplerMode::WavSampler || m_samplerMode == SamplerMode::Sfz) {
                if (m_wavSamplerVoice) {
                    // Always call Render — it handles CheckSwap internally
                    // and outputs silence if no map is active yet
                    m_wavSamplerVoice->Render(m_voiceBuffer[0], m_voiceBuffer[1], frameCount);
                }
            } else {
                if (m_soundFontVoice) {
                    // Always call Render — it handles CheckSwap internally
                    // and outputs silence if no SoundFont is active yet
                    m_soundFontVoice->Render(m_voiceBuffer[0], m_voiceBuffer[1], frameCount);
                }
            }

            // Record from Sampler (channel 11) pre-output
            processRecordingForChannel(11, m_voiceBuffer[0], m_voiceBuffer[1], frameCount);

            // Capture for Rings exciter (source 11 = Sampler)
            if (m_ringsExciterSource == 11) {
                std::memcpy(m_ringsExciterBufferL, m_voiceBuffer[0], frameCount * sizeof(float));
                std::memcpy(m_ringsExciterBufferR, m_voiceBuffer[1], frameCount * sizeof(float));
            }

            if (channelBuffers[14]) {
                std::memcpy(channelBuffers[14] + frameOffset, m_voiceBuffer[0], frameCount * sizeof(float));
            }
            if (channelBuffers[15]) {
                std::memcpy(channelBuffers[15] + frameOffset, m_voiceBuffer[1], frameCount * sizeof(float));
            }

            for (int i = 0; i < frameCount; ++i) {
                float peak = std::max(std::abs(m_voiceBuffer[0][i]), std::abs(m_voiceBuffer[1][i]));
                channelPeaks[7] = std::max(channelPeaks[7], peak);
            }
        }

        // Process external input recording
        processExternalInputRecording(frameCount);
    };

    // Process with sample-accurate note events
    int cursorFrame = 0;
    int eventIndex = 0;
    while (eventIndex < dueEventCount) {
        const uint64_t eventSample = dueEvents[eventIndex].sampleTime;
        const int eventFrame = static_cast<int>(std::min<uint64_t>(numFrames, eventSample - bufferStartSample));

        if (eventFrame > cursorFrame) {
            renderChunk(cursorFrame, eventFrame - cursorFrame);
            cursorFrame = eventFrame;
        }

        while (eventIndex < dueEventCount && dueEvents[eventIndex].sampleTime == eventSample) {
            const ScheduledNoteEvent& event = dueEvents[eventIndex];
            if (event.isNoteOn) {
                noteOnTarget(static_cast<int>(event.note), static_cast<int>(event.velocity), event.targetMask, event.trackId);
            } else {
                noteOffTarget(static_cast<int>(event.note), event.targetMask, event.trackId);
            }
            ++eventIndex;
        }
    }

    if (cursorFrame < numFrames) {
        renderChunk(cursorFrame, numFrames - cursorFrame);
    }

    // Update channel level meters
    for (int i = 0; i < kNumMixerChannels; ++i) {
        float current = m_channelLevels[i].load();
        float target = channelPeaks[i];
        if (target > current) {
            m_channelLevels[i].store(target);
        } else {
            m_channelLevels[i].store(current * kMeterDecay + target * kMeterAttack);
        }
    }

    m_activeGrains.store(totalActiveGrains);
    m_currentSampleTime.store(bufferEndSample, std::memory_order_relaxed);

}

void AudioEngine::renderAndReadMultiChannel(
    int channelIndex,
    int64_t sampleTime,
    float* left,
    float* right,
    int numFrames
) {
    if (!left || !right || numFrames <= 0) {
        return;
    }
    if (channelIndex < 0 || channelIndex >= kNumMixerChannelsForRing) {
        std::memset(left, 0, numFrames * sizeof(float));
        std::memset(right, 0, numFrames * sizeof(float));
        return;
    }

    if (numFrames > kMaxBufferSize) {
        int frameOffset = 0;
        while (frameOffset < numFrames) {
            const int chunkFrames = std::min(kMaxBufferSize, numFrames - frameOffset);
            int64_t chunkSampleTime = sampleTime;
            if (chunkSampleTime >= 0) {
                chunkSampleTime += static_cast<int64_t>(frameOffset);
            }
            renderAndReadMultiChannel(
                channelIndex,
                chunkSampleTime,
                left + frameOffset,
                right + frameOffset,
                chunkFrames
            );
            frameOffset += chunkFrames;
        }
        return;
    }

    const int cachedFramesAtEntry = m_cachedBlockFrames.load(std::memory_order_acquire);
    const int64_t cachedSampleTimeAtEntry = m_cachedBlockSampleTime.load(std::memory_order_acquire);

    int64_t requestedSampleTime = sampleTime >= 0
        ? sampleTime
        : (cachedFramesAtEntry == numFrames && cachedSampleTimeAtEntry >= 0)
            ? cachedSampleTimeAtEntry
            : static_cast<int64_t>(m_currentSampleTime.load(std::memory_order_acquire));
    if (requestedSampleTime >= 0 && numFrames > 0) {
        requestedSampleTime = (requestedSampleTime / numFrames) * numFrames;
    }

    for (int attempt = 0; attempt < 4; ++attempt) {
        const int cachedFrames = m_cachedBlockFrames.load(std::memory_order_acquire);
        const int64_t cachedSampleTime = m_cachedBlockSampleTime.load(std::memory_order_acquire);
        if (cachedFrames == numFrames && cachedSampleTime == requestedSampleTime) {
            std::memcpy(left, m_cachedMultiChannelL[channelIndex], numFrames * sizeof(float));
            std::memcpy(right, m_cachedMultiChannelR[channelIndex], numFrames * sizeof(float));
            return;
        }

        bool expected = false;
        if (m_cachedRenderInProgress.compare_exchange_strong(expected, true, std::memory_order_acq_rel)) {
            const int latestFrames = m_cachedBlockFrames.load(std::memory_order_relaxed);
            const int64_t latestSampleTime = m_cachedBlockSampleTime.load(std::memory_order_relaxed);

            if (latestFrames != numFrames || latestSampleTime != requestedSampleTime) {
                m_renderingBlockFrames.store(numFrames, std::memory_order_release);
                m_renderingBlockSampleTime.store(requestedSampleTime, std::memory_order_release);
                m_currentSampleTime.store(static_cast<uint64_t>(requestedSampleTime), std::memory_order_relaxed);

                float* bufferPtrs[kNumMixerChannelsForRing * 2];
                for (int ch = 0; ch < kNumMixerChannelsForRing; ++ch) {
                    bufferPtrs[ch * 2] = m_cachedMultiChannelL[ch];
                    bufferPtrs[ch * 2 + 1] = m_cachedMultiChannelR[ch];
                }

                processMultiChannel(bufferPtrs, numFrames);
                m_cachedBlockFrames.store(numFrames, std::memory_order_release);
                m_cachedBlockSampleTime.store(requestedSampleTime, std::memory_order_release);
            }

            m_cachedRenderInProgress.store(false, std::memory_order_release);
        } else {
            int spinCount = 0;
            while (m_cachedRenderInProgress.load(std::memory_order_acquire) && spinCount < 50000) {
#if defined(__aarch64__) || defined(__arm64__)
                __builtin_arm_yield();
#elif defined(__x86_64__) || defined(__i386__)
                __builtin_ia32_pause();
#endif
                ++spinCount;
            }

            if (sampleTime < 0) {
                const int64_t renderingSample = m_renderingBlockSampleTime.load(std::memory_order_acquire);
                if (renderingSample >= 0) {
                    requestedSampleTime = renderingSample;
                }
            }
        }
    }

    const int cachedFrames = m_cachedBlockFrames.load(std::memory_order_acquire);
    if (cachedFrames == numFrames) {
        std::memcpy(left, m_cachedMultiChannelL[channelIndex], numFrames * sizeof(float));
        std::memcpy(right, m_cachedMultiChannelR[channelIndex], numFrames * sizeof(float));
    } else {
        std::memset(left, 0, numFrames * sizeof(float));
        std::memset(right, 0, numFrames * sizeof(float));
    }
}

void AudioEngine::renderAndReadLegacyBus(
    int busIndex,
    int64_t sampleTime,
    float* left,
    float* right,
    int numFrames
) {
    if (!left || !right || numFrames <= 0) {
        return;
    }
    if (busIndex < 0 || busIndex >= kNumLegacyOutputBuses) {
        std::memset(left, 0, numFrames * sizeof(float));
        std::memset(right, 0, numFrames * sizeof(float));
        return;
    }

    if (numFrames > kMaxBufferSize) {
        int frameOffset = 0;
        while (frameOffset < numFrames) {
            const int chunkFrames = std::min(kMaxBufferSize, numFrames - frameOffset);
            int64_t chunkSampleTime = sampleTime;
            if (chunkSampleTime >= 0) {
                chunkSampleTime += static_cast<int64_t>(frameOffset);
            }
            renderAndReadLegacyBus(
                busIndex,
                chunkSampleTime,
                left + frameOffset,
                right + frameOffset,
                chunkFrames
            );
            frameOffset += chunkFrames;
        }
        return;
    }

    const int cachedFramesAtEntry = m_cachedLegacyBlockFrames.load(std::memory_order_acquire);
    const int64_t cachedSampleAtEntry = m_cachedLegacyBlockSampleTime.load(std::memory_order_acquire);

    int64_t requestedSampleTime = sampleTime >= 0
        ? sampleTime
        : (cachedFramesAtEntry == numFrames && cachedSampleAtEntry >= 0)
            ? cachedSampleAtEntry
            : static_cast<int64_t>(m_currentSampleTime.load(std::memory_order_acquire));
    if (requestedSampleTime >= 0 && numFrames > 0) {
        requestedSampleTime = (requestedSampleTime / numFrames) * numFrames;
    }

    for (int attempt = 0; attempt < 4; ++attempt) {
        const int cachedFrames = m_cachedLegacyBlockFrames.load(std::memory_order_acquire);
        const int64_t cachedSample = m_cachedLegacyBlockSampleTime.load(std::memory_order_acquire);
        if (cachedFrames == numFrames && cachedSample == requestedSampleTime) {
            std::memcpy(left, m_cachedLegacyBusL[busIndex], numFrames * sizeof(float));
            std::memcpy(right, m_cachedLegacyBusR[busIndex], numFrames * sizeof(float));
            return;
        }

        bool expected = false;
        if (m_cachedLegacyRenderInProgress.compare_exchange_strong(expected, true, std::memory_order_acq_rel)) {
            const int latestFrames = m_cachedLegacyBlockFrames.load(std::memory_order_relaxed);
            const int64_t latestSample = m_cachedLegacyBlockSampleTime.load(std::memory_order_relaxed);

            if (latestFrames != numFrames || latestSample != requestedSampleTime) {
                m_renderingLegacyBlockFrames.store(numFrames, std::memory_order_release);
                m_renderingLegacyBlockSampleTime.store(requestedSampleTime, std::memory_order_release);
                m_currentSampleTime.store(static_cast<uint64_t>(requestedSampleTime), std::memory_order_relaxed);

                const bool previousExternalRouting = m_externalSendRoutingEnabled;
                m_externalSendRoutingEnabled = true;
                float* dryOut[2] = {
                    m_cachedLegacyBusL[0],
                    m_cachedLegacyBusR[0]
                };
                process(nullptr, dryOut, 2, numFrames);
                m_externalSendRoutingEnabled = previousExternalRouting;

                std::memcpy(m_cachedLegacyBusL[1], m_lastSendBusAL, numFrames * sizeof(float));
                std::memcpy(m_cachedLegacyBusR[1], m_lastSendBusAR, numFrames * sizeof(float));
                std::memcpy(m_cachedLegacyBusL[2], m_lastSendBusBL, numFrames * sizeof(float));
                std::memcpy(m_cachedLegacyBusR[2], m_lastSendBusBR, numFrames * sizeof(float));

                m_cachedLegacyBlockFrames.store(numFrames, std::memory_order_release);
                m_cachedLegacyBlockSampleTime.store(requestedSampleTime, std::memory_order_release);
            }

            m_cachedLegacyRenderInProgress.store(false, std::memory_order_release);
        } else {
            int spinCount = 0;
            while (m_cachedLegacyRenderInProgress.load(std::memory_order_acquire) && spinCount < 50000) {
#if defined(__aarch64__) || defined(__arm64__)
                __builtin_arm_yield();
#elif defined(__x86_64__) || defined(__i386__)
                __builtin_ia32_pause();
#endif
                ++spinCount;
            }

            if (sampleTime < 0) {
                const int64_t renderingSample = m_renderingLegacyBlockSampleTime.load(std::memory_order_acquire);
                if (renderingSample >= 0) {
                    requestedSampleTime = renderingSample;
                }
            }
        }
    }

    const int cachedFrames = m_cachedLegacyBlockFrames.load(std::memory_order_acquire);
    if (cachedFrames == numFrames) {
        std::memcpy(left, m_cachedLegacyBusL[busIndex], numFrames * sizeof(float));
        std::memcpy(right, m_cachedLegacyBusR[busIndex], numFrames * sizeof(float));
    } else {
        std::memset(left, 0, numFrames * sizeof(float));
        std::memset(right, 0, numFrames * sizeof(float));
    }
}

void AudioEngine::setParameter(ParameterID id, int voiceIndex, float value) {
    float clampedValue = std::max(0.0f, std::min(1.0f, value));

    // Clamp voice index for granular voices
    int granularVoice = std::max(0, std::min(voiceIndex, kNumGranularVoices - 1));
    int looperVoice = (voiceIndex == 1 || voiceIndex == 2) ? (voiceIndex - 1) : -1;

    switch (id) {
        // ========== Granular Parameters (Mangl-style) ==========
        case ParameterID::GranularSpeed:
            // Convert 0-1 to -2 to +2 (with 0.5 = 0 frozen, 0.75 = 1.0 normal speed)
            // Display: 100% = normal speed (1.0x), 200% = double, -100% = full reverse
            if (m_granularVoices[granularVoice]) {
                float speed = (clampedValue - 0.5f) * 4.0f;
                m_granularVoices[granularVoice]->SetSpeed(speed);
            }
            break;

        case ParameterID::GranularPitch:
            // Convert 0-1 to -24 to +24 semitones, then to pitch ratio
            if (m_granularVoices[granularVoice]) {
                float pitch = (clampedValue - 0.5f) * 48.0f;
                m_granularVoices[granularVoice]->SetPitchSemitones(pitch);
            }
            break;

        case ParameterID::GranularSize:
            // Convert 0-1 to 0-2.5 seconds (linear, 0-2500ms)
            if (m_granularVoices[granularVoice]) {
                float size = clampedValue * 2.5f;           // Linear: 0-2500ms
                size = std::max(0.001f, size);              // Minimum 1ms
                m_granularVoices[granularVoice]->SetSize(size);
            }
            break;

        case ParameterID::GranularDensity:
            // Convert 0-1 to 1-512 Hz (logarithmic)
            if (m_granularVoices[granularVoice]) {
                float density = 1.0f * std::pow(512.0f, clampedValue);
                m_granularVoices[granularVoice]->SetDensity(density);
            }
            break;

        case ParameterID::GranularJitter:
            // Convert 0-1 to 0-0.5 seconds (0ms to 500ms)
            if (m_granularVoices[granularVoice]) {
                float jitter = clampedValue * 0.5f;
                m_granularVoices[granularVoice]->SetJitter(jitter);
            }
            break;

        case ParameterID::GranularSpread:
            if (m_granularVoices[granularVoice]) {
                m_granularVoices[granularVoice]->SetSpread(clampedValue);
            }
            break;

        case ParameterID::GranularPan:
            // Convert 0-1 to -1 to +1
            if (m_granularVoices[granularVoice]) {
                float pan = (clampedValue - 0.5f) * 2.0f;
                m_granularVoices[granularVoice]->SetPan(pan);
            }
            break;

        case ParameterID::GranularFilterCutoff:
            // Convert 0-1 to 20-20000 Hz (logarithmic)
            if (m_granularVoices[granularVoice]) {
                float cutoff = 20.0f * std::pow(1000.0f, clampedValue);
                m_granularVoices[granularVoice]->SetCutoff(cutoff);
            }
            break;

        case ParameterID::GranularFilterResonance:
            if (m_granularVoices[granularVoice]) {
                m_granularVoices[granularVoice]->SetQ(clampedValue);
            }
            break;

        case ParameterID::GranularGain:
            if (m_granularVoices[granularVoice]) {
                m_granularVoices[granularVoice]->SetGain(clampedValue);
            }
            break;

        case ParameterID::GranularSend:
            if (m_granularVoices[granularVoice]) {
                m_granularVoices[granularVoice]->SetSend(clampedValue);
            }
            break;

        case ParameterID::GranularEnvelope:
            // Convert 0-1 to 0-7 (8 window types)
            if (m_granularVoices[granularVoice]) {
                int envIndex = static_cast<int>(value * 7.0f + 0.5f);
                m_granularVoices[granularVoice]->SetWindowTypeIndex(envIndex);
            }
            break;

        case ParameterID::GranularDecay:
            // Convert 0-1 to decay rate (inverted: 0 = fast/short, 1 = slow/long)
            // Higher slider value = longer decay time
            // Use exponential mapping for wider range: 0->12 (very fast), 1->0.15 (very slow)
            if (m_granularVoices[granularVoice]) {
                float decayRate = 12.0f * std::pow(0.0125f, clampedValue);  // Exponential: 12 down to ~0.15
                m_granularVoices[granularVoice]->SetDecayRate(decayRate);
            }
            break;

        case ParameterID::GranularFilterModel:
            if (m_granularVoices[granularVoice]) {
                const int maxIndex = static_cast<int>(GranularVoice::FilterModel::Count) - 1;
                int modelIndex = static_cast<int>(clampedValue * static_cast<float>(maxIndex) + 0.5f);
                m_granularVoices[granularVoice]->SetFilterModelIndex(modelIndex);
            }
            break;

        case ParameterID::GranularReverse:
            if (m_granularVoices[granularVoice]) {
                m_granularVoices[granularVoice]->SetReverseGrains(clampedValue > 0.5f);
            }
            break;

        case ParameterID::GranularMorph:
            if (m_granularVoices[granularVoice]) {
                m_granularVoices[granularVoice]->SetMorphAmount(clampedValue);
            }
            break;

        // ========== Rings Parameters ==========
        case ParameterID::RingsModel:
            if (m_ringsVoice) {
                const int maxModel = static_cast<int>(rings::RESONATOR_MODEL_LAST) - 1;
                const int model = std::clamp(static_cast<int>(clampedValue * maxModel + 0.5f), 0, maxModel);
                m_currentRingsModel = model;
                m_ringsVoice->SetModel(model);
            }
            break;

        case ParameterID::RingsStructure:
            m_ringsStructure = clampedValue;
            if (m_ringsVoice) {
                m_ringsVoice->SetStructure(clampedValue);
            }
            break;

        case ParameterID::RingsBrightness:
            m_ringsBrightness = clampedValue;
            if (m_ringsVoice) {
                m_ringsVoice->SetBrightness(clampedValue);
            }
            break;

        case ParameterID::RingsDamping:
            m_ringsDamping = clampedValue;
            if (m_ringsVoice) {
                m_ringsVoice->SetDamping(clampedValue);
            }
            break;

        case ParameterID::RingsPosition:
            m_ringsPosition = clampedValue;
            if (m_ringsVoice) {
                m_ringsVoice->SetPosition(clampedValue);
            }
            break;

        case ParameterID::RingsLevel:
            m_ringsLevel = clampedValue;
            if (m_ringsVoice) {
                m_ringsVoice->SetLevel(clampedValue);
            }
            break;

        case ParameterID::RingsPolyphony:
            if (m_ringsVoice) {
                int poly;
                if (clampedValue < 0.33f) poly = 1;
                else if (clampedValue < 0.67f) poly = 2;
                else poly = 4;
                m_ringsPolyphony = poly;
                m_ringsVoice->SetPolyphony(poly);
            }
            break;

        case ParameterID::RingsChord:
            if (m_ringsVoice) {
                m_ringsChord = std::clamp(static_cast<int>(clampedValue * 10.0f + 0.5f), 0, 10);
                m_ringsVoice->SetChord(m_ringsChord);
            }
            break;

        case ParameterID::RingsFM:
            if (m_ringsVoice) {
                m_ringsFM = clampedValue;
                m_ringsVoice->SetFM(clampedValue);
            }
            break;

        case ParameterID::RingsExciterSource:
        {
            // 0.0 = internal, >0 maps linearly to channel indices 0-11
            if (clampedValue < 0.01f) {
                m_ringsExciterSource = -1;  // internal
            } else {
                m_ringsExciterSource = std::clamp(static_cast<int>(clampedValue * 12.0f - 0.5f), 0, 11);
            }
            if (m_ringsVoice) {
                m_ringsVoice->SetInternalExciter(m_ringsExciterSource < 0);
            }
            break;
        }

        // ========== Looper Parameters (tracks 2 & 3) ==========
        case ParameterID::LooperRate:
            if (looperVoice >= 0 && looperVoice < kNumLooperVoices && m_looperVoices[looperVoice]) {
                // 0..1 -> 0.25x..2x (musically useful loop speed range)
                const float rate = 0.25f + clampedValue * 1.75f;
                m_looperVoices[looperVoice]->SetRate(rate);
            }
            break;

        case ParameterID::LooperReverse:
            if (looperVoice >= 0 && looperVoice < kNumLooperVoices && m_looperVoices[looperVoice]) {
                m_looperVoices[looperVoice]->SetReverse(clampedValue > 0.5f);
            }
            break;

        case ParameterID::LooperLoopStart:
            if (looperVoice >= 0 && looperVoice < kNumLooperVoices && m_looperVoices[looperVoice]) {
                m_looperVoices[looperVoice]->SetLoopStart(clampedValue);
            }
            break;

        case ParameterID::LooperLoopEnd:
            if (looperVoice >= 0 && looperVoice < kNumLooperVoices && m_looperVoices[looperVoice]) {
                m_looperVoices[looperVoice]->SetLoopEnd(clampedValue);
            }
            break;

        case ParameterID::LooperCut:
            if (looperVoice >= 0 && looperVoice < kNumLooperVoices && m_looperVoices[looperVoice]) {
                const int cut = std::clamp(static_cast<int>(clampedValue * 7.0f + 0.5f), 0, 7);
                m_looperVoices[looperVoice]->TriggerCut(cut, 8);
            }
            break;

        // ========== Plaits Parameters ==========
        case ParameterID::PlaitsModel:
            m_currentEngine = static_cast<int>(value * 23.0f + 0.5f);
            // Apply to all voices
            for (int i = 0; i < kNumPlaitsVoices; ++i) {
                if (m_plaitsVoices[i]) {
                    m_plaitsVoices[i]->SetEngine(m_currentEngine);
                    m_plaitsVoices[i]->SetSixOpCustomEnabled(m_plaitsSixOpCustomEnabled);
                    if (m_plaitsSixOpCustomEnabled && m_currentEngine >= 2 && m_currentEngine <= 4) {
                        m_plaitsVoices[i]->SetSixOpCustomPatchIndex(m_plaitsSixOpCustomPatchIndex);
                    }
                }
            }
            break;

        case ParameterID::PlaitsHarmonics:
        {
            float harmonicsValue = clampedValue;
            if (m_plaitsSixOpCustomEnabled && m_currentEngine >= 2 && m_currentEngine <= 4) {
                m_plaitsSixOpCustomPatchIndex = std::clamp(
                    static_cast<int>(clampedValue * 31.0f + 0.5f),
                    0,
                    31);
                harmonicsValue = static_cast<float>(m_plaitsSixOpCustomPatchIndex) / 31.0f;
            }
            m_harmonics = harmonicsValue;
            for (int i = 0; i < kNumPlaitsVoices; ++i) {
                if (m_plaitsVoices[i]) {
                    if (m_plaitsSixOpCustomEnabled && m_currentEngine >= 2 && m_currentEngine <= 4) {
                        m_plaitsVoices[i]->SetSixOpCustomPatchIndex(m_plaitsSixOpCustomPatchIndex);
                    }
                    m_plaitsVoices[i]->SetHarmonics(harmonicsValue);
                }
            }
            break;
        }

        case ParameterID::PlaitsTimbre:
            m_timbre = clampedValue;
            for (int i = 0; i < kNumPlaitsVoices; ++i) {
                if (m_plaitsVoices[i]) {
                    m_plaitsVoices[i]->SetTimbre(clampedValue);
                }
            }
            break;

        case ParameterID::PlaitsMorph:
            m_morph = clampedValue;
            for (int i = 0; i < kNumPlaitsVoices; ++i) {
                if (m_plaitsVoices[i]) {
                    m_plaitsVoices[i]->SetMorph(clampedValue);
                }
            }
            break;

        case ParameterID::PlaitsFrequency:
            m_plaitsFrequency = clampedValue;
            // Legacy: Set note on voice 0 only
            if (m_plaitsVoices[0]) {
                m_plaitsVoices[0]->SetNote(24.0f + clampedValue * 72.0f);
            }
            break;

        case ParameterID::PlaitsLevel:
            m_plaitsLevel = clampedValue;
            // Set level on all voices
            for (int i = 0; i < kNumPlaitsVoices; ++i) {
                if (m_plaitsVoices[i]) {
                    m_plaitsVoices[i]->SetLevel(clampedValue);
                }
            }
            break;

        case ParameterID::PlaitsMidiNote:
            // Legacy: Direct MIDI note on voice 0
            if (m_plaitsVoices[0]) {
                m_plaitsVoices[0]->SetNote(value);
            }
            break;

        case ParameterID::PlaitsLPGColor:
            m_lpgColor = clampedValue;
            for (int i = 0; i < kNumPlaitsVoices; ++i) {
                if (m_plaitsVoices[i]) {
                    m_plaitsVoices[i]->SetLPGColor(clampedValue);
                }
            }
            break;

        case ParameterID::PlaitsLPGDecay:
            m_lpgDecay = clampedValue;
            for (int i = 0; i < kNumPlaitsVoices; ++i) {
                if (m_plaitsVoices[i]) {
                    m_plaitsVoices[i]->SetLPGDecay(clampedValue);
                }
            }
            break;

        case ParameterID::PlaitsLPGAttack:
            m_lpgAttack = clampedValue;
            for (int i = 0; i < kNumPlaitsVoices; ++i) {
                if (m_plaitsVoices[i]) {
                    m_plaitsVoices[i]->SetLPGAttack(clampedValue);
                }
            }
            break;

        case ParameterID::PlaitsLPGBypass:
            m_lpgBypass = value > 0.5f;
            for (int i = 0; i < kNumPlaitsVoices; ++i) {
                if (m_plaitsVoices[i]) {
                    m_plaitsVoices[i]->SetLPGBypass(m_lpgBypass);
                }
            }
            break;

        // ========== Effects Parameters ==========
        case ParameterID::DelayTime:
            // RE-201 style repeat rate control
            m_delayTime = clampedValue;
            break;

        case ParameterID::DelayFeedback:
            m_delayFeedback = clampedValue * 0.95f;  // Cap at 95% to prevent runaway
            break;

        case ParameterID::DelayMix:
            m_delayMix = clampedValue;
            break;

        case ParameterID::DelayHeadMode:
            m_delayHeadMode = clampedValue;
            break;

        case ParameterID::DelayWow:
            m_delayWow = clampedValue;
            break;

        case ParameterID::DelayFlutter:
            m_delayFlutter = clampedValue;
            break;

        case ParameterID::DelayTone:
            m_delayTone = clampedValue;
            break;

        case ParameterID::DelaySync:
            m_delaySync = clampedValue > 0.5f;
            break;

        case ParameterID::DelayTempo:
            // 60-180 BPM
            m_delayTempoBPM = 60.0f + clampedValue * 120.0f;
            break;

        case ParameterID::DelaySubdivision:
            m_delaySubdivision = clampedValue;
            break;

        case ParameterID::ReverbSize:
            m_reverbSize = clampedValue;
            break;

        case ParameterID::ReverbDamping:
            m_reverbDamping = clampedValue;
            break;

        case ParameterID::ReverbMix:
            m_reverbMix = clampedValue;
            break;

        // ========== Mixer Parameters ==========
        case ParameterID::VoiceGain:
            if (voiceIndex >= 0 && voiceIndex < kNumMixerChannels) {
                // Allow gain up to 2.0 (0-1 maps to 0-2 for +6dB headroom)
                m_channelGain[voiceIndex] = clampedValue * 2.0f;
            }
            break;

        case ParameterID::VoicePan:
            if (voiceIndex >= 0 && voiceIndex < kNumMixerChannels) {
                // Convert 0-1 to -1 to +1
                m_channelPan[voiceIndex] = (clampedValue - 0.5f) * 2.0f;
            }
            break;

        case ParameterID::VoiceSend:
            if (voiceIndex >= 0 && voiceIndex < kNumMixerChannels) {
                m_channelSendA[voiceIndex] = clampedValue;
            }
            break;

        case ParameterID::VoiceMicroDelay:
            if (voiceIndex >= 0 && voiceIndex < kNumMixerChannels) {
                const float maxDelaySeconds = 0.05f; // 50ms
                const int delaySamples = static_cast<int>(clampedValue * maxDelaySeconds * static_cast<float>(m_sampleRate) + 0.5f);
                m_channelDelaySamples[voiceIndex] = std::clamp(delaySamples, 0, kMaxChannelDelaySamples);
            }
            break;

        case ParameterID::MasterGain:
            // Allow master gain up to 2.0 (0-1 maps to 0-2 for +6dB headroom)
            m_masterGain = clampedValue * 2.0f;
            break;

        // ========== Master Filter Parameters ==========
        case ParameterID::MasterFilterCutoff:
            // Map 0-1 to 20-20000 Hz (logarithmic)
            m_masterFilterCutoff = 20.0f * std::pow(1000.0f, clampedValue);
            updateMasterFilterParameters();
            break;

        case ParameterID::MasterFilterResonance:
            m_masterFilterResonance = clampedValue;
            updateMasterFilterParameters();
            break;

        case ParameterID::MasterFilterModel:
            // Map 0-1 to model index (0-9)
            m_masterFilterModel = static_cast<int>(clampedValue * 9.0f + 0.5f);
            initMasterFilter();  // Recreate filter instances
            break;

        // ========== DaisyDrum Parameters ==========
        case ParameterID::DaisyDrumEngine:
            m_currentDaisyDrumEngine = static_cast<int>(value * 4.0f + 0.5f);
            if (m_daisyDrumVoice) {
                m_daisyDrumVoice->SetEngine(m_currentDaisyDrumEngine);
            }
            break;

        case ParameterID::DaisyDrumHarmonics:
            m_daisyDrumHarmonics = clampedValue;
            if (m_daisyDrumVoice) {
                m_daisyDrumVoice->SetHarmonics(clampedValue);
            }
            break;

        case ParameterID::DaisyDrumTimbre:
            m_daisyDrumTimbre = clampedValue;
            if (m_daisyDrumVoice) {
                m_daisyDrumVoice->SetTimbre(clampedValue);
            }
            break;

        case ParameterID::DaisyDrumMorph:
            m_daisyDrumMorph = clampedValue;
            if (m_daisyDrumVoice) {
                m_daisyDrumVoice->SetMorph(clampedValue);
            }
            break;

        case ParameterID::DaisyDrumLevel:
            m_daisyDrumLevel = clampedValue;
            if (m_daisyDrumVoice) {
                m_daisyDrumVoice->SetLevel(clampedValue);
            }
            break;

        // SoundFont sampler parameters
        case ParameterID::SamplerPreset:
            if (m_soundFontVoice) {
                int count = m_soundFontVoice->GetPresetCount();
                if (count > 0) {
                    int idx = std::clamp(static_cast<int>(clampedValue * (count - 1) + 0.5f), 0, count - 1);
                    m_soundFontVoice->SetPreset(idx);
                }
            }
            // WAV sampler doesn't have presets — parameter ignored for it
            break;
        case ParameterID::SamplerAttack:
            m_samplerAttack = clampedValue;
            if (m_soundFontVoice) m_soundFontVoice->SetAttack(clampedValue);
            if (m_wavSamplerVoice) m_wavSamplerVoice->SetAttack(clampedValue);
            break;
        case ParameterID::SamplerDecay:
            m_samplerDecay = clampedValue;
            if (m_soundFontVoice) m_soundFontVoice->SetDecay(clampedValue);
            if (m_wavSamplerVoice) m_wavSamplerVoice->SetDecay(clampedValue);
            break;
        case ParameterID::SamplerSustain:
            m_samplerSustain = clampedValue;
            if (m_soundFontVoice) m_soundFontVoice->SetSustain(clampedValue);
            if (m_wavSamplerVoice) m_wavSamplerVoice->SetSustain(clampedValue);
            break;
        case ParameterID::SamplerRelease:
            m_samplerRelease = clampedValue;
            if (m_soundFontVoice) m_soundFontVoice->SetRelease(clampedValue);
            if (m_wavSamplerVoice) m_wavSamplerVoice->SetRelease(clampedValue);
            break;
        case ParameterID::SamplerFilterCutoff:
            m_samplerFilterCutoff = clampedValue;
            if (m_soundFontVoice) m_soundFontVoice->SetFilterCutoff(clampedValue);
            if (m_wavSamplerVoice) m_wavSamplerVoice->SetFilterCutoff(clampedValue);
            break;
        case ParameterID::SamplerFilterResonance:
            m_samplerFilterResonance = clampedValue;
            if (m_soundFontVoice) m_soundFontVoice->SetFilterResonance(clampedValue);
            if (m_wavSamplerVoice) m_wavSamplerVoice->SetFilterResonance(clampedValue);
            break;
        case ParameterID::SamplerTuning:
        {
            m_samplerTuning = clampedValue;
            // Map 0-1 to -24..+24 semitones
            float semitones = (clampedValue * 48.0f) - 24.0f;
            if (m_soundFontVoice) m_soundFontVoice->SetTuning(semitones);
            if (m_wavSamplerVoice) m_wavSamplerVoice->SetTuning(semitones);
            break;
        }
        case ParameterID::SamplerLevel:
            m_samplerLevel = clampedValue;
            if (m_soundFontVoice) m_soundFontVoice->SetLevel(clampedValue);
            if (m_wavSamplerVoice) m_wavSamplerVoice->SetLevel(clampedValue);
            break;
        case ParameterID::SamplerMode:
            if (clampedValue < 0.33f)
                m_samplerMode = SamplerMode::SoundFont;
            else if (clampedValue < 0.67f)
                m_samplerMode = SamplerMode::Sfz;
            else
                m_samplerMode = SamplerMode::WavSampler;
            if (m_wavSamplerVoice)
                m_wavSamplerVoice->SetUseSfzEnvelopes(m_samplerMode == SamplerMode::Sfz);
            break;

        default:
            break;
    }
}

float AudioEngine::getParameter(ParameterID id, int voiceIndex) const {
    const int granularVoice = std::max(0, std::min(voiceIndex, kNumGranularVoices - 1));

    auto clamp01 = [](float x) -> float {
        return std::max(0.0f, std::min(1.0f, x));
    };

    switch (id) {
        case ParameterID::GranularSpeed:
            if (m_granularVoices[granularVoice]) {
                const float speed = m_granularVoices[granularVoice]->GetSpeed();
                return clamp01((speed / 4.0f) + 0.5f);
            }
            return 0.0f;
        case ParameterID::GranularPitch:
            if (m_granularVoices[granularVoice]) {
                const float pitchRatio = std::max(0.0001f, m_granularVoices[granularVoice]->GetPitch());
                const float semitones = 12.0f * std::log2(pitchRatio);
                return clamp01((semitones + 24.0f) / 48.0f);
            }
            return 0.0f;
        case ParameterID::GranularSize:
            if (m_granularVoices[granularVoice]) {
                const float seconds = std::max(0.001f, m_granularVoices[granularVoice]->GetSize());
                return clamp01(seconds / 2.5f);  // Linear inverse: 0-2.5s -> 0-1
            }
            return 0.0f;
        case ParameterID::GranularDensity:
            if (m_granularVoices[granularVoice]) {
                const float density = std::max(1.0f, m_granularVoices[granularVoice]->GetDensity());
                return clamp01(std::log(density) / std::log(512.0f));
            }
            return 0.0f;
        case ParameterID::GranularJitter:
            if (m_granularVoices[granularVoice]) {
                return clamp01(m_granularVoices[granularVoice]->GetJitter() / 0.5f);
            }
            return 0.0f;
        case ParameterID::GranularSpread:
            if (m_granularVoices[granularVoice]) {
                return clamp01(m_granularVoices[granularVoice]->GetSpread());
            }
            return 0.0f;
        case ParameterID::GranularPan:
            if (m_granularVoices[granularVoice]) {
                return clamp01((m_granularVoices[granularVoice]->GetPan() + 1.0f) * 0.5f);
            }
            return 0.5f;
        case ParameterID::GranularFilterCutoff:
            if (m_granularVoices[granularVoice]) {
                const float cutoff = std::max(20.0f, m_granularVoices[granularVoice]->GetCutoff());
                return clamp01(std::log(cutoff / 20.0f) / std::log(1000.0f));
            }
            return 1.0f;
        case ParameterID::GranularFilterResonance:
            if (m_granularVoices[granularVoice]) {
                return clamp01(m_granularVoices[granularVoice]->GetQ());
            }
            return 0.0f;
        case ParameterID::GranularGain:
            if (m_granularVoices[granularVoice]) {
                return clamp01(m_granularVoices[granularVoice]->GetGain());
            }
            return 0.0f;
        case ParameterID::GranularSend:
            if (m_granularVoices[granularVoice]) {
                return clamp01(m_granularVoices[granularVoice]->GetSend());
            }
            return 0.0f;
        case ParameterID::GranularEnvelope:
            if (m_granularVoices[granularVoice]) {
                const int index = static_cast<int>(m_granularVoices[granularVoice]->GetWindowType());
                return clamp01(static_cast<float>(std::max(0, std::min(index, 7))) / 7.0f);
            }
            return 0.0f;
        case ParameterID::GranularDecay:
            if (m_granularVoices[granularVoice]) {
                const float decayRate = std::max(0.0001f, m_granularVoices[granularVoice]->GetDecayRate());
                return clamp01(std::log(decayRate / 12.0f) / std::log(0.0125f));
            }
            return 0.0f;
        case ParameterID::GranularFilterModel:
            if (m_granularVoices[granularVoice]) {
                const int maxIndex = static_cast<int>(GranularVoice::FilterModel::Count) - 1;
                const int index = static_cast<int>(m_granularVoices[granularVoice]->GetFilterModel());
                return clamp01(static_cast<float>(std::max(0, std::min(index, maxIndex))) / static_cast<float>(std::max(maxIndex, 1)));
            }
            return 0.0f;
        case ParameterID::GranularReverse:
            if (m_granularVoices[granularVoice]) {
                return m_granularVoices[granularVoice]->GetReverseGrains() ? 1.0f : 0.0f;
            }
            return 0.0f;
        case ParameterID::GranularMorph:
            if (m_granularVoices[granularVoice]) {
                return clamp01(m_granularVoices[granularVoice]->GetMorphAmount());
            }
            return 0.0f;

        // Existing global state readbacks.
        case ParameterID::RingsModel: {
            const int maxModel = static_cast<int>(rings::RESONATOR_MODEL_LAST) - 1;
            if (maxModel <= 0) { return 0.0f; }
            return clamp01(static_cast<float>(m_currentRingsModel) / static_cast<float>(maxModel));
        }
        case ParameterID::RingsStructure: return clamp01(m_ringsStructure);
        case ParameterID::RingsBrightness: return clamp01(m_ringsBrightness);
        case ParameterID::RingsDamping: return clamp01(m_ringsDamping);
        case ParameterID::RingsPosition: return clamp01(m_ringsPosition);
        case ParameterID::RingsLevel: return clamp01(m_ringsLevel);
        case ParameterID::RingsPolyphony: {
            if (m_ringsPolyphony >= 4) return 1.0f;
            if (m_ringsPolyphony >= 2) return 0.5f;
            return 0.0f;
        }
        case ParameterID::RingsChord: return clamp01(static_cast<float>(m_ringsChord) / 10.0f);
        case ParameterID::RingsFM: return clamp01(m_ringsFM);
        case ParameterID::RingsExciterSource: {
            if (m_ringsExciterSource < 0) return 0.0f;
            return clamp01((static_cast<float>(m_ringsExciterSource) + 0.5f) / 12.0f);
        }
        case ParameterID::PlaitsModel: return clamp01(static_cast<float>(m_currentEngine) / 23.0f);
        case ParameterID::PlaitsHarmonics: return clamp01(m_harmonics);
        case ParameterID::PlaitsTimbre: return clamp01(m_timbre);
        case ParameterID::PlaitsMorph: return clamp01(m_morph);
        case ParameterID::PlaitsLevel: return clamp01(m_plaitsLevel);
        case ParameterID::PlaitsLPGColor: return clamp01(m_lpgColor);
        case ParameterID::PlaitsLPGDecay: return clamp01(m_lpgDecay);
        case ParameterID::PlaitsLPGAttack: return clamp01(m_lpgAttack);
        case ParameterID::PlaitsLPGBypass: return m_lpgBypass ? 1.0f : 0.0f;
        case ParameterID::DelayTime: return clamp01(m_delayTime);
        case ParameterID::DelayFeedback: return clamp01(m_delayFeedback / 0.95f);
        case ParameterID::DelayMix: return clamp01(m_delayMix);
        case ParameterID::DelayHeadMode: return clamp01(m_delayHeadMode);
        case ParameterID::DelayWow: return clamp01(m_delayWow);
        case ParameterID::DelayFlutter: return clamp01(m_delayFlutter);
        case ParameterID::DelayTone: return clamp01(m_delayTone);
        case ParameterID::DelaySync: return m_delaySync ? 1.0f : 0.0f;
        case ParameterID::DelayTempo: return clamp01((m_delayTempoBPM - 60.0f) / 120.0f);
        case ParameterID::DelaySubdivision: return clamp01(m_delaySubdivision);
        case ParameterID::ReverbSize: return clamp01(m_reverbSize);
        case ParameterID::ReverbDamping: return clamp01(m_reverbDamping);
        case ParameterID::ReverbMix: return clamp01(m_reverbMix);
        case ParameterID::MasterGain: return clamp01(m_masterGain / 2.0f);

        // Master filter readbacks
        case ParameterID::MasterFilterCutoff:
            // Inverse of: cutoff = 20 * pow(1000, value)  =>  value = log(cutoff/20) / log(1000)
            return clamp01(std::log(m_masterFilterCutoff / 20.0f) / std::log(1000.0f));
        case ParameterID::MasterFilterResonance: return clamp01(m_masterFilterResonance);
        case ParameterID::MasterFilterModel: return clamp01(static_cast<float>(m_masterFilterModel) / 9.0f);

        // Plaits frequency readback
        case ParameterID::PlaitsFrequency: return clamp01(m_plaitsFrequency);

        // DaisyDrum readbacks
        case ParameterID::DaisyDrumEngine: return clamp01(static_cast<float>(m_currentDaisyDrumEngine) / 4.0f);
        case ParameterID::DaisyDrumHarmonics: return clamp01(m_daisyDrumHarmonics);
        case ParameterID::DaisyDrumTimbre: return clamp01(m_daisyDrumTimbre);
        case ParameterID::DaisyDrumMorph: return clamp01(m_daisyDrumMorph);
        case ParameterID::DaisyDrumLevel: return clamp01(m_daisyDrumLevel);

        // Looper readbacks (tracks 2 & 3)
        case ParameterID::LooperRate: {
            const int lv = (voiceIndex == 1 || voiceIndex == 2) ? (voiceIndex - 1) : -1;
            if (lv >= 0 && lv < kNumLooperVoices && m_looperVoices[lv]) {
                // Inverse of set: rate = 0.25 + normalized * 1.75  =>  normalized = (rate - 0.25) / 1.75
                return clamp01((m_looperVoices[lv]->GetRate() - 0.25f) / 1.75f);
            }
            return 0.0f;
        }
        case ParameterID::LooperReverse: {
            const int lv = (voiceIndex == 1 || voiceIndex == 2) ? (voiceIndex - 1) : -1;
            if (lv >= 0 && lv < kNumLooperVoices && m_looperVoices[lv]) {
                return m_looperVoices[lv]->GetReverse() ? 1.0f : 0.0f;
            }
            return 0.0f;
        }
        case ParameterID::LooperLoopStart: {
            const int lv = (voiceIndex == 1 || voiceIndex == 2) ? (voiceIndex - 1) : -1;
            if (lv >= 0 && lv < kNumLooperVoices && m_looperVoices[lv]) {
                return clamp01(m_looperVoices[lv]->GetLoopStart());
            }
            return 0.0f;
        }
        case ParameterID::LooperLoopEnd: {
            const int lv = (voiceIndex == 1 || voiceIndex == 2) ? (voiceIndex - 1) : -1;
            if (lv >= 0 && lv < kNumLooperVoices && m_looperVoices[lv]) {
                return clamp01(m_looperVoices[lv]->GetLoopEnd());
            }
            return 0.0f;
        }

        // SoundFont sampler parameters
        case ParameterID::SamplerPreset: {
            if (!m_soundFontVoice) return 0.0f;
            int count = m_soundFontVoice->GetPresetCount();
            if (count <= 1) return 0.0f;
            return clamp01(static_cast<float>(m_soundFontVoice->GetPreset()) / static_cast<float>(count - 1));
        }
        case ParameterID::SamplerAttack: return clamp01(m_samplerAttack);
        case ParameterID::SamplerDecay: return clamp01(m_samplerDecay);
        case ParameterID::SamplerSustain: return clamp01(m_samplerSustain);
        case ParameterID::SamplerRelease: return clamp01(m_samplerRelease);
        case ParameterID::SamplerFilterCutoff: return clamp01(m_samplerFilterCutoff);
        case ParameterID::SamplerFilterResonance: return clamp01(m_samplerFilterResonance);
        case ParameterID::SamplerTuning: return clamp01(m_samplerTuning);
        case ParameterID::SamplerLevel: return clamp01(m_samplerLevel);
        case ParameterID::SamplerMode:
            if (m_samplerMode == SamplerMode::SoundFont) return 0.0f;
            if (m_samplerMode == SamplerMode::Sfz) return 0.5f;
            return 1.0f;  // WavSampler

        default:
            return 0.0f;
    }
}

void AudioEngine::triggerPlaits(bool state) {
    // Legacy: trigger voice 0
    if (m_plaitsVoices[0]) {
        m_plaitsVoices[0]->Trigger(state);
    }
}

void AudioEngine::triggerDaisyDrum(bool state) {
    if (m_daisyDrumVoice) {
        if (state) {
            m_daisyDrumVoice->SetEngine(m_currentDaisyDrumEngine);
            m_daisyDrumVoice->SetHarmonics(m_daisyDrumHarmonics);
            m_daisyDrumVoice->SetTimbre(m_daisyDrumTimbre);
            m_daisyDrumVoice->SetMorph(m_daisyDrumMorph);
            m_daisyDrumVoice->SetLevel(m_daisyDrumLevel);
        }
        m_daisyDrumVoice->Trigger(state);
    }
}

// SoundFont sampler methods
bool AudioEngine::loadSoundFont(const char* filePath) {
    if (m_soundFontVoice) {
        return m_soundFontVoice->LoadSoundFont(filePath);
    }
    return false;
}

void AudioEngine::unloadSoundFont() {
    if (m_soundFontVoice) {
        m_soundFontVoice->UnloadSoundFont();
    }
}

int AudioEngine::getSoundFontPresetCount() const {
    if (m_soundFontVoice) {
        return m_soundFontVoice->GetPresetCount();
    }
    return 0;
}

const char* AudioEngine::getSoundFontPresetName(int index) const {
    if (m_soundFontVoice) {
        return m_soundFontVoice->GetPresetName(index);
    }
    return "";
}

bool AudioEngine::loadWavSampler(const char* dirPath) {
    if (m_wavSamplerVoice) {
        return m_wavSamplerVoice->LoadFromDirectory(dirPath);
    }
    return false;
}

bool AudioEngine::loadSfzFile(const char* sfzPath) {
    if (m_wavSamplerVoice) {
        bool ok = m_wavSamplerVoice->LoadFromSfzFile(sfzPath);
        if (ok) {
            m_samplerMode = SamplerMode::Sfz;
            m_wavSamplerVoice->SetUseSfzEnvelopes(true);
        }
        return ok;
    }
    return false;
}

void AudioEngine::unloadWavSampler() {
    if (m_wavSamplerVoice) {
        m_wavSamplerVoice->Unload();
    }
}

const char* AudioEngine::getWavSamplerInstrumentName() const {
    if (m_wavSamplerVoice) {
        return m_wavSamplerVoice->GetInstrumentName();
    }
    return "";
}

void AudioEngine::setSamplerMode(SamplerMode mode) {
    m_samplerMode = mode;
    if (m_wavSamplerVoice) {
        m_wavSamplerVoice->SetUseSfzEnvelopes(mode == SamplerMode::Sfz);
    }
}

void AudioEngine::triggerDrumSeqLane(int laneIndex, bool state) {
    if (laneIndex < 0 || laneIndex >= kNumDrumSeqLanes) return;
    if (m_drumSeqVoices[laneIndex]) {
        if (state) {
            m_drumSeqVoices[laneIndex]->SetLevel(m_drumSeqLevel[laneIndex]);
            m_drumSeqVoices[laneIndex]->SetHarmonics(m_drumSeqHarmonics[laneIndex]);
            m_drumSeqVoices[laneIndex]->SetTimbre(m_drumSeqTimbre[laneIndex]);
            m_drumSeqVoices[laneIndex]->SetMorph(m_drumSeqMorph[laneIndex]);
        }
        m_drumSeqVoices[laneIndex]->Trigger(state);
    }
}

void AudioEngine::setDrumSeqLaneLevel(int laneIndex, float level) {
    if (laneIndex < 0 || laneIndex >= kNumDrumSeqLanes) return;
    m_drumSeqLevel[laneIndex] = level;
}

void AudioEngine::setDrumSeqLaneHarmonics(int laneIndex, float value) {
    if (laneIndex < 0 || laneIndex >= kNumDrumSeqLanes) return;
    m_drumSeqHarmonics[laneIndex] = value;
}

void AudioEngine::setDrumSeqLaneTimbre(int laneIndex, float value) {
    if (laneIndex < 0 || laneIndex >= kNumDrumSeqLanes) return;
    m_drumSeqTimbre[laneIndex] = value;
}

void AudioEngine::setDrumSeqLaneMorph(int laneIndex, float value) {
    if (laneIndex < 0 || laneIndex >= kNumDrumSeqLanes) return;
    m_drumSeqMorph[laneIndex] = value;
}

void AudioEngine::loadUserWavetable(const float* data, int numSamples, int frameSize) {
    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        if (m_plaitsVoices[i]) {
            m_plaitsVoices[i]->LoadUserWavetable(data, numSamples, frameSize);
        }
    }
}

bool AudioEngine::loadPlaitsSixOpCustomBank(const uint8_t* data, int numBytes) {
    if (data == nullptr || numBytes < 32 * 128) {
        return false;
    }

    bool loaded = false;
    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        if (m_plaitsVoices[i]) {
            loaded = m_plaitsVoices[i]->LoadSixOpCustomBank(
                data,
                static_cast<size_t>(numBytes)) || loaded;
            m_plaitsVoices[i]->SetSixOpCustomEnabled(m_plaitsSixOpCustomEnabled);
            m_plaitsVoices[i]->SetSixOpCustomPatchIndex(m_plaitsSixOpCustomPatchIndex);
        }
    }
    return loaded;
}

void AudioEngine::setPlaitsSixOpCustomMode(bool enabled) {
    m_plaitsSixOpCustomEnabled = enabled;
    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        if (m_plaitsVoices[i]) {
            m_plaitsVoices[i]->SetSixOpCustomEnabled(enabled);
        }
    }
}

void AudioEngine::setPlaitsSixOpCustomPatch(int patchIndex) {
    m_plaitsSixOpCustomPatchIndex = std::clamp(patchIndex, 0, 31);
    const float normalizedPatch = static_cast<float>(m_plaitsSixOpCustomPatchIndex) / 31.0f;
    m_harmonics = normalizedPatch;
    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        if (m_plaitsVoices[i]) {
            m_plaitsVoices[i]->SetSixOpCustomPatchIndex(m_plaitsSixOpCustomPatchIndex);
            m_plaitsVoices[i]->SetHarmonics(normalizedPatch);
        }
    }
}

bool AudioEngine::loadAudioFile(const char* filePath, int reelIndex) {
    (void)filePath;
    (void)reelIndex;
    return false;
}

bool AudioEngine::loadAudioData(int reelIndex, const float* leftChannel, const float* rightChannel, size_t numSamples, float sampleRate) {
    if (reelIndex < 0 || reelIndex >= 32) return false;
    if (!leftChannel || numSamples == 0) return false;

    // Create buffer if it doesn't exist
    if (!m_reelBuffers[reelIndex]) {
        m_reelBuffers[reelIndex] = std::make_unique<ReelBuffer>();
    }

    auto& buffer = m_reelBuffers[reelIndex];

    // Clear existing content
    buffer->Clear();

    // Copy audio data (limit to max buffer size)
    size_t samplesToLoad = std::min(numSamples, buffer->GetMaxLength());

    for (size_t i = 0; i < samplesToLoad; ++i) {
        buffer->SetSample(0, i, leftChannel[i]);
        buffer->SetSample(1, i, rightChannel ? rightChannel[i] : leftChannel[i]);
    }

    buffer->SetLength(samplesToLoad);
    buffer->SetSampleRate(sampleRate);

    // Add a default splice covering the entire buffer
    buffer->AddSplice(0, static_cast<uint32_t>(samplesToLoad));

    // Assign to track voices if this is reel 0-3
    if (reelIndex < kNumGranularVoices && m_granularVoices[reelIndex]) {
        m_granularVoices[reelIndex]->SetBuffer(buffer.get());
    }
    if ((reelIndex == 1 || reelIndex == 2) && m_looperVoices[reelIndex - 1]) {
        m_looperVoices[reelIndex - 1]->SetBuffer(buffer.get());
    }

    return true;
}

void AudioEngine::clearReel(int reelIndex) {
    if (reelIndex < 0 || reelIndex >= 32) return;
    if (m_reelBuffers[reelIndex]) {
        m_reelBuffers[reelIndex]->Clear();
    }
}

size_t AudioEngine::getReelLength(int reelIndex) const {
    if (reelIndex < 0 || reelIndex >= 32) return 0;
    if (!m_reelBuffers[reelIndex]) return 0;
    return m_reelBuffers[reelIndex]->GetLength();
}

void AudioEngine::getWaveformOverview(int reelIndex, float* output, size_t outputSize) const {
    if (reelIndex < 0 || reelIndex >= 32) return;
    if (!m_reelBuffers[reelIndex] || !output || outputSize == 0) return;
    m_reelBuffers[reelIndex]->GenerateOverview(output, outputSize);
}

void AudioEngine::setGranularPlaying(int voiceIndex, bool playing) {
    if (voiceIndex < 0 || voiceIndex >= kNumGranularVoices) return;
    if ((voiceIndex == 1 || voiceIndex == 2) && m_looperVoices[voiceIndex - 1]) {
        m_looperVoices[voiceIndex - 1]->SetPlaying(playing);
        return;
    }
    if (m_granularVoices[voiceIndex]) {
        m_granularVoices[voiceIndex]->SetPlaying(playing);
    }
}

void AudioEngine::setGranularPosition(int voiceIndex, float position) {
    if (voiceIndex < 0 || voiceIndex >= kNumGranularVoices) return;
    if ((voiceIndex == 1 || voiceIndex == 2) && m_looperVoices[voiceIndex - 1]) {
        m_looperVoices[voiceIndex - 1]->SetPosition(position);
        return;
    }
    if (m_granularVoices[voiceIndex]) {
        m_granularVoices[voiceIndex]->Seek(position);
    }
}

float AudioEngine::getGranularPosition(int voiceIndex) const {
    if (voiceIndex < 0 || voiceIndex >= kNumGranularVoices) return 0.0f;
    if ((voiceIndex == 1 || voiceIndex == 2) && m_looperVoices[voiceIndex - 1]) {
        return m_looperVoices[voiceIndex - 1]->GetPosition();
    }
    if (m_granularVoices[voiceIndex]) {
        return m_granularVoices[voiceIndex]->GetPosition();
    }
    return 0.0f;
}

void AudioEngine::setQuantizationMode(int voiceIndex, QuantizationMode mode) {
    (void)voiceIndex;
    (void)mode;
}

void AudioEngine::setCustomIntervals(int voiceIndex, const float* intervals, int count) {
    (void)voiceIndex;
    (void)intervals;
    (void)count;
}

float AudioEngine::getCPULoad() const {
    return m_cpuLoad.load();
}

int AudioEngine::getActiveGrainCount() const {
    return m_activeGrains.load();
}

float AudioEngine::getChannelLevel(int channelIndex) const {
    if (channelIndex < 0 || channelIndex >= kNumMixerChannels) return 0.0f;
    return m_channelLevels[channelIndex].load();
}

float AudioEngine::getMasterLevel(int channel) const {
    if (channel == 0) return m_masterLevelL.load();
    if (channel == 1) return m_masterLevelR.load();
    return 0.0f;
}

void AudioEngine::readScopeBuffer(int sourceIndex, float* output, int numFrames) const {
    if (sourceIndex < 0 || sourceIndex >= kScopeNumSources || !output || numFrames <= 0) return;
    const int frames = std::min(numFrames, kScopeBufferSize);
    const size_t wi = m_scopeWriteIndex.load(std::memory_order_acquire);
    // Read the most recent 'frames' samples ending at the current write position
    for (int i = 0; i < frames; ++i) {
        size_t idx = (wi + kScopeBufferSize - frames + i) % kScopeBufferSize;
        output[i] = m_scopeBuffer[sourceIndex][idx];
    }
}

size_t AudioEngine::getScopeWriteIndex() const {
    return m_scopeWriteIndex.load(std::memory_order_acquire);
}

void AudioEngine::setChannelSendLevel(int channelIndex, int sendIndex, float level) {
    if (channelIndex < 0 || channelIndex >= kNumMixerChannels) {
        return;
    }

    const float clamped = std::clamp(level, 0.0f, 1.0f);
    if (sendIndex == 0) {
        m_channelSendA[channelIndex] = clamped;
    } else if (sendIndex == 1) {
        m_channelSendB[channelIndex] = clamped;
    }
}

// ========== Effects Implementation ==========

void AudioEngine::initEffects() {
    // Allocate delay buffers
    m_delayBufferL = new float[kMaxDelayLength];
    m_delayBufferR = new float[kMaxDelayLength];
    std::memset(m_delayBufferL, 0, kMaxDelayLength * sizeof(float));
    std::memset(m_delayBufferR, 0, kMaxDelayLength * sizeof(float));
    m_delayWritePos = 0;
    if (m_delaySync) {
        const float divisionTable[9] = {2.0f, 1.333333f, 1.5f, 1.0f, 0.666667f, 0.75f, 0.5f, 0.333333f, 0.25f};
        const int divisionIndex = std::clamp(static_cast<int>(m_delaySubdivision * 8.0f + 0.5f), 0, 8);
        const float beatSeconds = 60.0f / std::max(40.0f, m_delayTempoBPM);
        m_delayTimeSmoothed = beatSeconds * divisionTable[divisionIndex];
    } else {
        m_delayTimeSmoothed = 0.06f + (m_delayTime * m_delayTime) * 0.39f;
    }
    m_tapeWowPhase = 0.0f;
    m_tapeFlutterPhase = 0.0f;
    m_tapeDrift = 0.0f;
    m_tapeFeedbackLP = 0.0f;
    m_tapeFeedbackHPIn = 0.0f;
    m_tapeFeedbackHPOut = 0.0f;
    m_tapeToneL = 0.0f;
    m_tapeToneR = 0.0f;
    m_tapeNoiseState = 0x12345678u;

    // Allocate send buffers
    m_sendBufferAL = new float[kMaxBufferSize];
    m_sendBufferAR = new float[kMaxBufferSize];
    m_sendBufferBL = new float[kMaxBufferSize];
    m_sendBufferBR = new float[kMaxBufferSize];
    std::memset(m_sendBufferAL, 0, kMaxBufferSize * sizeof(float));
    std::memset(m_sendBufferAR, 0, kMaxBufferSize * sizeof(float));
    std::memset(m_sendBufferBL, 0, kMaxBufferSize * sizeof(float));
    std::memset(m_sendBufferBR, 0, kMaxBufferSize * sizeof(float));

    // Initialize reverb comb filters (Freeverb-style tunings)
    // These lengths are tuned for 48kHz
    const size_t combTunings[kNumCombs] = {
        1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116
    };

    for (size_t i = 0; i < kNumCombs; ++i) {
        m_combLengths[i] = combTunings[i];
        m_combBuffersL[i] = new float[combTunings[i]];
        m_combBuffersR[i] = new float[combTunings[i]];
        std::memset(m_combBuffersL[i], 0, combTunings[i] * sizeof(float));
        std::memset(m_combBuffersR[i], 0, combTunings[i] * sizeof(float));
        m_combPos[i] = 0;
        m_combFilters[i] = 0.0f;
        m_combFiltersR[i] = 0.0f;
    }

    // Initialize allpass filters
    const size_t allpassTunings[kNumAllpasses] = {
        556, 441, 341, 225
    };

    for (size_t i = 0; i < kNumAllpasses; ++i) {
        m_allpassLengths[i] = allpassTunings[i];
        m_allpassBuffersL[i] = new float[allpassTunings[i]];
        m_allpassBuffersR[i] = new float[allpassTunings[i]];
        std::memset(m_allpassBuffersL[i], 0, allpassTunings[i] * sizeof(float));
        std::memset(m_allpassBuffersR[i], 0, allpassTunings[i] * sizeof(float));
        m_allpassPos[i] = 0;
    }
}

void AudioEngine::cleanupEffects() {
    // Free delay buffers
    if (m_delayBufferL) {
        delete[] m_delayBufferL;
        m_delayBufferL = nullptr;
    }
    if (m_delayBufferR) {
        delete[] m_delayBufferR;
        m_delayBufferR = nullptr;
    }

    // Free send buffers
    if (m_sendBufferAL) {
        delete[] m_sendBufferAL;
        m_sendBufferAL = nullptr;
    }
    if (m_sendBufferAR) {
        delete[] m_sendBufferAR;
        m_sendBufferAR = nullptr;
    }
    if (m_sendBufferBL) {
        delete[] m_sendBufferBL;
        m_sendBufferBL = nullptr;
    }
    if (m_sendBufferBR) {
        delete[] m_sendBufferBR;
        m_sendBufferBR = nullptr;
    }

    // Free reverb buffers
    for (size_t i = 0; i < kNumCombs; ++i) {
        if (m_combBuffersL[i]) {
            delete[] m_combBuffersL[i];
            m_combBuffersL[i] = nullptr;
        }
        if (m_combBuffersR[i]) {
            delete[] m_combBuffersR[i];
            m_combBuffersR[i] = nullptr;
        }
    }

    for (size_t i = 0; i < kNumAllpasses; ++i) {
        if (m_allpassBuffersL[i]) {
            delete[] m_allpassBuffersL[i];
            m_allpassBuffersL[i] = nullptr;
        }
        if (m_allpassBuffersR[i]) {
            delete[] m_allpassBuffersR[i];
            m_allpassBuffersR[i] = nullptr;
        }
    }
}

void AudioEngine::processDelay(float& left, float& right) {
    if (!m_delayBufferL || !m_delayBufferR) return;

    constexpr float kPi = 3.14159265358979323846f;
    constexpr float kTwoPi = 6.28318530717958647692f;
    constexpr int kNumHeads = 3;
    constexpr int kNumHeadModes = 8;
    constexpr int kNumDivisions = 9;

    // Head spacing roughly follows a fixed multi-head tape layout.
    const float headRatios[kNumHeads] = {1.0f, 1.42f, 1.95f};
    const float headGains[kNumHeads] = {0.55f, 0.40f, 0.30f};
    const float headPans[kNumHeads] = {-0.55f, 0.0f, 0.55f};

    // Classic space-echo head combinations.
    const float modeMatrix[kNumHeadModes][kNumHeads] = {
        {1.00f, 0.00f, 0.00f}, // Head 1
        {0.00f, 1.00f, 0.00f}, // Head 2
        {0.00f, 0.00f, 1.00f}, // Head 3
        {0.85f, 0.65f, 0.00f}, // 1 + 2
        {0.00f, 0.75f, 0.58f}, // 2 + 3
        {0.80f, 0.00f, 0.58f}, // 1 + 3
        {0.72f, 0.55f, 0.42f}, // 1 + 2 + 3
        {0.95f, 0.45f, 0.28f}  // dense stack
    };

    const int modeIndex = std::clamp(static_cast<int>(m_delayHeadMode * static_cast<float>(kNumHeadModes - 1) + 0.5f), 0, kNumHeadModes - 1);

    float targetHead1Seconds;
    if (m_delaySync) {
        // Rhythmic values in quarter-note units.
        const float divisionTable[kNumDivisions] = {
            2.0f, 1.333333f, 1.5f, 1.0f, 0.666667f, 0.75f, 0.5f, 0.333333f, 0.25f
        };
        const int divisionIndex = std::clamp(static_cast<int>(m_delaySubdivision * static_cast<float>(kNumDivisions - 1) + 0.5f), 0, kNumDivisions - 1);
        const float beatSeconds = 60.0f / std::max(40.0f, m_delayTempoBPM);
        targetHead1Seconds = beatSeconds * divisionTable[divisionIndex];
    } else {
        // Free repeat-rate mapping: short head ranges ~60ms to ~450ms.
        const float repeatCurve = m_delayTime * m_delayTime;
        targetHead1Seconds = 0.06f + repeatCurve * 0.39f;
    }

    const float maxHead1Seconds = (static_cast<float>(kMaxDelayLength - 4) / static_cast<float>(m_sampleRate)) / headRatios[kNumHeads - 1];
    targetHead1Seconds = std::clamp(targetHead1Seconds, 0.03f, maxHead1Seconds);

    const float timeSmoothing = m_delaySync ? 0.0028f : 0.0015f;
    m_delayTimeSmoothed += (targetHead1Seconds - m_delayTimeSmoothed) * timeSmoothing;

    // Tape speed modulation (wow, flutter, and slow random drift).
    m_tapeWowPhase += kTwoPi * 0.17f / static_cast<float>(m_sampleRate);
    m_tapeFlutterPhase += kTwoPi * 5.4f / static_cast<float>(m_sampleRate);
    if (m_tapeWowPhase > kTwoPi) m_tapeWowPhase -= kTwoPi;
    if (m_tapeFlutterPhase > kTwoPi) m_tapeFlutterPhase -= kTwoPi;

    m_tapeNoiseState = m_tapeNoiseState * 1664525u + 1013904223u;
    float randomDrift = (static_cast<float>((m_tapeNoiseState >> 8) & 0x00FFFFFF) / 16777216.0f) * 2.0f - 1.0f;
    m_tapeDrift = m_tapeDrift * 0.99985f + randomDrift * 0.00015f;

    const float wowDepth = 0.0010f + m_delayWow * 0.0070f;
    const float flutterDepth = 0.00025f + m_delayFlutter * 0.0025f;
    const float driftDepth = 0.0007f + m_delayWow * 0.0014f;
    const float speedMod = std::clamp(
        std::sin(m_tapeWowPhase) * wowDepth +
        std::sin(m_tapeFlutterPhase) * flutterDepth +
        m_tapeDrift * driftDepth,
        -0.02f,
        0.02f
    );

    auto readInterpolated = [&](float* buffer, float delaySamples) -> float {
        float clampedDelay = std::max(1.0f, std::min(delaySamples, static_cast<float>(kMaxDelayLength - 2)));
        float readPos = static_cast<float>(m_delayWritePos) - clampedDelay;
        while (readPos < 0.0f) {
            readPos += static_cast<float>(kMaxDelayLength);
        }

        int indexA = static_cast<int>(readPos);
        int indexB = (indexA + 1) % static_cast<int>(kMaxDelayLength);
        float frac = readPos - static_cast<float>(indexA);
        return buffer[indexA] + (buffer[indexB] - buffer[indexA]) * frac;
    };

    float echoL = 0.0f;
    float echoR = 0.0f;
    float feedbackSum = 0.0f;

    for (int i = 0; i < kNumHeads; ++i) {
        const float modeGain = modeMatrix[modeIndex][i];
        if (modeGain < 0.001f) {
            continue;
        }

        float delaySeconds = m_delayTimeSmoothed * headRatios[i] * (1.0f + speedMod);
        float delaySamples = delaySeconds * static_cast<float>(m_sampleRate);

        float tapL = readInterpolated(m_delayBufferL, delaySamples);
        float tapR = readInterpolated(m_delayBufferR, delaySamples);
        float tapMono = (tapL + tapR) * 0.5f;
        float headOut = tapMono * headGains[i] * modeGain;

        float panAngle = (headPans[i] + 1.0f) * 0.25f * kPi;
        float panL = std::cos(panAngle);
        float panR = std::sin(panAngle);

        echoL += headOut * panL;
        echoR += headOut * panR;
        feedbackSum += headOut * (i == (kNumHeads - 1) ? 0.85f : 1.0f);
    }

    // Roll off highs/lows in the feedback path like aging tape.
    const float feedbackLPCoeff = std::clamp((0.28f + m_delayTone * 0.32f) - m_delayFeedback * 0.12f, 0.08f, 0.80f);
    m_tapeFeedbackLP += (std::tanh(feedbackSum * (1.1f + m_delayFeedback * 2.2f)) - m_tapeFeedbackLP) * feedbackLPCoeff;

    float feedbackHPCoeff = 1.0f - (kTwoPi * 110.0f / static_cast<float>(m_sampleRate));
    feedbackHPCoeff = std::max(0.0f, std::min(feedbackHPCoeff, 0.9999f));
    float feedbackHP = feedbackHPCoeff * (m_tapeFeedbackHPOut + m_tapeFeedbackLP - m_tapeFeedbackHPIn);
    m_tapeFeedbackHPIn = m_tapeFeedbackLP;
    m_tapeFeedbackHPOut = feedbackHP;

    // Tape preamp behavior before writing back to the loop.
    float inputMono = (left + right) * 0.5f;
    float preampedInput = std::tanh(inputMono * (1.0f + m_delayFeedback * 1.4f));

    m_tapeNoiseState = m_tapeNoiseState * 1664525u + 1013904223u;
    float hiss = ((static_cast<float>((m_tapeNoiseState >> 8) & 0x00FFFFFF) / 16777216.0f) * 2.0f - 1.0f) * 0.00003f;

    float writeSample = preampedInput + feedbackHP * (m_delayFeedback * 0.92f) + hiss;
    m_delayBufferL[m_delayWritePos] = writeSample;
    m_delayBufferR[m_delayWritePos] = writeSample * 0.985f + feedbackHP * 0.02f;
    m_delayWritePos = (m_delayWritePos + 1) % kMaxDelayLength;

    // Output tone shaping to keep repeats dark and soft.
    const float outputToneCoeff = std::clamp((0.35f + m_delayTone * 0.35f) - m_delayFeedback * 0.15f, 0.10f, 0.90f);
    m_tapeToneL += (echoL - m_tapeToneL) * outputToneCoeff;
    m_tapeToneR += (echoR - m_tapeToneR) * outputToneCoeff;

    float delayedL = std::tanh(m_tapeToneL * 1.25f);
    float delayedR = std::tanh(m_tapeToneR * 1.25f);

    // Mix dry/wet
    left = left * (1.0f - m_delayMix) + delayedL * m_delayMix;
    right = right * (1.0f - m_delayMix) + delayedR * m_delayMix;
}

void AudioEngine::processReverb(float& left, float& right) {
    // Freeverb-style algorithm
    float inputL = left;
    float inputR = right;

    // Calculate feedback based on room size
    float feedback = m_reverbSize * 0.28f + 0.7f;

    // Calculate damping filter coefficient
    float damp1 = m_reverbDamping * 0.4f;
    float damp2 = 1.0f - damp1;

    // Accumulate comb filter outputs
    float outL = 0.0f;
    float outR = 0.0f;

    for (size_t i = 0; i < kNumCombs; ++i) {
        // Left channel comb
        float combOutL = m_combBuffersL[i][m_combPos[i]];

        // Apply lowpass filter (damping)
        m_combFilters[i] = combOutL * damp2 + m_combFilters[i] * damp1;

        // Write back with feedback
        m_combBuffersL[i][m_combPos[i]] = inputL + m_combFilters[i] * feedback;

        outL += combOutL;

        // Right channel comb (slightly offset for stereo, with symmetric damping)
        size_t rightPos = (m_combPos[i] + 23) % m_combLengths[i];
        float combOutR = m_combBuffersR[i][rightPos];
        m_combFiltersR[i] = combOutR * damp2 + m_combFiltersR[i] * damp1;
        m_combBuffersR[i][rightPos] = inputR + m_combFiltersR[i] * feedback;
        outR += combOutR;

        // Advance position
        m_combPos[i] = (m_combPos[i] + 1) % m_combLengths[i];
    }

    // Process through allpass filters for diffusion
    for (size_t i = 0; i < kNumAllpasses; ++i) {
        // Left channel
        float bufOutL = m_allpassBuffersL[i][m_allpassPos[i]];
        float allpassOutL = -outL + bufOutL;
        m_allpassBuffersL[i][m_allpassPos[i]] = outL + bufOutL * 0.5f;
        outL = allpassOutL;

        // Right channel
        float bufOutR = m_allpassBuffersR[i][m_allpassPos[i]];
        float allpassOutR = -outR + bufOutR;
        m_allpassBuffersR[i][m_allpassPos[i]] = outR + bufOutR * 0.5f;
        outR = allpassOutR;

        // Advance position
        m_allpassPos[i] = (m_allpassPos[i] + 1) % m_allpassLengths[i];
    }

    // Scale output
    outL *= 0.15f;
    outR *= 0.15f;

    // Mix dry/wet
    left = left * (1.0f - m_reverbMix) + outL * m_reverbMix;
    right = right * (1.0f - m_reverbMix) + outR * m_reverbMix;
}

// ========== Master Clock Implementation ==========

void AudioEngine::setClockBPM(float bpm) {
    m_clockBPM.store(std::clamp(bpm, 10.0f, 330.0f));
}

void AudioEngine::setClockRunning(bool running) {
    if (running && !m_clockRunning.load()) {
        // Starting clock - record start time and reset phases
        m_clockStartSample = m_currentSampleTime.load(std::memory_order_relaxed);
        for (int i = 0; i < kNumClockOutputs; ++i) {
            m_clockOutputs[i].phaseAccumulator = m_clockOutputs[i].phase;
        }
    }
    m_clockRunning.store(running);
}

void AudioEngine::setClockStartSample(uint64_t startSample) {
    // Set the clock start sample explicitly for synchronization with sequencer
    m_clockStartSample = startSample;
    // Reset all phase accumulators to their initial phase offset
    for (int i = 0; i < kNumClockOutputs; ++i) {
        m_clockOutputs[i].phaseAccumulator = m_clockOutputs[i].phase;
    }
}

void AudioEngine::setClockSwing(float swing) {
    m_clockSwing = std::clamp(swing, 0.0f, 1.0f);
}

float AudioEngine::getClockBPM() const {
    return m_clockBPM.load();
}

bool AudioEngine::isClockRunning() const {
    return m_clockRunning.load();
}

void AudioEngine::setClockOutputMode(int outputIndex, int mode) {
    if (outputIndex >= 0 && outputIndex < kNumClockOutputs) {
        m_clockOutputs[outputIndex].mode = mode;
    }
}

void AudioEngine::setClockOutputWaveform(int outputIndex, int waveform) {
    if (outputIndex >= 0 && outputIndex < kNumClockOutputs) {
        m_clockOutputs[outputIndex].waveform = std::clamp(waveform, 0,
            static_cast<int>(ClockWaveform::NumWaveforms) - 1);
    }
}

void AudioEngine::setClockOutputDivision(int outputIndex, int division) {
    if (outputIndex >= 0 && outputIndex < kNumClockOutputs) {
        m_clockOutputs[outputIndex].divisionIndex = std::clamp(division, 0, 18);
    }
}

void AudioEngine::setClockOutputLevel(int outputIndex, float level) {
    if (outputIndex >= 0 && outputIndex < kNumClockOutputs) {
        m_clockOutputs[outputIndex].level = std::clamp(level, 0.0f, 1.0f);
    }
}

void AudioEngine::setClockOutputOffset(int outputIndex, float offset) {
    if (outputIndex >= 0 && outputIndex < kNumClockOutputs) {
        m_clockOutputs[outputIndex].offset = std::clamp(offset, -1.0f, 1.0f);
    }
}

void AudioEngine::setClockOutputPhase(int outputIndex, float phase) {
    if (outputIndex >= 0 && outputIndex < kNumClockOutputs) {
        m_clockOutputs[outputIndex].phase = std::clamp(phase, 0.0f, 1.0f);
    }
}

void AudioEngine::setClockOutputWidth(int outputIndex, float width) {
    if (outputIndex >= 0 && outputIndex < kNumClockOutputs) {
        m_clockOutputs[outputIndex].width = std::clamp(width, 0.0f, 1.0f);
    }
}

void AudioEngine::setClockOutputDestination(int outputIndex, int dest) {
    if (outputIndex >= 0 && outputIndex < kNumClockOutputs) {
        m_clockOutputs[outputIndex].destination = std::clamp(dest, 0,
            static_cast<int>(ModulationDestination::NumDestinations) - 1);
    }
}

void AudioEngine::setClockOutputModAmount(int outputIndex, float amount) {
    if (outputIndex >= 0 && outputIndex < kNumClockOutputs) {
        m_clockOutputs[outputIndex].modulationAmount = std::clamp(amount, 0.0f, 1.0f);
    }
}

void AudioEngine::setClockOutputMuted(int outputIndex, bool muted) {
    if (outputIndex >= 0 && outputIndex < kNumClockOutputs) {
        m_clockOutputs[outputIndex].muted = muted;
    }
}

void AudioEngine::setClockOutputSlowMode(int outputIndex, bool slow) {
    if (outputIndex >= 0 && outputIndex < kNumClockOutputs) {
        m_clockOutputs[outputIndex].slowMode = slow;
    }
}

float AudioEngine::getClockOutputValue(int outputIndex) const {
    if (outputIndex >= 0 && outputIndex < kNumClockOutputs) {
        return m_clockOutputValues[outputIndex].load();
    }
    return 0.0f;
}

float AudioEngine::getModulationValue(int destination) const {
    if (destination >= 0 && destination < static_cast<int>(ModulationDestination::NumDestinations)) {
        return m_modulationValues[destination];
    }
    return 0.0f;
}

float AudioEngine::generateWaveform(int waveform, double phase, float width, ClockOutputState& state) {
    // Phase is 0-1, output is -1 to +1
    const float p = static_cast<float>(phase);

    switch (static_cast<ClockWaveform>(waveform)) {
        case ClockWaveform::Gate:
            // Gate/pulse wave - width controls duty cycle
            return (p < width) ? 1.0f : -1.0f;

        case ClockWaveform::Sine:
            return std::sin(p * 2.0f * 3.14159265359f);

        case ClockWaveform::Triangle: {
            // Triangle with skew controlled by width
            if (p < width) {
                return (width > 0.0f) ? (-1.0f + 2.0f * p / width) : 0.0f;
            } else {
                return (width < 1.0f) ? (1.0f - 2.0f * (p - width) / (1.0f - width)) : 0.0f;
            }
        }

        case ClockWaveform::Saw:
            // Sawtooth down (starts high, falls to low)
            return 1.0f - 2.0f * p;

        case ClockWaveform::Ramp:
            // Ramp up (starts low, rises to high)
            return -1.0f + 2.0f * p;

        case ClockWaveform::Square:
            // Square wave (fixed 50% duty)
            return (p < 0.5f) ? 1.0f : -1.0f;

        case ClockWaveform::Random: {
            // Smoothed random - interpolates toward a new random target each cycle
            // Detect cycle wrap (phase crosses from high to low)
            bool cycleStart = (p < 0.01f && state.lastPhaseForSH > 0.5f);
            if (cycleStart) {
                // Generate new random target at start of each cycle
                state.randomState = state.randomState * 1664525u + 1013904223u;
                state.randomTarget = static_cast<float>(state.randomState) / static_cast<float>(0xFFFFFFFFu) * 2.0f - 1.0f;
            }
            state.lastPhaseForSH = p;

            // Smooth interpolation toward target (slew rate based on sample rate)
            const float smoothingCoeff = 0.001f;  // Adjust for smoothness
            state.smoothedRandomValue += smoothingCoeff * (state.randomTarget - state.smoothedRandomValue);
            return state.smoothedRandomValue;
        }

        case ClockWaveform::SampleHold: {
            // Sample & Hold - update held value at start of each cycle (phase wrap)
            // Detect cycle wrap (phase crosses from high to low)
            bool cycleStart = (p < 0.01f && state.lastPhaseForSH > 0.5f);
            if (cycleStart) {
                state.randomState = state.randomState * 1664525u + 1013904223u;
                state.sampleHoldValue = static_cast<float>(state.randomState) / static_cast<float>(0xFFFFFFFFu) * 2.0f - 1.0f;
            }
            state.lastPhaseForSH = p;
            return state.sampleHoldValue;
        }

        default:
            return 0.0f;
    }
}

void AudioEngine::processClockOutputs(int numFrames) {
    if (!m_clockRunning.load()) {
        // Clock stopped - output zeros
        for (int i = 0; i < kNumClockOutputs; ++i) {
            m_clockOutputs[i].currentValue = 0.0f;
            m_clockOutputValues[i].store(0.0f);
        }
        // Clear modulation
        for (int i = 0; i < static_cast<int>(ModulationDestination::NumDestinations); ++i) {
            m_modulationValues[i] = 0.0f;
        }
        return;
    }

    const float bpm = m_clockBPM.load();
    const float beatsPerSecond = bpm / 60.0f;
    const double samplesPerBeat = static_cast<double>(m_sampleRate) / static_cast<double>(beatsPerSecond);

    // Clear modulation accumulators
    for (int i = 0; i < static_cast<int>(ModulationDestination::NumDestinations); ++i) {
        m_modulationValues[i] = 0.0f;
    }

    const size_t scopeWi = m_scopeWriteIndex.load(std::memory_order_relaxed);

    // Process each clock output
    for (int i = 0; i < kNumClockOutputs; ++i) {
        ClockOutputState& out = m_clockOutputs[i];

        if (out.muted) {
            out.currentValue = 0.0f;
            m_clockOutputValues[i].store(0.0f);
            // Zero scope buffer for muted outputs
            for (int s = 0; s < numFrames; ++s) {
                m_scopeBuffer[9 + i][(scopeWi + s) % kScopeBufferSize] = 0.0f;
            }
            continue;
        }

        // Calculate frequency for this output based on division
        const int divIdx = std::clamp(out.divisionIndex, 0, 18);
        float multiplier = kDivisionMultipliers[divIdx];

        // Apply slow mode (/4 multiplier) if enabled
        if (out.slowMode) {
            multiplier *= 0.25f;
        }

        const double cyclesPerSample = (beatsPerSecond * static_cast<double>(multiplier)) / static_cast<double>(m_sampleRate);

        // Save starting phase for per-sample scope rendering
        const double startPhase = out.phaseAccumulator;

        // Advance phase for this buffer
        out.phaseAccumulator += cyclesPerSample * static_cast<double>(numFrames);

        // Wrap phase to 0-1
        while (out.phaseAccumulator >= 1.0) {
            out.phaseAccumulator -= 1.0;
        }

        // Generate waveform value (end of buffer — used for modulation and UI readback)
        float rawValue = generateWaveform(out.waveform, out.phaseAccumulator, out.width, out);

        // Apply level and offset
        float scaledValue = rawValue * out.level;
        float finalValue = std::clamp(scaledValue + out.offset, -1.0f, 1.0f);

        out.currentValue = finalValue;
        m_clockOutputValues[i].store(finalValue);

        // Fill scope buffer with per-sample waveform values for smooth display
        // For stateless waveforms, compute from interpolated phase.
        // For S&H/Random, repeat the final value (state-dependent).
        const bool isStateless = out.waveform != static_cast<int>(ClockWaveform::Random) &&
                                  out.waveform != static_cast<int>(ClockWaveform::SampleHold);
        if (isStateless) {
            for (int s = 0; s < numFrames; ++s) {
                double samplePhase = startPhase + cyclesPerSample * static_cast<double>(s);
                // Wrap to 0-1
                samplePhase -= static_cast<double>(static_cast<long long>(samplePhase));
                if (samplePhase < 0.0) samplePhase += 1.0;

                // Inline stateless waveform generation (avoids touching ClockOutputState)
                const float p = static_cast<float>(samplePhase);
                float raw = 0.0f;
                switch (static_cast<ClockWaveform>(out.waveform)) {
                    case ClockWaveform::Gate:    raw = (p < out.width) ? 1.0f : -1.0f; break;
                    case ClockWaveform::Sine:    raw = std::sin(p * 2.0f * 3.14159265359f); break;
                    case ClockWaveform::Triangle:
                        if (p < out.width)
                            raw = (out.width > 0.0f) ? (-1.0f + 2.0f * p / out.width) : 0.0f;
                        else
                            raw = (out.width < 1.0f) ? (1.0f - 2.0f * (p - out.width) / (1.0f - out.width)) : 0.0f;
                        break;
                    case ClockWaveform::Saw:     raw = 1.0f - 2.0f * p; break;
                    case ClockWaveform::Ramp:    raw = -1.0f + 2.0f * p; break;
                    case ClockWaveform::Square:  raw = (p < 0.5f) ? 1.0f : -1.0f; break;
                    default: break;
                }
                m_scopeBuffer[9 + i][(scopeWi + s) % kScopeBufferSize] =
                    std::clamp(raw * out.level + out.offset, -1.0f, 1.0f);
            }
        } else {
            // S&H and Random: repeat the final computed value
            for (int s = 0; s < numFrames; ++s) {
                m_scopeBuffer[9 + i][(scopeWi + s) % kScopeBufferSize] = finalValue;
            }
        }

        // Route to modulation destination
        if (out.destination > 0 && out.destination < static_cast<int>(ModulationDestination::NumDestinations)) {
            float modValue = finalValue * out.modulationAmount;
            m_modulationValues[out.destination] += modValue;
        }
    }
}

void AudioEngine::applyModulation() {
    // Apply accumulated modulation values to parameters
    // This is called once per buffer after processClockOutputs
    // Modulation values are bipolar (-1 to +1 range scaled by mod amount)

    // Plaits modulation - always apply (even when 0 to clear previous modulation)
    float harmonicsMod = m_modulationValues[static_cast<int>(ModulationDestination::PlaitsHarmonics)];
    float timbreMod = m_modulationValues[static_cast<int>(ModulationDestination::PlaitsTimbre)];
    float morphMod = m_modulationValues[static_cast<int>(ModulationDestination::PlaitsMorph)];

    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        if (m_plaitsVoices[i]) {
            m_plaitsVoices[i]->SetHarmonicsModAmount(harmonicsMod);
            m_plaitsVoices[i]->SetTimbreModAmount(timbreMod);
            m_plaitsVoices[i]->SetMorphModAmount(morphMod);
        }
    }

    // Rings modulation - structure, brightness, damping, position
    if (m_ringsVoice) {
        m_ringsVoice->SetStructureMod(m_modulationValues[static_cast<int>(ModulationDestination::RingsStructure)]);
        m_ringsVoice->SetBrightnessMod(m_modulationValues[static_cast<int>(ModulationDestination::RingsBrightness)]);
        m_ringsVoice->SetDampingMod(m_modulationValues[static_cast<int>(ModulationDestination::RingsDamping)]);
        m_ringsVoice->SetPositionMod(m_modulationValues[static_cast<int>(ModulationDestination::RingsPosition)]);
    }

    // Granular 1 modulation (voice index 0)
    if (m_granularVoices[0]) {
        m_granularVoices[0]->SetSpeedMod(m_modulationValues[static_cast<int>(ModulationDestination::Granular1Speed)]);
        m_granularVoices[0]->SetPitchMod(m_modulationValues[static_cast<int>(ModulationDestination::Granular1Pitch)]);
        m_granularVoices[0]->SetSizeMod(m_modulationValues[static_cast<int>(ModulationDestination::Granular1Size)]);
        m_granularVoices[0]->SetDensityMod(m_modulationValues[static_cast<int>(ModulationDestination::Granular1Density)]);
        m_granularVoices[0]->SetFilterMod(m_modulationValues[static_cast<int>(ModulationDestination::Granular1Filter)]);
    }

    // Granular 2 modulation (voice index 1)
    if (m_granularVoices[1]) {
        m_granularVoices[1]->SetSpeedMod(m_modulationValues[static_cast<int>(ModulationDestination::Granular2Speed)]);
        m_granularVoices[1]->SetPitchMod(m_modulationValues[static_cast<int>(ModulationDestination::Granular2Pitch)]);
        m_granularVoices[1]->SetSizeMod(m_modulationValues[static_cast<int>(ModulationDestination::Granular2Size)]);
        m_granularVoices[1]->SetDensityMod(m_modulationValues[static_cast<int>(ModulationDestination::Granular2Density)]);
        m_granularVoices[1]->SetFilterMod(m_modulationValues[static_cast<int>(ModulationDestination::Granular2Filter)]);
    }

    // DaisyDrum modulation
    if (m_daisyDrumVoice) {
        m_daisyDrumVoice->SetHarmonicsMod(m_modulationValues[static_cast<int>(ModulationDestination::DaisyDrumHarmonics)]);
        m_daisyDrumVoice->SetTimbreMod(m_modulationValues[static_cast<int>(ModulationDestination::DaisyDrumTimbre)]);
        m_daisyDrumVoice->SetMorphMod(m_modulationValues[static_cast<int>(ModulationDestination::DaisyDrumMorph)]);
    }

    // Note: Delay modulation would be applied similarly
    // but requires additional state tracking for smooth modulation
}

// ========== Master Filter Implementation ==========

void AudioEngine::initMasterFilter() {
    // Create filter instances based on selected model
    auto createFilter = [this](int model) -> std::unique_ptr<LadderFilterBase> {
        switch (model) {
            case 0: return std::make_unique<HuovilainenMoog>(static_cast<float>(m_sampleRate));
            case 1: return std::make_unique<StilsonMoog>(static_cast<float>(m_sampleRate));
            case 2: return std::make_unique<MicrotrackerMoog>(static_cast<float>(m_sampleRate));
            case 3: return std::make_unique<KrajeskiMoog>(static_cast<float>(m_sampleRate));
            case 4: return std::make_unique<MusicDSPMoog>(static_cast<float>(m_sampleRate));
            case 5: return std::make_unique<OberheimVariationMoog>(static_cast<float>(m_sampleRate));
            case 6: return std::make_unique<ImprovedMoog>(static_cast<float>(m_sampleRate));
            case 7: return std::make_unique<RKSimulationMoog>(static_cast<float>(m_sampleRate));
            case 8: return std::make_unique<HyperionMoog>(static_cast<float>(m_sampleRate));
            default: return std::make_unique<StilsonMoog>(static_cast<float>(m_sampleRate));
        }
    };

    m_masterFilterL = createFilter(m_masterFilterModel);
    m_masterFilterR = createFilter(m_masterFilterModel);

    updateMasterFilterParameters();
}

void AudioEngine::updateMasterFilterParameters() {
    if (!m_masterFilterL || !m_masterFilterR) return;

    // Model-specific stability limits (same as GranularVoice)
    float cutoffLimit = 0.45f;
    float resonanceMax = 1.0f;

    switch (m_masterFilterModel) {
        case 0:  cutoffLimit = 0.38f; resonanceMax = 0.74f; break;  // Huovilainen
        case 1:  cutoffLimit = 0.45f; resonanceMax = 0.95f; break;  // Stilson
        case 2:  cutoffLimit = 0.45f; resonanceMax = 0.92f; break;  // Microtracker
        case 3:  cutoffLimit = 0.45f; resonanceMax = 0.93f; break;  // Krajeski
        case 4:  cutoffLimit = 0.42f; resonanceMax = 0.88f; break;  // MusicDSP
        case 5:  cutoffLimit = 0.40f; resonanceMax = 0.86f; break;  // OberheimVariation
        case 6:  cutoffLimit = 0.40f; resonanceMax = 0.82f; break;  // Improved
        case 7:  cutoffLimit = 0.35f; resonanceMax = 0.55f; break;  // RKSimulation
        case 8:  cutoffLimit = 0.42f; resonanceMax = 0.88f; break;  // Hyperion
        default: break;
    }

    const float nyquist = static_cast<float>(m_sampleRate) * 0.5f;
    const float safeCutoff = std::max(20.0f, std::min(m_masterFilterCutoff, nyquist * cutoffLimit));
    const float safeResonance = std::max(0.0f, std::min(m_masterFilterResonance, resonanceMax));

    m_masterFilterL->SetCutoff(safeCutoff);
    m_masterFilterR->SetCutoff(safeCutoff);
    m_masterFilterL->SetResonance(safeResonance);
    m_masterFilterR->SetResonance(safeResonance);
}

void AudioEngine::processMasterFilter(float& left, float& right) {
    if (!m_masterFilterL || !m_masterFilterR) return;

    // Skip processing if filter is wide open and no resonance
    if (m_masterFilterCutoff >= 19000.0f && m_masterFilterResonance < 0.01f) {
        return;
    }

    // Apply soft saturation before filter to prevent extreme peaks
    left = std::tanh(left * 0.5f) * 2.0f;
    right = std::tanh(right * 0.5f) * 2.0f;

    // Process through filters (single sample at a time)
    m_masterFilterL->Process(&left, 1);
    m_masterFilterR->Process(&right, 1);

    // Snap to zero to prevent denormals
    if (std::fabs(left) < 1.0e-20f) left = 0.0f;
    if (std::fabs(right) < 1.0e-20f) right = 0.0f;
}

// MARK: - MultiChannelRingBuffer Implementation

MultiChannelRingBuffer::MultiChannelRingBuffer() {
    reset();
}

void MultiChannelRingBuffer::reset() {
    m_writeIndex.store(0, std::memory_order_release);
    for (int i = 0; i < kNumMixerChannelsForRing; ++i) {
        m_readIndex[i].store(0, std::memory_order_release);
        std::memset(m_bufferL[i], 0, sizeof(m_bufferL[i]));
        std::memset(m_bufferR[i], 0, sizeof(m_bufferR[i]));
    }
}

void MultiChannelRingBuffer::writeChannel(int channelIndex, const float* left, const float* right, int numFrames) {
    if (channelIndex < 0 || channelIndex >= kNumMixerChannelsForRing) return;

    size_t writeIdx = m_writeIndex.load(std::memory_order_relaxed);

    for (int i = 0; i < numFrames; ++i) {
        size_t idx = (writeIdx + i) % kMultiChannelRingBufferSize;
        m_bufferL[channelIndex][idx] = left[i];
        m_bufferR[channelIndex][idx] = right[i];
    }
    // Note: advanceWriteIndex() is called separately after ALL channels are written
}

void MultiChannelRingBuffer::advanceWriteIndex(int numFrames) {
    size_t writeIdx = m_writeIndex.load(std::memory_order_relaxed);
    m_writeIndex.store((writeIdx + numFrames) % kMultiChannelRingBufferSize, std::memory_order_release);
}

bool MultiChannelRingBuffer::canWrite(int numFrames) const {
    // Check if we have space for numFrames samples
    // Find the slowest reader (minimum read index distance from write)
    size_t writeIdx = m_writeIndex.load(std::memory_order_acquire);
    size_t minAvailable = kMultiChannelRingBufferSize;

    for (int i = 0; i < kNumMixerChannelsForRing; ++i) {
        size_t readIdx = m_readIndex[i].load(std::memory_order_acquire);
        // Calculate how many samples until we'd overwrite unread data
        size_t available = (readIdx - writeIdx - 1 + kMultiChannelRingBufferSize) % kMultiChannelRingBufferSize;
        if (available < minAvailable) {
            minAvailable = available;
        }
    }

    return minAvailable >= static_cast<size_t>(numFrames);
}

void MultiChannelRingBuffer::readChannel(int channelIndex, float* left, float* right, int numFrames) {
    if (channelIndex < 0 || channelIndex >= kNumMixerChannelsForRing) {
        // Invalid channel - output silence
        std::memset(left, 0, numFrames * sizeof(float));
        std::memset(right, 0, numFrames * sizeof(float));
        return;
    }

    size_t readIdx = m_readIndex[channelIndex].load(std::memory_order_acquire);
    size_t writeIdx = m_writeIndex.load(std::memory_order_acquire);

    // Calculate available data (handle wrap-around)
    size_t available = (writeIdx - readIdx + kMultiChannelRingBufferSize) % kMultiChannelRingBufferSize;

    for (int i = 0; i < numFrames; ++i) {
        if (static_cast<size_t>(i) < available) {
            size_t idx = (readIdx + i) % kMultiChannelRingBufferSize;
            left[i] = m_bufferL[channelIndex][idx];
            right[i] = m_bufferR[channelIndex][idx];
        } else {
            // Underrun - output silence
            left[i] = 0.0f;
            right[i] = 0.0f;
        }
    }

    // Advance read index
    size_t actualRead = std::min(static_cast<size_t>(numFrames), available);
    m_readIndex[channelIndex].store((readIdx + actualRead) % kMultiChannelRingBufferSize, std::memory_order_release);
}

bool MultiChannelRingBuffer::canRead(int channelIndex, int numFrames) const {
    if (channelIndex < 0 || channelIndex >= kNumMixerChannelsForRing) return false;

    size_t readIdx = m_readIndex[channelIndex].load(std::memory_order_acquire);
    size_t writeIdx = m_writeIndex.load(std::memory_order_acquire);

    size_t available = (writeIdx - readIdx + kMultiChannelRingBufferSize) % kMultiChannelRingBufferSize;
    return available >= static_cast<size_t>(numFrames);
}

size_t MultiChannelRingBuffer::getReadableFrames(int channelIndex) const {
    if (channelIndex < 0 || channelIndex >= kNumMixerChannelsForRing) return 0;

    size_t readIdx = m_readIndex[channelIndex].load(std::memory_order_acquire);
    size_t writeIdx = m_writeIndex.load(std::memory_order_acquire);

    return (writeIdx - readIdx + kMultiChannelRingBufferSize) % kMultiChannelRingBufferSize;
}

size_t MultiChannelRingBuffer::getWritableFrames() const {
    size_t writeIdx = m_writeIndex.load(std::memory_order_acquire);
    size_t minAvailable = kMultiChannelRingBufferSize;

    for (int i = 0; i < kNumMixerChannelsForRing; ++i) {
        size_t readIdx = m_readIndex[i].load(std::memory_order_acquire);
        size_t available = (readIdx - writeIdx - 1 + kMultiChannelRingBufferSize) % kMultiChannelRingBufferSize;
        if (available < minAvailable) {
            minAvailable = available;
        }
    }

    return minAvailable;
}

// MARK: - MasterCaptureRingBuffer Implementation

void MasterCaptureRingBuffer::reset() {
    m_writeIndex.store(0, std::memory_order_release);
    m_readIndex.store(0, std::memory_order_release);
}

void MasterCaptureRingBuffer::write(const float* left, const float* right, int numFrames) {
    size_t writeIdx = m_writeIndex.load(std::memory_order_relaxed);
    size_t readIdx = m_readIndex.load(std::memory_order_acquire);

    // Available space (leave 1 slot to distinguish full from empty)
    size_t space = (readIdx - writeIdx - 1 + kMasterCaptureRingSize) % kMasterCaptureRingSize;
    int framesToWrite = std::min(numFrames, static_cast<int>(space));

    for (int i = 0; i < framesToWrite; ++i) {
        size_t idx = (writeIdx + i) % kMasterCaptureRingSize;
        m_bufferL[idx] = left[i];
        m_bufferR[idx] = right[i];
    }

    m_writeIndex.store((writeIdx + framesToWrite) % kMasterCaptureRingSize, std::memory_order_release);
}

int MasterCaptureRingBuffer::read(float* left, float* right, int maxFrames) {
    size_t readIdx = m_readIndex.load(std::memory_order_relaxed);
    size_t writeIdx = m_writeIndex.load(std::memory_order_acquire);

    size_t available = (writeIdx - readIdx + kMasterCaptureRingSize) % kMasterCaptureRingSize;
    int framesToRead = std::min(maxFrames, static_cast<int>(available));

    for (int i = 0; i < framesToRead; ++i) {
        size_t idx = (readIdx + i) % kMasterCaptureRingSize;
        left[i] = m_bufferL[idx];
        right[i] = m_bufferR[idx];
    }

    m_readIndex.store((readIdx + framesToRead) % kMasterCaptureRingSize, std::memory_order_release);
    return framesToRead;
}

// MARK: - Master Output Capture

void AudioEngine::startMasterCapture() {
    m_masterCaptureRing.reset();
    m_masterCaptureActive.store(true, std::memory_order_release);
}

void AudioEngine::stopMasterCapture() {
    m_masterCaptureActive.store(false, std::memory_order_release);
}

bool AudioEngine::isMasterCaptureActive() const {
    return m_masterCaptureActive.load(std::memory_order_acquire);
}

int AudioEngine::readMasterCaptureBuffer(float* left, float* right, int maxFrames) {
    return m_masterCaptureRing.read(left, right, maxFrames);
}

// MARK: - Multi-Channel Processing Thread

void AudioEngine::startMultiChannelProcessing() {
    if (m_multiChannelProcessingActive.load(std::memory_order_acquire)) return;

    m_ringBuffer.reset();
    m_multiChannelProcessingActive.store(true, std::memory_order_release);

    m_processingThread = std::thread([this]() {
        multiChannelProcessingLoop();
    });

    // Note: Thread priority is set inside the loop for macOS
    printf("✓ Multi-channel processing thread started\n");
    fflush(stdout);
}

void AudioEngine::stopMultiChannelProcessing() {
    m_multiChannelProcessingActive.store(false, std::memory_order_release);
    if (m_processingThread.joinable()) {
        m_processingThread.join();
    }
    printf("✓ Multi-channel processing thread stopped\n");
}

void AudioEngine::multiChannelProcessingLoop() {
    // Set high priority for audio processing on macOS
    #if defined(__APPLE__)
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    #endif

    // Allocate temp buffers for processMultiChannel
    // Layout: [ch0_L, ch0_R, ch1_L, ch1_R, ..., ch5_L, ch5_R]
    constexpr int kNumBuffers = kNumMixerChannelsForRing * 2;  // 12 buffers (6 stereo pairs)
    float tempBuffers[kNumBuffers][kRingBufferProcessFrames];
    float* bufferPtrs[kNumBuffers];

    for (int i = 0; i < kNumBuffers; ++i) {
        bufferPtrs[i] = tempBuffers[i];
        std::memset(bufferPtrs[i], 0, kRingBufferProcessFrames * sizeof(float));
    }

    while (m_multiChannelProcessingActive.load(std::memory_order_acquire)) {
        // Only process if ring buffer has space for another chunk
        if (m_ringBuffer.canWrite(kRingBufferProcessFrames)) {
            // Process all channels through the existing processMultiChannel
            processMultiChannel(bufferPtrs, kRingBufferProcessFrames);

            // Write each channel to ring buffer
            for (int ch = 0; ch < kNumMixerChannelsForRing; ++ch) {
                m_ringBuffer.writeChannel(ch, bufferPtrs[ch * 2], bufferPtrs[ch * 2 + 1], kRingBufferProcessFrames);
            }
            m_ringBuffer.advanceWriteIndex(kRingBufferProcessFrames);
        }

        // Sleep to maintain timing
        // 256 samples @ 48kHz = 5.33ms, process slightly faster (~4.8ms) to maintain buffer lead
        std::this_thread::sleep_for(std::chrono::microseconds(4800));
    }
}

void AudioEngine::readChannelFromRingBuffer(int channelIndex, float* left, float* right, int numFrames) {
    m_ringBuffer.readChannel(channelIndex, left, right, numFrames);
}

size_t AudioEngine::getRingBufferReadableFrames(int channelIndex) const {
    return m_ringBuffer.getReadableFrames(channelIndex);
}

// ========== Recording Implementation ==========

void AudioEngine::startRecording(int reelIndex, int mode, int sourceType, int sourceChannel) {
    if (reelIndex < 0 || reelIndex >= 32) return;

    // Create reel buffer if needed
    if (!m_reelBuffers[reelIndex]) {
        m_reelBuffers[reelIndex] = std::make_unique<ReelBuffer>();
    }

    auto& reel = m_reelBuffers[reelIndex];
    RecordMode recMode = static_cast<RecordMode>(mode);

    // For LiveLoop, if buffer has no content yet, initialize to 2 minutes of silence
    if (recMode == RecordMode::LiveLoop && reel->GetLength() == 0) {
        reel->SetLength(ReelBuffer::kMaxRecordSamples);
        reel->SetLoopLength(ReelBuffer::kMaxRecordSamples);
    } else if (recMode == RecordMode::LiveLoop) {
        reel->SetLoopLength(reel->GetLength());
    }

    // Assign buffer to voice if this is a standard reel index
    if (reelIndex < kNumGranularVoices && m_granularVoices[reelIndex]) {
        m_granularVoices[reelIndex]->SetBuffer(reel.get());
    }
    if ((reelIndex == 1 || reelIndex == 2) && m_looperVoices[reelIndex - 1]) {
        m_looperVoices[reelIndex - 1]->SetBuffer(reel.get());
    }

    // Find a free recording slot or reuse one targeting the same reel
    int slot = -1;
    for (int i = 0; i < kMaxRecordingSessions; ++i) {
        if (!m_recordingStates[i].active.load(std::memory_order_relaxed)) {
            slot = i;
            break;
        }
        if (m_recordingStates[i].targetReel == reelIndex) {
            slot = i;
            break;
        }
    }
    if (slot < 0) return;  // No free slots

    m_recordingStates[slot].sourceType = sourceType;
    m_recordingStates[slot].sourceChannel = sourceChannel;
    m_recordingStates[slot].targetReel = reelIndex;

    reel->StartRecording(recMode);
    m_recordingStates[slot].active.store(true, std::memory_order_release);
}

void AudioEngine::stopRecording(int reelIndex) {
    if (reelIndex < 0 || reelIndex >= 32) return;

    for (int i = 0; i < kMaxRecordingSessions; ++i) {
        if (m_recordingStates[i].active.load(std::memory_order_relaxed) &&
            m_recordingStates[i].targetReel == reelIndex) {
            m_recordingStates[i].active.store(false, std::memory_order_release);
        }
    }

    if (m_reelBuffers[reelIndex]) {
        m_reelBuffers[reelIndex]->StopRecording();

        // Update default splice to cover recorded content
        auto& reel = m_reelBuffers[reelIndex];
        if (reel->GetNumSplices() > 0) {
            reel->GetSpliceMutable(0).end_sample = static_cast<uint32_t>(reel->GetLength());
        }
    }
}

void AudioEngine::setRecordingFeedback(int reelIndex, float feedback) {
    if (reelIndex < 0 || reelIndex >= 32) return;
    if (m_reelBuffers[reelIndex]) {
        m_reelBuffers[reelIndex]->SetFeedback(std::clamp(feedback, 0.0f, 1.0f));
    }
}

bool AudioEngine::isRecording(int reelIndex) const {
    if (reelIndex < 0 || reelIndex >= 32) return false;
    if (!m_reelBuffers[reelIndex]) return false;
    return m_reelBuffers[reelIndex]->IsRecording();
}

float AudioEngine::getRecordingPosition(int reelIndex) const {
    if (reelIndex < 0 || reelIndex >= 32) return 0.0f;
    if (!m_reelBuffers[reelIndex]) return 0.0f;
    return m_reelBuffers[reelIndex]->GetNormalizedRecordPosition();
}

void AudioEngine::writeExternalInput(const float* left, const float* right, int numFrames) {
    int count = std::min(numFrames, kMaxBufferSize);
    std::memcpy(m_externalInputL, left, count * sizeof(float));
    std::memcpy(m_externalInputR, right, count * sizeof(float));
    m_externalInputFrameCount.store(count, std::memory_order_release);
}

void AudioEngine::processRecordingForChannel(int channelIndex, const float* srcLeft, const float* srcRight, int numFrames) {
    for (int r = 0; r < kMaxRecordingSessions; ++r) {
        if (!m_recordingStates[r].active.load(std::memory_order_relaxed)) continue;
        if (m_recordingStates[r].sourceType != 1) continue;  // Only internal voice sources
        if (m_recordingStates[r].sourceChannel != channelIndex) continue;

        int targetReel = m_recordingStates[r].targetReel;
        if (targetReel < 0 || targetReel >= 32) continue;
        auto& reel = m_reelBuffers[targetReel];
        if (!reel || !reel->IsRecording()) continue;

        for (int i = 0; i < numFrames; ++i) {
            reel->RecordSampleWithFeedback(srcLeft[i], srcRight[i]);
        }
    }
}

void AudioEngine::processExternalInputRecording(int numFrames) {
    int inputFrames = m_externalInputFrameCount.load(std::memory_order_acquire);
    if (inputFrames == 0) return;

    int framesToProcess = std::min(inputFrames, numFrames);

    for (int r = 0; r < kMaxRecordingSessions; ++r) {
        if (!m_recordingStates[r].active.load(std::memory_order_relaxed)) continue;
        if (m_recordingStates[r].sourceType != 0) continue;  // Only external sources

        int targetReel = m_recordingStates[r].targetReel;
        if (targetReel < 0 || targetReel >= 32) continue;
        auto& reel = m_reelBuffers[targetReel];
        if (!reel || !reel->IsRecording()) continue;

        for (int i = 0; i < framesToProcess; ++i) {
            reel->RecordSampleWithFeedback(m_externalInputL[i], m_externalInputR[i]);
        }
    }
}

} // namespace Grainulator

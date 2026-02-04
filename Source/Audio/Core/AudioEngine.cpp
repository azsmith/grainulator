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
#include <cstring>
#include <cmath>
#include <algorithm>

namespace Grainulator {

AudioEngine::AudioEngine()
    : m_sampleRate(kSampleRate)
    , m_bufferSize(512)
    , m_initialized(false)
    , m_currentSampleTime(0)
    , m_cpuLoad(0.0f)
    , m_activeGrains(0)
    , m_voiceCounter(0)
    , m_currentEngine(0)
    , m_harmonics(0.5f)
    , m_timbre(0.5f)
    , m_morph(0.5f)
    , m_lpgColor(0.5f)
    , m_lpgDecay(0.5f)
    , m_lpgAttack(0.0f)
    , m_lpgBypass(false)
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
    , m_sendBufferL(nullptr)
    , m_sendBufferR(nullptr)
    , m_scheduledReadIndex(0)
    , m_scheduledWriteIndex(0)
{
    // Initialize processing buffers
    m_processingBuffer[0] = nullptr;
    m_processingBuffer[1] = nullptr;
    m_voiceBuffer[0] = nullptr;
    m_voiceBuffer[1] = nullptr;

    // Initialize effects buffers to nullptr
    for (size_t i = 0; i < kNumCombs; ++i) {
        m_combBuffersL[i] = nullptr;
        m_combBuffersR[i] = nullptr;
        m_combPos[i] = 0;
        m_combFilters[i] = 0.0f;
    }
    for (size_t i = 0; i < kNumAllpasses; ++i) {
        m_allpassBuffersL[i] = nullptr;
        m_allpassBuffersR[i] = nullptr;
        m_allpassPos[i] = 0;
    }

    // Initialize voice state
    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        m_voiceNote[i] = -1;  // -1 = free
        m_voiceAge[i] = 0;
    }

    // Initialize mixer state
    for (int i = 0; i < kNumMixerChannels; ++i) {
        m_channelGain[i] = 1.0f;  // Unity gain
        m_channelPan[i] = 0.0f;   // Center
        m_channelSend[i] = 0.0f;
        m_channelMute[i] = false;
        m_channelSolo[i] = false;
        m_channelLevels[i].store(0.0f);
    }
    m_masterGain = 1.0f;  // Default master at unity
    m_masterLevelL.store(0.0f);
    m_masterLevelR.store(0.0f);
}

AudioEngine::~AudioEngine() {
    shutdown();
}

bool AudioEngine::initialize(int sampleRate, int bufferSize) {
    if (m_initialized.load()) {
        return false;
    }

    m_sampleRate = sampleRate;
    m_bufferSize = bufferSize;
    m_currentSampleTime.store(0, std::memory_order_relaxed);
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
        m_voiceAge[i] = 0;
    }
    m_ringsVoice = std::make_unique<RingsVoice>();
    m_ringsVoice->Init(static_cast<float>(sampleRate));

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

    m_initialized.store(true);
    return true;
}

void AudioEngine::shutdown() {
    if (!m_initialized.load()) {
        return;
    }

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

    m_initialized.store(false);
}

int AudioEngine::allocateVoice(int note) {
    // First, check if this note is already playing - retrigger same voice
    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        if (m_voiceNote[i] == note) {
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
    noteOnTarget(note, velocity, static_cast<uint8_t>(NoteTarget::TargetBoth));
}

void AudioEngine::noteOff(int note) {
    noteOffTarget(note, static_cast<uint8_t>(NoteTarget::TargetBoth));
}

void AudioEngine::noteOnTarget(int note, int velocity, uint8_t targetMask) {
    if (!m_initialized.load()) return;

    if ((targetMask & static_cast<uint8_t>(NoteTarget::TargetPlaits)) != 0) {
        int voiceIndex = allocateVoice(note);
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
                m_voiceAge[voiceIndex] = ++m_voiceCounter;
            }
        }
    }

    if ((targetMask & static_cast<uint8_t>(NoteTarget::TargetRings)) != 0 && m_ringsVoice) {
        m_ringsVoice->NoteOn(note, velocity);
    }
}

void AudioEngine::noteOffTarget(int note, uint8_t targetMask) {
    if (!m_initialized.load()) return;

    if ((targetMask & static_cast<uint8_t>(NoteTarget::TargetRings)) != 0 && m_ringsVoice) {
        m_ringsVoice->NoteOff(note);
    }

    if ((targetMask & static_cast<uint8_t>(NoteTarget::TargetPlaits)) == 0) {
        return;
    }

    // Find the voice playing this note and release it
    for (int i = 0; i < kNumPlaitsVoices; ++i) {
        if (m_voiceNote[i] == note) {
            if (m_plaitsVoices[i]) {
                m_plaitsVoices[i]->Trigger(false);
            }
            // Mark voice as free (it will continue to decay naturally)
            m_voiceNote[i] = -1;
            break;
        }
    }
}

bool AudioEngine::enqueueScheduledEvent(const ScheduledNoteEvent& event) {
    const uint32_t write = m_scheduledWriteIndex.load(std::memory_order_relaxed);
    const uint32_t nextWrite = (write + 1) % kScheduledEventCapacity;
    const uint32_t read = m_scheduledReadIndex.load(std::memory_order_acquire);

    if (nextWrite == read) {
        // Queue full: drop newest event to avoid blocking the audio thread.
        return false;
    }

    m_scheduledEvents[write] = event;
    m_scheduledWriteIndex.store(nextWrite, std::memory_order_release);
    return true;
}

void AudioEngine::scheduleNoteOn(int note, int velocity, uint64_t sampleTime) {
    scheduleNoteOnTarget(note, velocity, sampleTime, static_cast<uint8_t>(NoteTarget::TargetBoth));
}

void AudioEngine::scheduleNoteOff(int note, uint64_t sampleTime) {
    scheduleNoteOffTarget(note, sampleTime, static_cast<uint8_t>(NoteTarget::TargetBoth));
}

void AudioEngine::scheduleNoteOnTarget(int note, int velocity, uint64_t sampleTime, uint8_t targetMask) {
    if (!m_initialized.load()) return;

    const int clampedNote = std::max(0, std::min(note, 127));
    const int clampedVelocity = std::max(1, std::min(velocity, 127));

    ScheduledNoteEvent event;
    event.sampleTime = sampleTime;
    event.note = static_cast<uint8_t>(clampedNote);
    event.velocity = static_cast<uint8_t>(clampedVelocity);
    event.isNoteOn = true;
    event.targetMask = targetMask == 0 ? static_cast<uint8_t>(NoteTarget::TargetBoth) : targetMask;
    enqueueScheduledEvent(event);
}

void AudioEngine::scheduleNoteOffTarget(int note, uint64_t sampleTime, uint8_t targetMask) {
    if (!m_initialized.load()) return;

    const int clampedNote = std::max(0, std::min(note, 127));

    ScheduledNoteEvent event;
    event.sampleTime = sampleTime;
    event.note = static_cast<uint8_t>(clampedNote);
    event.velocity = 0;
    event.isNoteOn = false;
    event.targetMask = targetMask == 0 ? static_cast<uint8_t>(NoteTarget::TargetBoth) : targetMask;
    enqueueScheduledEvent(event);
}

void AudioEngine::clearScheduledNotes() {
    m_scheduledReadIndex.store(0, std::memory_order_relaxed);
    m_scheduledWriteIndex.store(0, std::memory_order_relaxed);
}

uint64_t AudioEngine::getCurrentSampleTime() const {
    return m_currentSampleTime.load(std::memory_order_relaxed);
}

void AudioEngine::process(float** inputBuffers, float** outputBuffers, int numChannels, int numFrames) {
    if (!m_initialized.load() || numFrames > kMaxBufferSize) {
        // Not initialized or buffer too large - output silence
        for (int ch = 0; ch < numChannels; ++ch) {
            std::memset(outputBuffers[ch], 0, numFrames * sizeof(float));
        }
        return;
    }

    const uint64_t bufferStartSample = m_currentSampleTime.load(std::memory_order_relaxed);
    const uint64_t bufferEndSample = bufferStartSample + static_cast<uint64_t>(numFrames);

    // Pop all queued note events that fall within this buffer.
    std::array<ScheduledNoteEvent, kScheduledEventCapacity> dueEvents{};
    int dueEventCount = 0;
    while (dueEventCount < static_cast<int>(kScheduledEventCapacity)) {
        const uint32_t read = m_scheduledReadIndex.load(std::memory_order_relaxed);
        const uint32_t write = m_scheduledWriteIndex.load(std::memory_order_acquire);
        if (read == write) {
            break;
        }

        const ScheduledNoteEvent event = m_scheduledEvents[read];
        if (event.sampleTime >= bufferEndSample) {
            break;
        }

        m_scheduledReadIndex.store((read + 1) % kScheduledEventCapacity, std::memory_order_release);
        dueEvents[dueEventCount] = event;
        if (dueEvents[dueEventCount].sampleTime < bufferStartSample) {
            dueEvents[dueEventCount].sampleTime = bufferStartSample;
        }
        ++dueEventCount;
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

    auto renderChunk = [&](int frameOffset, int frameCount) {
        if (frameCount <= 0) return;

        // Clear main processing and send buffers for this chunk.
        std::memset(m_processingBuffer[0], 0, frameCount * sizeof(float));
        std::memset(m_processingBuffer[1], 0, frameCount * sizeof(float));
        std::memset(m_sendBufferL, 0, frameCount * sizeof(float));
        std::memset(m_sendBufferR, 0, frameCount * sizeof(float));

        // ========== Channel 0: Plaits ==========
        {
            int ch = 0;
            bool shouldPlay = !m_channelMute[ch] && (!anySoloed || m_channelSolo[ch]);

            std::memset(m_voiceBuffer[0], 0, frameCount * sizeof(float));
            std::memset(m_voiceBuffer[1], 0, frameCount * sizeof(float));

            for (int v = 0; v < kNumPlaitsVoices; ++v) {
                if (m_plaitsVoices[v]) {
                    float tempL[kMaxBufferSize], tempR[kMaxBufferSize];
                    std::memset(tempL, 0, frameCount * sizeof(float));
                    std::memset(tempR, 0, frameCount * sizeof(float));
                    m_plaitsVoices[v]->Render(tempL, tempR, frameCount);
                    for (int i = 0; i < frameCount; ++i) {
                        m_voiceBuffer[0][i] += tempL[i];
                        m_voiceBuffer[1][i] += tempR[i];
                    }
                }
            }

            float gain = m_channelGain[ch];
            float pan = m_channelPan[ch];
            float send = m_channelSend[ch];
            float panL = std::cos((pan + 1.0f) * 0.25f * 3.14159265f);
            float panR = std::sin((pan + 1.0f) * 0.25f * 3.14159265f);

            for (int i = 0; i < frameCount; ++i) {
                float mono = (m_voiceBuffer[0][i] + m_voiceBuffer[1][i]) * 0.5f * gain;
                float outL = mono * panL;
                float outR = mono * panR;

                channelPeaks[ch] = std::max(channelPeaks[ch], std::abs(mono));

                if (shouldPlay) {
                    m_processingBuffer[0][i] += outL;
                    m_processingBuffer[1][i] += outR;
                }

                m_sendBufferL[i] += outL * send;
                m_sendBufferR[i] += outR * send;
            }
        }

        // ========== Channel 1: Rings ==========
        {
            int ch = 1;
            bool shouldPlay = !m_channelMute[ch] && (!anySoloed || m_channelSolo[ch]);

            std::memset(m_voiceBuffer[0], 0, frameCount * sizeof(float));
            std::memset(m_voiceBuffer[1], 0, frameCount * sizeof(float));
            if (m_ringsVoice) {
                m_ringsVoice->Render(m_voiceBuffer[0], m_voiceBuffer[1], frameCount);
            }

            float gain = m_channelGain[ch];
            float pan = m_channelPan[ch];
            float send = m_channelSend[ch];
            float panL = std::cos((pan + 1.0f) * 0.25f * 3.14159265f);
            float panR = std::sin((pan + 1.0f) * 0.25f * 3.14159265f);

            for (int i = 0; i < frameCount; ++i) {
                float sampleL = m_voiceBuffer[0][i] * gain;
                float sampleR = m_voiceBuffer[1][i] * gain;
                float outL = sampleL * panL;
                float outR = sampleR * panR;

                channelPeaks[ch] = std::max(channelPeaks[ch], std::max(std::abs(sampleL), std::abs(sampleR)));

                if (shouldPlay) {
                    m_processingBuffer[0][i] += outL;
                    m_processingBuffer[1][i] += outR;
                }

                m_sendBufferL[i] += outL * send;
                m_sendBufferR[i] += outR * send;
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

            float gain = m_channelGain[ch];
            float pan = m_channelPan[ch];
            float send = m_channelSend[ch];
            float panL = std::cos((pan + 1.0f) * 0.25f * 3.14159265f);
            float panR = std::sin((pan + 1.0f) * 0.25f * 3.14159265f);

            for (int i = 0; i < frameCount; ++i) {
                float sampleL = m_voiceBuffer[0][i] * gain;
                float sampleR = m_voiceBuffer[1][i] * gain;
                float outL = sampleL * panL;
                float outR = sampleR * panR;

                channelPeaks[ch] = std::max(channelPeaks[ch], std::max(std::abs(sampleL), std::abs(sampleR)));

                if (shouldPlay) {
                    m_processingBuffer[0][i] += outL;
                    m_processingBuffer[1][i] += outR;
                }

                m_sendBufferL[i] += outL * send;
                m_sendBufferR[i] += outR * send;
            }
        }

        // ========== Process Effects on Send Buffer ==========
        for (int i = 0; i < frameCount; ++i) {
            float wetL = m_sendBufferL[i];
            float wetR = m_sendBufferR[i];

            if (m_delayMix > 0.001f) {
                processDelay(wetL, wetR);
            }

            if (m_reverbMix > 0.001f) {
                processReverb(wetL, wetR);
            }

            m_processingBuffer[0][i] += wetL;
            m_processingBuffer[1][i] += wetR;
        }

        // ========== Final Processing + output ==========
        for (int i = 0; i < frameCount; ++i) {
            m_processingBuffer[0][i] *= m_masterGain;
            m_processingBuffer[1][i] *= m_masterGain;
            m_processingBuffer[0][i] = std::tanh(m_processingBuffer[0][i]);
            m_processingBuffer[1][i] = std::tanh(m_processingBuffer[1][i]);

            masterPeakL = std::max(masterPeakL, std::abs(m_processingBuffer[0][i]));
            masterPeakR = std::max(masterPeakR, std::abs(m_processingBuffer[1][i]));
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
                noteOnTarget(static_cast<int>(event.note), static_cast<int>(event.velocity), event.targetMask);
            } else {
                noteOffTarget(static_cast<int>(event.note), event.targetMask);
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
            m_channelLevels[i].store(current * 0.95f + target * 0.05f);
        }
    }

    float currentL = m_masterLevelL.load();
    float currentR = m_masterLevelR.load();
    m_masterLevelL.store(masterPeakL > currentL ? masterPeakL : currentL * 0.95f + masterPeakL * 0.05f);
    m_masterLevelR.store(masterPeakR > currentR ? masterPeakR : currentR * 0.95f + masterPeakR * 0.05f);

    m_activeGrains.store(totalActiveGrains);
    m_currentSampleTime.store(bufferEndSample, std::memory_order_relaxed);
}

void AudioEngine::setParameter(ParameterID id, int voiceIndex, float value) {
    float clampedValue = std::max(0.0f, std::min(1.0f, value));

    // Clamp voice index for granular voices
    int granularVoice = std::max(0, std::min(voiceIndex, kNumGranularVoices - 1));
    int looperVoice = (voiceIndex == 1 || voiceIndex == 2) ? (voiceIndex - 1) : -1;

    switch (id) {
        // ========== Granular Parameters (Mangl-style) ==========
        case ParameterID::GranularSpeed:
            // Convert 0-1 to -2 to +2 (with 0.5 = 0, which is frozen)
            // Displayed as percentage: 100% = normal speed, -100% = reverse
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
            // Convert 0-1 to 0.001-0.5 seconds (logarithmic, 1ms to 500ms)
            if (m_granularVoices[granularVoice]) {
                float size = 0.001f * std::pow(500.0f, clampedValue);
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
                m_ringsVoice->SetModel(model);
            }
            break;

        case ParameterID::RingsStructure:
            if (m_ringsVoice) {
                m_ringsVoice->SetStructure(clampedValue);
            }
            break;

        case ParameterID::RingsBrightness:
            if (m_ringsVoice) {
                m_ringsVoice->SetBrightness(clampedValue);
            }
            break;

        case ParameterID::RingsDamping:
            if (m_ringsVoice) {
                m_ringsVoice->SetDamping(clampedValue);
            }
            break;

        case ParameterID::RingsPosition:
            if (m_ringsVoice) {
                m_ringsVoice->SetPosition(clampedValue);
            }
            break;

        case ParameterID::RingsLevel:
            if (m_ringsVoice) {
                m_ringsVoice->SetLevel(clampedValue);
            }
            break;

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
            m_currentEngine = static_cast<int>(value * 15.0f + 0.5f);
            // Apply to all voices
            for (int i = 0; i < kNumPlaitsVoices; ++i) {
                if (m_plaitsVoices[i]) {
                    m_plaitsVoices[i]->SetEngine(m_currentEngine);
                }
            }
            break;

        case ParameterID::PlaitsHarmonics:
            m_harmonics = clampedValue;
            for (int i = 0; i < kNumPlaitsVoices; ++i) {
                if (m_plaitsVoices[i]) {
                    m_plaitsVoices[i]->SetHarmonics(clampedValue);
                }
            }
            break;

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
            // Legacy: Set note on voice 0 only
            if (m_plaitsVoices[0]) {
                m_plaitsVoices[0]->SetNote(24.0f + clampedValue * 72.0f);
            }
            break;

        case ParameterID::PlaitsLevel:
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
                m_channelSend[voiceIndex] = clampedValue;
            }
            break;

        case ParameterID::MasterGain:
            // Allow master gain up to 2.0 (0-1 maps to 0-2 for +6dB headroom)
            m_masterGain = clampedValue * 2.0f;
            break;

        default:
            break;
    }
}

float AudioEngine::getParameter(ParameterID id, int voiceIndex) const {
    (void)id;
    (void)voiceIndex;
    return 0.0f;
}

void AudioEngine::triggerPlaits(bool state) {
    // Legacy: trigger voice 0
    if (m_plaitsVoices[0]) {
        m_plaitsVoices[0]->Trigger(state);
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
    m_sendBufferL = new float[kMaxBufferSize];
    m_sendBufferR = new float[kMaxBufferSize];
    std::memset(m_sendBufferL, 0, kMaxBufferSize * sizeof(float));
    std::memset(m_sendBufferR, 0, kMaxBufferSize * sizeof(float));

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
    if (m_sendBufferL) {
        delete[] m_sendBufferL;
        m_sendBufferL = nullptr;
    }
    if (m_sendBufferR) {
        delete[] m_sendBufferR;
        m_sendBufferR = nullptr;
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

        // Right channel comb (slightly offset for stereo)
        size_t rightPos = (m_combPos[i] + 23) % m_combLengths[i];
        float combOutR = m_combBuffersR[i][rightPos];
        m_combBuffersR[i][rightPos] = inputR + combOutR * feedback;
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

} // namespace Grainulator

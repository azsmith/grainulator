//
//  AudioEngineBridge.cpp
//  Grainulator
//
//  C interface implementation for Swift to call C++ AudioEngine
//

#include "AudioEngineBridge.h"
#include "AudioEngine.h"

using namespace Grainulator;

extern "C" {

AudioEngineHandle AudioEngine_Create() {
    return new AudioEngine();
}

void AudioEngine_Destroy(AudioEngineHandle handle) {
    if (handle) {
        delete static_cast<AudioEngine*>(handle);
    }
}

bool AudioEngine_Initialize(AudioEngineHandle handle, int sampleRate, int bufferSize) {
    if (!handle) return false;
    return static_cast<AudioEngine*>(handle)->initialize(sampleRate, bufferSize);
}

void AudioEngine_Shutdown(AudioEngineHandle handle) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->shutdown();
    }
}

void AudioEngine_Process(AudioEngineHandle handle, float** outputBuffers, int numChannels, int numFrames) {
    if (handle) {
        // Pass nullptr for input buffers since we're generating sound
        static_cast<AudioEngine*>(handle)->process(nullptr, outputBuffers, numChannels, numFrames);
    }
}

void AudioEngine_ProcessMultiChannel(AudioEngineHandle handle, float** channelBuffers, int numFrames) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->processMultiChannel(channelBuffers, numFrames);
    }
}

void AudioEngine_SetParameter(AudioEngineHandle handle, int parameterId, int voiceIndex, float value) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setParameter(
            static_cast<AudioEngine::ParameterID>(parameterId),
            voiceIndex,
            value
        );
    }
}

float AudioEngine_GetParameter(AudioEngineHandle handle, int parameterId, int voiceIndex) {
    if (!handle) return 0.0f;
    return static_cast<AudioEngine*>(handle)->getParameter(
        static_cast<AudioEngine::ParameterID>(parameterId),
        voiceIndex
    );
}

void AudioEngine_SetChannelSendLevel(AudioEngineHandle handle, int channelIndex, int sendIndex, float level) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setChannelSendLevel(channelIndex, sendIndex, level);
    }
}

float AudioEngine_GetCPULoad(AudioEngineHandle handle) {
    if (!handle) return 0.0f;
    return static_cast<AudioEngine*>(handle)->getCPULoad();
}

void AudioEngine_TriggerPlaits(AudioEngineHandle handle, bool state) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->triggerPlaits(state);
    }
}

void AudioEngine_TriggerDaisyDrum(AudioEngineHandle handle, bool state) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->triggerDaisyDrum(state);
    }
}

void AudioEngine_SetDaisyDrumEngine(AudioEngineHandle handle, int engine) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setParameter(
            AudioEngine::ParameterID::DaisyDrumEngine,
            0,
            static_cast<float>(engine) / 4.0f
        );
    }
}

void AudioEngine_NoteOn(AudioEngineHandle handle, int note, int velocity) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->noteOn(note, velocity);
    }
}

void AudioEngine_NoteOff(AudioEngineHandle handle, int note) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->noteOff(note);
    }
}

void AudioEngine_ScheduleNoteOn(AudioEngineHandle handle, int note, int velocity, uint64_t sampleTime) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->scheduleNoteOn(note, velocity, sampleTime);
    }
}

void AudioEngine_ScheduleNoteOff(AudioEngineHandle handle, int note, uint64_t sampleTime) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->scheduleNoteOff(note, sampleTime);
    }
}

void AudioEngine_ScheduleNoteOnTarget(AudioEngineHandle handle, int note, int velocity, uint64_t sampleTime, uint8_t targetMask) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->scheduleNoteOnTarget(note, velocity, sampleTime, targetMask);
    }
}

void AudioEngine_ScheduleNoteOffTarget(AudioEngineHandle handle, int note, uint64_t sampleTime, uint8_t targetMask) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->scheduleNoteOffTarget(note, sampleTime, targetMask);
    }
}

void AudioEngine_ClearScheduledNotes(AudioEngineHandle handle) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->clearScheduledNotes();
    }
}

uint64_t AudioEngine_GetCurrentSampleTime(AudioEngineHandle handle) {
    if (!handle) return 0;
    return static_cast<AudioEngine*>(handle)->getCurrentSampleTime();
}

// ========== Granular Buffer Management ==========

bool AudioEngine_LoadAudioData(AudioEngineHandle handle, int reelIndex, const float* leftChannel, const float* rightChannel, size_t numSamples, float sampleRate) {
    if (!handle) return false;
    return static_cast<AudioEngine*>(handle)->loadAudioData(reelIndex, leftChannel, rightChannel, numSamples, sampleRate);
}

void AudioEngine_ClearReel(AudioEngineHandle handle, int reelIndex) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->clearReel(reelIndex);
    }
}

size_t AudioEngine_GetReelLength(AudioEngineHandle handle, int reelIndex) {
    if (!handle) return 0;
    return static_cast<AudioEngine*>(handle)->getReelLength(reelIndex);
}

void AudioEngine_GetWaveformOverview(AudioEngineHandle handle, int reelIndex, float* output, size_t outputSize) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->getWaveformOverview(reelIndex, output, outputSize);
    }
}

void AudioEngine_SetGranularPlaying(AudioEngineHandle handle, int voiceIndex, bool playing) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setGranularPlaying(voiceIndex, playing);
    }
}

void AudioEngine_SetGranularPosition(AudioEngineHandle handle, int voiceIndex, float position) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setGranularPosition(voiceIndex, position);
    }
}

int AudioEngine_GetActiveGrainCount(AudioEngineHandle handle) {
    if (!handle) return 0;
    return static_cast<AudioEngine*>(handle)->getActiveGrainCount();
}

float AudioEngine_GetGranularPosition(AudioEngineHandle handle, int voiceIndex) {
    if (!handle) return 0.0f;
    return static_cast<AudioEngine*>(handle)->getGranularPosition(voiceIndex);
}

// ========== Level Metering ==========

float AudioEngine_GetChannelLevel(AudioEngineHandle handle, int channelIndex) {
    if (!handle) return 0.0f;
    return static_cast<AudioEngine*>(handle)->getChannelLevel(channelIndex);
}

float AudioEngine_GetMasterLevel(AudioEngineHandle handle, int channel) {
    if (!handle) return 0.0f;
    return static_cast<AudioEngine*>(handle)->getMasterLevel(channel);
}

// ========== Master Clock ==========

void AudioEngine_SetClockBPM(AudioEngineHandle handle, float bpm) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockBPM(bpm);
    }
}

void AudioEngine_SetClockRunning(AudioEngineHandle handle, bool running) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockRunning(running);
    }
}

void AudioEngine_SetClockStartSample(AudioEngineHandle handle, uint64_t startSample) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockStartSample(startSample);
    }
}

void AudioEngine_SetClockSwing(AudioEngineHandle handle, float swing) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockSwing(swing);
    }
}

float AudioEngine_GetClockBPM(AudioEngineHandle handle) {
    if (!handle) return 120.0f;
    return static_cast<AudioEngine*>(handle)->getClockBPM();
}

bool AudioEngine_IsClockRunning(AudioEngineHandle handle) {
    if (!handle) return false;
    return static_cast<AudioEngine*>(handle)->isClockRunning();
}

void AudioEngine_SetClockOutputMode(AudioEngineHandle handle, int outputIndex, int mode) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockOutputMode(outputIndex, mode);
    }
}

void AudioEngine_SetClockOutputWaveform(AudioEngineHandle handle, int outputIndex, int waveform) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockOutputWaveform(outputIndex, waveform);
    }
}

void AudioEngine_SetClockOutputDivision(AudioEngineHandle handle, int outputIndex, int division) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockOutputDivision(outputIndex, division);
    }
}

void AudioEngine_SetClockOutputLevel(AudioEngineHandle handle, int outputIndex, float level) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockOutputLevel(outputIndex, level);
    }
}

void AudioEngine_SetClockOutputOffset(AudioEngineHandle handle, int outputIndex, float offset) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockOutputOffset(outputIndex, offset);
    }
}

void AudioEngine_SetClockOutputPhase(AudioEngineHandle handle, int outputIndex, float phase) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockOutputPhase(outputIndex, phase);
    }
}

void AudioEngine_SetClockOutputWidth(AudioEngineHandle handle, int outputIndex, float width) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockOutputWidth(outputIndex, width);
    }
}

void AudioEngine_SetClockOutputDestination(AudioEngineHandle handle, int outputIndex, int dest) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockOutputDestination(outputIndex, dest);
    }
}

void AudioEngine_SetClockOutputModAmount(AudioEngineHandle handle, int outputIndex, float amount) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockOutputModAmount(outputIndex, amount);
    }
}

void AudioEngine_SetClockOutputMuted(AudioEngineHandle handle, int outputIndex, bool muted) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockOutputMuted(outputIndex, muted);
    }
}

void AudioEngine_SetClockOutputSlowMode(AudioEngineHandle handle, int outputIndex, bool slow) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setClockOutputSlowMode(outputIndex, slow);
    }
}

float AudioEngine_GetClockOutputValue(AudioEngineHandle handle, int outputIndex) {
    if (!handle) return 0.0f;
    return static_cast<AudioEngine*>(handle)->getClockOutputValue(outputIndex);
}

float AudioEngine_GetModulationValue(AudioEngineHandle handle, int destination) {
    if (!handle) return 0.0f;
    return static_cast<AudioEngine*>(handle)->getModulationValue(destination);
}

// MARK: - Multi-channel Ring Buffer Processing

void AudioEngine_StartMultiChannelProcessing(AudioEngineHandle handle) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->startMultiChannelProcessing();
    }
}

void AudioEngine_StopMultiChannelProcessing(AudioEngineHandle handle) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->stopMultiChannelProcessing();
    }
}

void AudioEngine_ReadChannelFromRingBuffer(AudioEngineHandle handle, int channelIndex, float* left, float* right, int numFrames) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->readChannelFromRingBuffer(channelIndex, left, right, numFrames);
    }
}

size_t AudioEngine_GetRingBufferReadableFrames(AudioEngineHandle handle, int channelIndex) {
    if (!handle) return 0;
    return static_cast<AudioEngine*>(handle)->getRingBufferReadableFrames(channelIndex);
}

void AudioEngine_RenderAndReadMultiChannel(
    AudioEngineHandle handle,
    int channelIndex,
    int64_t sampleTime,
    float* left,
    float* right,
    int numFrames
) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->renderAndReadMultiChannel(channelIndex, sampleTime, left, right, numFrames);
    }
}

void AudioEngine_RenderAndReadLegacyBus(
    AudioEngineHandle handle,
    int busIndex,
    int64_t sampleTime,
    float* left,
    float* right,
    int numFrames
) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->renderAndReadLegacyBus(busIndex, sampleTime, left, right, numFrames);
    }
}

// ========== Recording Control ==========

void AudioEngine_StartRecording(AudioEngineHandle handle, int reelIndex, int mode, int sourceType, int sourceChannel) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->startRecording(reelIndex, mode, sourceType, sourceChannel);
    }
}

void AudioEngine_StopRecording(AudioEngineHandle handle, int reelIndex) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->stopRecording(reelIndex);
    }
}

void AudioEngine_SetRecordingFeedback(AudioEngineHandle handle, int reelIndex, float feedback) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setRecordingFeedback(reelIndex, feedback);
    }
}

bool AudioEngine_IsRecording(AudioEngineHandle handle, int reelIndex) {
    if (!handle) return false;
    return static_cast<AudioEngine*>(handle)->isRecording(reelIndex);
}

float AudioEngine_GetRecordingPosition(AudioEngineHandle handle, int reelIndex) {
    if (!handle) return 0.0f;
    return static_cast<AudioEngine*>(handle)->getRecordingPosition(reelIndex);
}

void AudioEngine_WriteExternalInput(AudioEngineHandle handle, const float* left, const float* right, int numFrames) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->writeExternalInput(left, right, numFrames);
    }
}

// ========== Drum Sequencer Lane Control ==========

void AudioEngine_TriggerDrumSeqLane(AudioEngineHandle handle, int lane, bool state) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->triggerDrumSeqLane(lane, state);
    }
}

void AudioEngine_SetDrumSeqLaneLevel(AudioEngineHandle handle, int lane, float level) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setDrumSeqLaneLevel(lane, level);
    }
}

void AudioEngine_SetDrumSeqLaneHarmonics(AudioEngineHandle handle, int lane, float value) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setDrumSeqLaneHarmonics(lane, value);
    }
}

void AudioEngine_SetDrumSeqLaneTimbre(AudioEngineHandle handle, int lane, float value) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setDrumSeqLaneTimbre(lane, value);
    }
}

void AudioEngine_SetDrumSeqLaneMorph(AudioEngineHandle handle, int lane, float value) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->setDrumSeqLaneMorph(lane, value);
    }
}

// SoundFont sampler control
bool AudioEngine_LoadSoundFont(AudioEngineHandle handle, const char* filePath) {
    if (!handle) return false;
    return static_cast<AudioEngine*>(handle)->loadSoundFont(filePath);
}

void AudioEngine_UnloadSoundFont(AudioEngineHandle handle) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->unloadSoundFont();
    }
}

int AudioEngine_GetSoundFontPresetCount(AudioEngineHandle handle) {
    if (!handle) return 0;
    return static_cast<AudioEngine*>(handle)->getSoundFontPresetCount();
}

const char* AudioEngine_GetSoundFontPresetName(AudioEngineHandle handle, int index) {
    if (!handle) return "";
    return static_cast<AudioEngine*>(handle)->getSoundFontPresetName(index);
}

bool AudioEngine_LoadWavSampler(AudioEngineHandle handle, const char* dirPath) {
    if (!handle) return false;
    return static_cast<AudioEngine*>(handle)->loadWavSampler(dirPath);
}

void AudioEngine_UnloadWavSampler(AudioEngineHandle handle) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->unloadWavSampler();
    }
}

const char* AudioEngine_GetWavSamplerInstrumentName(AudioEngineHandle handle) {
    if (!handle) return "";
    return static_cast<AudioEngine*>(handle)->getWavSamplerInstrumentName();
}

void AudioEngine_SetSamplerMode(AudioEngineHandle handle, int mode) {
    if (handle) {
        auto m = (mode == 1) ? AudioEngine::SamplerMode::WavSampler : AudioEngine::SamplerMode::SoundFont;
        static_cast<AudioEngine*>(handle)->setSamplerMode(m);
    }
}

} // extern "C"

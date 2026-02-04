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

float AudioEngine_GetCPULoad(AudioEngineHandle handle) {
    if (!handle) return 0.0f;
    return static_cast<AudioEngine*>(handle)->getCPULoad();
}

void AudioEngine_TriggerPlaits(AudioEngineHandle handle, bool state) {
    if (handle) {
        static_cast<AudioEngine*>(handle)->triggerPlaits(state);
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

} // extern "C"

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

} // extern "C"

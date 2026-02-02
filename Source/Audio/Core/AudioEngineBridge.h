//
//  AudioEngineBridge.h
//  Grainulator
//
//  C interface for Swift to call C++ AudioEngine
//

#ifndef AUDIOENGINEBRIDGE_H
#define AUDIOENGINEBRIDGE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque pointer to C++ AudioEngine
typedef void* AudioEngineHandle;

// Lifecycle
AudioEngineHandle AudioEngine_Create(void);
void AudioEngine_Destroy(AudioEngineHandle handle);
bool AudioEngine_Initialize(AudioEngineHandle handle, int sampleRate, int bufferSize);
void AudioEngine_Shutdown(AudioEngineHandle handle);

// Audio processing
void AudioEngine_Process(AudioEngineHandle handle, float** outputBuffers, int numChannels, int numFrames);

// Parameter control
void AudioEngine_SetParameter(AudioEngineHandle handle, int parameterId, int voiceIndex, float value);
float AudioEngine_GetParameter(AudioEngineHandle handle, int parameterId, int voiceIndex);

// Performance metrics
float AudioEngine_GetCPULoad(AudioEngineHandle handle);

// Trigger control
void AudioEngine_TriggerPlaits(AudioEngineHandle handle, bool state);

#ifdef __cplusplus
}
#endif

#endif // AUDIOENGINEBRIDGE_H

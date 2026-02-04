//
//  AudioEngineBridge.h
//  Grainulator
//
//  C interface for Swift to call C++ AudioEngine
//

#ifndef AUDIOENGINEBRIDGE_H
#define AUDIOENGINEBRIDGE_H

#include <stddef.h>
#include <stdint.h>

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

// Polyphonic note control
void AudioEngine_NoteOn(AudioEngineHandle handle, int note, int velocity);
void AudioEngine_NoteOff(AudioEngineHandle handle, int note);
void AudioEngine_ScheduleNoteOn(AudioEngineHandle handle, int note, int velocity, uint64_t sampleTime);
void AudioEngine_ScheduleNoteOff(AudioEngineHandle handle, int note, uint64_t sampleTime);
void AudioEngine_ScheduleNoteOnTarget(AudioEngineHandle handle, int note, int velocity, uint64_t sampleTime, uint8_t targetMask);
void AudioEngine_ScheduleNoteOffTarget(AudioEngineHandle handle, int note, uint64_t sampleTime, uint8_t targetMask);
void AudioEngine_ClearScheduledNotes(AudioEngineHandle handle);
uint64_t AudioEngine_GetCurrentSampleTime(AudioEngineHandle handle);

// Granular buffer management
bool AudioEngine_LoadAudioData(AudioEngineHandle handle, int reelIndex, const float* leftChannel, const float* rightChannel, size_t numSamples, float sampleRate);
void AudioEngine_ClearReel(AudioEngineHandle handle, int reelIndex);
size_t AudioEngine_GetReelLength(AudioEngineHandle handle, int reelIndex);
void AudioEngine_GetWaveformOverview(AudioEngineHandle handle, int reelIndex, float* output, size_t outputSize);
void AudioEngine_SetGranularPlaying(AudioEngineHandle handle, int voiceIndex, bool playing);
int AudioEngine_GetActiveGrainCount(AudioEngineHandle handle);

// Granular voice position (for playhead display, returns 0-1)
float AudioEngine_GetGranularPosition(AudioEngineHandle handle, int voiceIndex);

// Master clock control
void AudioEngine_SetClockBPM(AudioEngineHandle handle, float bpm);
void AudioEngine_SetClockRunning(AudioEngineHandle handle, bool running);
void AudioEngine_SetClockStartSample(AudioEngineHandle handle, uint64_t startSample);
void AudioEngine_SetClockSwing(AudioEngineHandle handle, float swing);
float AudioEngine_GetClockBPM(AudioEngineHandle handle);
bool AudioEngine_IsClockRunning(AudioEngineHandle handle);

// Clock output configuration (8 outputs)
void AudioEngine_SetClockOutputMode(AudioEngineHandle handle, int outputIndex, int mode);
void AudioEngine_SetClockOutputWaveform(AudioEngineHandle handle, int outputIndex, int waveform);
void AudioEngine_SetClockOutputDivision(AudioEngineHandle handle, int outputIndex, int division);
void AudioEngine_SetClockOutputLevel(AudioEngineHandle handle, int outputIndex, float level);
void AudioEngine_SetClockOutputOffset(AudioEngineHandle handle, int outputIndex, float offset);
void AudioEngine_SetClockOutputPhase(AudioEngineHandle handle, int outputIndex, float phase);
void AudioEngine_SetClockOutputWidth(AudioEngineHandle handle, int outputIndex, float width);
void AudioEngine_SetClockOutputDestination(AudioEngineHandle handle, int outputIndex, int dest);
void AudioEngine_SetClockOutputModAmount(AudioEngineHandle handle, int outputIndex, float amount);
void AudioEngine_SetClockOutputMuted(AudioEngineHandle handle, int outputIndex, bool muted);
void AudioEngine_SetClockOutputSlowMode(AudioEngineHandle handle, int outputIndex, bool slow);
float AudioEngine_GetClockOutputValue(AudioEngineHandle handle, int outputIndex);
float AudioEngine_GetModulationValue(AudioEngineHandle handle, int destination);

#ifdef __cplusplus
}
#endif

#endif // AUDIOENGINEBRIDGE_H

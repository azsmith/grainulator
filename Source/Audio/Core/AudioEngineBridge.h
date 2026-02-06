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
void AudioEngine_SetChannelSendLevel(AudioEngineHandle handle, int channelIndex, int sendIndex, float level);

// Performance metrics
float AudioEngine_GetCPULoad(AudioEngineHandle handle);

// Trigger control
void AudioEngine_TriggerPlaits(AudioEngineHandle handle, bool state);
void AudioEngine_TriggerDaisyDrum(AudioEngineHandle handle, bool state);
void AudioEngine_SetDaisyDrumEngine(AudioEngineHandle handle, int engine);

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
void AudioEngine_SetGranularPosition(AudioEngineHandle handle, int voiceIndex, float position);
int AudioEngine_GetActiveGrainCount(AudioEngineHandle handle);
float AudioEngine_GetGranularPosition(AudioEngineHandle handle, int voiceIndex);

// Level metering
float AudioEngine_GetChannelLevel(AudioEngineHandle handle, int channelIndex);
float AudioEngine_GetMasterLevel(AudioEngineHandle handle, int channel);
void AudioEngine_RenderAndReadLegacyBus(AudioEngineHandle handle, int busIndex, int64_t sampleTime, float* left, float* right, int numFrames);

// Recording control
void AudioEngine_StartRecording(AudioEngineHandle handle, int reelIndex, int mode, int sourceType, int sourceChannel);
void AudioEngine_StopRecording(AudioEngineHandle handle, int reelIndex);
void AudioEngine_SetRecordingFeedback(AudioEngineHandle handle, int reelIndex, float feedback);
bool AudioEngine_IsRecording(AudioEngineHandle handle, int reelIndex);
float AudioEngine_GetRecordingPosition(AudioEngineHandle handle, int reelIndex);
void AudioEngine_WriteExternalInput(AudioEngineHandle handle, const float* left, const float* right, int numFrames);

// Drum sequencer lane control
void AudioEngine_TriggerDrumSeqLane(AudioEngineHandle handle, int lane, bool state);
void AudioEngine_SetDrumSeqLaneLevel(AudioEngineHandle handle, int lane, float level);
void AudioEngine_SetDrumSeqLaneHarmonics(AudioEngineHandle handle, int lane, float value);
void AudioEngine_SetDrumSeqLaneTimbre(AudioEngineHandle handle, int lane, float value);
void AudioEngine_SetDrumSeqLaneMorph(AudioEngineHandle handle, int lane, float value);

#ifdef __cplusplus
}
#endif

#endif // AUDIOENGINEBRIDGE_H

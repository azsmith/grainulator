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

// Multi-channel audio processing for AU plugin hosting
// Outputs 6 separate stereo channels (12 buffers total) without mixing or effects
// Buffer layout: [ch0_L, ch0_R, ch1_L, ch1_R, ch2_L, ch2_R, ch3_L, ch3_R, ch4_L, ch4_R, ch5_L, ch5_R]
// Channel mapping: 0=Plaits, 1=Rings, 2=Granular1, 3=Looper1, 4=Looper2, 5=Granular2, 6=DaisyDrum, 7=Sampler
void AudioEngine_ProcessMultiChannel(AudioEngineHandle handle, float** channelBuffers, int numFrames);

// Parameter control
void AudioEngine_SetParameter(AudioEngineHandle handle, int parameterId, int voiceIndex, float value);
float AudioEngine_GetParameter(AudioEngineHandle handle, int parameterId, int voiceIndex);
void AudioEngine_SetChannelSendLevel(AudioEngineHandle handle, int channelIndex, int sendIndex, float level);

// Per-channel insert processing (for VST3/AU plugin hosting in C++)
typedef void (*AudioEngine_InsertProcessCallback)(void* pluginHandle, float* left, float* right, int numFrames);
void AudioEngine_SetInsertProcessCallback(AudioEngineHandle handle, AudioEngine_InsertProcessCallback callback);
void AudioEngine_SetChannelInsert(AudioEngineHandle handle, int channelIndex, int slotIndex, void* pluginHandle);
void AudioEngine_ClearChannelInsert(AudioEngineHandle handle, int channelIndex, int slotIndex);
void AudioEngine_SetChannelInsertBypassed(AudioEngineHandle handle, int channelIndex, int slotIndex, bool bypassed);

// Send bus plugin processing (for VST3 send effects)
void AudioEngine_SetSendPlugin(AudioEngineHandle handle, int sendIndex, void* pluginHandle);
void AudioEngine_ClearSendPlugin(AudioEngineHandle handle, int sendIndex);
void AudioEngine_SetSendPluginBypassed(AudioEngineHandle handle, int sendIndex, bool bypassed);
void AudioEngine_SetSendReturnLevel(AudioEngineHandle handle, int sendIndex, float level);

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
void AudioEngine_ScheduleNoteOnTargetTagged(AudioEngineHandle handle, int note, int velocity, uint64_t sampleTime, uint8_t targetMask, uint8_t trackId);
void AudioEngine_ScheduleNoteOffTargetTagged(AudioEngineHandle handle, int note, uint64_t sampleTime, uint8_t targetMask, uint8_t trackId);
void AudioEngine_ClearScheduledNotes(AudioEngineHandle handle);
uint64_t AudioEngine_GetCurrentSampleTime(AudioEngineHandle handle);

// Granular buffer management
bool AudioEngine_LoadAudioData(AudioEngineHandle handle, int reelIndex, const float* leftChannel, const float* rightChannel, size_t numSamples, float sampleRate);
void AudioEngine_ClearReel(AudioEngineHandle handle, int reelIndex);
size_t AudioEngine_GetReelLength(AudioEngineHandle handle, int reelIndex);
float AudioEngine_GetReelSampleRate(AudioEngineHandle handle, int reelIndex);
size_t AudioEngine_CopyReelData(AudioEngineHandle handle, int reelIndex, float* leftOut, float* rightOut, size_t maxSamples);
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
void AudioEngine_ResetClockOutput(AudioEngineHandle handle, int outputIndex);
float AudioEngine_GetClockOutputValue(AudioEngineHandle handle, int outputIndex);
float AudioEngine_GetModulationValue(AudioEngineHandle handle, int destination);

// Euclidean rhythm control
void AudioEngine_SetClockOutputEuclidean(AudioEngineHandle handle, int outputIndex, bool enabled, int steps, const bool* pattern, int patternLength);
int AudioEngine_GetClockOutputEuclideanStep(AudioEngineHandle handle, int outputIndex);

// Clock start sample (for bar:beat calculation)
uint64_t AudioEngine_GetClockStartSample(AudioEngineHandle handle);

// Clock output quantize (0=off, 1=1/16, 2=1/8, 3=1/4, 4=bar)
void AudioEngine_SetClockOutputQuantize(AudioEngineHandle handle, int outputIndex, int mode);

// Time signature
void AudioEngine_SetTimeSignature(AudioEngineHandle handle, int numerator, int denominator);
int AudioEngine_GetTimeSignatureNumerator(AudioEngineHandle handle);
int AudioEngine_GetTimeSignatureDenominator(AudioEngineHandle handle);
float AudioEngine_GetQuarterNotesPerBar(AudioEngineHandle handle);

// Multi-channel ring buffer processing (for AU plugin hosting)
// These functions enable a producer/consumer pattern where a background thread
// fills ring buffers and audio callbacks only read from them (no race condition)
void AudioEngine_StartMultiChannelProcessing(AudioEngineHandle handle);
void AudioEngine_StopMultiChannelProcessing(AudioEngineHandle handle);
void AudioEngine_ReadChannelFromRingBuffer(AudioEngineHandle handle, int channelIndex, float* left, float* right, int numFrames);
size_t AudioEngine_GetRingBufferReadableFrames(AudioEngineHandle handle, int channelIndex);

// Pull-synchronous rendering entry point used by AVAudioSourceNode callbacks.
// Renders one multi-channel quantum exactly once per host sampleTime and returns one channel.
void AudioEngine_RenderAndReadMultiChannel(AudioEngineHandle handle, int channelIndex, int64_t sampleTime, float* left, float* right, int numFrames);

// Pull-synchronous legacy rendering with dedicated aux buses.
// Bus mapping: 0=dry mix, 1=send A, 2=send B.
void AudioEngine_RenderAndReadLegacyBus(AudioEngineHandle handle, int busIndex, int64_t sampleTime, float* left, float* right, int numFrames);

// Scope buffer access (for oscilloscope visualization)
void AudioEngine_ReadScopeBuffer(AudioEngineHandle handle, int sourceIndex, float* output, int numFrames);
size_t AudioEngine_GetScopeWriteIndex(AudioEngineHandle handle);

// Recording control
// mode: 0=OneShot, 1=LiveLoop
// sourceType: 0=external (mic/line), 1=internal voice
// sourceChannel: mixer channel index (0=Plaits,1=Rings,2=Gran1,3=Loop1,4=Loop2,5=Gran4)
void AudioEngine_StartRecording(AudioEngineHandle handle, int reelIndex, int mode, int sourceType, int sourceChannel);
void AudioEngine_StopRecording(AudioEngineHandle handle, int reelIndex);
void AudioEngine_SetRecordingFeedback(AudioEngineHandle handle, int reelIndex, float feedback);
bool AudioEngine_IsRecording(AudioEngineHandle handle, int reelIndex);
float AudioEngine_GetRecordingPosition(AudioEngineHandle handle, int reelIndex);
void AudioEngine_WriteExternalInput(AudioEngineHandle handle, const float* left, const float* right, int numFrames);

// Plaits custom six-op bank controls
bool AudioEngine_LoadPlaitsSixOpCustomBank(AudioEngineHandle handle, const uint8_t* data, int numBytes);
void AudioEngine_SetPlaitsSixOpCustomMode(AudioEngineHandle handle, bool enabled);
void AudioEngine_SetPlaitsSixOpCustomPatch(AudioEngineHandle handle, int patchIndex);

// Master compressor metering
float AudioEngine_GetCompressorGainReduction(AudioEngineHandle handle);

#ifdef __cplusplus
}
#endif

#endif // AUDIOENGINEBRIDGE_H

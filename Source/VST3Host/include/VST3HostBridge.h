//
//  VST3HostBridge.h
//  Grainulator
//
//  C bridge for the VST3 plugin host. Exposes plugin lifecycle,
//  audio processing, state persistence, and scanning to Swift.
//  Mirrors the pattern of AudioEngineBridge.h.
//

#ifndef VST3HOSTBRIDGE_H
#define VST3HOSTBRIDGE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to a VST3Host instance (manages scanning + global state)
typedef void* VST3HostHandle;

// Opaque handle to a loaded VST3 plugin instance
typedef void* VST3PluginHandle;

// Plugin info returned by scanning
typedef struct {
    char name[256];
    char vendor[256];
    char category[128];
    char classID[64];       // 32-char hex FUID
    bool hasEditor;
} VST3PluginInfo;

// ========== Host Lifecycle ==========

/// Create a new VST3 host. Call once at app startup.
VST3HostHandle VST3Host_Create(double sampleRate, int maxBlockSize);

/// Destroy the host and all loaded plugins.
void VST3Host_Destroy(VST3HostHandle host);

/// Update sample rate / block size (e.g. when audio hardware changes)
void VST3Host_SetProcessingParameters(VST3HostHandle host, double sampleRate, int maxBlockSize);

// ========== Plugin Scanning ==========

/// Scan standard VST3 directories for available plugins.
/// Returns the number of plugins found.
int VST3Host_ScanPlugins(VST3HostHandle host);

/// Get info for a scanned plugin by index.
/// Returns false if index is out of range.
bool VST3Host_GetPluginInfo(VST3HostHandle host, int index, VST3PluginInfo* outInfo);

// ========== Plugin Instance Lifecycle ==========

/// Load a plugin by its class ID (hex string from VST3PluginInfo.classID).
/// Returns a plugin handle, or NULL on failure.
VST3PluginHandle VST3Host_LoadPlugin(VST3HostHandle host, const char* classID);

/// Unload a plugin instance. Invalidates the handle.
void VST3Host_UnloadPlugin(VST3HostHandle host, VST3PluginHandle plugin);

/// Set bypass state on a loaded plugin.
void VST3Host_SetBypass(VST3PluginHandle plugin, bool bypassed);

/// Get bypass state.
bool VST3Host_GetBypass(VST3PluginHandle plugin);

// ========== Audio Processing ==========

/// Process a stereo audio buffer in-place.
/// left/right: interleaved float buffers of `numFrames` samples.
/// Call from the audio thread only.
void VST3Host_Process(VST3PluginHandle plugin, float* left, float* right, int numFrames);

// ========== State Persistence ==========

/// Get the plugin state as a binary blob.
/// Returns the size of the state data, or 0 on failure.
/// If outData is NULL, returns the required buffer size.
int VST3Host_GetState(VST3PluginHandle plugin, uint8_t* outData, int maxSize);

/// Restore plugin state from a binary blob.
/// Returns true on success.
bool VST3Host_SetState(VST3PluginHandle plugin, const uint8_t* data, int size);

// ========== Parameter Automation ==========

/// Get the number of parameters exposed by the plugin.
int VST3Host_GetParameterCount(VST3PluginHandle plugin);

/// Get parameter info by index.
/// Returns false if index is out of range.
bool VST3Host_GetParameterInfo(VST3PluginHandle plugin, int index,
                                char* outName, int nameMaxLen,
                                uint32_t* outParamID,
                                double* outDefaultValue);

/// Set a parameter value (0-1 normalized).
void VST3Host_SetParameter(VST3PluginHandle plugin, uint32_t paramID, double value);

/// Get a parameter value (0-1 normalized).
double VST3Host_GetParameter(VST3PluginHandle plugin, uint32_t paramID);

// ========== Editor / UI ==========

/// Returns true if the plugin has a custom editor GUI.
bool VST3Host_HasEditor(VST3PluginHandle plugin);

/// Callback type for plugin-initiated resize requests.
typedef void (*VST3EditorResizeCallback)(void* context, int width, int height);

/// Prepare the plugin editor. Creates the IPlugView internally and returns
/// the preferred width/height. Returns true on success.
/// Call this before AttachEditorToView.
bool VST3Host_PrepareEditor(VST3PluginHandle plugin, int* outWidth, int* outHeight);

/// Attach the prepared editor to a parent NSView.
/// The parentNSView must remain valid until DetachEditor is called.
/// Returns true on success.
bool VST3Host_AttachEditorToView(VST3PluginHandle plugin, void* parentNSView);

/// Set a callback that fires when the plugin requests a resize.
void VST3Host_SetEditorResizeCallback(VST3PluginHandle plugin,
                                       VST3EditorResizeCallback callback,
                                       void* context);

/// Detach the editor from its parent view and release the IPlugView.
void VST3Host_DetachEditor(VST3PluginHandle plugin);

#ifdef __cplusplus
}
#endif

#endif // VST3HOSTBRIDGE_H

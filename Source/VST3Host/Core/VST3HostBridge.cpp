//
//  VST3HostBridge.cpp
//  Grainulator
//
//  C bridge implementation for VST3Host.
//

#include "VST3HostBridge.h"
#include "VST3Host.h"

#include <cstring>

using namespace Grainulator;

extern "C" {

// ========== Host Lifecycle ==========

VST3HostHandle VST3Host_Create(double sampleRate, int maxBlockSize) {
    return new VST3Host(sampleRate, maxBlockSize);
}

void VST3Host_Destroy(VST3HostHandle host) {
    if (host) {
        delete static_cast<VST3Host*>(host);
    }
}

void VST3Host_SetProcessingParameters(VST3HostHandle host, double sampleRate, int maxBlockSize) {
    if (host) {
        static_cast<VST3Host*>(host)->setProcessingParameters(sampleRate, maxBlockSize);
    }
}

// ========== Plugin Scanning ==========

int VST3Host_ScanPlugins(VST3HostHandle host) {
    if (!host) return 0;
    return static_cast<VST3Host*>(host)->scanPlugins();
}

bool VST3Host_GetPluginInfo(VST3HostHandle host, int index, VST3PluginInfo* outInfo) {
    if (!host || !outInfo) return false;
    auto* h = static_cast<VST3Host*>(host);
    const auto& plugins = h->getPlugins();
    if (index < 0 || index >= static_cast<int>(plugins.size())) return false;

    const auto& p = plugins[index];
    std::memset(outInfo, 0, sizeof(VST3PluginInfo));
    strncpy(outInfo->name, p.name.c_str(), sizeof(outInfo->name) - 1);
    strncpy(outInfo->vendor, p.vendor.c_str(), sizeof(outInfo->vendor) - 1);
    strncpy(outInfo->category, p.category.c_str(), sizeof(outInfo->category) - 1);
    strncpy(outInfo->classID, p.classIDHex().c_str(), sizeof(outInfo->classID) - 1);
    outInfo->hasEditor = p.hasEditor;
    return true;
}

// ========== Plugin Instance Lifecycle ==========

VST3PluginHandle VST3Host_LoadPlugin(VST3HostHandle host, const char* classID) {
    if (!host || !classID) return nullptr;
    return static_cast<VST3Host*>(host)->loadPlugin(classID);
}

void VST3Host_UnloadPlugin(VST3HostHandle host, VST3PluginHandle plugin) {
    if (!host || !plugin) return;
    static_cast<VST3Host*>(host)->unloadPlugin(static_cast<VST3PluginInstance*>(plugin));
}

void VST3Host_SetBypass(VST3PluginHandle plugin, bool bypassed) {
    if (plugin) {
        static_cast<VST3PluginInstance*>(plugin)->setBypass(bypassed);
    }
}

bool VST3Host_GetBypass(VST3PluginHandle plugin) {
    if (!plugin) return false;
    return static_cast<VST3PluginInstance*>(plugin)->isBypassed();
}

// ========== Audio Processing ==========

void VST3Host_Process(VST3PluginHandle plugin, float* left, float* right, int numFrames) {
    if (plugin) {
        static_cast<VST3PluginInstance*>(plugin)->process(left, right, numFrames);
    }
}

// ========== State Persistence ==========

int VST3Host_GetState(VST3PluginHandle plugin, uint8_t* outData, int maxSize) {
    if (!plugin) return 0;
    auto state = static_cast<VST3PluginInstance*>(plugin)->getState();
    if (state.empty()) return 0;

    int stateSize = static_cast<int>(state.size());
    if (!outData) return stateSize;  // Query mode: return required size
    if (maxSize < stateSize) return 0;  // Buffer too small

    std::memcpy(outData, state.data(), stateSize);
    return stateSize;
}

bool VST3Host_SetState(VST3PluginHandle plugin, const uint8_t* data, int size) {
    if (!plugin || !data || size <= 0) return false;
    return static_cast<VST3PluginInstance*>(plugin)->setState(data, size);
}

// ========== Parameter Automation ==========

int VST3Host_GetParameterCount(VST3PluginHandle plugin) {
    if (!plugin) return 0;
    return static_cast<VST3PluginInstance*>(plugin)->getParameterCount();
}

bool VST3Host_GetParameterInfo(VST3PluginHandle plugin, int index,
                                char* outName, int nameMaxLen,
                                uint32_t* outParamID,
                                double* outDefaultValue) {
    if (!plugin) return false;
    std::string name;
    Steinberg::Vst::ParamID paramID;
    double defaultValue;

    if (!static_cast<VST3PluginInstance*>(plugin)->getParameterInfo(index, name, paramID, defaultValue)) {
        return false;
    }

    if (outName && nameMaxLen > 0) {
        strncpy(outName, name.c_str(), nameMaxLen - 1);
        outName[nameMaxLen - 1] = '\0';
    }
    if (outParamID) *outParamID = paramID;
    if (outDefaultValue) *outDefaultValue = defaultValue;
    return true;
}

void VST3Host_SetParameter(VST3PluginHandle plugin, uint32_t paramID, double value) {
    if (plugin) {
        static_cast<VST3PluginInstance*>(plugin)->setParameter(paramID, value);
    }
}

double VST3Host_GetParameter(VST3PluginHandle plugin, uint32_t paramID) {
    if (!plugin) return 0.0;
    return static_cast<VST3PluginInstance*>(plugin)->getParameter(paramID);
}

// ========== Editor / UI ==========

bool VST3Host_HasEditor(VST3PluginHandle plugin) {
    if (!plugin) return false;
    return static_cast<VST3PluginInstance*>(plugin)->hasEditor();
}

bool VST3Host_PrepareEditor(VST3PluginHandle plugin, int* outWidth, int* outHeight) {
    if (!plugin || !outWidth || !outHeight) return false;
    return static_cast<VST3PluginInstance*>(plugin)->prepareEditor(*outWidth, *outHeight);
}

bool VST3Host_AttachEditorToView(VST3PluginHandle plugin, void* parentNSView) {
    if (!plugin || !parentNSView) return false;
    return static_cast<VST3PluginInstance*>(plugin)->attachEditorToView(parentNSView);
}

void VST3Host_SetEditorResizeCallback(VST3PluginHandle plugin,
                                       VST3EditorResizeCallback callback,
                                       void* context) {
    if (!plugin) return;
    static_cast<VST3PluginInstance*>(plugin)->setEditorResizeCallback(
        reinterpret_cast<Grainulator::EditorResizeCallback>(callback), context);
}

void VST3Host_DetachEditor(VST3PluginHandle plugin) {
    if (plugin) {
        static_cast<VST3PluginInstance*>(plugin)->detachEditor();
    }
}

} // extern "C"

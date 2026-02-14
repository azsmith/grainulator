//
//  VST3Host.h
//  Grainulator
//
//  C++ VST3 plugin host. Loads .vst3 bundles, manages plugin instances,
//  routes audio, and handles state persistence.
//

#pragma once

#include <string>
#include <vector>
#include <memory>
#include <unordered_map>

#include "pluginterfaces/vst/ivstaudioprocessor.h"
#include "pluginterfaces/vst/ivstcomponent.h"
#include "pluginterfaces/vst/ivsteditcontroller.h"
#include "pluginterfaces/vst/ivstparameterchanges.h"
#include "pluginterfaces/vst/ivstevents.h"
#include "pluginterfaces/gui/iplugview.h"
#include "pluginterfaces/base/ipluginbase.h"
#include "pluginterfaces/base/funknown.h"
#include "pluginterfaces/base/smartpointer.h"

namespace Grainulator {

// Forward declarations
class VST3PluginInstance;

/// Metadata for a discovered VST3 plugin
struct VST3PluginDescriptor {
    std::string name;
    std::string vendor;
    std::string category;
    Steinberg::FUID classID;
    bool hasEditor = false;

    /// classID as 32-char hex string
    std::string classIDHex() const;
};

/// Manages VST3 plugin discovery and instance lifecycle
class VST3Host {
public:
    VST3Host(double sampleRate, int maxBlockSize);
    ~VST3Host();

    // Non-copyable
    VST3Host(const VST3Host&) = delete;
    VST3Host& operator=(const VST3Host&) = delete;

    /// Update processing parameters
    void setProcessingParameters(double sampleRate, int maxBlockSize);

    /// Scan standard macOS VST3 directories
    /// Returns number of plugins found
    int scanPlugins();

    /// Get all discovered plugins
    const std::vector<VST3PluginDescriptor>& getPlugins() const { return m_plugins; }

    /// Load a plugin by class ID hex string
    /// Returns nullptr on failure
    VST3PluginInstance* loadPlugin(const std::string& classIDHex);

    /// Unload and destroy a plugin instance
    void unloadPlugin(VST3PluginInstance* instance);

private:
    double m_sampleRate;
    int m_maxBlockSize;

    std::vector<VST3PluginDescriptor> m_plugins;
    std::vector<std::unique_ptr<VST3PluginInstance>> m_instances;

    /// Scan a single .vst3 bundle
    void scanBundle(const std::string& path);

    /// Scan a directory for .vst3 bundles
    void scanDirectory(const std::string& dirPath);
};

/// A loaded VST3 plugin instance ready for audio processing
class VST3PluginInstance {
public:
    VST3PluginInstance(const VST3PluginDescriptor& descriptor,
                       double sampleRate, int maxBlockSize);
    ~VST3PluginInstance();

    // Non-copyable
    VST3PluginInstance(const VST3PluginInstance&) = delete;
    VST3PluginInstance& operator=(const VST3PluginInstance&) = delete;

    /// Initialize the plugin component and processor
    bool initialize(Steinberg::IPluginFactory* factory);

    /// Activate for audio processing
    bool activate();

    /// Deactivate (stop processing)
    void deactivate();

    /// Process stereo audio in-place
    void process(float* left, float* right, int numFrames);

    /// Bypass control
    void setBypass(bool bypassed);
    bool isBypassed() const { return m_bypassed; }

    /// State persistence
    std::vector<uint8_t> getState() const;
    bool setState(const uint8_t* data, int size);

    /// Parameter access
    int getParameterCount() const;
    bool getParameterInfo(int index, std::string& name,
                          Steinberg::Vst::ParamID& paramID,
                          double& defaultValue) const;
    void setParameter(Steinberg::Vst::ParamID id, double value);
    double getParameter(Steinberg::Vst::ParamID id) const;

    /// Editor
    bool hasEditor() const;
    void* createEditorView();  // Returns NSView*
    void destroyEditorView();

    const VST3PluginDescriptor& descriptor() const { return m_descriptor; }

private:
    VST3PluginDescriptor m_descriptor;
    double m_sampleRate;
    int m_maxBlockSize;
    bool m_bypassed = false;
    bool m_active = false;

    // VST3 COM interfaces (reference-counted)
    Steinberg::IPtr<Steinberg::Vst::IComponent> m_component;
    Steinberg::IPtr<Steinberg::Vst::IAudioProcessor> m_processor;
    Steinberg::IPtr<Steinberg::Vst::IEditController> m_controller;
    Steinberg::IPtr<Steinberg::IPlugView> m_plugView;

    // Processing buffers
    float* m_inputBuffers[2] = {nullptr, nullptr};
    float* m_outputBuffers[2] = {nullptr, nullptr};

    // Module handle (dylib)
    void* m_moduleHandle = nullptr;

    void allocateBuffers();
    void freeBuffers();
};

} // namespace Grainulator

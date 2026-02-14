//
//  VST3Host.cpp
//  Grainulator
//
//  VST3 plugin host implementation using raw VST3 SDK.
//  Handles .vst3 bundle loading, plugin scanning, audio processing,
//  and state persistence on macOS.
//

#include "VST3Host.h"
#include "pluginterfaces/base/ibstream.h"
#include "pluginterfaces/vst/ivstprocesscontext.h"
#include "pluginterfaces/gui/iplugview.h"

#include <cstring>
#include <algorithm>
#include <iostream>
#include <filesystem>
#include <sstream>
#include <iomanip>
#include <dlfcn.h>

// macOS: CFBundle for .vst3 loading
#if __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#endif

using namespace Steinberg;
using namespace Steinberg::Vst;

// Define IPlugFrame IID (normally in commoniids.cpp which we don't compile)
DEF_CLASS_IID(IPlugFrame)

namespace Grainulator {

// ========== Helper: Memory stream for state save/load ==========

class MemoryStream : public IBStream {
public:
    MemoryStream() = default;
    MemoryStream(const uint8_t* data, int size) : m_data(data, data + size) {}

    // IBStream
    tresult PLUGIN_API read(void* buffer, int32 numBytes, int32* numBytesRead) override {
        int32 available = static_cast<int32>(m_data.size()) - m_cursor;
        int32 toRead = std::min(numBytes, available);
        if (toRead > 0) {
            std::memcpy(buffer, m_data.data() + m_cursor, toRead);
            m_cursor += toRead;
        }
        if (numBytesRead) *numBytesRead = toRead;
        return kResultOk;
    }

    tresult PLUGIN_API write(void* buffer, int32 numBytes, int32* numBytesWritten) override {
        if (m_cursor + numBytes > static_cast<int32>(m_data.size())) {
            m_data.resize(m_cursor + numBytes);
        }
        std::memcpy(m_data.data() + m_cursor, buffer, numBytes);
        m_cursor += numBytes;
        if (numBytesWritten) *numBytesWritten = numBytes;
        return kResultOk;
    }

    tresult PLUGIN_API seek(int64 pos, int32 mode, int64* result) override {
        switch (mode) {
            case kIBSeekSet: m_cursor = static_cast<int32>(pos); break;
            case kIBSeekCur: m_cursor += static_cast<int32>(pos); break;
            case kIBSeekEnd: m_cursor = static_cast<int32>(m_data.size()) + static_cast<int32>(pos); break;
        }
        m_cursor = std::max(0, std::min(m_cursor, static_cast<int32>(m_data.size())));
        if (result) *result = m_cursor;
        return kResultOk;
    }

    tresult PLUGIN_API tell(int64* pos) override {
        if (pos) *pos = m_cursor;
        return kResultOk;
    }

    // FUnknown
    tresult PLUGIN_API queryInterface(const TUID iid, void** obj) override {
        QUERY_INTERFACE(iid, obj, FUnknown::iid, IBStream)
        QUERY_INTERFACE(iid, obj, IBStream::iid, IBStream)
        *obj = nullptr;
        return kNoInterface;
    }
    uint32 PLUGIN_API addRef() override { return ++m_refCount; }
    uint32 PLUGIN_API release() override {
        if (--m_refCount == 0) { delete this; return 0; }
        return m_refCount;
    }

    const std::vector<uint8_t>& getData() const { return m_data; }
    int32 getSize() const { return static_cast<int32>(m_data.size()); }

private:
    std::vector<uint8_t> m_data;
    int32 m_cursor = 0;
    uint32 m_refCount = 1;
};

// ========== VST3PluginDescriptor ==========

std::string VST3PluginDescriptor::classIDHex() const {
    char buf[33];
    TUID tuid;
    classID.toTUID(tuid);
    for (int i = 0; i < 16; ++i) {
        snprintf(buf + i * 2, 3, "%02X", static_cast<uint8_t>(tuid[i]));
    }
    buf[32] = '\0';
    return std::string(buf);
}

// ========== VST3Host ==========

VST3Host::VST3Host(double sampleRate, int maxBlockSize)
    : m_sampleRate(sampleRate)
    , m_maxBlockSize(maxBlockSize)
{}

VST3Host::~VST3Host() {
    // Unload all instances
    m_instances.clear();
}

void VST3Host::setProcessingParameters(double sampleRate, int maxBlockSize) {
    m_sampleRate = sampleRate;
    m_maxBlockSize = maxBlockSize;
    // TODO: notify active instances to reconfigure
}

int VST3Host::scanPlugins() {
    m_plugins.clear();

    // Standard macOS VST3 directories
    scanDirectory("/Library/Audio/Plug-Ins/VST3");

    // User library
    const char* home = getenv("HOME");
    if (home) {
        std::string userDir = std::string(home) + "/Library/Audio/Plug-Ins/VST3";
        scanDirectory(userDir);
    }

    std::cout << "VST3Host: Found " << m_plugins.size() << " VST3 plugins" << std::endl;
    return static_cast<int>(m_plugins.size());
}

void VST3Host::scanDirectory(const std::string& dirPath) {
    namespace fs = std::filesystem;
    std::error_code ec;

    if (!fs::exists(dirPath, ec) || !fs::is_directory(dirPath, ec)) {
        return;
    }

    for (const auto& entry : fs::directory_iterator(dirPath, ec)) {
        if (entry.is_directory(ec)) {
            std::string path = entry.path().string();
            if (path.size() > 5 && path.substr(path.size() - 5) == ".vst3") {
                scanBundle(path);
            }
            // Also scan subdirectories (some manufacturers use subfolders)
            else {
                for (const auto& subentry : fs::directory_iterator(path, ec)) {
                    if (subentry.is_directory(ec)) {
                        std::string subpath = subentry.path().string();
                        if (subpath.size() > 5 && subpath.substr(subpath.size() - 5) == ".vst3") {
                            scanBundle(subpath);
                        }
                    }
                }
            }
        }
    }
}

void VST3Host::scanBundle(const std::string& bundlePath) {
#if __APPLE__
    // Load the .vst3 bundle using CFBundle
    CFURLRef bundleURL = CFURLCreateFromFileSystemRepresentation(
        kCFAllocatorDefault,
        reinterpret_cast<const UInt8*>(bundlePath.c_str()),
        bundlePath.size(),
        true  // isDirectory
    );
    if (!bundleURL) return;

    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL);
    CFRelease(bundleURL);
    if (!bundle) return;

    // Load the bundle's executable
    if (!CFBundleLoadExecutable(bundle)) {
        CFRelease(bundle);
        return;
    }

    // Get the factory function
    using GetFactoryFunc = IPluginFactory* (*)();
    auto getFactory = reinterpret_cast<GetFactoryFunc>(
        CFBundleGetFunctionPointerForName(bundle, CFSTR("GetPluginFactory"))
    );

    if (!getFactory) {
        CFBundleUnloadExecutable(bundle);
        CFRelease(bundle);
        return;
    }

    IPluginFactory* factory = getFactory();
    if (!factory) {
        CFBundleUnloadExecutable(bundle);
        CFRelease(bundle);
        return;
    }

    // Enumerate classes in the factory
    int32 classCount = factory->countClasses();
    for (int32 i = 0; i < classCount; ++i) {
        PClassInfo classInfo;
        if (factory->getClassInfo(i, &classInfo) == kResultOk) {
            // Only interested in audio processor components
            if (strcmp(classInfo.category, kVstAudioEffectClass) == 0) {
                VST3PluginDescriptor desc;
                desc.name = classInfo.name;
                desc.category = classInfo.category;
                desc.classID = FUID::fromTUID(classInfo.cid);

                // Try to get extended info (PClassInfo2) for vendor name
                IPluginFactory2* factory2 = nullptr;
                if (factory->queryInterface(IPluginFactory2::iid, reinterpret_cast<void**>(&factory2)) == kResultOk && factory2) {
                    PClassInfo2 classInfo2;
                    if (factory2->getClassInfo2(i, &classInfo2) == kResultOk) {
                        desc.vendor = classInfo2.vendor;
                        desc.name = classInfo2.name;
                    }
                    factory2->release();
                }

                // Check for editor by attempting to create a component
                // (deferred to load time for performance)
                desc.hasEditor = true;  // Assume true; checked on load
                desc.bundlePath = bundlePath;  // Cache for direct loading

                m_plugins.push_back(desc);
            }
        }
    }

    // Don't unload the bundle yet — we may need it for instantiation
    // Store the bundle reference if we want to instantiate later
    // For now, unload (we'll reload on instantiation)
    CFBundleUnloadExecutable(bundle);
    CFRelease(bundle);
#endif
}

VST3PluginInstance* VST3Host::loadPlugin(const std::string& classIDHex) {
    // Find the descriptor
    const VST3PluginDescriptor* desc = nullptr;
    for (const auto& p : m_plugins) {
        if (p.classIDHex() == classIDHex) {
            desc = &p;
            break;
        }
    }
    if (!desc) {
        std::cerr << "VST3Host: Plugin not found: " << classIDHex << std::endl;
        return nullptr;
    }

    if (desc->bundlePath.empty()) {
        std::cerr << "VST3Host: No bundle path cached for " << desc->name << std::endl;
        return nullptr;
    }

    auto instance = std::make_unique<VST3PluginInstance>(*desc, m_sampleRate, m_maxBlockSize);

    // Load directly from the cached bundle path — avoids loading unrelated bundles
    // whose static initializers may crash
    bool loaded = false;
#if __APPLE__
    CFURLRef bundleURL = CFURLCreateFromFileSystemRepresentation(
        kCFAllocatorDefault,
        reinterpret_cast<const UInt8*>(desc->bundlePath.c_str()),
        desc->bundlePath.size(), true);
    if (!bundleURL) {
        std::cerr << "VST3Host: Failed to create URL for " << desc->bundlePath << std::endl;
        return nullptr;
    }

    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL);
    CFRelease(bundleURL);
    if (!bundle) {
        std::cerr << "VST3Host: Failed to create bundle for " << desc->bundlePath << std::endl;
        return nullptr;
    }

    if (!CFBundleLoadExecutable(bundle)) {
        std::cerr << "VST3Host: Failed to load executable for " << desc->bundlePath << std::endl;
        CFRelease(bundle);
        return nullptr;
    }

    using GetFactoryFunc = IPluginFactory* (*)();
    auto getFactory = reinterpret_cast<GetFactoryFunc>(
        CFBundleGetFunctionPointerForName(bundle, CFSTR("GetPluginFactory")));

    if (!getFactory) {
        std::cerr << "VST3Host: No GetPluginFactory in " << desc->bundlePath << std::endl;
        CFBundleUnloadExecutable(bundle);
        CFRelease(bundle);
        return nullptr;
    }

    IPluginFactory* factory = getFactory();
    if (!factory) {
        CFBundleUnloadExecutable(bundle);
        CFRelease(bundle);
        return nullptr;
    }

    if (instance->initialize(factory)) {
        if (instance->activate()) {
            // Don't release bundle — keep loaded while instance lives
            loaded = true;
        }
    }

    if (!loaded) {
        CFBundleUnloadExecutable(bundle);
        CFRelease(bundle);
    }
#endif

    if (!loaded) {
        std::cerr << "VST3Host: Failed to load plugin: " << desc->name << std::endl;
        return nullptr;
    }

    VST3PluginInstance* ptr = instance.get();
    m_instances.push_back(std::move(instance));
    std::cout << "VST3Host: Loaded " << desc->name << std::endl;
    return ptr;
}

void VST3Host::unloadPlugin(VST3PluginInstance* instance) {
    auto it = std::find_if(m_instances.begin(), m_instances.end(),
        [instance](const auto& p) { return p.get() == instance; });
    if (it != m_instances.end()) {
        std::cout << "VST3Host: Unloaded " << instance->descriptor().name << std::endl;
        m_instances.erase(it);
    }
}

// ========== VST3PluginInstance ==========

VST3PluginInstance::VST3PluginInstance(const VST3PluginDescriptor& descriptor,
                                       double sampleRate, int maxBlockSize)
    : m_descriptor(descriptor)
    , m_sampleRate(sampleRate)
    , m_maxBlockSize(maxBlockSize)
{}

VST3PluginInstance::~VST3PluginInstance() {
    detachEditor();
    deactivate();
    freeBuffers();

    if (m_controller) {
        m_controller->terminate();
        m_controller = nullptr;
    }
    if (m_component) {
        m_component->terminate();
        m_component = nullptr;
    }
    m_processor = nullptr;
}

bool VST3PluginInstance::initialize(IPluginFactory* factory) {
    // Create the component
    TUID componentTUID;
    m_descriptor.classID.toTUID(componentTUID);

    void* obj = nullptr;
    if (factory->createInstance(componentTUID, IComponent::iid, &obj) != kResultOk || !obj) {
        std::cerr << "VST3: Failed to create component for " << m_descriptor.name << std::endl;
        return false;
    }
    m_component = static_cast<IComponent*>(obj);

    // Initialize the component
    // Note: A proper host would pass an IHostApplication here
    if (m_component->initialize(nullptr) != kResultOk) {
        std::cerr << "VST3: Component init failed for " << m_descriptor.name << std::endl;
        m_component = nullptr;
        return false;
    }

    // Get the audio processor interface
    if (m_component->queryInterface(IAudioProcessor::iid, reinterpret_cast<void**>(&obj)) != kResultOk) {
        std::cerr << "VST3: No IAudioProcessor for " << m_descriptor.name << std::endl;
        return false;
    }
    m_processor = static_cast<IAudioProcessor*>(obj);
    if (obj) static_cast<IAudioProcessor*>(obj)->release(); // queryInterface addRef'd

    // Get the edit controller (may be combined with component or separate)
    if (m_component->queryInterface(IEditController::iid, reinterpret_cast<void**>(&obj)) == kResultOk && obj) {
        m_controller = static_cast<IEditController*>(obj);
        static_cast<IEditController*>(obj)->release();
    } else {
        // Try to create a separate controller
        TUID controllerCID;
        if (m_component->getControllerClassId(controllerCID) == kResultOk) {
            if (factory->createInstance(controllerCID, IEditController::iid, &obj) == kResultOk && obj) {
                m_controller = static_cast<IEditController*>(obj);
                m_controller->initialize(nullptr);
            }
        }
    }

    allocateBuffers();
    return true;
}

bool VST3PluginInstance::activate() {
    if (!m_processor) return false;

    // Set up processing
    ProcessSetup setup;
    setup.processMode = kRealtime;
    setup.symbolicSampleSize = kSample32;
    setup.maxSamplesPerBlock = m_maxBlockSize;
    setup.sampleRate = m_sampleRate;

    if (m_processor->setupProcessing(setup) != kResultOk) {
        std::cerr << "VST3: setupProcessing failed for " << m_descriptor.name << std::endl;
        return false;
    }

    // Activate audio buses
    // Assume stereo in + stereo out (bus 0)
    m_component->activateBus(kAudio, kInput, 0, true);
    m_component->activateBus(kAudio, kOutput, 0, true);

    if (m_component->setActive(true) != kResultOk) {
        std::cerr << "VST3: setActive failed for " << m_descriptor.name << std::endl;
        return false;
    }

    m_processor->setProcessing(true);
    m_active = true;
    return true;
}

void VST3PluginInstance::deactivate() {
    if (!m_active) return;
    if (m_processor) {
        m_processor->setProcessing(false);
    }
    if (m_component) {
        m_component->setActive(false);
    }
    m_active = false;
}

void VST3PluginInstance::allocateBuffers() {
    freeBuffers();
    m_inputBuffers[0] = new float[m_maxBlockSize]();
    m_inputBuffers[1] = new float[m_maxBlockSize]();
    m_outputBuffers[0] = new float[m_maxBlockSize]();
    m_outputBuffers[1] = new float[m_maxBlockSize]();
}

void VST3PluginInstance::freeBuffers() {
    delete[] m_inputBuffers[0]; m_inputBuffers[0] = nullptr;
    delete[] m_inputBuffers[1]; m_inputBuffers[1] = nullptr;
    delete[] m_outputBuffers[0]; m_outputBuffers[0] = nullptr;
    delete[] m_outputBuffers[1]; m_outputBuffers[1] = nullptr;
}

void VST3PluginInstance::process(float* left, float* right, int numFrames) {
    if (!m_processor || !m_active || m_bypassed) return;
    if (numFrames <= 0 || numFrames > m_maxBlockSize) return;

    // Copy input
    std::memcpy(m_inputBuffers[0], left, numFrames * sizeof(float));
    std::memcpy(m_inputBuffers[1], right, numFrames * sizeof(float));

    // Set up VST3 process data
    AudioBusBuffers inputBus;
    inputBus.numChannels = 2;
    inputBus.silenceFlags = 0;
    inputBus.channelBuffers32 = m_inputBuffers;

    AudioBusBuffers outputBus;
    outputBus.numChannels = 2;
    outputBus.silenceFlags = 0;
    outputBus.channelBuffers32 = m_outputBuffers;

    ProcessData data;
    data.processMode = kRealtime;
    data.symbolicSampleSize = kSample32;
    data.numSamples = numFrames;
    data.numInputs = 1;
    data.numOutputs = 1;
    data.inputs = &inputBus;
    data.outputs = &outputBus;
    data.inputParameterChanges = nullptr;
    data.outputParameterChanges = nullptr;
    data.inputEvents = nullptr;
    data.outputEvents = nullptr;
    data.processContext = nullptr;

    // Process
    if (m_processor->process(data) == kResultOk) {
        // Copy output back to caller's buffers
        std::memcpy(left, m_outputBuffers[0], numFrames * sizeof(float));
        std::memcpy(right, m_outputBuffers[1], numFrames * sizeof(float));
    }
}

void VST3PluginInstance::setBypass(bool bypassed) {
    m_bypassed = bypassed;
}

std::vector<uint8_t> VST3PluginInstance::getState() const {
    if (!m_component) return {};

    auto stream = new MemoryStream();
    if (m_component->getState(stream) == kResultOk) {
        auto result = stream->getData();
        stream->release();
        return result;
    }
    stream->release();
    return {};
}

bool VST3PluginInstance::setState(const uint8_t* data, int size) {
    if (!m_component || !data || size <= 0) return false;

    auto stream = new MemoryStream(data, size);
    bool ok = m_component->setState(stream) == kResultOk;

    // Also restore controller state if separate
    if (ok && m_controller) {
        stream->seek(0, IBStream::kIBSeekSet, nullptr);
        m_controller->setComponentState(stream);
    }
    stream->release();
    return ok;
}

int VST3PluginInstance::getParameterCount() const {
    if (!m_controller) return 0;
    return m_controller->getParameterCount();
}

bool VST3PluginInstance::getParameterInfo(int index, std::string& name,
                                           ParamID& paramID,
                                           double& defaultValue) const {
    if (!m_controller || index < 0 || index >= m_controller->getParameterCount()) {
        return false;
    }

    ParameterInfo info;
    if (m_controller->getParameterInfo(index, info) != kResultOk) {
        return false;
    }

    // Convert UTF-16 name to ASCII
    char nameBuf[256];
    for (int i = 0; i < 128 && info.title[i]; ++i) {
        nameBuf[i] = static_cast<char>(info.title[i] & 0x7F);
        nameBuf[i + 1] = '\0';
    }
    name = nameBuf;
    paramID = info.id;
    defaultValue = info.defaultNormalizedValue;
    return true;
}

void VST3PluginInstance::setParameter(ParamID id, double value) {
    if (!m_controller) return;
    m_controller->setParamNormalized(id, value);
}

double VST3PluginInstance::getParameter(ParamID id) const {
    if (!m_controller) return 0.0;
    return m_controller->getParamNormalized(id);
}

bool VST3PluginInstance::hasEditor() const {
    if (!m_controller) return false;
    auto view = m_controller->createView("editor");
    if (view) {
        view->release();
        return true;
    }
    return false;
}

bool VST3PluginInstance::prepareEditor(int& outWidth, int& outHeight) {
#if __APPLE__
    if (!m_controller) return false;

    // Clean up any existing editor
    detachEditor();

    m_plugView = m_controller->createView("editor");
    if (!m_plugView) return false;

    // Check if the view supports Cocoa (NSView)
    if (m_plugView->isPlatformTypeSupported("NSView") != kResultOk) {
        m_plugView = nullptr;
        return false;
    }

    // Get preferred size
    ViewRect rect;
    if (m_plugView->getSize(&rect) != kResultOk) {
        rect = ViewRect(0, 0, 600, 400);
    }

    outWidth = rect.getWidth();
    outHeight = rect.getHeight();

    // Create and attach the plug frame for resize requests
    m_plugFrame = new VST3PlugFrame();
    m_plugView->setFrame(m_plugFrame);

    return true;
#else
    return false;
#endif
}

bool VST3PluginInstance::attachEditorToView(void* parentNSView) {
#if __APPLE__
    if (!m_plugView || !parentNSView) return false;
    return m_plugView->attached(parentNSView, "NSView") == kResultOk;
#else
    return false;
#endif
}

void VST3PluginInstance::setEditorResizeCallback(EditorResizeCallback callback, void* context) {
    if (m_plugFrame) {
        m_plugFrame->setResizeCallback(callback, context);
    }
}

void VST3PluginInstance::detachEditor() {
    if (m_plugView) {
        m_plugView->setFrame(nullptr);
        m_plugView->removed();
        m_plugView = nullptr;
    }
    m_plugFrame = nullptr;
}

} // namespace Grainulator

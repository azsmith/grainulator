//
//  VST3PluginHost.swift
//  Grainulator
//
//  VST3 backend (backend 2) for the PluginHost protocol.
//  Wraps the C++ VST3Host via bridge functions.
//

import Foundation
import AppKit
import AVFoundation

// MARK: - Bridge declarations

@_silgen_name("VST3Host_Create")
func VST3Host_Create(_ sampleRate: Double, _ maxBlockSize: Int32) -> OpaquePointer?

@_silgen_name("VST3Host_Destroy")
func VST3Host_Destroy(_ host: OpaquePointer)

@_silgen_name("VST3Host_SetProcessingParameters")
func VST3Host_SetProcessingParameters(_ host: OpaquePointer, _ sampleRate: Double, _ maxBlockSize: Int32)

@_silgen_name("VST3Host_ScanPlugins")
func VST3Host_ScanPlugins(_ host: OpaquePointer) -> Int32

@_silgen_name("VST3Host_GetPluginInfo")
func VST3Host_GetPluginInfo(_ host: OpaquePointer, _ index: Int32, _ outInfo: UnsafeMutablePointer<VST3PluginInfoC>) -> Bool

@_silgen_name("VST3Host_LoadPlugin")
func VST3Host_LoadPlugin(_ host: OpaquePointer, _ classID: UnsafePointer<CChar>) -> OpaquePointer?

@_silgen_name("VST3Host_UnloadPlugin")
func VST3Host_UnloadPlugin(_ host: OpaquePointer, _ plugin: OpaquePointer)

@_silgen_name("VST3Host_SetBypass")
func VST3Host_SetBypass(_ plugin: OpaquePointer, _ bypassed: Bool)

@_silgen_name("VST3Host_GetBypass")
func VST3Host_GetBypass(_ plugin: OpaquePointer) -> Bool

@_silgen_name("VST3Host_Process")
func VST3Host_Process(_ plugin: OpaquePointer, _ left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>, _ numFrames: Int32)

@_silgen_name("VST3Host_GetState")
func VST3Host_GetState(_ plugin: OpaquePointer, _ outData: UnsafeMutablePointer<UInt8>?, _ maxSize: Int32) -> Int32

@_silgen_name("VST3Host_SetState")
func VST3Host_SetState(_ plugin: OpaquePointer, _ data: UnsafePointer<UInt8>, _ size: Int32) -> Bool

@_silgen_name("VST3Host_GetParameterCount")
func VST3Host_GetParameterCount(_ plugin: OpaquePointer) -> Int32

@_silgen_name("VST3Host_SetParameter")
func VST3Host_SetParameter(_ plugin: OpaquePointer, _ paramID: UInt32, _ value: Double)

@_silgen_name("VST3Host_GetParameter")
func VST3Host_GetParameter(_ plugin: OpaquePointer, _ paramID: UInt32) -> Double

@_silgen_name("VST3Host_HasEditor")
func VST3Host_HasEditor(_ plugin: OpaquePointer) -> Bool

@_silgen_name("VST3Host_PrepareEditor")
func VST3Host_PrepareEditor(_ plugin: OpaquePointer, _ outWidth: UnsafeMutablePointer<Int32>, _ outHeight: UnsafeMutablePointer<Int32>) -> Bool

@_silgen_name("VST3Host_AttachEditorToView")
func VST3Host_AttachEditorToView(_ plugin: OpaquePointer, _ parentNSView: UnsafeMutableRawPointer) -> Bool

@_silgen_name("VST3Host_SetEditorResizeCallback")
func VST3Host_SetEditorResizeCallback(_ plugin: OpaquePointer,
                                       _ callback: (@convention(c) (UnsafeMutableRawPointer?, Int32, Int32) -> Void)?,
                                       _ context: UnsafeMutableRawPointer?)

@_silgen_name("VST3Host_DetachEditor")
func VST3Host_DetachEditor(_ plugin: OpaquePointer)

// MARK: - C struct mirror

/// Mirror of the C VST3PluginInfo struct
struct VST3PluginInfoC {
    var name: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
               CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) // 256
    var vendor: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                 CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) // 256
    var category: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                   CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) // 128
    var classID: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                  CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                  CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                  CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                  CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                  CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                  CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                  CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) // 64
    var hasEditor: Bool
}

extension VST3PluginInfoC {
    var nameString: String {
        withUnsafePointer(to: name) { ptr in
            String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
        }
    }
    var vendorString: String {
        withUnsafePointer(to: vendor) { ptr in
            String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
        }
    }
    var categoryString: String {
        withUnsafePointer(to: category) { ptr in
            String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
        }
    }
    var classIDString: String {
        withUnsafePointer(to: classID) { ptr in
            String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
        }
    }
}

// MARK: - VST3 Plugin Instance

/// Wraps a loaded VST3 plugin instance behind the PluginInstance protocol
final class VST3PluginInstanceWrapper: PluginInstance, @unchecked Sendable {
    let descriptor: PluginDescriptor
    let backend: PluginBackend = .vst3
    let handle: OpaquePointer

    init(handle: OpaquePointer, descriptor: PluginDescriptor) {
        self.handle = handle
        self.descriptor = descriptor
    }

    func setBypass(_ bypassed: Bool) {
        VST3Host_SetBypass(handle, bypassed)
    }

    var fullState: [String: Any]? {
        get {
            // Get state as binary blob, wrap in dict for compatibility
            let size = VST3Host_GetState(handle, nil, 0)
            guard size > 0 else { return nil }
            var data = [UInt8](repeating: 0, count: Int(size))
            let written = VST3Host_GetState(handle, &data, size)
            guard written > 0 else { return nil }
            return ["vst3state": Data(data)]
        }
        set {
            guard let dict = newValue,
                  let data = dict["vst3state"] as? Data else { return }
            data.withUnsafeBytes { rawPtr in
                guard let ptr = rawPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                _ = VST3Host_SetState(handle, ptr, Int32(data.count))
            }
        }
    }

    func requestViewController(completion: @escaping (NSViewController?) -> Void) {
        var width: Int32 = 0
        var height: Int32 = 0
        guard VST3Host_PrepareEditor(handle, &width, &height) else {
            completion(nil)
            return
        }
        let vc = VST3EditorViewController(
            pluginHandle: handle,
            editorSize: NSSize(width: CGFloat(width), height: CGFloat(height))
        )
        completion(vc)
    }

    var avAudioUnit: AVAudioUnit? { nil }
    var vst3Handle: OpaquePointer? { handle }

    /// Process stereo audio in-place (called from audio thread)
    func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, numFrames: Int32) {
        VST3Host_Process(handle, left, right, numFrames)
    }
}

// MARK: - VST3 Editor View Controller

/// Hosts a VST3 plugin's native editor GUI inside an NSView.
/// The NSView is created in Swift and its pointer is passed to C++ for IPlugView::attached().
final class VST3EditorViewController: NSViewController {
    private let pluginHandle: OpaquePointer
    private let editorSize: NSSize
    private var isAttached = false

    init(pluginHandle: OpaquePointer, editorSize: NSSize) {
        self.pluginHandle = pluginHandle
        self.editorSize = editorSize
        super.init(nibName: nil, bundle: nil)
        self.preferredContentSize = editorSize
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView(frame: NSRect(origin: .zero, size: editorSize))
        container.wantsLayer = true
        self.view = container
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !isAttached else { return }

        // Set up resize callback before attaching so we catch the first resize
        let context = Unmanaged.passUnretained(self).toOpaque()
        VST3Host_SetEditorResizeCallback(pluginHandle, { ctx, w, h in
            guard let ctx else { return }
            let vc = Unmanaged<VST3EditorViewController>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async {
                let newSize = NSSize(width: CGFloat(w), height: CGFloat(h))
                vc.view.setFrameSize(newSize)
                vc.preferredContentSize = newSize
                if let window = vc.view.window {
                    window.setContentSize(newSize)
                }
            }
        }, context)

        // Attach the plugin's IPlugView to our NSView
        let nsViewPtr = Unmanaged.passUnretained(view).toOpaque()
        if VST3Host_AttachEditorToView(pluginHandle, nsViewPtr) {
            isAttached = true
        } else {
            print("VST3EditorViewController: failed to attach editor view")
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        detach()
    }

    deinit {
        detach()
    }

    private func detach() {
        guard isAttached else { return }
        VST3Host_SetEditorResizeCallback(pluginHandle, nil, nil)
        VST3Host_DetachEditor(pluginHandle)
        isAttached = false
    }
}

// MARK: - VST3 Plugin Host

/// VST3 backend for the PluginHost protocol
@MainActor
final class VST3PluginHost: PluginHost, ObservableObject {
    let backend: PluginBackend = .vst3

    private var hostHandle: OpaquePointer?
    @Published private(set) var scannedPlugins: [PluginDescriptor] = []
    @Published private(set) var isScanning: Bool = false

    var availablePlugins: [PluginDescriptor] { scannedPlugins }

    init(sampleRate: Double, maxBlockSize: Int) {
        hostHandle = VST3Host_Create(sampleRate, Int32(maxBlockSize))
    }

    deinit {
        if let handle = hostHandle {
            VST3Host_Destroy(handle)
        }
    }

    func refreshPluginList() {
        guard let handle = hostHandle else { return }
        isScanning = true

        Task.detached { [handle] in
            let count = VST3Host_ScanPlugins(handle)
            var descriptors: [PluginDescriptor] = []

            for i in 0..<count {
                var info = VST3PluginInfoC(
                    name: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                           0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                           0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                           0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                           0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                           0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                           0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                           0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
                    vendor: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
                    category: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                               0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                               0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                               0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
                    classID: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                              0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
                    hasEditor: false
                )

                if VST3Host_GetPluginInfo(handle, i, &info) {
                    let desc = PluginDescriptor(
                        name: info.nameString,
                        manufacturerName: info.vendorString,
                        vst3ClassID: info.classIDString,
                        typeName: "Effect",
                        hasCustomView: info.hasEditor
                    )
                    descriptors.append(desc)
                }
            }

            await MainActor.run { [descriptors] in
                self.scannedPlugins = descriptors
                self.isScanning = false
                print("VST3PluginHost: Found \(descriptors.count) VST3 plugins")
            }
        }
    }

    func instantiate(_ descriptor: PluginDescriptor, outOfProcess: Bool) async throws -> PluginInstance {
        guard let handle = hostHandle,
              let classID = descriptor.vst3ClassID else {
            throw AUPluginError.instantiationFailed
        }

        let pluginHandle = classID.withCString { cStr in
            VST3Host_LoadPlugin(handle, cStr)
        }

        guard let pluginHandle else {
            print("VST3PluginHost: Failed to load \(descriptor.name)")
            throw AUPluginError.instantiationFailed
        }

        return VST3PluginInstanceWrapper(handle: pluginHandle, descriptor: descriptor)
    }

    func release(_ instance: PluginInstance) {
        guard let wrapper = instance as? VST3PluginInstanceWrapper,
              let handle = hostHandle else { return }
        VST3Host_UnloadPlugin(handle, wrapper.handle)
    }

    func search(_ query: String) -> [PluginDescriptor] {
        guard !query.isEmpty else { return scannedPlugins }
        let lowerQuery = query.lowercased()
        return scannedPlugins.filter {
            $0.name.lowercased().contains(lowerQuery) ||
            $0.manufacturerName.lowercased().contains(lowerQuery)
        }
    }

    func plugins(in category: AUPluginCategory) -> [PluginDescriptor] {
        if category == .all { return scannedPlugins }
        return scannedPlugins.filter { category.matches($0.name) }
    }
}

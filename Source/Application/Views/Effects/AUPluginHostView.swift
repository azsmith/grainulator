//
//  AUPluginHostView.swift
//  Grainulator
//
//  NSViewRepresentable wrapper to display Audio Unit plugin's native view controller
//

import SwiftUI
import AVFoundation
import CoreAudioKit

// MARK: - AU Plugin Host View

/// Displays the native UI of an Audio Unit plugin
struct AUPluginHostView: NSViewRepresentable {
    let audioUnit: AVAudioUnit

    @Binding var preferredSize: CGSize

    init(audioUnit: AVAudioUnit, preferredSize: Binding<CGSize> = .constant(CGSize(width: 400, height: 300))) {
        self.audioUnit = audioUnit
        self._preferredSize = preferredSize
    }

    func makeNSView(context: Context) -> NSView {
        let containerView = AUHostContainerView()
        containerView.coordinator = context.coordinator

        // Request AU's view controller asynchronously
        audioUnit.auAudioUnit.requestViewController { viewController in
            DispatchQueue.main.async {
                context.coordinator.handleViewController(viewController, in: containerView)
            }
        }

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Updates handled by coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(preferredSize: $preferredSize)
    }

    // MARK: - Coordinator

    class Coordinator {
        @Binding var preferredSize: CGSize
        var viewController: NSViewController?
        private var frameObservation: NSKeyValueObservation?
        private var pcsObservation: NSKeyValueObservation?
        private var sizePollingTimer: Timer?

        init(preferredSize: Binding<CGSize>) {
            self._preferredSize = preferredSize
        }

        deinit {
            sizePollingTimer?.invalidate()
        }

        fileprivate func handleViewController(_ vc: NSViewController?, in containerView: AUHostContainerView) {
            // Clean up previous state
            frameObservation = nil
            pcsObservation = nil
            sizePollingTimer?.invalidate()
            sizePollingTimer = nil

            guard let viewController = vc else {
                containerView.showGenericView()
                return
            }

            self.viewController = viewController
            let auView = viewController.view

            // CRITICAL: Remove from any previous superview before re-hosting.
            // When a sheet is closed and reopened, SwiftUI creates a new container
            // but the AU returns the same view controller. The view is still parented
            // to the old (dead) container, so we must explicitly detach it first.
            auView.removeFromSuperview()

            // Use frame-based layout — don't fight the plugin's own layout system.
            // Position at origin in the container.
            auView.translatesAutoresizingMaskIntoConstraints = true
            auView.frame.origin = .zero
            containerView.addSubview(auView)

            // Force initial layout
            containerView.needsLayout = true
            containerView.layoutSubtreeIfNeeded()

            // Do an initial size check
            let initialSize = resolvePluginSize(viewController: viewController, auView: auView)
            updatePreferredSize(initialSize)

            // Observe frame changes for plugins that resize after initialization
            frameObservation = auView.observe(\.frame, options: [.new]) { [weak self] view, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    let resolved = self.resolvePluginSize(viewController: viewController, auView: view)
                    self.updatePreferredSize(resolved)
                }
            }

            // Observe preferredContentSize
            pcsObservation = viewController.observe(\.preferredContentSize, options: [.new]) { [weak self] vc, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    let resolved = self.resolvePluginSize(viewController: vc, auView: vc.view)
                    self.updatePreferredSize(resolved)
                }
            }

            // Many AU plugins (especially Soundtoys) initialize their view asynchronously —
            // the frame is zero at first, then updates after 1-2 runloop cycles.
            // Poll a few times over the first second to catch late-arriving sizes.
            var pollCount = 0
            sizePollingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                pollCount += 1
                let resolved = self.resolvePluginSize(viewController: viewController, auView: auView)
                self.updatePreferredSize(resolved)
                if pollCount >= 10 {
                    timer.invalidate()
                    self.sizePollingTimer = nil
                }
            }

            containerView.hideGenericView()
        }

        /// Check multiple size sources to find the best plugin dimensions.
        private func resolvePluginSize(viewController: NSViewController, auView: NSView) -> CGSize {
            var bestWidth: CGFloat = 0
            var bestHeight: CGFloat = 0

            // 1. View controller's preferredContentSize (most reliable for many AU plugins)
            let pcs = viewController.preferredContentSize
            if pcs.width > 10 && pcs.height > 10 {
                bestWidth = max(bestWidth, pcs.width)
                bestHeight = max(bestHeight, pcs.height)
            }

            // 2. The view's actual frame
            let frame = auView.frame
            if frame.width > 10 && frame.height > 10 {
                bestWidth = max(bestWidth, frame.width)
                bestHeight = max(bestHeight, frame.height)
            }

            // 3. fittingSize (Auto Layout plugins)
            let fitting = auView.fittingSize
            if fitting.width > 10 && fitting.height > 10 {
                bestWidth = max(bestWidth, fitting.width)
                bestHeight = max(bestHeight, fitting.height)
            }

            // 4. Intrinsic content size
            let intrinsic = auView.intrinsicContentSize
            if intrinsic.width > 10 && intrinsic.height > 10 {
                bestWidth = max(bestWidth, intrinsic.width)
                bestHeight = max(bestHeight, intrinsic.height)
            }

            // 5. Check subviews — some plugins nest their real content view
            for subview in auView.subviews {
                let sf = subview.frame
                let maxX = sf.origin.x + sf.width
                let maxY = sf.origin.y + sf.height
                if maxX > bestWidth { bestWidth = maxX }
                if maxY > bestHeight { bestHeight = maxY }
            }

            // Fallback
            if bestWidth < 10 { bestWidth = 400 }
            if bestHeight < 10 { bestHeight = 300 }

            return CGSize(
                width: min(1600, bestWidth),
                height: min(1200, bestHeight)
            )
        }

        private func updatePreferredSize(_ size: CGSize) {
            // Only grow — prevents shrinking during layout churn,
            // but allows growth as the plugin reports its real size
            let newWidth = max(preferredSize.width, size.width)
            let newHeight = max(preferredSize.height, size.height)
            let newSize = CGSize(width: newWidth, height: newHeight)
            if newSize != preferredSize {
                preferredSize = newSize
            }
        }
    }
}

// MARK: - Container View

/// Container view that hosts the AU plugin view.
/// Does NOT use isFlipped — AU plugins expect standard macOS coordinates.
private class AUHostContainerView: NSView {
    weak var coordinator: AUPluginHostView.Coordinator?

    private var genericView: NSView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupGenericView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGenericView()
    }

    private func setupGenericView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(ColorPalette.backgroundSecondary).cgColor

        let label = NSTextField(labelWithString: "Loading plugin UI...")
        label.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textColor = NSColor(ColorPalette.textMuted)
        label.alignment = .center

        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        genericView = container
    }

    func showGenericView() {
        if let container = genericView {
            for subview in container.subviews {
                if let label = subview as? NSTextField {
                    label.stringValue = "Plugin has no custom UI"
                }
            }
            container.isHidden = false
        }
    }

    func hideGenericView() {
        genericView?.isHidden = true
    }
}

// MARK: - AU Plugin Window View

/// A view that wraps the AU host view in a window-like container with controls
struct AUPluginWindowView: View {
    let audioUnit: AVAudioUnit
    let pluginInfo: AUPluginInfo
    let channelIndex: Int
    let slotIndex: Int
    @ObservedObject var slot: AUInsertSlot

    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @Binding var isPresented: Bool
    @State private var preferredSize = CGSize(width: 400, height: 300)

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .background(ColorPalette.divider)

            AUPluginHostView(audioUnit: audioUnit, preferredSize: $preferredSize)
                .frame(width: preferredSize.width, height: preferredSize.height)
        }
        .frame(minWidth: 300, minHeight: 200)
        .background(ColorPalette.backgroundPrimary)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pluginInfo.name)
                    .font(Typography.panelTitle)
                    .foregroundColor(.white)

                Text(pluginInfo.manufacturerName)
                    .font(Typography.parameterLabelSmall)
                    .foregroundColor(ColorPalette.textDimmed)
            }

            Spacer()

            Button(action: {
                audioEngine.toggleInsertBypass(channelIndex: channelIndex, slotIndex: slotIndex)
            }) {
                Text("BYP")
                    .font(Typography.buttonTiny)
                    .foregroundColor(slot.isBypassed ? .white : ColorPalette.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(slot.isBypassed ? ColorPalette.ledAmber : ColorPalette.ledOff)
                    )
            }
            .buttonStyle(.plain)

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.15))
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ColorPalette.backgroundSecondary)
    }
}

// MARK: - Generic AU Parameter View

/// Fallback view for plugins without custom UI - displays parameters as sliders
struct AUGenericParameterView: View {
    let audioUnit: AVAudioUnit

    @State private var parameterTree: AUParameterTree?
    @State private var parameters: [AUParameter] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if parameters.isEmpty {
                    Text("No parameters available")
                        .font(Typography.parameterLabel)
                        .foregroundColor(ColorPalette.textDimmed)
                        .padding()
                } else {
                    ForEach(Array(parameters.enumerated()), id: \.1.identifier) { index, param in
                        GenericParameterRow(parameter: param)
                    }
                }
            }
            .padding(12)
        }
        .background(ColorPalette.backgroundSecondary)
        .onAppear {
            loadParameters()
        }
    }

    private func loadParameters() {
        parameterTree = audioUnit.auAudioUnit.parameterTree
        if let tree = parameterTree {
            parameters = collectParameters(from: tree)
        }
    }

    private func collectParameters(from group: AUParameterGroup) -> [AUParameter] {
        var result: [AUParameter] = []
        for child in group.children {
            if let param = child as? AUParameter {
                result.append(param)
            } else if let subgroup = child as? AUParameterGroup {
                result.append(contentsOf: collectParameters(from: subgroup))
            }
        }
        return result
    }

    private func collectParameters(from tree: AUParameterTree) -> [AUParameter] {
        var result: [AUParameter] = []
        for child in tree.children {
            if let param = child as? AUParameter {
                result.append(param)
            } else if let group = child as? AUParameterGroup {
                result.append(contentsOf: collectParameters(from: group))
            }
        }
        return result
    }
}

// MARK: - Generic Parameter Row

private struct GenericParameterRow: View {
    let parameter: AUParameter

    @State private var value: Float = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(parameter.displayName)
                    .font(Typography.parameterLabelSmall)
                    .foregroundColor(ColorPalette.textMuted)

                Spacer()

                Text(formattedValue)
                    .font(Typography.valueTiny)
                    .foregroundColor(ColorPalette.ledBlue)
                    .monospacedDigit()
            }

            Slider(value: $value, in: parameter.minValue...parameter.maxValue)
                .tint(ColorPalette.ledBlue)
                .onChange(of: value) { newValue in
                    parameter.setValue(newValue, originator: nil)
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(ColorPalette.backgroundTertiary)
        )
        .onAppear {
            value = parameter.value
        }
    }

    private var formattedValue: String {
        if let unit = parameter.unitName, !unit.isEmpty {
            return String(format: "%.2f %@", value, unit)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Preview

#if DEBUG
struct AUPluginHostView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("AU Plugin Host View")
                .font(.title)
                .foregroundColor(.white)

            Text("Requires a real AVAudioUnit to preview")
                .foregroundColor(.gray)
        }
        .frame(width: 400, height: 300)
        .background(ColorPalette.backgroundPrimary)
    }
}
#endif

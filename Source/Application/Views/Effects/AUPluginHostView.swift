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

        init(preferredSize: Binding<CGSize>) {
            self._preferredSize = preferredSize
        }

        fileprivate func handleViewController(_ vc: NSViewController?, in containerView: AUHostContainerView) {
            // Remove old view controller if any
            if let oldVC = viewController {
                oldVC.view.removeFromSuperview()
            }

            guard let viewController = vc else {
                // Plugin doesn't have a custom view, show generic view
                containerView.showGenericView()
                return
            }

            self.viewController = viewController

            // Add the AU's view to our container
            let auView = viewController.view
            containerView.addSubview(auView)

            // Set up constraints
            auView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                auView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                auView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                auView.topAnchor.constraint(equalTo: containerView.topAnchor),
                auView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])

            // Update preferred size based on AU view's intrinsic size
            let fittingSize = auView.fittingSize
            if fittingSize.width > 0 && fittingSize.height > 0 {
                DispatchQueue.main.async {
                    self.preferredSize = CGSize(
                        width: max(200, min(800, fittingSize.width)),
                        height: max(100, min(600, fittingSize.height))
                    )
                }
            }

            containerView.hideGenericView()
        }
    }
}

// MARK: - Container View

/// Container view that hosts the AU plugin view
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
        // Update label to indicate no custom view
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
            // Header bar
            header

            Divider()
                .background(ColorPalette.divider)

            // Plugin UI
            AUPluginHostView(audioUnit: audioUnit, preferredSize: $preferredSize)
                .frame(minWidth: 200, minHeight: 100)
                .frame(width: preferredSize.width, height: preferredSize.height)
        }
        .background(ColorPalette.backgroundPrimary)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }

    private var header: some View {
        HStack(spacing: 12) {
            // Plugin name
            VStack(alignment: .leading, spacing: 2) {
                Text(pluginInfo.name)
                    .font(Typography.panelTitle)
                    .foregroundColor(.white)

                Text(pluginInfo.manufacturerName)
                    .font(Typography.parameterLabelSmall)
                    .foregroundColor(ColorPalette.textDimmed)
            }

            Spacer()

            // Bypass toggle - use audioEngine to safely toggle
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

            // Close button
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(ColorPalette.textMuted)
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

        // Get top-level parameters
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

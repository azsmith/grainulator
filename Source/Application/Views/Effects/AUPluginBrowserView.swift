//
//  AUPluginBrowserView.swift
//  Grainulator
//
//  SwiftUI view for browsing and selecting Audio Unit plugins
//

import SwiftUI

// MARK: - AU Plugin Browser View

struct AUPluginBrowserView: View {
    @EnvironmentObject var pluginManager: AUPluginManager

    @Binding var isPresented: Bool
    let onSelect: (AUPluginInfo) -> Void

    @State private var searchText = ""
    @State private var selectedCategory: AUPluginCategory? = nil
    @State private var selectedManufacturer: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()
                .background(ColorPalette.divider)

            // Search and filters
            filterBar

            Divider()
                .background(ColorPalette.divider)

            // Plugin list
            pluginList
        }
        .frame(width: 400, height: 500)
        .background(ColorPalette.backgroundPrimary)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("SELECT PLUGIN")
                .font(Typography.panelTitle)
                .foregroundColor(.white)

            Spacer()

            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ColorPalette.backgroundSecondary)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(ColorPalette.textDimmed)

                TextField("Search plugins...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(Typography.parameterLabel)
                    .foregroundColor(.white)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ColorPalette.textDimmed)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(ColorPalette.backgroundTertiary)
            )

            // Category and manufacturer filters
            HStack(spacing: 8) {
                // Category filter
                Menu {
                    Button("All Categories") {
                        selectedCategory = nil
                    }

                    Divider()

                    ForEach(AUPluginCategory.allCases, id: \.self) { category in
                        Button(category.displayName) {
                            selectedCategory = category
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedCategory?.displayName ?? "All Categories")
                            .font(Typography.parameterLabelSmall)
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(ColorPalette.ledBlue)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.backgroundTertiary)
                    )
                }
                .buttonStyle(.plain)

                // Manufacturer filter
                Menu {
                    Button("All Manufacturers") {
                        selectedManufacturer = nil
                    }

                    Divider()

                    ForEach(manufacturers, id: \.self) { manufacturer in
                        Button(manufacturer) {
                            selectedManufacturer = manufacturer
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedManufacturer ?? "All Manufacturers")
                            .font(Typography.parameterLabelSmall)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(ColorPalette.ledBlue)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorPalette.backgroundTertiary)
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                // Refresh button
                Button(action: {
                    pluginManager.refreshPluginList()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(ColorPalette.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(ColorPalette.backgroundSecondary.opacity(0.5))
    }

    // MARK: - Plugin List

    private var pluginList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // "None" option to clear slot
                    PluginRowView(
                        name: "None",
                        manufacturer: "Clear slot",
                        category: nil,
                        isSelected: false
                    ) {
                    isPresented = false
                }

                Divider()
                    .background(ColorPalette.divider)

                // Filtered plugins
                ForEach(filteredPlugins) { plugin in
                    PluginRowView(
                        name: plugin.name,
                        manufacturer: plugin.manufacturerName,
                        category: plugin.category,
                        isSelected: false
                    ) {
                        DispatchQueue.main.async {
                            onSelect(plugin)
                            isPresented = false
                        }
                    }

                    if plugin.id != filteredPlugins.last?.id {
                        Divider()
                            .background(ColorPalette.divider.opacity(0.5))
                    }
                }

                if filteredPlugins.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundColor(ColorPalette.textDimmed)

                        Text("No plugins found")
                            .font(Typography.parameterLabel)
                            .foregroundColor(ColorPalette.textMuted)

                        Text("Try adjusting your search or filters")
                            .font(Typography.parameterLabelSmall)
                            .foregroundColor(ColorPalette.textDimmed)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredPlugins: [AUPluginInfo] {
        pluginManager.availableEffects.filter { plugin in
            // Search filter
            let matchesSearch = searchText.isEmpty ||
                plugin.name.localizedCaseInsensitiveContains(searchText) ||
                plugin.manufacturerName.localizedCaseInsensitiveContains(searchText)

            // Category filter
            let matchesCategory = selectedCategory == nil ||
                plugin.category == selectedCategory

            // Manufacturer filter
            let matchesManufacturer = selectedManufacturer == nil ||
                plugin.manufacturerName == selectedManufacturer

            return matchesSearch && matchesCategory && matchesManufacturer
        }
    }

    private var manufacturers: [String] {
        let allManufacturers = Set(pluginManager.availableEffects.map { $0.manufacturerName })
        return allManufacturers.sorted()
    }
}

// MARK: - Plugin Row View

private struct PluginRowView: View {
    let name: String
    let manufacturer: String
    let category: AUPluginCategory?
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Plugin icon placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(category?.color ?? ColorPalette.backgroundTertiary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: category?.iconName ?? "waveform")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    )

                // Plugin info
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(Typography.parameterLabel)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(manufacturer)
                            .font(Typography.parameterLabelSmall)
                            .foregroundColor(ColorPalette.textDimmed)
                            .lineLimit(1)

                        if let category = category {
                            Text(category.abbreviation)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(category.color)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(category.color.opacity(0.2))
                                )
                        }
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ColorPalette.ledGreen)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? ColorPalette.backgroundTertiary : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Plugin Category Extension

extension AUPluginCategory {
    var displayName: String {
        switch self {
        case .all: return "All"
        case .eq: return "Equalizer"
        case .dynamics: return "Dynamics"
        case .filter: return "Filter"
        case .distortion: return "Distortion"
        case .delay: return "Delay"
        case .reverb: return "Reverb"
        case .modulation: return "Modulation"
        case .other: return "Other"
        }
    }

    var abbreviation: String {
        switch self {
        case .all: return "ALL"
        case .eq: return "EQ"
        case .dynamics: return "DYN"
        case .filter: return "FLT"
        case .distortion: return "DST"
        case .delay: return "DLY"
        case .reverb: return "REV"
        case .modulation: return "MOD"
        case .other: return "FX"
        }
    }

    var color: Color {
        switch self {
        case .all: return ColorPalette.textMuted
        case .eq: return ColorPalette.ledBlue
        case .dynamics: return ColorPalette.ledGreen
        case .filter: return ColorPalette.accentRings
        case .distortion: return ColorPalette.ledRed
        case .delay: return ColorPalette.ledAmber
        case .reverb: return ColorPalette.accentPlaits
        case .modulation: return ColorPalette.ledPurple
        case .other: return ColorPalette.textMuted
        }
    }

    var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .eq: return "slider.horizontal.3"
        case .dynamics: return "waveform.path"
        case .filter: return "line.3.crossed.swirl.circle"
        case .distortion: return "bolt.fill"
        case .delay: return "clock"
        case .reverb: return "waveform.badge.plus"
        case .modulation: return "arrow.triangle.2.circlepath"
        case .other: return "waveform"
        }
    }
}

// MARK: - Color Palette Extension (for purple LED)

extension ColorPalette {
    static let ledPurple = Color(red: 0.6, green: 0.4, blue: 0.9)
}

// MARK: - Preview

#if DEBUG
struct AUPluginBrowserView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @StateObject private var pluginManager = AUPluginManager()
        @State private var isPresented = true

        var body: some View {
            AUPluginBrowserView(
                isPresented: $isPresented,
                onSelect: { plugin in
                    print("Selected: \(plugin.name)")
                }
            )
            .environmentObject(pluginManager)
            .onAppear {
                pluginManager.refreshPluginList()
            }
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif

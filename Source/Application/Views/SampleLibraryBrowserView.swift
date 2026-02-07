//
//  SampleLibraryBrowserView.swift
//  Grainulator
//
//  Sheet view for browsing, downloading, and loading mx.samples instruments.
//

import SwiftUI

struct SampleLibraryBrowserView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @ObservedObject var library: SampleLibraryManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedCategory: InstrumentCategory? = nil
    @State private var downloadError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider()
                .background(ColorPalette.accentSampler.opacity(0.3))

            // Category filter
            categoryFilterBar

            // Instrument list
            instrumentList

            // Footer with storage info
            footerBar
        }
        .frame(width: 420, height: 520)
        .background(ColorPalette.backgroundPrimary)
        .onAppear {
            if library.instruments.isEmpty {
                Task { await library.refreshIndex() }
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SAMPLE LIBRARY")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("mx.samples instruments")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorPalette.textSecondary)
            }

            Spacer()

            // Refresh button
            Button(action: {
                Task { await library.refreshIndex() }
            }) {
                if library.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(ColorPalette.accentSampler)
                }
            }
            .buttonStyle(.plain)
            .disabled(library.isRefreshing)

            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ColorPalette.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Category Filter

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                categoryChip(nil, label: "All")
                ForEach(InstrumentCategory.allCases) { cat in
                    let count = filteredInstruments.filter { $0.category == cat }.count
                    if count > 0 {
                        categoryChip(cat, label: "\(cat.rawValue) (\(count))")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func categoryChip(_ category: InstrumentCategory?, label: String) -> some View {
        let isSelected = selectedCategory == category
        return Button(action: { selectedCategory = category }) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isSelected ? ColorPalette.accentSampler : ColorPalette.backgroundTertiary)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search + List

    private var filteredInstruments: [MxInstrument] {
        var results = library.instruments
        if let cat = selectedCategory {
            results = results.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            results = results.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return results
    }

    private var instrumentList: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(ColorPalette.textSecondary)
                TextField("Search instruments...", text: $searchText)
                    .font(.system(size: 10, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ColorPalette.backgroundSecondary)

            Divider().background(Color.gray.opacity(0.2))

            if filteredInstruments.isEmpty {
                Spacer()
                if library.isRefreshing {
                    ProgressView("Loading library...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                } else {
                    Text("No instruments found")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredInstruments) { instrument in
                            instrumentRow(instrument)
                            Divider().background(Color.gray.opacity(0.1))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Instrument Row

    private func instrumentRow(_ instrument: MxInstrument) -> some View {
        HStack(spacing: 10) {
            // Category icon
            Image(systemName: categoryIcon(instrument.category))
                .font(.system(size: 12))
                .foregroundColor(ColorPalette.accentSampler.opacity(0.7))
                .frame(width: 20)

            // Name + size
            VStack(alignment: .leading, spacing: 2) {
                Text(instrument.name)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(instrument.formattedSize)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                    Text(instrument.category.rawValue)
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorPalette.accentSampler.opacity(0.6))
                }
            }

            Spacer()

            // Action button
            if let progress = library.downloadProgress[instrument.id] {
                // Downloading
                VStack(spacing: 2) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 50)
                        .tint(ColorPalette.accentSampler)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(ColorPalette.textSecondary)
                }
                Button(action: { library.cancelDownload(instrument.id) }) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            } else if instrument.isInstalled {
                // Installed — load button
                Button(action: { loadInstrument(instrument) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 7))
                        Text("LOAD")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ColorPalette.accentSampler)
                    )
                }
                .buttonStyle(.plain)

                // Delete button
                Button(action: {
                    try? library.deleteInstrument(instrument.id)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            } else {
                // Not installed — download button
                Button(action: {
                    Task {
                        do {
                            try await library.downloadInstrument(instrument.id)
                        } catch {
                            downloadError = error.localizedDescription
                        }
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 8))
                        Text("GET")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(ColorPalette.accentSampler)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(ColorPalette.accentSampler.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.clear)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            let installed = library.instruments.filter(\.isInstalled).count
            let total = library.instruments.count
            Text("\(installed)/\(total) installed")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(ColorPalette.textSecondary)

            Spacer()

            if let err = downloadError {
                Text(err)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.red.opacity(0.8))
                    .lineLimit(1)
            }

            if let err = library.error {
                Text(err)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.red.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ColorPalette.backgroundSecondary)
    }

    // MARK: - Helpers

    private func loadInstrument(_ instrument: MxInstrument) {
        guard let path = instrument.localPath ?? library.localPath(for: instrument.id) else { return }
        audioEngine.loadWavSampler(directory: path)
        dismiss()
    }

    private func categoryIcon(_ category: InstrumentCategory) -> String {
        switch category {
        case .piano: return "pianokeys"
        case .guitar: return "guitars"
        case .strings: return "waveform"
        case .woodwind: return "wind"
        case .brass: return "speaker.wave.2"
        case .percussion: return "drum"
        case .keys: return "keyboard"
        case .other: return "music.note"
        }
    }
}

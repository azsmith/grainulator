//
//  SampleLibraryManager.swift
//  Grainulator
//
//  Manages the mx.samples instrument library: index fetching, downloading,
//  extraction, and local storage management.
//

import Foundation

/// Represents an instrument available from the mx.samples library
struct MxInstrument: Codable, Identifiable, Hashable {
    let id: String              // Derived from asset filename, e.g., "ghost-piano"
    let name: String            // Human-friendly display name
    let downloadURL: URL        // GitHub release asset download URL
    let sizeBytes: Int64        // ZIP file size in bytes
    var isInstalled: Bool       // Whether this instrument is downloaded locally
    var localPath: URL?         // Path to extracted folder

    /// Category derived from instrument name
    var category: InstrumentCategory {
        let lower = name.lowercased()
        if lower.contains("piano") || lower.contains("keys") || lower.contains("rhodes") || lower.contains("wurlitzer") {
            return .piano
        }
        if lower.contains("guitar") || lower.contains("strat") || lower.contains("telecaster") || lower.contains("epiphone") || lower.contains("ebow") {
            return .guitar
        }
        if lower.contains("cello") || lower.contains("violin") || lower.contains("viola") || lower.contains("string") || lower.contains("harp") {
            return .strings
        }
        if lower.contains("flute") || lower.contains("clarinet") || lower.contains("oboe") || lower.contains("bassoon") || lower.contains("sax") {
            return .woodwind
        }
        if lower.contains("trumpet") || lower.contains("trombone") || lower.contains("horn") || lower.contains("tuba") || lower.contains("brass") {
            return .brass
        }
        if lower.contains("drum") || lower.contains("marimba") || lower.contains("glockenspiel") || lower.contains("kalimba") ||
           lower.contains("percussion") || lower.contains("metallofoon") || lower.contains("vibraphone") {
            return .percussion
        }
        if lower.contains("organ") || lower.contains("harmonium") || lower.contains("melodica") || lower.contains("accordion") ||
           lower.contains("dx7") || lower.contains("electric piano") || lower.contains("ep ") || lower.contains("r3 ") {
            return .keys
        }
        return .other
    }

    /// Formatted size string
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }
}

enum InstrumentCategory: String, CaseIterable, Identifiable {
    case piano = "Piano"
    case guitar = "Guitar"
    case strings = "Strings"
    case woodwind = "Woodwind"
    case brass = "Brass"
    case percussion = "Percussion"
    case keys = "Keys"
    case other = "Other"

    var id: String { rawValue }
}

/// Manages downloading, extracting, and tracking mx.samples instruments
@MainActor
class SampleLibraryManager: ObservableObject {
    @Published var instruments: [MxInstrument] = []
    @Published var downloadProgress: [String: Double] = [:]
    @Published var isRefreshing: Bool = false
    @Published var error: String? = nil

    private let storageDir: URL
    private let indexCacheURL: URL
    private let indexCacheMaxAge: TimeInterval = 24 * 60 * 60 // 24 hours
    private var activeDownloads: [String: URLSessionDownloadTask] = [:]

    static let shared = SampleLibraryManager()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let grainulatorDir = appSupport.appendingPathComponent("Grainulator", isDirectory: true)
        storageDir = grainulatorDir.appendingPathComponent("Samples", isDirectory: true)
        indexCacheURL = grainulatorDir.appendingPathComponent("mx-samples-index.json")

        // Ensure directories exist
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: grainulatorDir, withIntermediateDirectories: true)

        // Load cached index
        loadCachedIndex()
    }

    // MARK: - Index Management

    /// Refresh the instrument index from GitHub releases API
    func refreshIndex() async {
        isRefreshing = true
        error = nil

        do {
            let assets = try await fetchGitHubReleaseAssets()
            var newInstruments: [MxInstrument] = []

            for asset in assets {
                let id = instrumentId(from: asset.name)
                let name = instrumentDisplayName(from: asset.name)
                let localDir = storageDir.appendingPathComponent(id, isDirectory: true)
                let isInstalled = FileManager.default.fileExists(atPath: localDir.path)

                newInstruments.append(MxInstrument(
                    id: id,
                    name: name,
                    downloadURL: asset.browserDownloadURL,
                    sizeBytes: asset.size,
                    isInstalled: isInstalled,
                    localPath: isInstalled ? localDir : nil
                ))
            }

            // Sort alphabetically
            newInstruments.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            instruments = newInstruments
            saveCachedIndex()
        } catch {
            self.error = "Failed to refresh library: \(error.localizedDescription)"
        }

        isRefreshing = false
    }

    /// Download and extract an instrument by ID
    func downloadInstrument(_ id: String) async throws {
        guard let instrument = instruments.first(where: { $0.id == id }) else {
            throw LibraryError.instrumentNotFound
        }

        let destDir = storageDir.appendingPathComponent(id, isDirectory: true)
        let zipURL = storageDir.appendingPathComponent("\(id).zip")

        // Download ZIP
        downloadProgress[id] = 0.0

        let (tempURL, _) = try await downloadWithProgress(
            url: instrument.downloadURL,
            instrumentId: id
        )

        // Move to final location
        try? FileManager.default.removeItem(at: zipURL)
        try FileManager.default.moveItem(at: tempURL, to: zipURL)

        // Extract ZIP
        try? FileManager.default.removeItem(at: destDir)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", zipURL.path, "-d", destDir.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw LibraryError.extractionFailed
        }

        // Clean up ZIP
        try? FileManager.default.removeItem(at: zipURL)

        // Update state
        downloadProgress.removeValue(forKey: id)
        if let idx = instruments.firstIndex(where: { $0.id == id }) {
            instruments[idx].isInstalled = true
            instruments[idx].localPath = destDir
        }
        saveCachedIndex()
    }

    /// Delete a downloaded instrument
    func deleteInstrument(_ id: String) throws {
        let destDir = storageDir.appendingPathComponent(id, isDirectory: true)
        if FileManager.default.fileExists(atPath: destDir.path) {
            try FileManager.default.removeItem(at: destDir)
        }
        if let idx = instruments.firstIndex(where: { $0.id == id }) {
            instruments[idx].isInstalled = false
            instruments[idx].localPath = nil
        }
        saveCachedIndex()
    }

    /// Cancel an in-progress download
    func cancelDownload(_ id: String) {
        activeDownloads[id]?.cancel()
        activeDownloads.removeValue(forKey: id)
        downloadProgress.removeValue(forKey: id)
    }

    /// Get the local path for an installed instrument
    func localPath(for id: String) -> URL? {
        let dir = storageDir.appendingPathComponent(id, isDirectory: true)
        return FileManager.default.fileExists(atPath: dir.path) ? dir : nil
    }

    /// Scan local storage to refresh installed state
    func rescanLocal() {
        for i in instruments.indices {
            let dir = storageDir.appendingPathComponent(instruments[i].id, isDirectory: true)
            instruments[i].isInstalled = FileManager.default.fileExists(atPath: dir.path)
            instruments[i].localPath = instruments[i].isInstalled ? dir : nil
        }
    }

    // MARK: - Private Helpers

    private struct GitHubAsset: Decodable {
        let name: String
        let size: Int64
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case size
            case browserDownloadURL = "browser_download_url"
        }
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let assets: [GitHubAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case assets
        }
    }

    private func fetchGitHubReleaseAssets() async throws -> [GitHubAsset] {
        let url = URL(string: "https://api.github.com/repos/schollz/mx.samples/releases")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LibraryError.networkError
        }

        let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)

        // Collect all ZIP assets from the "samples" tagged release
        var allAssets: [GitHubAsset] = []
        for release in releases {
            for asset in release.assets where asset.name.hasSuffix(".zip") {
                allAssets.append(asset)
            }
        }

        // Deduplicate by name (prefer latest release)
        var seen: Set<String> = []
        var unique: [GitHubAsset] = []
        for asset in allAssets {
            let id = instrumentId(from: asset.name)
            if !seen.contains(id) {
                seen.insert(id)
                unique.append(asset)
            }
        }

        return unique
    }

    private func downloadWithProgress(url: URL, instrumentId: String) async throws -> (URL, URLResponse) {
        // Use URLSession download task with progress observation
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let tempURL, let response else {
                    continuation.resume(throwing: LibraryError.downloadFailed)
                    return
                }

                // Move temp file to a stable location before returning
                let stablePath = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".zip")
                do {
                    try FileManager.default.moveItem(at: tempURL, to: stablePath)
                    continuation.resume(returning: (stablePath, response))
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            // Observe progress
            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                Task { @MainActor in
                    self.downloadProgress[instrumentId] = progress.fractionCompleted
                }
            }

            activeDownloads[instrumentId] = task
            task.resume()

            // Keep observation alive until task completes
            _ = observation
        }
    }

    private func instrumentId(from filename: String) -> String {
        // "ghost-piano.zip" -> "ghost-piano"
        var name = filename
        if name.hasSuffix(".zip") {
            name = String(name.dropLast(4))
        }
        return name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }

    private func instrumentDisplayName(from filename: String) -> String {
        var name = filename
        if name.hasSuffix(".zip") {
            name = String(name.dropLast(4))
        }
        // Convert hyphens/underscores to spaces and title-case
        return name
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    // MARK: - Cache

    private func saveCachedIndex() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(instruments) {
            try? data.write(to: indexCacheURL)
        }
    }

    private func loadCachedIndex() {
        guard FileManager.default.fileExists(atPath: indexCacheURL.path) else { return }

        // Check cache freshness
        if let attrs = try? FileManager.default.attributesOfItem(atPath: indexCacheURL.path),
           let modDate = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) < indexCacheMaxAge {
            if let data = try? Data(contentsOf: indexCacheURL),
               let cached = try? JSONDecoder().decode([MxInstrument].self, from: data) {
                instruments = cached
                rescanLocal()
            }
        }
    }

    // MARK: - Errors

    enum LibraryError: LocalizedError {
        case instrumentNotFound
        case networkError
        case downloadFailed
        case extractionFailed

        var errorDescription: String? {
            switch self {
            case .instrumentNotFound: return "Instrument not found in library"
            case .networkError: return "Network request failed"
            case .downloadFailed: return "Download failed"
            case .extractionFailed: return "Failed to extract ZIP archive"
            }
        }
    }
}

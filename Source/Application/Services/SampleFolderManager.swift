//
//  SampleFolderManager.swift
//  Grainulator
//
//  Manages configured sample library folders and scans for SF2/SFZ files.
//

import SwiftUI
import AppKit

enum SampleFileType: String, Hashable {
    case sf2
    case sfz
}

struct SampleFileEntry: Identifiable, Hashable {
    let id: String        // full path
    let name: String      // filename without extension
    let url: URL
    let fileSize: Int64
    let folderName: String // parent configured-folder display name
    let type: SampleFileType

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

@MainActor
final class SampleFolderManager: ObservableObject {
    static let shared = SampleFolderManager()

    private static let bookmarksKey = "SampleFolderBookmarks"

    @Published var folders: [URL] = []
    @Published var sf2Files: [SampleFileEntry] = []
    @Published var sfzFiles: [SampleFileEntry] = []
    @Published var isScanning: Bool = false

    private init() {
        loadBookmarks()
        Task { await scanAllFolders() }
    }

    // MARK: - Folder Management

    func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Add Sample Library Folder"
        panel.prompt = "Add Folder"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Avoid duplicates
        if folders.contains(where: { $0.path == url.path }) { return }

        // Create security-scoped bookmark
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = loadRawBookmarks()
            bookmarks.append(bookmarkData)
            UserDefaults.standard.set(bookmarks, forKey: Self.bookmarksKey)

            folders.append(url)
            Task { await scanAllFolders() }
        } catch {
            print("[SampleFolderManager] Failed to create bookmark: \(error)")
        }
    }

    func removeFolder(at index: Int) {
        guard folders.indices.contains(index) else { return }
        folders.remove(at: index)

        // Rebuild bookmarks from remaining folders
        var newBookmarks: [Data] = []
        for folder in folders {
            if let data = try? folder.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                newBookmarks.append(data)
            }
        }
        UserDefaults.standard.set(newBookmarks, forKey: Self.bookmarksKey)

        Task { await scanAllFolders() }
    }

    func rescan() {
        Task { await scanAllFolders() }
    }

    // MARK: - Bookmark Persistence

    private func loadRawBookmarks() -> [Data] {
        UserDefaults.standard.array(forKey: Self.bookmarksKey) as? [Data] ?? []
    }

    private func loadBookmarks() {
        let bookmarks = loadRawBookmarks()
        var resolved: [URL] = []
        var validBookmarks: [Data] = []

        for data in bookmarks {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { continue }

            if isStale {
                // Re-create bookmark
                if let freshData = try? url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    validBookmarks.append(freshData)
                }
            } else {
                validBookmarks.append(data)
            }
            resolved.append(url)
        }

        if validBookmarks.count != bookmarks.count {
            UserDefaults.standard.set(validBookmarks, forKey: Self.bookmarksKey)
        }
        folders = resolved
    }

    // MARK: - Scanning

    private func scanAllFolders() async {
        isScanning = true
        let foldersCopy = folders

        let results = await Task.detached { () -> ([SampleFileEntry], [SampleFileEntry]) in
            var sf2: [SampleFileEntry] = []
            var sfz: [SampleFileEntry] = []

            for folder in foldersCopy {
                let didAccess = folder.startAccessingSecurityScopedResource()
                defer { if didAccess { folder.stopAccessingSecurityScopedResource() } }

                let folderName = folder.lastPathComponent

                guard let enumerator = FileManager.default.enumerator(
                    at: folder,
                    includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                let allFiles = enumerator.allObjects.compactMap { $0 as? URL }
                for fileURL in allFiles {
                    guard let resourceValues = try? fileURL.resourceValues(
                        forKeys: [.fileSizeKey, .isRegularFileKey]
                    ),
                    resourceValues.isRegularFile == true else { continue }

                    let ext = fileURL.pathExtension.lowercased()
                    let size = Int64(resourceValues.fileSize ?? 0)
                    let name = fileURL.deletingPathExtension().lastPathComponent

                    switch ext {
                    case "sf2":
                        sf2.append(SampleFileEntry(
                            id: fileURL.path,
                            name: name,
                            url: fileURL,
                            fileSize: size,
                            folderName: folderName,
                            type: .sf2
                        ))
                    case "sfz":
                        sfz.append(SampleFileEntry(
                            id: fileURL.path,
                            name: name,
                            url: fileURL,
                            fileSize: size,
                            folderName: folderName,
                            type: .sfz
                        ))
                    default:
                        break
                    }
                }
            }

            sf2.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            sfz.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return (sf2, sfz)
        }.value

        sf2Files = results.0
        sfzFiles = results.1
        isScanning = false
    }
}

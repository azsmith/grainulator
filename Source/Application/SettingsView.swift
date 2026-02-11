//
//  SettingsView.swift
//  Grainulator
//
//  Application settings window
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper
    @State private var selectedTab: SettingsTab = .audio

    enum SettingsTab: String, CaseIterable {
        case audio = "Audio"
        case midi = "MIDI"
        case controllers = "Controllers"
        case library = "Library"
        case appearance = "Appearance"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            AudioSettingsView()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }
                .tag(SettingsTab.audio)

            MIDISettingsView()
                .tabItem {
                    Label("MIDI", systemImage: "pianokeys")
                }
                .tag(SettingsTab.midi)

            ControllerSettingsView()
                .tabItem {
                    Label("Controllers", systemImage: "gamecontroller")
                }
                .tag(SettingsTab.controllers)

            LibrarySettingsView()
                .tabItem {
                    Label("Library", systemImage: "folder.badge.gearshape")
                }
                .tag(SettingsTab.library)

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }
                .tag(SettingsTab.appearance)
        }
        .frame(width: 600, height: 400)
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @EnvironmentObject var audioEngine: AudioEngineWrapper

    var body: some View {
        Form {
            Section("Audio Interface") {
                Picker("Input Device:", selection: $audioEngine.selectedInputDevice) {
                    ForEach(audioEngine.availableInputDevices) { device in
                        Text("\(device.name) (\(device.inputChannelCount) ch)")
                            .tag(device as AudioDevice?)
                    }
                }

                Picker("Output Device:", selection: $audioEngine.selectedOutputDevice) {
                    ForEach(audioEngine.availableOutputDevices) { device in
                        Text("\(device.name) (\(device.outputChannelCount) ch)")
                            .tag(device as AudioDevice?)
                    }
                }
            }

            Section("Performance") {
                Picker("Sample Rate:", selection: $audioEngine.sampleRate) {
                    Text("44.1 kHz").tag(44100.0)
                    Text("48 kHz").tag(48000.0)
                    Text("88.2 kHz").tag(88200.0)
                    Text("96 kHz").tag(96000.0)
                }

                Picker("Buffer Size:", selection: $audioEngine.bufferSize) {
                    Text("64 samples").tag(64)
                    Text("128 samples").tag(128)
                    Text("256 samples").tag(256)
                    Text("512 samples").tag(512)
                    Text("1024 samples").tag(1024)
                }

                HStack {
                    Text("Latency:")
                    Spacer()
                    Text(String(format: "%.1f ms", audioEngine.latency))
                        .foregroundColor(.secondary)
                }
            }

            Section("Status") {
                HStack {
                    Text("Engine Status:")
                    Spacer()
                    Text(audioEngine.isRunning ? "Running" : "Stopped")
                        .foregroundColor(audioEngine.isRunning ? .green : .red)
                }

                HStack {
                    Text("CPU Load:")
                    Spacer()
                    Text(String(format: "%.1f%%", audioEngine.cpuLoad))
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - MIDI Settings

struct MIDISettingsView: View {
    var body: some View {
        VStack {
            Text("MIDI Settings")
                .font(.headline)
            Text("Coming soon...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Controller Settings

struct ControllerSettingsView: View {
    var body: some View {
        VStack {
            Text("Controller Settings")
                .font(.headline)
            Text("Coming soon...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Library Settings

struct LibrarySettingsView: View {
    @StateObject private var folderManager = SampleFolderManager.shared

    var body: some View {
        Form {
            Section("Sample Library Folders") {
                if folderManager.folders.isEmpty {
                    Text("No folders configured. Add a folder containing SF2 or SFZ files.")
                        .foregroundColor(.secondary)
                        .font(.callout)
                } else {
                    ForEach(Array(folderManager.folders.enumerated()), id: \.offset) { index, folder in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(folder.lastPathComponent)
                                    .fontWeight(.medium)
                                Text(folder.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button(action: { folderManager.removeFolder(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    Button("Add Folder...") {
                        folderManager.addFolder()
                    }

                    Spacer()

                    if folderManager.isScanning {
                        ProgressView()
                            .controlSize(.small)
                        Text("Scanning...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Button("Rescan") {
                            folderManager.rescan()
                        }
                    }
                }
            }

            Section("Summary") {
                HStack {
                    Text("SF2 files found:")
                    Spacer()
                    Text("\(folderManager.sf2Files.count)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("SFZ files found:")
                    Spacer()
                    Text("\(folderManager.sfzFiles.count)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    var body: some View {
        VStack {
            Text("Appearance Settings")
                .font(.headline)
            Text("Coming soon...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

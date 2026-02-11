//
//  ChordSequencerEngine.swift
//  Grainulator
//
//  Chord progression sequencer — 8-step chord programmer
//  that feeds intervals into the step sequencer's scale system.
//

import Foundation
import SwiftUI

// MARK: - Chord Data Types

struct ChordDegree: Identifiable, Hashable {
    let id: String          // "I", "bII", "ii", etc.
    let label: String       // "I", "♭II", "ii", etc.
    let semitone: Int       // semitone offset from root (0-11)
}

struct ChordQuality: Identifiable, Hashable {
    let id: String          // "maj", "min", "dom7", etc.
    let label: String       // "Major", "Minor", etc.
    let suffix: String      // "", "m", "7", etc.
    let intervals: [Int]    // semitone intervals from chord root
}

struct ChordStep: Identifiable {
    let id: Int             // 0-7
    var degreeId: String?   // nil = empty step
    var qualityId: String?  // nil = empty step
    var active: Bool = true

    var isEmpty: Bool { degreeId == nil || qualityId == nil }
}

struct ChordPreset: Identifiable {
    let id: String
    let name: String
    let category: String
    /// Each element is (degreeId, qualityId) or nil for empty
    let chords: [(String, String)?]
}

// MARK: - Chord Sequencer

@MainActor
final class ChordSequencer: ObservableObject {

    // MARK: - Published State

    @Published var steps: [ChordStep] = (0..<8).map { ChordStep(id: $0) }
    @Published var division: SequencerClockDivision = .div4
    @Published var selectedStep: Int = 0
    @Published var playheadStep: Int = 0
    @Published var isEnabled: Bool = true
    @Published var activePresetId: String?

    // MARK: - Static Data

    static let allDegrees: [ChordDegree] = [
        ChordDegree(id: "I",    label: "I",    semitone: 0),
        ChordDegree(id: "bII",  label: "♭II",  semitone: 1),
        ChordDegree(id: "ii",   label: "ii",   semitone: 2),
        ChordDegree(id: "bIII", label: "♭III", semitone: 3),
        ChordDegree(id: "iii",  label: "iii",  semitone: 4),
        ChordDegree(id: "IV",   label: "IV",   semitone: 5),
        ChordDegree(id: "bV",   label: "♭V",   semitone: 6),
        ChordDegree(id: "V",    label: "V",    semitone: 7),
        ChordDegree(id: "bVI",  label: "♭VI",  semitone: 8),
        ChordDegree(id: "vi",   label: "vi",   semitone: 9),
        ChordDegree(id: "bVII", label: "♭VII", semitone: 10),
        ChordDegree(id: "vii",  label: "vii",  semitone: 11),
    ]

    static let allQualities: [ChordQuality] = [
        ChordQuality(id: "maj",   label: "Major",       suffix: "",     intervals: [0, 4, 7]),
        ChordQuality(id: "min",   label: "Minor",       suffix: "m",    intervals: [0, 3, 7]),
        ChordQuality(id: "dim",   label: "Diminished",  suffix: "°",    intervals: [0, 3, 6]),
        ChordQuality(id: "aug",   label: "Augmented",   suffix: "+",    intervals: [0, 4, 8]),
        ChordQuality(id: "sus2",  label: "Sus2",        suffix: "sus2", intervals: [0, 2, 7]),
        ChordQuality(id: "sus4",  label: "Sus4",        suffix: "sus4", intervals: [0, 5, 7]),
        ChordQuality(id: "pow",   label: "Power",       suffix: "5",    intervals: [0, 7]),
        ChordQuality(id: "maj7",  label: "Maj 7th",     suffix: "maj7", intervals: [0, 4, 7, 11]),
        ChordQuality(id: "min7",  label: "Min 7th",     suffix: "m7",   intervals: [0, 3, 7, 10]),
        ChordQuality(id: "dom7",  label: "Dom 7th",     suffix: "7",    intervals: [0, 4, 7, 10]),
        ChordQuality(id: "hdim7", label: "Half-dim",    suffix: "ø7",   intervals: [0, 3, 6, 10]),
        ChordQuality(id: "fdim7", label: "Full-dim",    suffix: "°7",   intervals: [0, 3, 6, 9]),
        ChordQuality(id: "dom9",  label: "Dom 9th",     suffix: "9",    intervals: [0, 4, 7, 10, 14]),
        ChordQuality(id: "maj9",  label: "Maj 9th",     suffix: "maj9", intervals: [0, 4, 7, 11, 14]),
        ChordQuality(id: "min9",  label: "Min 9th",     suffix: "m9",   intervals: [0, 3, 7, 10, 14]),
        ChordQuality(id: "dom11", label: "Dom 11th",    suffix: "11",   intervals: [0, 4, 7, 10, 14, 17]),
        ChordQuality(id: "dom13", label: "Dom 13th",    suffix: "13",   intervals: [0, 4, 7, 10, 14, 21]),
    ]

    static let presetCategories: [String] = [
        "Pop/Rock", "Jazz", "Blues/Soul", "Folk/Country", "Minor/Dark", "Modal/Ambient"
    ]

    static let presets: [ChordPreset] = [
        // MARK: Pop/Rock
        ChordPreset(id: "pop", name: "I-V-vi-IV", category: "Pop/Rock", chords: [
            ("I","maj"), ("V","maj"), ("vi","min"), ("IV","maj"),
            ("I","maj"), ("V","maj"), ("vi","min"), ("IV","maj"),
        ]),
        ChordPreset(id: "emotional", name: "vi-IV-I-V", category: "Pop/Rock", chords: [
            ("vi","min"), ("IV","maj"), ("I","maj"), ("V","maj"),
            ("vi","min"), ("IV","maj"), ("I","maj"), ("V","maj"),
        ]),
        ChordPreset(id: "pop2", name: "I-IV-vi-V", category: "Pop/Rock", chords: [
            ("I","maj"), ("IV","maj"), ("vi","min"), ("V","maj"),
            ("I","maj"), ("IV","maj"), ("vi","min"), ("V","maj"),
        ]),
        ChordPreset(id: "doowop", name: "I-vi-IV-V", category: "Pop/Rock", chords: [
            ("I","maj"), ("vi","min"), ("IV","maj"), ("V","maj"),
            ("I","maj"), ("vi","min"), ("IV","maj"), ("V","maj"),
        ]),
        ChordPreset(id: "rock", name: "I-IV-V-IV", category: "Pop/Rock", chords: [
            ("I","maj"), ("IV","maj"), ("V","maj"), ("IV","maj"),
            ("I","maj"), ("IV","maj"), ("V","maj"), ("IV","maj"),
        ]),

        // MARK: Jazz
        ChordPreset(id: "jazz", name: "ii-V-I", category: "Jazz", chords: [
            ("ii","min7"), ("V","dom7"), ("I","maj7"), nil,
            ("ii","min7"), ("V","dom7"), ("I","maj7"), nil,
        ]),
        ChordPreset(id: "turnaround", name: "I-vi-ii-V", category: "Jazz", chords: [
            ("I","maj7"), ("vi","min7"), ("ii","min7"), ("V","dom7"),
            ("I","maj7"), ("vi","min7"), ("ii","min7"), ("V","dom7"),
        ]),
        ChordPreset(id: "circle4", name: "iii-vi-ii-V", category: "Jazz", chords: [
            ("iii","min7"), ("vi","min7"), ("ii","min7"), ("V","dom7"),
            ("iii","min7"), ("vi","min7"), ("ii","min7"), ("V","dom7"),
        ]),
        ChordPreset(id: "bossa", name: "I△7-IV△7-iii-vi", category: "Jazz", chords: [
            ("I","maj7"), ("IV","maj7"), ("iii","min7"), ("vi","min7"),
            ("I","maj7"), ("IV","maj7"), ("iii","min7"), ("vi","min7"),
        ]),
        ChordPreset(id: "jazzta", name: "ii7-V7-I△7-VI7", category: "Jazz", chords: [
            ("ii","min7"), ("V","dom7"), ("I","maj7"), ("vi","dom7"),
            ("ii","min7"), ("V","dom7"), ("I","maj7"), ("vi","dom7"),
        ]),

        // MARK: Blues/Soul
        ChordPreset(id: "blues", name: "I-IV-V-I", category: "Blues/Soul", chords: [
            ("I","dom7"), ("I","dom7"), ("IV","dom7"), ("IV","dom7"),
            ("V","dom7"), ("IV","dom7"), ("I","dom7"), ("V","dom7"),
        ]),
        ChordPreset(id: "blues8", name: "I7-IV7-I7-V7", category: "Blues/Soul", chords: [
            ("I","dom7"), ("I","dom7"), ("IV","dom7"), ("IV","dom7"),
            ("I","dom7"), ("V","dom7"), ("I","dom7"), ("V","dom7"),
        ]),
        ChordPreset(id: "minblues", name: "i-iv-i-V", category: "Blues/Soul", chords: [
            ("I","min"), ("I","min"), ("IV","min"), ("IV","min"),
            ("I","min"), ("V","dom7"), ("I","min"), ("V","dom7"),
        ]),
        ChordPreset(id: "soul", name: "i7-iv7-i7-V7", category: "Blues/Soul", chords: [
            ("I","min7"), ("I","min7"), ("IV","min7"), ("IV","min7"),
            ("I","min7"), ("V","dom7"), ("I","min7"), ("V","dom7"),
        ]),

        // MARK: Folk/Country
        ChordPreset(id: "folk1", name: "I-IV-V-V", category: "Folk/Country", chords: [
            ("I","maj"), ("IV","maj"), ("V","maj"), ("V","maj"),
            ("I","maj"), ("IV","maj"), ("V","maj"), ("V","maj"),
        ]),
        ChordPreset(id: "folk2", name: "I-V-IV-V", category: "Folk/Country", chords: [
            ("I","maj"), ("V","maj"), ("IV","maj"), ("V","maj"),
            ("I","maj"), ("V","maj"), ("IV","maj"), ("V","maj"),
        ]),
        ChordPreset(id: "folk3", name: "I-ii-V-I", category: "Folk/Country", chords: [
            ("I","maj"), ("ii","min"), ("V","maj"), ("I","maj"),
            ("I","maj"), ("ii","min"), ("V","maj"), ("I","maj"),
        ]),
        ChordPreset(id: "country", name: "I-IV-I-V", category: "Folk/Country", chords: [
            ("I","maj"), ("IV","maj"), ("I","maj"), ("V","maj"),
            ("I","maj"), ("IV","maj"), ("I","maj"), ("V","maj"),
        ]),

        // MARK: Minor/Dark
        ChordPreset(id: "andalusian", name: "i-♭VII-♭VI-V", category: "Minor/Dark", chords: [
            ("I","min"), ("bVII","maj"), ("bVI","maj"), ("V","maj"),
            ("I","min"), ("bVII","maj"), ("bVI","maj"), ("V","maj"),
        ]),
        ChordPreset(id: "epic", name: "i-♭VI-♭III-♭VII", category: "Minor/Dark", chords: [
            ("I","min"), ("bVI","maj"), ("bIII","maj"), ("bVII","maj"),
            ("I","min"), ("bVI","maj"), ("bIII","maj"), ("bVII","maj"),
        ]),
        ChordPreset(id: "darkmin", name: "i-iv-v-i", category: "Minor/Dark", chords: [
            ("I","min"), ("IV","min"), ("V","min"), ("I","min"),
            ("I","min"), ("IV","min"), ("V","min"), ("I","min"),
        ]),
        ChordPreset(id: "darkrock", name: "i-♭VII-♭VI-♭VII", category: "Minor/Dark", chords: [
            ("I","min"), ("bVII","maj"), ("bVI","maj"), ("bVII","maj"),
            ("I","min"), ("bVII","maj"), ("bVI","maj"), ("bVII","maj"),
        ]),

        // MARK: Modal/Ambient
        ChordPreset(id: "mixolydian", name: "I-♭VII-IV-I", category: "Modal/Ambient", chords: [
            ("I","maj"), ("bVII","maj"), ("IV","maj"), ("I","maj"),
            ("I","maj"), ("bVII","maj"), ("IV","maj"), ("I","maj"),
        ]),
        ChordPreset(id: "dorian", name: "i-♭III-♭VII-IV", category: "Modal/Ambient", chords: [
            ("I","min"), ("bIII","maj"), ("bVII","maj"), ("IV","maj"),
            ("I","min"), ("bIII","maj"), ("bVII","maj"), ("IV","maj"),
        ]),
        ChordPreset(id: "lydian", name: "I-II-IV-I", category: "Modal/Ambient", chords: [
            ("I","maj"), ("ii","maj"), ("IV","maj"), ("I","maj"),
            ("I","maj"), ("ii","maj"), ("IV","maj"), ("I","maj"),
        ]),
        ChordPreset(id: "phrygian", name: "i-♭II-i-♭VII", category: "Modal/Ambient", chords: [
            ("I","min"), ("bII","maj"), ("I","min"), ("bVII","maj"),
            ("I","min"), ("bII","maj"), ("I","min"), ("bVII","maj"),
        ]),
    ]

    // MARK: - Lookup Helpers

    static func degree(for id: String) -> ChordDegree? {
        allDegrees.first { $0.id == id }
    }

    static func quality(for id: String) -> ChordQuality? {
        allQualities.first { $0.id == id }
    }

    // MARK: - Step Editing

    func setDegree(_ stepIndex: Int, _ degreeId: String) {
        guard steps.indices.contains(stepIndex) else { return }
        steps[stepIndex].degreeId = degreeId
    }

    func setQuality(_ stepIndex: Int, _ qualityId: String) {
        guard steps.indices.contains(stepIndex) else { return }
        steps[stepIndex].qualityId = qualityId
    }

    func setStepActive(_ stepIndex: Int, _ active: Bool) {
        guard steps.indices.contains(stepIndex) else { return }
        steps[stepIndex].active = active
    }

    func clearStep(_ stepIndex: Int) {
        guard steps.indices.contains(stepIndex) else { return }
        steps[stepIndex].degreeId = nil
        steps[stepIndex].qualityId = nil
    }

    func clearAll() {
        steps = (0..<8).map { ChordStep(id: $0) }
        selectedStep = 0
        activePresetId = nil
    }

    func loadPreset(_ preset: ChordPreset) {
        var newSteps: [ChordStep] = []
        for i in 0..<8 {
            if let chord = preset.chords[i] {
                newSteps.append(ChordStep(id: i, degreeId: chord.0, qualityId: chord.1, active: true))
            } else {
                newSteps.append(ChordStep(id: i, active: true))
            }
        }
        steps = newSteps
        selectedStep = 0
        activePresetId = preset.id
    }

    // MARK: - Chord Resolution

    /// Display name for a step: "IVmaj7", "vi", "V7", or "—"
    func chordDisplayName(for step: ChordStep) -> String {
        guard let degId = step.degreeId,
              let qualId = step.qualityId,
              let deg = Self.degree(for: degId),
              let qual = Self.quality(for: qualId) else { return "—" }
        return "\(deg.label)\(qual.suffix)"
    }

    /// Resolve chord notes as pitch class names for display
    func resolvedNoteNames(for step: ChordStep, rootNote: Int) -> [String]? {
        guard let degId = step.degreeId,
              let qualId = step.qualityId,
              let deg = Self.degree(for: degId),
              let qual = Self.quality(for: qualId) else { return nil }

        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let chordRoot = (rootNote + deg.semitone) % 12
        return qual.intervals.map { interval in
            noteNames[((chordRoot + interval) % 12 + 12) % 12]
        }
    }

    /// Returns the chord intervals for a given step, offset by the degree's semitone.
    /// These become the "scale intervals" when the Chord Sequencer scale is active.
    /// e.g. degree=IV(5), quality=maj([0,4,7]) → [5, 9, 12] (F, A, C in key of C)
    func chordIntervalsForStep(_ stepIndex: Int) -> [Int]? {
        guard steps.indices.contains(stepIndex) else { return nil }
        let step = steps[stepIndex]
        guard step.active,
              let degId = step.degreeId,
              let qualId = step.qualityId,
              let deg = Self.degree(for: degId),
              let qual = Self.quality(for: qualId) else { return nil }

        return qual.intervals.map { $0 + deg.semitone }
    }

    /// Returns the chord intervals for the current playhead step.
    func currentChordIntervals() -> [Int]? {
        chordIntervalsForStep(playheadStep)
    }
}

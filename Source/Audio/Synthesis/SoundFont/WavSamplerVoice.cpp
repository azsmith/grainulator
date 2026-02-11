//
//  WavSamplerVoice.cpp
//  Grainulator
//
//  WAV-based polyphonic sample player voice for mx.samples instruments.
//  Uses dr_wav (public domain) for WAV file decoding.
//

#define DR_WAV_IMPLEMENTATION
#include "dr_wav.h"

#include "WavSamplerVoice.h"
#include "SfzParser.h"
#include <cstring>
#include <cmath>
#include <algorithm>
#include <vector>
#include <string>
#include <dirent.h>
#include <sys/stat.h>

namespace Grainulator {

// --- Filename parsing for mx.samples convention ---
// Format: {midiNote}.{dynamicLayer}.{totalDynamics}.{variation}.{isRelease}.wav
// Example: 60.1.3.2.1.wav = MIDI 60, dynamic 1 of 3, variation 2, release sample
// Some instruments use note names like "c4" instead of MIDI numbers.

static int noteNameToMidi(const std::string& name) {
    if (name.empty()) return -1;

    // Try pure numeric first
    bool allDigits = true;
    for (char c : name) {
        if (!std::isdigit(static_cast<unsigned char>(c))) { allDigits = false; break; }
    }
    if (allDigits) {
        int val = std::atoi(name.c_str());
        return (val >= 0 && val <= 127) ? val : -1;
    }

    // Parse note name: e.g., "c4", "fs3", "bb5", "c#4"
    static const int noteOffsets[] = { 9, 11, 0, 2, 4, 5, 7 }; // a=9, b=11, c=0, d=2, e=4, f=5, g=7
    char letter = std::tolower(static_cast<unsigned char>(name[0]));
    if (letter < 'a' || letter > 'g') return -1;

    int noteBase = noteOffsets[letter - 'a'];
    size_t pos = 1;

    // Check for sharp/flat
    if (pos < name.size()) {
        char mod = name[pos];
        if (mod == 's' || mod == '#') { noteBase++; pos++; }
        else if (mod == 'b') { noteBase--; pos++; }
    }

    // Parse octave
    if (pos >= name.size()) return -1;
    std::string octStr = name.substr(pos);
    bool octDigits = true;
    for (char c : octStr) {
        if (!std::isdigit(static_cast<unsigned char>(c)) && c != '-') { octDigits = false; break; }
    }
    if (!octDigits) return -1;

    int octave = std::atoi(octStr.c_str());
    int midi = (octave + 1) * 12 + noteBase;
    return (midi >= 0 && midi <= 127) ? midi : -1;
}

struct ParsedFilename {
    int midiNote;
    int dynamicLayer;
    int totalDynamics;
    int variation;
    bool isRelease;
    bool valid;
};

static ParsedFilename parseMxSamplesFilename(const std::string& filename) {
    ParsedFilename result{};
    result.valid = false;

    // Remove .wav extension
    std::string base = filename;
    if (base.size() > 4) {
        std::string ext = base.substr(base.size() - 4);
        for (auto& c : ext) c = std::tolower(static_cast<unsigned char>(c));
        if (ext == ".wav") {
            base = base.substr(0, base.size() - 4);
        } else {
            return result;
        }
    } else {
        return result;
    }

    // Split by '.'
    std::vector<std::string> parts;
    std::string current;
    for (char c : base) {
        if (c == '.') {
            if (!current.empty()) parts.push_back(current);
            current.clear();
        } else {
            current += c;
        }
    }
    if (!current.empty()) parts.push_back(current);

    // Need at least: midiNote.dynamicLayer.totalDynamics.variation
    // Optional fifth field: isRelease (0 or 1)
    if (parts.size() < 4 || parts.size() > 5) return result;

    result.midiNote = noteNameToMidi(parts[0]);
    if (result.midiNote < 0) return result;

    // Parse numeric fields
    auto parseInt = [](const std::string& s) -> int {
        for (char c : s) {
            if (!std::isdigit(static_cast<unsigned char>(c))) return -1;
        }
        return s.empty() ? -1 : std::atoi(s.c_str());
    };

    result.dynamicLayer = parseInt(parts[1]);
    result.totalDynamics = parseInt(parts[2]);
    result.variation = parseInt(parts[3]);

    if (result.dynamicLayer < 0 || result.totalDynamics < 1 || result.variation < 0) return result;

    result.isRelease = false;
    if (parts.size() == 5) {
        int rel = parseInt(parts[4]);
        if (rel < 0) return result;
        result.isRelease = (rel != 0);
    }

    result.valid = true;
    return result;
}

// --- SampleMap lifecycle ---

void WavSamplerVoice::FreeSampleMap(SampleMap* map) {
    if (!map) return;
    for (int i = 0; i < map->sampleCount; ++i) {
        delete[] map->samples[i].data;
    }
    delete[] map->samples;
    delete map;
}

// --- Constructor / Destructor ---

WavSamplerVoice::WavSamplerVoice()
    : m_sampleRate(48000.0f)
    , m_mapActive(nullptr)
    , m_mapLoading(nullptr)
    , m_swapPending(false)
    , m_pendingFree(nullptr)
    , m_maxPolyphony(16)
    , m_voiceCounter(0)
    , m_level(0.8f)
    , m_attack(0.0f)
    , m_decay(0.0f)
    , m_sustain(1.0f)
    , m_release(0.1f)
    , m_filterCutoff(1.0f)
    , m_filterResonance(0.0f)
    , m_tuning(0.0f)
    , m_useSfzEnvelopes(false)
    , m_filterStateL(0.0f)
    , m_filterStateR(0.0f)
{
    std::memset(m_voices, 0, sizeof(m_voices));
    std::memset(m_roundRobin, 0, sizeof(m_roundRobin));
    for (int i = 0; i < kMaxVoices; ++i) {
        m_voices[i].state = SamplerVoiceSlot::State::Off;
    }
}

WavSamplerVoice::~WavSamplerVoice() {
    FreeSampleMap(m_mapActive);
    FreeSampleMap(m_mapLoading);
    FreeSampleMap(m_pendingFree);
}

void WavSamplerVoice::Init(float sample_rate) {
    m_sampleRate = sample_rate;
    m_filterStateL = 0.0f;
    m_filterStateR = 0.0f;
    m_voiceCounter = 0;
}

// --- Double-buffer swap ---

void WavSamplerVoice::CheckSwap() {
    if (m_swapPending.load(std::memory_order_acquire)) {
        // Free previously pending old map (deferred from last swap)
        if (m_pendingFree) {
            FreeSampleMap(m_pendingFree);
            m_pendingFree = nullptr;
        }

        // Swap: save old active for deferred free, install new
        m_pendingFree = m_mapActive;
        m_mapActive = m_mapLoading;
        m_mapLoading = nullptr;
        m_swapPending.store(false, std::memory_order_release);

        // Kill all playing voices when instrument changes
        AllNotesOff();
    }
}

// --- Loading ---

bool WavSamplerVoice::LoadFromDirectory(const char* dirPath) {
    // This runs on a background thread — allocations are fine here.
    DIR* dir = opendir(dirPath);
    if (!dir) return false;

    std::vector<WavSample> loadedSamples;
    size_t totalBytes = 0;

    struct dirent* entry;
    while ((entry = readdir(dir)) != nullptr) {
        std::string fname(entry->d_name);
        ParsedFilename parsed = parseMxSamplesFilename(fname);
        if (!parsed.valid) continue;

        // Build full path
        std::string fullPath = std::string(dirPath) + "/" + fname;

        // Load WAV with dr_wav
        drwav wav;
        if (!drwav_init_file(&wav, fullPath.c_str(), nullptr)) continue;

        // Read all frames as float
        size_t totalFrames = wav.totalPCMFrameCount;
        unsigned int channels = wav.channels;
        unsigned int wavSampleRate = wav.sampleRate;

        // Allocate stereo interleaved buffer
        float* stereoData = new float[totalFrames * 2];

        if (channels == 1) {
            // Mono: read then duplicate to stereo
            float* monoData = new float[totalFrames];
            drwav_read_pcm_frames_f32(&wav, totalFrames, monoData);
            for (size_t i = 0; i < totalFrames; ++i) {
                stereoData[i * 2]     = monoData[i];
                stereoData[i * 2 + 1] = monoData[i];
            }
            delete[] monoData;
        } else if (channels == 2) {
            // Stereo: read directly into interleaved buffer
            drwav_read_pcm_frames_f32(&wav, totalFrames, stereoData);
        } else {
            // Multi-channel: take first two channels
            float* rawData = new float[totalFrames * channels];
            drwav_read_pcm_frames_f32(&wav, totalFrames, rawData);
            for (size_t i = 0; i < totalFrames; ++i) {
                stereoData[i * 2]     = rawData[i * channels];
                stereoData[i * 2 + 1] = rawData[i * channels + 1];
            }
            delete[] rawData;
        }

        drwav_uninit(&wav);

        WavSample sample{};
        sample.data = stereoData;
        sample.frameCount = totalFrames;
        sample.sampleRate = static_cast<int>(wavSampleRate);
        sample.rootNote = parsed.midiNote;
        sample.dynamicLayer = parsed.dynamicLayer;
        sample.totalDynamics = parsed.totalDynamics;
        sample.variation = parsed.variation;
        sample.isRelease = parsed.isRelease;

        // SFZ fields: backward-compatible defaults for mx.samples
        sample.lokey = parsed.midiNote;
        sample.hikey = parsed.midiNote;
        sample.lovel = 0;
        sample.hivel = 127;
        sample.loopMode = WavSample::NoLoop;
        sample.loopStart = 0;
        sample.loopEnd = totalFrames > 0 ? totalFrames - 1 : 0;
        sample.offset = 0;
        sample.volume = 0.0f;
        sample.pan = 0.0f;
        sample.tune = 0;
        sample.transpose = 0;

        // SFZ extended: sentinel values (not specified)
        sample.ampeg_attack = -1.0f;
        sample.ampeg_hold = -1.0f;
        sample.ampeg_decay = -1.0f;
        sample.ampeg_sustain = -1.0f;
        sample.ampeg_release = -1.0f;
        sample.amp_veltrack = -1.0f;
        sample.group = 0;
        sample.off_by = 0;
        sample.cutoff = 0.0f;
        sample.resonance = 0.0f;
        sample.fil_type = 0;
        sample.pitch_keytrack = -1.0f;

        totalBytes += totalFrames * 2 * sizeof(float);
        loadedSamples.push_back(sample);
    }

    closedir(dir);

    if (loadedSamples.empty()) return false;

    // Sort by rootNote, then dynamicLayer, then variation
    std::sort(loadedSamples.begin(), loadedSamples.end(),
        [](const WavSample& a, const WavSample& b) {
            if (a.rootNote != b.rootNote) return a.rootNote < b.rootNote;
            if (a.dynamicLayer != b.dynamicLayer) return a.dynamicLayer < b.dynamicLayer;
            return a.variation < b.variation;
        });

    // Build SampleMap
    SampleMap* map = new SampleMap{};
    map->sampleCount = static_cast<int>(loadedSamples.size());
    map->samples = new WavSample[map->sampleCount];
    std::memcpy(map->samples, loadedSamples.data(), map->sampleCount * sizeof(WavSample));
    map->totalMemoryBytes = totalBytes;
    map->useSfzVelocity = false;

    // Build note lookup table
    for (int n = 0; n < 128; ++n) {
        map->noteTable[n].firstSampleIndex = -1;
        map->noteTable[n].sampleCount = 0;
    }
    for (int i = 0; i < map->sampleCount; ++i) {
        int note = map->samples[i].rootNote;
        if (note >= 0 && note < 128) {
            if (map->noteTable[note].firstSampleIndex < 0) {
                map->noteTable[note].firstSampleIndex = i;
            }
            map->noteTable[note].sampleCount++;
        }
    }

    // Extract instrument name from directory path
    std::string path(dirPath);
    // Remove trailing slashes
    while (!path.empty() && path.back() == '/') path.pop_back();
    size_t lastSlash = path.rfind('/');
    std::string name = (lastSlash != std::string::npos) ? path.substr(lastSlash + 1) : path;
    // Replace hyphens/underscores with spaces and capitalize
    for (auto& c : name) {
        if (c == '-' || c == '_') c = ' ';
    }
    std::strncpy(map->instrumentName, name.c_str(), sizeof(map->instrumentName) - 1);
    map->instrumentName[sizeof(map->instrumentName) - 1] = '\0';

    // Signal audio thread to swap
    m_mapLoading = map;
    m_swapPending.store(true, std::memory_order_release);

    return true;
}

bool WavSamplerVoice::LoadFromSfzFile(const char* sfzPath) {
    SfzParseResult result = ParseSfzFile(sfzPath);
    if (!result.success || result.samples.empty()) return false;

    // Sort by lokey, then lovel for consistent ordering
    std::sort(result.samples.begin(), result.samples.end(),
        [](const WavSample& a, const WavSample& b) {
            if (a.lokey != b.lokey) return a.lokey < b.lokey;
            if (a.lovel != b.lovel) return a.lovel < b.lovel;
            return a.variation < b.variation;
        });

    // Build SampleMap
    SampleMap* map = new SampleMap{};
    map->sampleCount = static_cast<int>(result.samples.size());
    map->samples = new WavSample[map->sampleCount];
    std::memcpy(map->samples, result.samples.data(), map->sampleCount * sizeof(WavSample));
    map->totalMemoryBytes = result.totalMemoryBytes;
    map->useSfzVelocity = true;

    // Note table left empty — FindSample does linear scan for SFZ mode
    for (int n = 0; n < 128; ++n) {
        map->noteTable[n].firstSampleIndex = -1;
        map->noteTable[n].sampleCount = 0;
    }

    // Instrument name from SFZ filename
    std::strncpy(map->instrumentName, result.instrumentName.c_str(),
                 sizeof(map->instrumentName) - 1);
    map->instrumentName[sizeof(map->instrumentName) - 1] = '\0';

    // Signal audio thread to swap
    m_mapLoading = map;
    m_swapPending.store(true, std::memory_order_release);
    return true;
}

void WavSamplerVoice::Unload() {
    m_mapLoading = nullptr;
    m_swapPending.store(true, std::memory_order_release);
}

bool WavSamplerVoice::IsLoaded() const {
    return m_mapActive != nullptr;
}

const char* WavSamplerVoice::GetInstrumentName() const {
    SampleMap* map = m_mapActive;
    return map ? map->instrumentName : "";
}

// --- Sample lookup ---

const WavSample* WavSamplerVoice::FindSample(int note, float velocity) {
    SampleMap* map = m_mapActive;
    if (!map || note < 0 || note > 127) return nullptr;

    // SFZ mode: direct key+velocity range matching
    if (map->useSfzVelocity) {
        int vel127 = static_cast<int>(velocity * 127.0f);
        if (vel127 < 0) vel127 = 0;
        if (vel127 > 127) vel127 = 127;

        // Linear scan: collect samples matching key range and velocity range
        std::vector<const WavSample*> candidates;
        candidates.reserve(16);
        for (int i = 0; i < map->sampleCount; ++i) {
            const WavSample& s = map->samples[i];
            if (note >= s.lokey && note <= s.hikey &&
                vel127 >= s.lovel && vel127 <= s.hivel &&
                !s.isRelease) {
                candidates.push_back(&s);
            }
        }
        if (candidates.empty()) return nullptr;

        // Round-robin among matching candidates
        int rr = m_roundRobin[note] % static_cast<int>(candidates.size());
        m_roundRobin[note] = rr + 1;
        return candidates[rr];
    }

    // mx.samples mode: nearest note + velocity layer lookup

    // Search for nearest note that has samples
    int closestNote = -1;
    for (int offset = 0; offset < 128; ++offset) {
        int lo = note - offset;
        int hi = note + offset;
        if (lo >= 0 && map->noteTable[lo].sampleCount > 0) {
            closestNote = lo;
            break;
        }
        if (hi <= 127 && map->noteTable[hi].sampleCount > 0) {
            closestNote = hi;
            break;
        }
    }

    if (closestNote < 0) return nullptr;

    const auto& entry = map->noteTable[closestNote];
    const WavSample* base = &map->samples[entry.firstSampleIndex];
    int count = entry.sampleCount;

    // Filter out release samples
    std::vector<const WavSample*> candidates; // Note: small, bounded by sample count per note
    candidates.reserve(count);
    for (int i = 0; i < count; ++i) {
        if (!base[i].isRelease) {
            candidates.push_back(&base[i]);
        }
    }
    if (candidates.empty()) {
        // Fall back to including release samples
        for (int i = 0; i < count; ++i) {
            candidates.push_back(&base[i]);
        }
    }
    if (candidates.empty()) return nullptr;

    // Select by velocity layer
    int totalDynamics = candidates[0]->totalDynamics;
    int targetLayer = static_cast<int>(velocity * totalDynamics);
    targetLayer = std::clamp(targetLayer, 1, totalDynamics);

    // Filter to matching dynamic layer
    std::vector<const WavSample*> layerCandidates;
    for (auto* s : candidates) {
        if (s->dynamicLayer == targetLayer) {
            layerCandidates.push_back(s);
        }
    }

    // Fall back to closest layer if exact match not found
    if (layerCandidates.empty()) {
        int bestLayerDist = 999;
        int bestLayer = 1;
        for (auto* s : candidates) {
            int dist = std::abs(s->dynamicLayer - targetLayer);
            if (dist < bestLayerDist) {
                bestLayerDist = dist;
                bestLayer = s->dynamicLayer;
            }
        }
        for (auto* s : candidates) {
            if (s->dynamicLayer == bestLayer) {
                layerCandidates.push_back(s);
            }
        }
    }

    if (layerCandidates.empty()) return candidates[0];

    // Round-robin among variations
    int rr = m_roundRobin[note] % static_cast<int>(layerCandidates.size());
    m_roundRobin[note] = rr + 1;

    return layerCandidates[rr];
}

// --- Voice allocation ---

int WavSamplerVoice::AllocateVoice() {
    // First: find a free slot
    for (int i = 0; i < m_maxPolyphony; ++i) {
        if (m_voices[i].state == SamplerVoiceSlot::State::Off) {
            return i;
        }
    }

    // Steal oldest voice (lowest startTime)
    int oldest = 0;
    uint64_t oldestTime = m_voices[0].startTime;
    for (int i = 1; i < m_maxPolyphony; ++i) {
        if (m_voices[i].startTime < oldestTime) {
            oldestTime = m_voices[i].startTime;
            oldest = i;
        }
    }
    return oldest;
}

float WavSamplerVoice::ComputePlaybackRate(int targetNote, const WavSample* smp) const {
    // SFZ pitch_keytrack: cents per key, default 100 (standard keyboard tracking)
    // pitch_keytrack=0 makes all keys play at the root note pitch (useful for drums)
    float keytrack = 100.0f;
    if (m_useSfzEnvelopes && smp->pitch_keytrack >= 0) {
        keytrack = smp->pitch_keytrack;
    }
    float semitoneDelta = static_cast<float>(targetNote - smp->rootNote) * (keytrack / 100.0f)
                        + m_tuning
                        + static_cast<float>(smp->transpose)
                        + static_cast<float>(smp->tune) / 100.0f;
    float pitchShift = std::pow(2.0f, semitoneDelta / 12.0f);
    float rateAdj = static_cast<float>(smp->sampleRate) / m_sampleRate;
    return pitchShift * rateAdj;
}

// --- ADSR Envelope ---

float WavSamplerVoice::AdvanceEnvelope(SamplerVoiceSlot& voice, float dt) {
    // Map 0-1 params to time values:
    // attack:  0→0.001s, 1→2.0s
    // decay:   0→0.001s, 1→2.0s
    // sustain: 0→0.0, 1→1.0 (level)
    // release: 0→0.001s, 1→3.0s

    auto paramToTime = [](float p, float maxTime) -> float {
        return 0.001f + p * maxTime;
    };

    // Use per-region SFZ values if available, else global knob values
    float attackTime, holdTime, decayTime, sustainLevel, releaseTime;

    if (m_useSfzEnvelopes && voice.sample) {
        const auto& s = *voice.sample;
        attackTime   = (s.ampeg_attack >= 0)  ? s.ampeg_attack  : paramToTime(m_attack, 2.0f);
        holdTime     = (s.ampeg_hold >= 0)    ? s.ampeg_hold    : 0.0f;
        decayTime    = (s.ampeg_decay >= 0)   ? s.ampeg_decay   : paramToTime(m_decay, 2.0f);
        sustainLevel = (s.ampeg_sustain >= 0) ? s.ampeg_sustain / 100.0f : m_sustain;
        releaseTime  = (s.ampeg_release >= 0) ? s.ampeg_release : paramToTime(m_release, 3.0f);
    } else {
        attackTime   = paramToTime(m_attack, 2.0f);
        holdTime     = 0.0f;
        decayTime    = paramToTime(m_decay, 2.0f);
        sustainLevel = m_sustain;
        releaseTime  = paramToTime(m_release, 3.0f);
    }

    // Clamp minimum times to avoid division by zero
    if (attackTime < 0.0001f) attackTime = 0.0001f;
    if (decayTime < 0.0001f) decayTime = 0.0001f;
    if (releaseTime < 0.0001f) releaseTime = 0.0001f;

    voice.envPhase += dt;

    switch (voice.state) {
        case SamplerVoiceSlot::State::Attack: {
            float t = voice.envPhase / attackTime;
            if (t >= 1.0f) {
                voice.envLevel = 1.0f;
                voice.envPhase = 0.0f;
                if (holdTime > 0.0f) {
                    voice.state = SamplerVoiceSlot::State::Hold;
                } else {
                    voice.state = SamplerVoiceSlot::State::Decay;
                }
            } else {
                voice.envLevel = t;
            }
            break;
        }
        case SamplerVoiceSlot::State::Hold: {
            voice.envLevel = 1.0f;
            if (voice.envPhase >= holdTime) {
                voice.state = SamplerVoiceSlot::State::Decay;
                voice.envPhase = 0.0f;
            }
            break;
        }
        case SamplerVoiceSlot::State::Decay: {
            float t = voice.envPhase / decayTime;
            if (t >= 1.0f) {
                voice.envLevel = sustainLevel;
                voice.state = SamplerVoiceSlot::State::Sustain;
                voice.envPhase = 0.0f;
            } else {
                voice.envLevel = 1.0f - t * (1.0f - sustainLevel);
            }
            break;
        }
        case SamplerVoiceSlot::State::Sustain:
            voice.envLevel = sustainLevel;
            break;
        case SamplerVoiceSlot::State::Release: {
            float t = voice.envPhase / releaseTime;
            if (t >= 1.0f) {
                voice.envLevel = 0.0f;
                voice.state = SamplerVoiceSlot::State::Off;
            } else {
                // Release starts from wherever the level was when note-off happened
                voice.envLevel = voice.envLevel * (1.0f - t);
            }
            break;
        }
        case SamplerVoiceSlot::State::Off:
            voice.envLevel = 0.0f;
            break;
    }

    return voice.envLevel;
}

// --- Note control ---

void WavSamplerVoice::NoteOn(int note, float velocity) {
    if (!m_mapActive) return;

    const WavSample* sample = FindSample(note, velocity);
    if (!sample) return;

    // Mute groups: if the new sample has a group, kill active voices whose off_by matches
    if (m_useSfzEnvelopes && sample->group > 0) {
        for (int i = 0; i < m_maxPolyphony; ++i) {
            auto& slot = m_voices[i];
            if (slot.state != SamplerVoiceSlot::State::Off &&
                slot.sample && slot.sample->off_by == sample->group) {
                slot.state = SamplerVoiceSlot::State::Off;
                slot.envLevel = 0.0f;
            }
        }
    }

    int slot = AllocateVoice();
    auto& v = m_voices[slot];

    v.state = SamplerVoiceSlot::State::Attack;
    v.note = note;
    v.velocity = velocity;
    v.playbackRate = ComputePlaybackRate(note, sample);
    v.playhead = static_cast<double>(sample->offset);
    v.sample = sample;
    v.envLevel = 0.0f;
    v.envPhase = 0.0f;
    v.svfIc1eqL = 0.0f;
    v.svfIc2eqL = 0.0f;
    v.svfIc1eqR = 0.0f;
    v.svfIc2eqR = 0.0f;
    v.startTime = ++m_voiceCounter;
}

void WavSamplerVoice::NoteOff(int note) {
    for (int i = 0; i < m_maxPolyphony; ++i) {
        auto& v = m_voices[i];
        if (v.note == note && v.state != SamplerVoiceSlot::State::Off &&
            v.state != SamplerVoiceSlot::State::Release) {
            // OneShot samples ignore note-off — play to completion
            if (v.sample && v.sample->loopMode == WavSample::OneShot) continue;
            // Store current level before transitioning so release can fade from it
            float currentLevel = v.envLevel;
            v.state = SamplerVoiceSlot::State::Release;
            v.envPhase = 0.0f;
            v.envLevel = currentLevel;
        }
    }
}

void WavSamplerVoice::AllNotesOff() {
    for (int i = 0; i < kMaxVoices; ++i) {
        m_voices[i].state = SamplerVoiceSlot::State::Off;
        m_voices[i].envLevel = 0.0f;
    }
}

int WavSamplerVoice::GetActiveVoiceCount() const {
    int count = 0;
    for (int i = 0; i < m_maxPolyphony; ++i) {
        if (m_voices[i].state != SamplerVoiceSlot::State::Off) {
            count++;
        }
    }
    return count;
}

// --- Parameters ---

void WavSamplerVoice::SetLevel(float value) { m_level = std::clamp(value, 0.0f, 1.0f); }
void WavSamplerVoice::SetAttack(float value) { m_attack = std::clamp(value, 0.0f, 1.0f); }
void WavSamplerVoice::SetDecay(float value) { m_decay = std::clamp(value, 0.0f, 1.0f); }
void WavSamplerVoice::SetSustain(float value) { m_sustain = std::clamp(value, 0.0f, 1.0f); }
void WavSamplerVoice::SetRelease(float value) { m_release = std::clamp(value, 0.0f, 1.0f); }
void WavSamplerVoice::SetFilterCutoff(float value) { m_filterCutoff = std::clamp(value, 0.0f, 1.0f); }
void WavSamplerVoice::SetFilterResonance(float value) { m_filterResonance = std::clamp(value, 0.0f, 1.0f); }

void WavSamplerVoice::SetTuning(float semitones) {
    m_tuning = std::clamp(semitones, -24.0f, 24.0f);
}

void WavSamplerVoice::SetUseSfzEnvelopes(bool use) { m_useSfzEnvelopes = use; }

void WavSamplerVoice::SetMaxPolyphony(int voices) {
    m_maxPolyphony = std::clamp(voices, 1, kMaxVoices);
    // Turn off any voices beyond the new limit
    for (int i = m_maxPolyphony; i < kMaxVoices; ++i) {
        m_voices[i].state = SamplerVoiceSlot::State::Off;
    }
}

// --- Render ---

void WavSamplerVoice::Render(float* out_left, float* out_right, size_t size) {
    // Check for pending instrument swap
    CheckSwap();

    if (!m_mapActive || size == 0) {
        std::memset(out_left, 0, size * sizeof(float));
        std::memset(out_right, 0, size * sizeof(float));
        return;
    }

    // Clear output buffers
    std::memset(out_left, 0, size * sizeof(float));
    std::memset(out_right, 0, size * sizeof(float));

    const float dt = 1.0f / m_sampleRate;

    // Render each active voice and accumulate
    for (int v = 0; v < m_maxPolyphony; ++v) {
        auto& voice = m_voices[v];
        if (voice.state == SamplerVoiceSlot::State::Off) continue;
        if (!voice.sample || !voice.sample->data) continue;

        const WavSample* smp = voice.sample;
        const float* data = smp->data;   // Interleaved stereo
        const size_t frames = smp->frameCount;

        // Per-sample volume (dB to linear) and pan (-100..+100)
        const float volGain = std::pow(10.0f, smp->volume / 20.0f);
        const float panNorm = smp->pan / 100.0f;  // -1 to +1
        const float gainL = volGain * std::min(1.0f, 1.0f - panNorm);
        const float gainR = volGain * std::min(1.0f, 1.0f + panNorm);

        // Velocity tracking: amp_veltrack controls how much velocity affects volume
        float veltrack = 1.0f;
        if (m_useSfzEnvelopes && smp->amp_veltrack >= 0) {
            veltrack = smp->amp_veltrack / 100.0f;
        }
        // velGain: when veltrack=100%, equals velocity; when veltrack=0%, equals 1.0
        float velGain = 1.0f - veltrack + veltrack * voice.velocity;

        // Per-voice SVF filter coefficients (computed once per voice per block)
        bool hasSvf = m_useSfzEnvelopes && smp->cutoff > 0.0f;
        float svfG = 0.0f, svfK = 0.0f, svfA1 = 0.0f, svfA2 = 0.0f, svfA3 = 0.0f;
        if (hasSvf) {
            float cutHz = smp->cutoff;
            if (cutHz > m_sampleRate * 0.49f) cutHz = m_sampleRate * 0.49f;
            svfG = std::tan(3.14159265f * cutHz / m_sampleRate);
            // resonance in dB (0-40 range typical) → damping factor
            svfK = 2.0f - 2.0f * std::min(smp->resonance, 40.0f) / 40.0f;
            if (svfK < 0.01f) svfK = 0.01f;
            svfA1 = 1.0f / (1.0f + svfG * (svfG + svfK));
            svfA2 = svfG * svfA1;
            svfA3 = svfG * svfA2;
        }

        for (size_t i = 0; i < size; ++i) {
            // Advance envelope
            float env = AdvanceEnvelope(voice, dt);
            if (voice.state == SamplerVoiceSlot::State::Off) break;

            // Get sample position
            double pos = voice.playhead;

            // Loop handling
            if (smp->loopMode == WavSample::LoopContinuous) {
                double loopS = static_cast<double>(smp->loopStart);
                double loopE = static_cast<double>(smp->loopEnd);
                double loopLen = loopE - loopS;
                if (loopLen > 0.0 && pos >= loopE) {
                    pos = loopS + std::fmod(pos - loopS, loopLen);
                    voice.playhead = pos;
                }
            } else if (smp->loopMode == WavSample::LoopSustain) {
                // Loop only during Attack/Hold/Decay/Sustain — release plays through to end
                if (voice.state != SamplerVoiceSlot::State::Release) {
                    double loopS = static_cast<double>(smp->loopStart);
                    double loopE = static_cast<double>(smp->loopEnd);
                    double loopLen = loopE - loopS;
                    if (loopLen > 0.0 && pos >= loopE) {
                        pos = loopS + std::fmod(pos - loopS, loopLen);
                        voice.playhead = pos;
                    }
                }
            }
            // NoLoop and OneShot: no loop wrapping

            // End-of-sample check
            if (pos >= static_cast<double>(frames - 1)) {
                if (voice.state != SamplerVoiceSlot::State::Release) {
                    voice.state = SamplerVoiceSlot::State::Release;
                    voice.envPhase = 0.0f;
                }
                env = AdvanceEnvelope(voice, dt);
                if (voice.state == SamplerVoiceSlot::State::Off) break;
                continue;
            }

            // 4-point Hermite interpolation for quality pitched playback
            size_t idx0 = static_cast<size_t>(pos);
            size_t idx_m1 = (idx0 > 0) ? idx0 - 1 : 0;
            size_t idx1 = idx0 + 1;
            size_t idx2 = idx0 + 2;
            if (idx1 >= frames) idx1 = idx0;
            if (idx2 >= frames) idx2 = idx1;
            float frac = static_cast<float>(pos - static_cast<double>(idx0));

            // Hermite cubic for left channel (interleaved stereo: L at even indices)
            float y0L = data[idx_m1 * 2], y1L = data[idx0 * 2], y2L = data[idx1 * 2], y3L = data[idx2 * 2];
            float c1L = 0.5f * (y2L - y0L);
            float c2L = y0L - 2.5f * y1L + 2.0f * y2L - 0.5f * y3L;
            float c3L = 0.5f * (y3L - y0L) + 1.5f * (y1L - y2L);
            float sampleL = ((c3L * frac + c2L) * frac + c1L) * frac + y1L;

            // Hermite cubic for right channel (interleaved stereo: R at odd indices)
            float y0R = data[idx_m1 * 2 + 1], y1R = data[idx0 * 2 + 1], y2R = data[idx1 * 2 + 1], y3R = data[idx2 * 2 + 1];
            float c1R = 0.5f * (y2R - y0R);
            float c2R = y0R - 2.5f * y1R + 2.0f * y2R - 0.5f * y3R;
            float c3R = 0.5f * (y3R - y0R) + 1.5f * (y1R - y2R);
            float sampleR = ((c3R * frac + c2R) * frac + c1R) * frac + y1R;

            // Per-voice SVF filter (Cytomic/Zavalishin topology)
            if (hasSvf) {
                // Left channel
                float v3L = sampleL - voice.svfIc2eqL;
                float v1L = svfA1 * voice.svfIc1eqL + svfA2 * v3L;
                float v2L = voice.svfIc2eqL + svfA2 * voice.svfIc1eqL + svfA3 * v3L;
                voice.svfIc1eqL = 2.0f * v1L - voice.svfIc1eqL;
                voice.svfIc2eqL = 2.0f * v2L - voice.svfIc2eqL;

                // Right channel (independent state for true stereo)
                float v3R = sampleR - voice.svfIc2eqR;
                float v1R = svfA1 * voice.svfIc1eqR + svfA2 * v3R;
                float v2R = voice.svfIc2eqR + svfA2 * voice.svfIc1eqR + svfA3 * v3R;
                voice.svfIc1eqR = 2.0f * v1R - voice.svfIc1eqR;
                voice.svfIc2eqR = 2.0f * v2R - voice.svfIc2eqR;

                // Select output based on fil_type: 0=lpf, 1=hpf, 2=bpf
                if (smp->fil_type == 1) {
                    sampleL = v3L - svfK * v1L;  // HPF
                    sampleR = v3R - svfK * v1R;
                } else if (smp->fil_type == 2) {
                    sampleL = v1L;  // BPF
                    sampleR = v1R;
                } else {
                    sampleL = v2L;  // LPF
                    sampleR = v2R;
                }
            }

            // Apply envelope, velocity tracking, level, and per-sample volume/pan
            float baseGain = env * velGain * m_level;
            out_left[i]  += sampleL * baseGain * gainL;
            out_right[i] += sampleR * baseGain * gainR;

            // Advance playhead
            voice.playhead += voice.playbackRate;
        }
    }

    // Apply post-render one-pole low-pass filter if cutoff < 1.0
    if (m_filterCutoff < 0.999f) {
        const float freq = 20.0f * std::pow(1000.0f, m_filterCutoff);
        const float w = 2.0f * 3.14159265f * freq / m_sampleRate;
        const float coeff = std::clamp(w / (1.0f + w), 0.0f, 1.0f);

        for (size_t i = 0; i < size; ++i) {
            m_filterStateL += coeff * (out_left[i] - m_filterStateL);
            m_filterStateR += coeff * (out_right[i] - m_filterStateR);
            out_left[i] = m_filterStateL;
            out_right[i] = m_filterStateR;
        }
    }
}

} // namespace Grainulator

//
//  SfzParser.cpp
//  Grainulator
//
//  Minimal SFZ parser. Handles <control>, <global>, <group>, <region>
//  headers with hierarchical opcode inheritance. Loads WAV samples
//  via dr_wav.
//

#include "SfzParser.h"
#include "dr_wav.h"
#include <cstring>
#include <cstdio>
#include <unordered_map>
#include <fstream>

namespace Grainulator {

// --- Note name parsing (shared with WavSamplerVoice) ---

static int sfzNoteNameToMidi(const std::string& name) {
    if (name.empty()) return -1;

    // Try pure numeric first
    bool allDigits = true;
    bool hasSign = false;
    for (size_t i = 0; i < name.size(); ++i) {
        char c = name[i];
        if (i == 0 && c == '-') { hasSign = true; continue; }
        if (!std::isdigit(static_cast<unsigned char>(c))) { allDigits = false; break; }
    }
    if (allDigits || (hasSign && name.size() > 1)) {
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
        else if (mod == 'b' && pos + 1 < name.size()) { noteBase--; pos++; } // 'b' only if followed by digit
    }

    // Parse octave
    if (pos >= name.size()) return -1;
    std::string octStr = name.substr(pos);
    for (char c : octStr) {
        if (!std::isdigit(static_cast<unsigned char>(c)) && c != '-') return -1;
    }

    int octave = std::atoi(octStr.c_str());
    int midi = (octave + 1) * 12 + noteBase;
    return (midi >= 0 && midi <= 127) ? midi : -1;
}

// --- Opcode storage ---

using OpcodeMap = std::unordered_map<std::string, std::string>;

// Merge src into dst (src overrides dst)
static void mergeOpcodes(OpcodeMap& dst, const OpcodeMap& src) {
    for (const auto& kv : src) {
        dst[kv.first] = kv.second;
    }
}

// --- String utilities ---

static std::string trimWhitespace(const std::string& s) {
    size_t start = s.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return "";
    size_t end = s.find_last_not_of(" \t\r\n");
    return s.substr(start, end - start + 1);
}

static std::string toLowerStr(const std::string& s) {
    std::string result = s;
    for (auto& c : result) c = std::tolower(static_cast<unsigned char>(c));
    return result;
}

// Normalize path separators: backslash to forward slash
static std::string normalizePath(const std::string& p) {
    std::string result = p;
    for (auto& c : result) {
        if (c == '\\') c = '/';
    }
    return result;
}

// Extract directory from a file path
static std::string directoryOf(const std::string& filePath) {
    std::string normalized = normalizePath(filePath);
    size_t lastSlash = normalized.rfind('/');
    if (lastSlash != std::string::npos) {
        return normalized.substr(0, lastSlash);
    }
    return ".";
}

// Extract filename without extension
static std::string filenameWithoutExt(const std::string& filePath) {
    std::string normalized = normalizePath(filePath);
    size_t lastSlash = normalized.rfind('/');
    std::string name = (lastSlash != std::string::npos) ? normalized.substr(lastSlash + 1) : normalized;
    size_t dot = name.rfind('.');
    if (dot != std::string::npos) {
        name = name.substr(0, dot);
    }
    // Replace hyphens/underscores with spaces
    for (auto& c : name) {
        if (c == '-' || c == '_') c = ' ';
    }
    return name;
}

// --- Parse a value that could be a note name or number ---

static int parseNoteOrNumber(const std::string& val) {
    int midi = sfzNoteNameToMidi(val);
    return midi;
}

// --- WAV loading (same pattern as WavSamplerVoice::LoadFromDirectory) ---

struct LoadedWav {
    float* data;        // Interleaved stereo
    size_t frameCount;
    int sampleRate;
    size_t memoryBytes;
    bool valid;
};

static LoadedWav loadWavFile(const std::string& path) {
    LoadedWav result{};
    result.valid = false;

    drwav wav;
    if (!drwav_init_file(&wav, path.c_str(), nullptr)) {
        return result;
    }

    size_t totalFrames = wav.totalPCMFrameCount;
    unsigned int channels = wav.channels;

    // Allocate stereo interleaved buffer
    float* stereoData = new (std::nothrow) float[totalFrames * 2];
    if (!stereoData) {
        drwav_uninit(&wav);
        return result;
    }

    if (channels == 1) {
        float* monoData = new (std::nothrow) float[totalFrames];
        if (!monoData) {
            delete[] stereoData;
            drwav_uninit(&wav);
            return result;
        }
        drwav_read_pcm_frames_f32(&wav, totalFrames, monoData);
        for (size_t i = 0; i < totalFrames; ++i) {
            stereoData[i * 2]     = monoData[i];
            stereoData[i * 2 + 1] = monoData[i];
        }
        delete[] monoData;
    } else if (channels == 2) {
        drwav_read_pcm_frames_f32(&wav, totalFrames, stereoData);
    } else {
        // Multi-channel: take first two channels
        float* rawData = new (std::nothrow) float[totalFrames * channels];
        if (!rawData) {
            delete[] stereoData;
            drwav_uninit(&wav);
            return result;
        }
        drwav_read_pcm_frames_f32(&wav, totalFrames, rawData);
        for (size_t i = 0; i < totalFrames; ++i) {
            stereoData[i * 2]     = rawData[i * channels];
            stereoData[i * 2 + 1] = (channels >= 2) ? rawData[i * channels + 1] : rawData[i * channels];
        }
        delete[] rawData;
    }

    drwav_uninit(&wav);

    result.data = stereoData;
    result.frameCount = totalFrames;
    result.sampleRate = static_cast<int>(wav.sampleRate);
    result.memoryBytes = totalFrames * 2 * sizeof(float);
    result.valid = true;
    return result;
}

// --- Build a WavSample from opcodes + loaded WAV data ---

static WavSample buildSampleFromOpcodes(const OpcodeMap& opcodes,
                                         const LoadedWav& wav) {
    WavSample s{};
    s.data = wav.data;
    s.frameCount = wav.frameCount;
    s.sampleRate = wav.sampleRate;

    // Default values
    s.rootNote = 60;
    s.dynamicLayer = 0;
    s.totalDynamics = 1;
    s.variation = 0;
    s.isRelease = false;
    s.lokey = 0;
    s.hikey = 127;
    s.lovel = 0;
    s.hivel = 127;
    s.loopMode = WavSample::NoLoop;
    s.loopStart = 0;
    s.loopEnd = wav.frameCount > 0 ? wav.frameCount - 1 : 0;
    s.offset = 0;
    s.volume = 0.0f;
    s.pan = 0.0f;
    s.tune = 0;
    s.transpose = 0;

    // SFZ extended fields — sentinel -1 means "not specified, use global"
    s.ampeg_attack = -1.0f;
    s.ampeg_hold = -1.0f;
    s.ampeg_decay = -1.0f;
    s.ampeg_sustain = -1.0f;
    s.ampeg_release = -1.0f;
    s.amp_veltrack = -1.0f;
    s.group = 0;
    s.off_by = 0;
    s.cutoff = 0.0f;
    s.resonance = 0.0f;
    s.fil_type = 0;
    s.pitch_keytrack = -1.0f;

    // Apply opcodes
    for (const auto& kv : opcodes) {
        const std::string& key = kv.first;
        const std::string& val = kv.second;

        if (key == "pitch_keycenter") {
            int n = parseNoteOrNumber(val);
            if (n >= 0) s.rootNote = n;
        } else if (key == "key") {
            int n = parseNoteOrNumber(val);
            if (n >= 0) {
                s.rootNote = n;
                s.lokey = n;
                s.hikey = n;
            }
        } else if (key == "lokey") {
            int n = parseNoteOrNumber(val);
            if (n >= 0) s.lokey = n;
        } else if (key == "hikey") {
            int n = parseNoteOrNumber(val);
            if (n >= 0) s.hikey = n;
        } else if (key == "lovel") {
            s.lovel = std::atoi(val.c_str());
            if (s.lovel < 0) s.lovel = 0;
            if (s.lovel > 127) s.lovel = 127;
        } else if (key == "hivel") {
            s.hivel = std::atoi(val.c_str());
            if (s.hivel < 0) s.hivel = 0;
            if (s.hivel > 127) s.hivel = 127;
        } else if (key == "loop_mode") {
            std::string mode = toLowerStr(val);
            if (mode == "no_loop") s.loopMode = WavSample::NoLoop;
            else if (mode == "one_shot") s.loopMode = WavSample::OneShot;
            else if (mode == "loop_continuous") s.loopMode = WavSample::LoopContinuous;
            else if (mode == "loop_sustain") s.loopMode = WavSample::LoopSustain;
        } else if (key == "loop_start") {
            s.loopStart = static_cast<size_t>(std::atoll(val.c_str()));
        } else if (key == "loop_end") {
            s.loopEnd = static_cast<size_t>(std::atoll(val.c_str()));
        } else if (key == "offset") {
            s.offset = static_cast<size_t>(std::atoll(val.c_str()));
        } else if (key == "end") {
            // Truncate effective frameCount
            size_t endFrame = static_cast<size_t>(std::atoll(val.c_str()));
            if (endFrame + 1 < s.frameCount) {
                s.frameCount = endFrame + 1;
            }
        } else if (key == "volume") {
            s.volume = static_cast<float>(std::atof(val.c_str()));
        } else if (key == "pan") {
            s.pan = static_cast<float>(std::atof(val.c_str()));
            if (s.pan < -100.0f) s.pan = -100.0f;
            if (s.pan > 100.0f) s.pan = 100.0f;
        } else if (key == "tune") {
            s.tune = std::atoi(val.c_str());
        } else if (key == "transpose") {
            s.transpose = std::atoi(val.c_str());
        } else if (key == "trigger") {
            if (toLowerStr(val) == "release") s.isRelease = true;
        }
        // SFZ per-region envelope opcodes
        else if (key == "ampeg_attack") {
            s.ampeg_attack = std::stof(val);
        } else if (key == "ampeg_hold") {
            s.ampeg_hold = std::stof(val);
        } else if (key == "ampeg_decay") {
            s.ampeg_decay = std::stof(val);
        } else if (key == "ampeg_sustain") {
            s.ampeg_sustain = std::stof(val);
        } else if (key == "ampeg_release") {
            s.ampeg_release = std::stof(val);
        }
        // SFZ velocity tracking
        else if (key == "amp_veltrack") {
            s.amp_veltrack = std::stof(val);
        }
        // SFZ mute groups
        else if (key == "group") {
            s.group = std::stoi(val);
        } else if (key == "off_by") {
            s.off_by = std::stoi(val);
        }
        // SFZ per-region filter
        else if (key == "cutoff") {
            s.cutoff = std::stof(val);
        } else if (key == "resonance") {
            s.resonance = std::stof(val);
        } else if (key == "fil_type") {
            std::string ft = toLowerStr(val);
            if (ft == "hpf_2p") s.fil_type = 1;
            else if (ft == "bpf_2p") s.fil_type = 2;
            else s.fil_type = 0;  // lpf_2p default
        }
        // SFZ pitch keytracking
        else if (key == "pitch_keytrack") {
            s.pitch_keytrack = std::stof(val);
        }
        // Unknown opcodes silently ignored
    }

    // Validate loop bounds
    if (s.loopStart >= s.frameCount) s.loopStart = 0;
    if (s.loopEnd >= s.frameCount) s.loopEnd = s.frameCount > 0 ? s.frameCount - 1 : 0;
    if (s.loopStart >= s.loopEnd) s.loopMode = WavSample::NoLoop;
    if (s.offset >= s.frameCount) s.offset = 0;

    return s;
}

// --- Main parser ---

SfzParseResult ParseSfzFile(const char* sfzPath) {
    SfzParseResult result{};
    result.totalMemoryBytes = 0;
    result.success = false;

    // Read entire file
    std::ifstream file(sfzPath);
    if (!file.is_open()) {
        result.errorMessage = "Could not open SFZ file";
        return result;
    }

    std::string content((std::istreambuf_iterator<char>(file)),
                         std::istreambuf_iterator<char>());
    file.close();

    std::string sfzDir = directoryOf(sfzPath);
    result.instrumentName = filenameWithoutExt(sfzPath);

    // Strip comments (// to end of line)
    std::string cleaned;
    cleaned.reserve(content.size());
    for (size_t i = 0; i < content.size(); ++i) {
        if (i + 1 < content.size() && content[i] == '/' && content[i + 1] == '/') {
            // Skip to end of line
            while (i < content.size() && content[i] != '\n') ++i;
            if (i < content.size()) cleaned += '\n';
        } else {
            cleaned += content[i];
        }
    }

    // Tokenize: find <header> tags and opcode=value pairs
    // Headers: <control>, <global>, <group>, <region>
    // Opcodes: key=value (value extends to next opcode or header)

    enum class Section { None, Control, Global, Group, Region };
    Section currentSection = Section::None;

    OpcodeMap controlOpcodes;
    OpcodeMap globalOpcodes;
    OpcodeMap groupOpcodes;

    std::string defaultPath;  // From <control> default_path

    // We parse by scanning for '<' characters to find headers,
    // then collecting opcodes between headers.

    struct Token {
        enum Type { Header, Opcode };
        Type type;
        std::string name;   // Header name or opcode key
        std::string value;  // Opcode value (empty for headers)
    };

    std::vector<Token> tokens;

    // Tokenize the cleaned content
    size_t pos = 0;
    while (pos < cleaned.size()) {
        // Skip whitespace
        while (pos < cleaned.size() && (cleaned[pos] == ' ' || cleaned[pos] == '\t' ||
               cleaned[pos] == '\r' || cleaned[pos] == '\n')) ++pos;
        if (pos >= cleaned.size()) break;

        if (cleaned[pos] == '<') {
            // Header
            size_t end = cleaned.find('>', pos);
            if (end == std::string::npos) break;
            std::string headerName = trimWhitespace(cleaned.substr(pos + 1, end - pos - 1));
            tokens.push_back({Token::Header, toLowerStr(headerName), ""});
            pos = end + 1;
        } else if (cleaned[pos] == '#') {
            // Preprocessor directive (#include, #define) — skip line
            while (pos < cleaned.size() && cleaned[pos] != '\n') ++pos;
        } else {
            // Opcode: key=value
            // Find '='
            size_t eqPos = cleaned.find('=', pos);
            if (eqPos == std::string::npos) break;

            // Key is from pos to eqPos
            std::string key = trimWhitespace(cleaned.substr(pos, eqPos - pos));
            pos = eqPos + 1;

            // Value extends until next opcode (key=) or header (<) or end
            // Special case: 'sample' opcode value can contain spaces
            std::string value;
            if (toLowerStr(key) == "sample") {
                // sample value goes to end of line
                size_t lineEnd = cleaned.find('\n', pos);
                if (lineEnd == std::string::npos) lineEnd = cleaned.size();
                // But stop at next '<' if on same line
                size_t nextHeader = cleaned.find('<', pos);
                if (nextHeader != std::string::npos && nextHeader < lineEnd) {
                    lineEnd = nextHeader;
                }
                value = trimWhitespace(cleaned.substr(pos, lineEnd - pos));
                pos = lineEnd;
            } else {
                // Find next whitespace, '<', or '='
                size_t valStart = pos;
                // Skip leading whitespace
                while (valStart < cleaned.size() && (cleaned[valStart] == ' ' || cleaned[valStart] == '\t')) ++valStart;

                // Value ends at: next whitespace that's followed by word=, or <, or newline
                // Simple approach: value is a single non-whitespace token
                size_t valEnd = valStart;
                while (valEnd < cleaned.size() &&
                       cleaned[valEnd] != ' ' && cleaned[valEnd] != '\t' &&
                       cleaned[valEnd] != '\r' && cleaned[valEnd] != '\n' &&
                       cleaned[valEnd] != '<') {
                    ++valEnd;
                }
                value = cleaned.substr(valStart, valEnd - valStart);
                pos = valEnd;
            }

            if (!key.empty()) {
                tokens.push_back({Token::Opcode, toLowerStr(key), value});
            }
        }
    }

    // Process tokens: build regions with hierarchical opcode inheritance
    OpcodeMap currentRegionOpcodes;
    bool inRegion = false;

    auto finalizeRegion = [&]() {
        if (!inRegion) return;
        inRegion = false;

        // Merge: global < group < region
        OpcodeMap merged = globalOpcodes;
        mergeOpcodes(merged, groupOpcodes);
        mergeOpcodes(merged, currentRegionOpcodes);

        // Must have a sample= opcode
        auto it = merged.find("sample");
        if (it == merged.end() || it->second.empty()) return;

        // Resolve sample path
        std::string samplePath = normalizePath(it->second);

        // Build full path: sfzDir / defaultPath / samplePath
        std::string fullPath;
        if (!samplePath.empty() && samplePath[0] == '/') {
            // Absolute path
            fullPath = samplePath;
        } else {
            fullPath = sfzDir;
            if (!defaultPath.empty()) {
                fullPath += "/" + defaultPath;
            }
            fullPath += "/" + samplePath;
        }

        // Load WAV
        LoadedWav wav = loadWavFile(fullPath);
        if (!wav.valid) return;

        // Build WavSample from merged opcodes
        WavSample sample = buildSampleFromOpcodes(merged, wav);

        result.samples.push_back(sample);
        result.totalMemoryBytes += wav.memoryBytes;
    };

    for (const auto& token : tokens) {
        if (token.type == Token::Header) {
            // Finalize previous region if any
            finalizeRegion();

            if (token.name == "control") {
                currentSection = Section::Control;
                controlOpcodes.clear();
            } else if (token.name == "global") {
                currentSection = Section::Global;
                globalOpcodes.clear();
                groupOpcodes.clear();
            } else if (token.name == "group") {
                currentSection = Section::Group;
                groupOpcodes.clear();
            } else if (token.name == "region") {
                currentSection = Section::Region;
                currentRegionOpcodes.clear();
                inRegion = true;
            } else {
                currentSection = Section::None;
            }
        } else {
            // Opcode
            switch (currentSection) {
                case Section::Control:
                    controlOpcodes[token.name] = token.value;
                    if (token.name == "default_path") {
                        defaultPath = normalizePath(token.value);
                        // Remove trailing slash
                        while (!defaultPath.empty() && defaultPath.back() == '/') {
                            defaultPath.pop_back();
                        }
                    }
                    break;
                case Section::Global:
                    globalOpcodes[token.name] = token.value;
                    break;
                case Section::Group:
                    groupOpcodes[token.name] = token.value;
                    break;
                case Section::Region:
                    currentRegionOpcodes[token.name] = token.value;
                    break;
                case Section::None:
                    // Opcodes outside any header — treat as global
                    globalOpcodes[token.name] = token.value;
                    break;
            }
        }
    }

    // Finalize last region
    finalizeRegion();

    if (result.samples.empty()) {
        result.errorMessage = "No valid regions with samples found in SFZ file";
        return result;
    }

    result.success = true;
    return result;
}

} // namespace Grainulator

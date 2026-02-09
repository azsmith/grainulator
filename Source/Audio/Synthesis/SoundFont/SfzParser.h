//
//  SfzParser.h
//  Grainulator
//
//  Minimal SFZ format parser. Reads .sfz text files and loads referenced
//  WAV samples into WavSample structs for use by WavSamplerVoice.
//  Supports: <control>, <global>, <group>, <region> headers with
//  hierarchical opcode inheritance.
//

#ifndef SFZPARSER_H
#define SFZPARSER_H

#include "WavSamplerVoice.h"
#include <vector>
#include <string>

namespace Grainulator {

struct SfzParseResult {
    std::vector<WavSample> samples;
    size_t totalMemoryBytes;
    std::string instrumentName;
    bool success;
    std::string errorMessage;
};

/// Parse an SFZ file and load all referenced WAV samples.
/// Resolves sample paths relative to the .sfz file location.
/// MUST be called off the audio thread (performs file I/O and allocations).
SfzParseResult ParseSfzFile(const char* sfzPath);

} // namespace Grainulator
#endif // SFZPARSER_H

# CLAUDE.MD — Grainulator

## Project Information

**Project Name:** Grainulator
**Description:** macOS granular/wavetable synthesizer with sequencer, effects, and conversational AI control
**Tech Stack:** Swift 5.9+ (UI/app), C++17 (audio engine), SwiftUI, CoreAudio, AVFoundation, CoreMIDI

## Architecture

- **Audio Engine** (C++): Real-time DSP — granular synthesis (4 voices), Mutable Instruments Plaits (24 engines + 6-OP FM with DX7 patch loading) + Rings, delay, reverb, master filter, mixer. Lock-free, no allocations on audio thread.
- **Application Layer** (Swift): SwiftUI interface, sequencer (step-sequencer-style, 2 tracks x 8 steps), master clock, project save/load, MIDI/controller mapping.
- **Conversational Control Bridge** (Swift): HTTP/1.1 + WebSocket server on `127.0.0.1:4850`. Implements the AI control API for ChatGPT/Claude tool-calling. See `ai-conversational-control-spec.md` and `ai-conversational-control-api-spec.md`.

## Key Directories

- `/Source/Application/` — Swift app layer, SwiftUI views, services
- `/Source/Application/Services/ConversationalControlBridge.swift` — The HTTP bridge (3,980 lines)
- `/Source/Application/Services/ConversationalRoutingCore.swift` — Pure routing/scheduling helpers
- `/Source/Audio/` — C++ audio engine (Core, Synthesis, Effects, Mixer)
- `/Tests/` — Unit tests including ConversationalRoutingCoreTests
- `/Resources/` — Assets, presets, samples
- `/scripts/` — Test and utility scripts

## Conversational Control API

The bridge exposes 18+ endpoints on `http://127.0.0.1:4850/v1`:
- Session management (create/delete with bearer token auth)
- State reads (full snapshot, path queries, history)
- Action bundles (validate → schedule, with timing/quantization)
- Recording control (start/stop/feedback/mode per voice)
- WebSocket event stream at `/v1/events`

Spec files:
- `ai-conversational-control-spec.md` — System architecture and design
- `ai-conversational-control-api-spec.md` — API endpoint details
- `ai-conversational-control-openapi.yaml` — OpenAPI 3.1.0 schema

## Build & Run

```bash
swift build
# or open in Xcode and build for macOS
```

## Testing

```bash
# Unit tests
swift test

# Bridge smoke test (requires Grainulator running)
./scripts/test-bridge.sh
```

## Claude Skills

- `/grainulator` — Conversational control skill. Creates a session, reads state, and controls the synth through natural language. Pass musical instructions as arguments.

## Guidelines for Claude

**When working on this project:**
- The audio engine is C++ and real-time safe — never add allocations, locks, or blocking calls to audio-thread code
- All state mutations go through the bridge's `recordMutation()` which increments `stateVersion` and emits events
- Use `DispatchQueue.main.sync` + `MainActor.assumeIsolated` pattern when reading/writing engine state from the bridge queue
- Parameter values are normalized 0.0-1.0 in the engine; the bridge converts to/from user-facing units
- Idempotency keys are required on all write endpoints
- The sequencer uses a step-sequencer-style model: stages with noteSlot, probability, ratchets, gateMode, stepType

**Allowed tool permissions:**
- `Bash(curl*127.0.0.1:4850*)` — Grainulator conversational control API calls
- `Bash(curl*localhost:4850*)` — Grainulator conversational control API calls

**Avoid:**
- Blocking the audio thread
- Adding network calls or file I/O to real-time paths
- Breaking the validate-then-schedule two-phase commit pattern
- Modifying engine C++ without understanding the lock-free command queue

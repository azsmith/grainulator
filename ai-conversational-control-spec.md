# Grainulator Conversational AI Control Specification

## Table of Contents
1. [Document Status](#1-document-status)
2. [Problem Statement](#2-problem-statement)
3. [Goals and Non-Goals](#3-goals-and-non-goals)
4. [User Experience Model](#4-user-experience-model)
5. [System Architecture](#5-system-architecture)
6. [Canonical State Model](#6-canonical-state-model)
7. [Intent and Action Model](#7-intent-and-action-model)
8. [Real-Time Musical Control Rules](#8-real-time-musical-control-rules)
9. [File and Asset Intelligence](#9-file-and-asset-intelligence)
10. [Safety, Security, and Reliability](#10-safety-security-and-reliability)
11. [Observability and Evaluation](#11-observability-and-evaluation)
12. [Implementation Plan](#12-implementation-plan)
13. [Acceptance Criteria](#13-acceptance-criteria)

---

## 1. Document Status

- **Version**: 0.1
- **Status**: Draft for implementation
- **Primary audience**: Product, audio engine, application, and AI integration engineers
- **Related document**: `ai-conversational-control-api-spec.md`

---

## 2. Problem Statement

Grainulator currently supports direct manual control via UI and controllers. The target capability is to add a conversational AI interface (for example, ChatGPT or Claude Code) that can:

1. Interpret musical language from the user.
2. Access and control all app configuration domains:
   - Sequencer
   - Synth settings
   - Granular and loop settings
   - Granular and loop recording state (replace/overdub/live) and feedback
   - Granular and loop file selection
   - Effects and mix routing
3. Work in both:
   - **One-time setup** workflows (designing a complete patch/state)
   - **Live performance** workflows (real-time musical adjustments)

The system must remain musically coherent and real-time safe under performance conditions.

---

## 3. Goals and Non-Goals

### 3.1 Goals

- Support natural-language musical intent, not only direct knob-level commands.
- Provide deterministic, reversible control of all exposed domains.
- Preserve audio-thread safety (no blocking calls, no dynamic allocations on audio thread).
- Enable beat/bar-aware parameter changes with smoothing and quantization.
- Produce transparent feedback on what changed, when, and why.

### 3.2 Non-Goals (v1)

- Full autonomous songwriting without user input.
- Direct LLM execution inside the audio thread.
- Replacing manual controls; AI is additive and optional.

---

## 4. User Experience Model

### 4.1 Interaction Modes

- **Design mode**: Build an initial setup from descriptive prompts.
  - Example: "Create a warm, evolving granular pad with sparse rhythmic accents."
- **Perform mode**: Apply live adjustments with timing semantics.
  - Example: "Open the filter over the next 8 bars, then dry up the reverb."
- **Explain mode**: Describe changes in musical and technical language.
  - Example: "What did you change to make it brighter?"

### 4.2 Utterance Classes

- **Descriptive**: sonic adjectives and high-level goals.
- **Directive**: explicit parameter or module instructions.
- **Structural**: scene/song-section planning ("verse", "build", "drop").
- **Asset intent**: file content constraints (key, BPM, texture, brightness).

### 4.3 Response Behavior

- **Low-risk changes**: auto-apply and confirm.
- **Medium/high-risk changes**: propose a musical diff and require confirmation when policy says so.
- Confirmation format should include:
  - What will change
  - Timing anchor (now/beat/bar)
  - Duration and ramp shape
  - Expected sonic result

### 4.4 Temporal Semantics

All user-facing and machine-facing operations support:

- `anchor`: `now`, `next_beat`, `next_bar`, `at_transport_position`
- `duration`: milliseconds, beats, or bars
- `quantization`: off, 1/16, 1/8, 1/4, 1 bar
- `curve`: linear, ease in/out, exponential (allowed per-parameter)

---

## 5. System Architecture

### 5.1 Architectural Principle

Separate the system into two loops:

1. **Meaning Loop (AI)**: interprets language and plans actions.
2. **Sound Loop (Engine)**: applies deterministic real-time-safe commands.

The AI planner never writes to DSP internals directly.

### 5.2 Components

1. **Chat Connector Layer**
   - Adapters for ChatGPT and Claude tool-calling patterns.
   - Session, context, and capability negotiation.
2. **Intent Planner**
   - LLM-facing parser and planner from text to structured intent.
3. **Policy and Musical Guardrail Engine**
   - Bounds checking, dependency validation, risk scoring.
   - Time quantization and smooth-transition enforcement.
4. **Action Scheduler**
   - Converts validated actions into timestamped trajectories.
5. **Engine Adapters**
   - Typed adapters for sequencer/synth/granular/loop/fx/files/transport.
6. **Canonical State Store + Event Log**
   - Full history of AI and manual mutations.
   - Undo/redo and session replay.
7. **Scene Manager**
   - Save/recall/morph named states.

### 5.3 Threading and Dataflow

- LLM planning and policy checks run off audio thread.
- Action scheduler emits lock-free command messages to control queue.
- Audio thread consumes validated commands only.
- All state mutations are serialized through a single control runtime commit path.

---

## 6. Canonical State Model

Canonical state is the single source of truth for all controllable domains.

```json
{
  "stateVersion": 1289,
  "schemaVersion": "0.1.0",
  "session": {
    "tempoBpm": 120.0,
    "timeSignature": "4/4",
    "key": "A minor"
  },
  "transport": {
    "playing": true,
    "bar": 17,
    "beat": 2.5
  },
  "sequencer": {
    "chords": {
      "enabled": true,
      "clockDivision": "x1",
      "steps": [
        {"step": 1, "degree": "I", "quality": "maj", "active": true, "displayName": "I", "notes": ["C", "E", "G"]},
        {"step": 2, "degree": "V", "quality": "maj", "active": true, "displayName": "V", "notes": ["G", "B", "D"]}
      ]
    }
  },
  "synth": {},
  "granular": {},
  "loop": {},
  "fx": {},
  "files": {},
  "scenes": []
}
```

Recording-related canonical paths include:

- `granular.<voiceId>.recording.active`
- `granular.<voiceId>.recording.mode`
- `granular.<voiceId>.recording.feedback`
- `loop.<voiceId>.recording.active`
- `loop.<voiceId>.recording.mode`
- `loop.<voiceId>.recording.feedback`

### 6.1 Parameter Metadata Requirements

Every parameter exposed to AI includes:

- `path` (for example, `granular.density`)
- `type` (`bool`, `int`, `float`, `enum`)
- `range` (`min`, `max`)
- `unit` (`ratio`, `hz`, `semitones`, `db`, etc.)
- `default`
- `safeUpdateMode` (`immediate`, `smoothed`, `quantized`)
- `smoothingMinMs`
- `musicalTags` (`brightness`, `density`, `motion`, `space`, `rhythm`)
- `riskClass` (`low`, `medium`, `high`)

### 6.2 Path and Versioning Rules

- Canonical path addressing is absolute from root modules (for example, `transport.beat`, `granular.density`).
- Every successful write increments `stateVersion` by exactly 1.
- Every event emitted from runtime includes the resulting `stateVersion`.
- Clients can use `stateVersion` preconditions to prevent stale scheduling in live contexts.

---

## 7. Intent and Action Model

### 7.1 Intent Object

The planner converts user language into a structured intent object:

```json
{
  "intentId": "intent_20260205_001",
  "mode": "perform",
  "goals": ["increase intensity", "preserve groove clarity"],
  "constraints": {
    "lockModules": ["sequencer"],
    "maxRisk": "medium"
  },
  "requestedTiming": {
    "anchor": "next_bar",
    "durationBars": 8
  }
}
```

### 7.2 Action Types

Supported action types in v1:

- `set`
- `ramp`
- `toggle`
- `trigger`
- `loadFile`
- `startRecording`
- `stopRecording`
- `setRecordingFeedback`
- `setRecordingMode`
- `saveScene`
- `recallScene`
- `morphScene`

### 7.3 Action Contract

```json
{
  "actionId": "act_001",
  "type": "ramp",
  "target": "granular.density",
  "from": 0.35,
  "to": 0.52,
  "time": {
    "anchor": "next_bar",
    "durationBars": 4,
    "quantization": "1/16"
  },
  "curve": "easeInOut",
  "reason": "Increase texture while avoiding abrupt onset"
}
```

### 7.4 Musical Diff

Before applying medium/high-risk changes, the system generates a musical diff:

- Parameter paths and values before/after
- Timing and ramp shape
- Expected sonic intent statement
- Confirmation requirement (if policy flags)

### 7.5 Bundle Semantics

- `atomic = true`: all actions in bundle commit or bundle is rejected.
- `atomic = false`: runtime may apply valid actions and return per-action failures.
- Bundles can include `preconditionStateVersion` to guard against stale reads.
- Any bundle that crosses policy threshold requires a short-lived confirmation token from validation.

---

## 8. Real-Time Musical Control Rules

### 8.1 Real-Time Safety

- No network, file IO, or memory allocation on audio thread.
- No locks on audio thread.
- Command queue must be lock-free and bounded.

### 8.2 Transition Policies

- Click-prone parameters require smoothing.
- Structural changes default to bar boundary quantization.
- Multiple related parameters should be trajectory-coordinated.
- Recording feedback changes always use smoothing, including in live mode.

### 8.3 Descriptor-to-Macro Mapping

Descriptors map to coordinated changes, not isolated knob jumps.

- `brighter`: cutoff up, high-shelf up, grain size down slightly
- `warmer`: cutoff down, saturation mild up, transients softened
- `more intense`: density up, drive up, dynamics guard enabled
- `more space`: reverb mix/decay up with wet/dry guardrails

### 8.4 Conflict Resolution

If manual and AI changes conflict:

- Priority order is `emergency` > `manual direct` > `scheduled automation/AI`.
- For equal priority, earliest scheduler commit order wins for determinism.
- Locked module updates are rejected with actionable feedback.

### 8.5 Clock and Scheduling Semantics

- Musical timing anchors are resolved against the transport sample clock, not wall clock.
- Scheduler computes target sample offsets at validation time and re-checks at commit time.
- If commit misses the requested quantization boundary, action rolls to the next valid boundary unless marked `strict`; strict actions fail fast.

---

## 9. File and Asset Intelligence

### 9.1 Asset Metadata

Each loop/granular file should be indexed with:

- Musical: key, bpm, meter, length bars
- Timbral: spectral centroid, brightness score, noisiness
- Rhythmic: transient density, syncopation estimate
- Tags: user tags and generated tags

### 9.2 File Query Semantics

AI queries can combine:

- Semantic filters ("dark", "airy", "percussive")
- Numeric constraints (BPM range, key/mode)
- Context constraints (current tempo/key)

### 9.3 Safe File Swaps

- Pre-buffer before switching
- Quantized swap at beat/bar boundary
- Optional crossfade window for continuity

### 9.4 Recording and Live Input Behavior

- Recording actions are voice-scoped for both granular and loop modules.
- Supported modes in v1: `replace`, `overdub`, `append`, `live_overdub`.
- `live_overdub` captures live input while mixing playback based on recording feedback.
- Feedback range is normalized (`0.0` to `1.0`) and represented as "input-vs-playback blend" for conversational UX.

---

## 10. Safety, Security, and Reliability

### 10.1 Permissions

- Local bridge defaults to loopback-only access.
- Explicit user session consent required for control.
- Tool-level permissions (read-only vs write/apply).

### 10.2 Guardrails

- Range enforcement and enum validation.
- Dependency checks (for example, cannot morph missing scenes).
- High-risk operations can require confirmation.
- Recording start is rejected if the target voice is already recording.
- Recording stop is rejected if the target voice is not recording.

### 10.3 Failure Behavior

- If AI planner fails/unavailable, app remains fully usable manually.
- Invalid actions return structured errors and suggestions.
- Partial action bundles can be all-or-nothing based on requested atomicity.
- Queue saturation must return explicit retry semantics; runtime must not drop accepted actions silently.
- Confirmation tokens expire quickly to avoid delayed high-risk execution in changed musical context.

---

## 11. Observability and Evaluation

### 11.1 Event Logging

Log at minimum:

- User intent hash/session ID
- Request correlation ID / idempotency key
- Parsed intent
- Approved/rejected actions with reasons
- Applied timestamps and measured latency

### 11.2 Metrics

- Intent-to-apply latency (p50/p95)
- Action rejection rate
- Undo/redo rate after AI changes
- Audio glitch count during AI actions
- User correction frequency

### 11.3 Debug Tooling

- Action timeline inspector
- Parameter trajectory visualization
- Scene diff viewer

---

## 12. Implementation Plan

### Phase 1: Control Foundation

- Canonical state schema
- Parameter metadata surface
- Action scheduler with quantized timing
- Event log and undo/redo primitives
- `stateVersion` precondition checks and idempotency plumbing

### Phase 2: AI Planning + Policy

- Intent parser/planner integration
- Risk classification and guardrail engine
- Low-risk auto-apply path + diff generation

### Phase 3: Musical Abstractions

- Descriptor-to-macro mapping
- Scene save/recall/morph
- Asset intelligence indexing and retrieval
- Recording intent handling (live capture, overdub density, feedback choreography)

### Phase 4: Connector and Hardening

- ChatGPT/Claude connector adapters
- Observability dashboards and QA stress tests
- UX tuning and confidence calibration

---

## 13. Acceptance Criteria

The feature is accepted for v1 when all conditions below hold:

1. A user can create a full multi-module setup via conversation.
2. A user can apply live musical changes at beat/bar boundaries.
3. AI-driven changes are undoable and visible in history.
4. Changes remain artifact-free under normal CPU headroom.
5. Asset selection from natural-language prompts is musically relevant.
6. The app remains functional if the conversational layer is offline.
7. Control writes are deterministic under concurrent manual and AI updates.
8. Conversational recording control works for granular and loop voices, including live mode with adjustable feedback.

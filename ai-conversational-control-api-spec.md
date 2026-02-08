# Grainulator Conversational Control API Specification

## Table of Contents
1. [Document Status](#1-document-status)
2. [Scope and Design Principles](#2-scope-and-design-principles)
3. [Transport and Session Model](#3-transport-and-session-model)
4. [Core Data Types](#4-core-data-types)
5. [Endpoints](#5-endpoints)
6. [Event Stream](#6-event-stream)
7. [Error Model](#7-error-model)
8. [Policy and Risk Model](#8-policy-and-risk-model)
9. [Real-Time Constraints and SLAs](#9-real-time-constraints-and-slas)
10. [Versioning and Compatibility](#10-versioning-and-compatibility)
11. [Reference Flows](#11-reference-flows)

---

## 1. Document Status

- **Version**: 0.1
- **Status**: Draft for implementation
- **Depends on**: `ai-conversational-control-spec.md`
- **Audience**: AI connector, app runtime, and engine integration engineers

---

## 2. Scope and Design Principles

### 2.1 Scope

This API defines how a conversational client (for example, ChatGPT or Claude connector) can:

- Discover capabilities and parameter metadata
- Read canonical state
- Propose and apply time-aware actions
- Control recording on granular and loop voices, including live overdub feedback
- Manage scenes and file selection
- Observe execution and state changes

### 2.2 Design Principles

- Deterministic execution in runtime
- Strongly typed payloads
- Real-time-safe command emission
- Explicit risk and policy handling
- Backward-compatible API evolution
- Deterministic conflict handling under concurrent manual and AI writes

---

## 3. Transport and Session Model

### 3.1 Transport

- **Control API**: HTTP/JSON (localhost only in v1)
- **Event API**: WebSocket (localhost only in v1)
- **Default base URL**: `http://127.0.0.1:4850/v1`
- **Default events URL**: `ws://127.0.0.1:4850/v1/events`

### 3.2 Session Lifecycle

1. Client creates a session.
2. Session returns a bearer token and negotiated capability set.
3. Client uses token for subsequent requests.
4. Session expires on timeout or explicit close.

### 3.3 Authentication

- `Authorization: Bearer <session-token>`
- Tokens are short-lived and bound to loopback source.
- v1 does not expose remote network access.

### 3.4 Idempotency

- Write endpoints accept `idempotencyKey`.
- Reusing the same key with the same payload returns the original result (`200` with `idempotentReplay: true`).
- Reusing the same key with a different payload returns `409`.

---

## 4. Core Data Types

### 4.1 Capability

```json
{
  "module": "granular",
  "actions": ["set", "ramp", "toggle", "loadFile", "startRecording", "stopRecording", "setRecordingFeedback", "setRecordingMode"],
  "paths": ["granular.density", "granular.size", "granular.position", "granular.<voiceId>.recording.feedback", "granular.<voiceId>.recording.active"]
}
```

Example for chords module:

```json
{
  "module": "chords",
  "description": "8-step chord progression sequencer",
  "actions": ["set", "toggle"],
  "paths": [
    "sequencer.chords.enabled",
    "sequencer.chords.clockDivision",
    "sequencer.chords.preset",
    "sequencer.chords.step<1-8>.degree",
    "sequencer.chords.step<1-8>.quality",
    "sequencer.chords.step<1-8>.active",
    "sequencer.chords.step<1-8>.clear"
  ]
}
```

### 4.2 ParameterSpec

```json
{
  "path": "granular.<voiceId>.recording.feedback",
  "type": "float",
  "min": 0.0,
  "max": 1.0,
  "default": 0.5,
  "unit": "ratio",
  "safeUpdateMode": "smoothed",
  "smoothingMinMs": 30,
  "quantizable": true,
  "riskClass": "medium",
  "musicalTags": ["recording", "blend", "continuity"]
}
```

### 4.3 TimeSpec

```json
{
  "anchor": "next_bar",
  "quantization": "1/16",
  "durationMs": null,
  "durationBeats": null,
  "durationBars": 4
}
```

Rules:

- Exactly one of `durationMs`, `durationBeats`, or `durationBars` may be non-null.
- If all durations are null, action is treated as instantaneous.
- `quantization` is required for beat/bar anchors and ignored for `now`.

### 4.4 Action

```json
{
  "actionId": "act_001",
  "type": "setRecordingFeedback",
  "target": "granular.voiceA.recording.feedback",
  "value": null,
  "from": 0.35,
  "to": 0.6,
  "curve": "easeInOut",
  "time": {
    "anchor": "next_bar",
    "quantization": "1/16",
    "durationBars": 2
  },
  "reason": "increase live-overdub persistence gradually"
}
```

Action type notes:

- Recording-related action types are `startRecording`, `stopRecording`, `setRecordingFeedback`, `setRecordingMode`.
- `startRecording` and `stopRecording` can be quantized like any other action.
- `setRecordingFeedback` is valid only for voices where recording mode supports feedback (`overdub`, `live_overdub`).

### 4.5 ActionBundle

```json
{
  "bundleId": "bundle_019f",
  "intentId": "intent_20260205_001",
  "validationId": "val_00a1",
  "preconditionStateVersion": 1289,
  "atomic": true,
  "requireConfirmation": false,
  "actions": []
}
```

### 4.6 MusicalDiff

```json
{
  "bundleId": "bundle_019f",
  "risk": "medium",
  "summary": "Brighter and denser over 4 bars",
  "changes": [
    {
      "path": "granular.density",
      "before": 0.35,
      "after": 0.52
    }
  ],
  "timing": {
    "anchor": "next_bar",
    "durationBars": 4
  }
}
```

### 4.7 RecordingMode

Supported recording modes:

- `replace`
- `overdub`
- `append`
- `live_overdub`

### 4.8 VoiceRecordingState

```json
{
  "voiceId": "granular.voiceA",
  "module": "granular",
  "isRecording": true,
  "mode": "live_overdub",
  "feedback": 0.42,
  "inputLevel": 0.31,
  "recordedDurationMs": 18450
}
```

---

## 5. Endpoints

### 5.1 Create Session

- `POST /sessions`

Request:

```json
{
  "client": {
    "name": "claude-connector",
    "version": "0.1.0"
  },
  "requestedScopes": ["state:read", "control:write", "recording:write", "scenes:write", "files:read"],
  "userLabel": "Live set rehearsal"
}
```

Response `201`:

```json
{
  "sessionId": "sess_10f3",
  "token": "redacted",
  "expiresAt": "2026-02-05T18:15:00Z",
  "capabilities": []
}
```

### 5.2 Close Session

- `DELETE /sessions/{sessionId}`
- Response `204`

### 5.3 Get Capabilities

- `GET /capabilities`
- Response `200`: array of `Capability`

### 5.4 List Parameters

- `GET /parameters?module=granular`
- Response `200`: array of `ParameterSpec`

### 5.5 Get Canonical State

- `GET /state`
- Response `200`: full state snapshot

### 5.6 Get State Slice

- `POST /state/query`

Request:

```json
{
  "paths": ["transport", "granular.density", "fx.reverb.mix"]
}
```

Response `200`:

```json
{
  "values": {
    "transport": {"playing": true, "bar": 17, "beat": 2.5},
    "granular.voiceA.recording.active": false,
    "granular.voiceA.recording.feedback": 0.5,
    "fx.reverb.mix": 0.24
  },
  "stateVersion": 1289
}
```

### 5.7 Validate Actions

- `POST /actions/validate`

Request:

```json
{
  "bundle": {
    "bundleId": "bundle_019f",
    "intentId": "intent_20260205_001",
    "atomic": true,
    "actions": []
  },
  "policy": {
    "maxRisk": "medium",
    "lockModules": ["sequencer"]
  }
}
```

Response `200`:

```json
{
  "valid": true,
  "validationId": "val_00a1",
  "risk": "low",
  "requiresConfirmation": false,
  "confirmationToken": null,
  "confirmationTokenExpiresAt": null,
  "normalizedBundle": {},
  "musicalDiff": {}
}
```

### 5.8 Schedule Actions

- `POST /actions/schedule`

Request:

```json
{
  "bundle": {
    "bundleId": "bundle_019f",
    "intentId": "intent_20260205_001",
    "validationId": "val_00a1",
    "preconditionStateVersion": 1289,
    "atomic": true,
    "actions": []
  },
  "applyMode": "validated_only",
  "confirmationToken": null,
  "idempotencyKey": "36ce6f0c-1034-4a6a-b743-83a85137d5af"
}
```

Response `202`:

```json
{
  "bundleId": "bundle_019f",
  "status": "scheduled",
  "idempotentReplay": false,
  "scheduledAtTransport": {"bar": 18, "beat": 1.0},
  "stateVersion": 1290
}
```

`applyMode` values:

- `validated_only`: requires a valid `validationId`, and for high-risk bundles requires a non-expired `confirmationToken`
- `best_effort`: runtime revalidates and may schedule only valid actions when `atomic` is false

### 5.9 List Scheduled Bundles

- `GET /actions/scheduled`
- Response `200`: queue view with statuses (`scheduled`, `in_progress`, `applied`, `partially_applied`, `rejected`, `canceled`, `expired`)

### 5.10 Cancel Scheduled Bundle

- `POST /actions/{bundleId}/cancel`
- Response `200`:

```json
{
  "bundleId": "bundle_019f",
  "status": "canceled"
}
```

### 5.11 Undo

- `POST /history/undo`
- Response `200`:

```json
{
  "applied": true,
  "stateVersion": 1291,
  "revertedBundleId": "bundle_019f"
}
```

### 5.12 Redo

- `POST /history/redo`
- Response `200`:

```json
{
  "applied": true,
  "stateVersion": 1292,
  "reappliedBundleId": "bundle_019f"
}
```

### 5.13 Save Scene

- `POST /scenes`

Request:

```json
{
  "name": "Verse A",
  "description": "Lower density, softer highs",
  "includeModules": ["granular", "loop", "fx"]
}
```

Response `201`:

```json
{
  "sceneId": "scene_0012",
  "name": "Verse A"
}
```

### 5.14 Recall Scene

- `POST /scenes/{sceneId}/recall`

Request:

```json
{
  "time": {
    "anchor": "next_bar",
    "durationBars": 2,
    "quantization": "1/16"
  },
  "mode": "morph"
}
```

Response `202`

### 5.15 Search Files

- `POST /files/search`

Request:

```json
{
  "query": "dark sparse percussion",
  "constraints": {
    "bpmMin": 85,
    "bpmMax": 100,
    "key": "A minor"
  },
  "limit": 20
}
```

Response `200`:

```json
{
  "results": [
    {
      "fileId": "file_17",
      "path": "/Users/andysmith/samples/drums/dark_loop_01.wav",
      "score": 0.89,
      "features": {
        "bpm": 92,
        "key": "A minor",
        "brightness": 0.21,
        "transientDensity": 0.31
      }
    }
  ]
}
```

### 5.16 Load File

- `POST /files/{fileId}/load`

Request:

```json
{
  "target": "loop.slotA",
  "time": {"anchor": "next_bar"},
  "crossfadeMs": 80
}
```

Response `202`:

```json
{
  "status": "scheduled",
  "target": "loop.slotA"
}
```

### 5.17 List Recording States

- `GET /recording/voices`
- Response `200`: array of `VoiceRecordingState`

### 5.18 Start Voice Recording

- `POST /recording/voices/{voiceId}/start`

Request:

```json
{
  "mode": "live_overdub",
  "feedback": 0.42,
  "time": {"anchor": "next_bar", "quantization": "1/16"},
  "idempotencyKey": "5cb5d75f-ecf9-46eb-9bb8-f212cfaf3129"
}
```

Response `202`:

```json
{
  "voiceId": "granular.voiceA",
  "status": "scheduled",
  "scheduledAtTransport": {"bar": 33, "beat": 1.0}
}
```

### 5.19 Stop Voice Recording

- `POST /recording/voices/{voiceId}/stop`

Request:

```json
{
  "time": {"anchor": "next_bar", "quantization": "1/16"},
  "idempotencyKey": "a63ee4ee-88da-4cf4-a92f-3935dc1b2cf3"
}
```

Response `202`:

```json
{
  "voiceId": "granular.voiceA",
  "status": "scheduled"
}
```

### 5.20 Set Recording Feedback

- `POST /recording/voices/{voiceId}/feedback`

Request:

```json
{
  "value": 0.55,
  "time": {"anchor": "next_beat", "durationBeats": 2, "quantization": "1/16"},
  "idempotencyKey": "9d3d9666-ef58-4cc0-b618-f7f89bcfd5d3"
}
```

Response `202`:

```json
{
  "voiceId": "loop.voiceB",
  "status": "scheduled",
  "target": "loop.voiceB.recording.feedback",
  "scheduledAtTransport": {"bar": 33, "beat": 2.0}
}
```

### 5.21 Set Recording Mode

- `POST /recording/voices/{voiceId}/mode`

Request:

```json
{
  "mode": "live_overdub",
  "time": {"anchor": "next_beat", "quantization": "1/16"},
  "idempotencyKey": "f6c7d7ec-2528-47a0-af95-bf3273b529ad"
}
```

Response `202`:

```json
{
  "voiceId": "loop.voiceB",
  "status": "scheduled",
  "target": "loop.voiceB.recording.mode",
  "scheduledAtTransport": {"bar": 33, "beat": 2.0}
}
```

### 5.22 Get Activity History

- `GET /history`
- Returns recent activity events for the authenticated session, including global events.
- Intended for chat clients to build short-term conversational context.

Query parameters:

- `limit` (optional, default `100`, range `1..500`)
- `afterSeq` (optional, exclusive lower bound)
- `beforeSeq` (optional, exclusive upper bound)
- `types` (optional, comma-separated event type filter)
- `includeStateChanged` (optional, default `true`)

Response `200`:

```json
{
  "sessionId": "sess_93D1DAF2",
  "stateVersion": 42,
  "activities": [
    {
      "eventId": "evt_119",
      "seq": 119,
      "type": "sequencer.step_updated",
      "ts": "2026-02-05T21:13:08.100Z",
      "sessionId": null,
      "scope": "global",
      "stateVersion": 42,
      "summary": "Track 1 step 1 ratchets updated",
      "payload": {
        "track": 1,
        "step": 1,
        "field": "ratchets",
        "value": 4
      }
    }
  ],
  "paging": {
    "limit": 100,
    "returned": 1,
    "hasMore": false,
    "nextBeforeSeq": null,
    "newestSeq": 119,
    "oldestSeq": 119
  },
  "filters": {
    "afterSeq": null,
    "beforeSeq": null,
    "types": [],
    "includeStateChanged": true
  }
}
```

---

## 6. Event Stream

Connect with bearer token to:

- `GET ws://127.0.0.1:4850/v1/events?afterSeq=<n>`

### 6.1 Event Envelope

```json
{
  "eventId": "evt_0319",
  "seq": 10422,
  "type": "actions.bundle_applied",
  "ts": "2026-02-05T18:01:21.321Z",
  "sessionId": "sess_10f3",
  "stateVersion": 1290,
  "payload": {}
}
```

### 6.2 Event Types

- `state.changed`
- `actions.bundle_scheduled`
- `actions.bundle_started`
- `actions.bundle_applied`
- `actions.bundle_rejected`
- `actions.bundle_canceled`
- `transport.tick`
- `scene.saved`
- `scene.recalled`
- `file.loaded`
- `recording.started`
- `recording.stopped`
- `recording.feedback_changed`
- `recording.mode_changed`
- `events.gap_detected`

### 6.3 Required Payload Fields

- `state.changed`: `changedPaths`, `stateVersion`
- `actions.bundle_rejected`: `bundleId`, `errors[]`, `risk`
- `transport.tick`: `bar`, `beat`, `tempoBpm`
- `recording.started`: `voiceId`, `mode`, `feedback`
- `recording.stopped`: `voiceId`, `recordedDurationMs`
- `recording.feedback_changed`: `voiceId`, `previous`, `current`
- `recording.mode_changed`: `voiceId`, `previous`, `current`
- `events.gap_detected`: `expectedSeq`, `actualSeq`, `recoveryHint`

---

## 7. Error Model

### 7.1 HTTP Status Usage

- `400` malformed payload
- `401` unauthorized or expired token
- `403` forbidden by scope/policy
- `404` missing resource
- `409` version or idempotency conflict
- `422` semantically invalid action
- `429` rate-limited
- `500` internal error

### 7.2 Structured Error Body

```json
{
  "error": {
    "code": "ACTION_OUT_OF_RANGE",
    "message": "granular.density must be within [0.0, 1.0]",
    "details": {
      "path": "granular.density",
      "provided": 1.4,
      "min": 0.0,
      "max": 1.0
    },
    "suggestions": [
      "Clamp to 1.0",
      "Use ramp over 2 bars for smoother increase"
    ]
  }
}
```

### 7.3 Canonical Error Codes

- `ACTION_OUT_OF_RANGE`
- `ACTION_PATH_UNKNOWN`
- `ACTION_TYPE_UNSUPPORTED`
- `MODULE_LOCKED`
- `RISK_EXCEEDS_POLICY`
- `DEPENDENCY_VIOLATION`
- `SCENE_NOT_FOUND`
- `FILE_NOT_FOUND`
- `TOKEN_EXPIRED`
- `QUEUE_FULL_RETRY`
- `STALE_STATE_VERSION`
- `CONFIRMATION_TOKEN_EXPIRED`
- `IDEMPOTENCY_KEY_CONFLICT`
- `RECORDING_ALREADY_ACTIVE`
- `RECORDING_NOT_ACTIVE`
- `RECORDING_MODE_UNSUPPORTED`
- `RECORDING_FEEDBACK_UNSUPPORTED`

---

## 8. Policy and Risk Model

### 8.1 Risk Levels

- `low`: safe to auto-apply
- `medium`: apply unless session policy requires confirmation
- `high`: always requires confirmation in v1

### 8.2 Policy Object

```json
{
  "maxRisk": "medium",
  "lockModules": ["sequencer"],
  "allowFileLoads": true,
  "allowRecording": true,
  "requireDiffForRiskAtLeast": "medium"
}
```

### 8.3 Confirmation Workflow

1. Validate bundle.
2. Return `requiresConfirmation: true` with `musicalDiff`.
3. Validation returns `confirmationToken` with short expiry.
4. Client resubmits `POST /actions/schedule` with `confirmationToken`.

### 8.4 Concurrency and Preconditions

- Scheduling with `preconditionStateVersion` fails with `STALE_STATE_VERSION` when current state has advanced.
- Clients should refresh state and replan when stale preconditions occur.

---

## 9. Real-Time Constraints and SLAs

### 9.1 Audio Safety Constraints

- No action path may bypass scheduler/guardrail pipeline.
- Runtime emits lock-free control messages only.
- File load actions must use pre-buffering and quantized switch where requested.

### 9.2 Latency Targets (v1)

- State query p95: <= 30 ms
- Validate action bundle p95: <= 40 ms
- Schedule acknowledgment p95: <= 25 ms
- Scheduled action timing error at boundary: <= 5 ms jitter budget

### 9.3 Throughput Targets (v1)

- Sustained action schedule rate: >= 50 actions/sec outside audio thread
- Event stream fanout: >= 1 client guaranteed, >= 3 best effort

### 9.4 Backpressure Behavior

- If schedule queue is full, API returns `429` with `QUEUE_FULL_RETRY`.
- Server includes `retryAfterMs` hint in error details.

---

## 10. Versioning and Compatibility

### 10.1 API Versioning

- Version in URL path (`/v1`)
- Backward-compatible additions allowed:
  - New optional fields
  - New event types
  - New modules/paths

### 10.2 Breaking Changes

Require `/v2` for:

- Removed/renamed required fields
- Changed semantics of existing fields
- Removed endpoints or action types

---

## 11. Reference Flows

### 11.1 One-Time Setup Flow

1. `POST /sessions`
2. `GET /capabilities`
3. `GET /parameters`
4. `POST /actions/validate`
5. `POST /actions/schedule`
6. observe `actions.bundle_applied`
7. `POST /scenes` (save setup)

### 11.2 Live Performance Adjustment Flow

1. Client receives user utterance.
2. Build action bundle with `TimeSpec` anchored to `next_bar`.
3. Validate with lock/policy settings.
4. Schedule bundle.
5. Watch event stream for apply/reject events.
6. If result is not musical, call `POST /history/undo`.

### 11.3 File Swap Flow

1. `POST /files/search`
2. optional audition in client context
3. `POST /files/{fileId}/load` with quantized timing
4. observe `file.loaded` and `state.changed`

### 11.4 Live Recording Flow

1. `GET /recording/voices` and select target voice.
2. `POST /recording/voices/{voiceId}/start` with `mode=live_overdub` and initial feedback.
3. During capture, adjust blend with `POST /recording/voices/{voiceId}/feedback`.
4. `POST /recording/voices/{voiceId}/stop` at the desired boundary.
5. Observe `recording.started`, `recording.feedback_changed`, `recording.stopped`, and `state.changed`.

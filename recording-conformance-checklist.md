# Recording Conformance Checklist

## Scope
This checklist validates conversational/API control of recording for both `granular` and `loop` voices, including `live_overdub` and adjustable feedback.

## Preconditions
- Control bridge running on `http://127.0.0.1:4850/v1`.
- Test project has at least one granular voice and one loop voice addressable as `granular.voiceA` and `loop.voiceB`.
- Transport is stable (known tempo/time signature) and event stream is connected.
- API client can provide unique `idempotencyKey` values per write.

## 1. Capability and Schema
- [ ] `GET /capabilities` includes recording actions: `startRecording`, `stopRecording`, `setRecordingFeedback`, `setRecordingMode` for granular/loop modules.
- [ ] `GET /parameters` exposes voice-scoped recording paths, including `*.recording.active`, `*.recording.mode`, `*.recording.feedback`.
- [ ] `GET /state` and `POST /state/query` return recording fields with expected types and value ranges.

## 2. Recording State Machine
- [ ] Start from idle state: `isRecording=false` on target voice.
- [ ] `POST /recording/voices/{voiceId}/start` transitions voice to recording state at requested timing boundary.
- [ ] `POST /recording/voices/{voiceId}/stop` transitions voice to non-recording state at requested timing boundary.
- [ ] Starting an already active voice returns `RECORDING_ALREADY_ACTIVE`.
- [ ] Stopping an inactive voice returns `RECORDING_NOT_ACTIVE`.

## 3. Mode Semantics
- [ ] `replace` mode overwrites target buffer behavior as expected.
- [ ] `overdub` mode mixes with existing content and accepts feedback control.
- [ ] `append` mode extends content rather than replacing beginning.
- [ ] `live_overdub` captures live input while mixing playback according to feedback.
- [ ] Unsupported mode requests return `RECORDING_MODE_UNSUPPORTED`.

## 4. Feedback Control
- [ ] `POST /recording/voices/{voiceId}/feedback` accepts values in `[0.0, 1.0]`.
- [ ] Values outside range fail with `ACTION_OUT_OF_RANGE`.
- [ ] Feedback changes support scheduled ramps (`durationBeats`/`durationBars`) without clicks.
- [ ] In modes that do not support feedback, update fails with `RECORDING_FEEDBACK_UNSUPPORTED`.

## 5. Timing and Quantization
- [ ] `start` with `anchor=next_bar` lands on next bar start within jitter budget.
- [ ] `stop` with `anchor=next_bar` lands on next bar start within jitter budget.
- [ ] Feedback ramps align to requested quantization boundaries.
- [ ] `strict` scheduling policy behavior (if enabled) fails rather than rolling when boundary is missed.

## 6. Idempotency and Preconditions
- [ ] Replaying same write payload + same `idempotencyKey` returns replay response and no duplicate side effect.
- [ ] Reusing an `idempotencyKey` with different payload returns `IDEMPOTENCY_KEY_CONFLICT`.
- [ ] Writes with stale `preconditionStateVersion` fail with `STALE_STATE_VERSION`.
- [ ] After stale failure, refresh + replan succeeds.

## 7. Event Stream Correctness
- [ ] `recording.started` emitted once per successful start with `voiceId`, `mode`, `feedback`.
- [ ] `recording.feedback_changed` emitted with `previous` and `current` values.
- [ ] `recording.stopped` emitted once per successful stop with `recordedDurationMs`.
- [ ] `state.changed` includes modified recording paths and monotonic `stateVersion`.
- [ ] Sequence continuity validated; gap handling works via `afterSeq`/`events.gap_detected`.

## 8. Cross-Module and Concurrency Behavior
- [ ] Granular and loop voices can record independently without cross-talk in state/event updates.
- [ ] Concurrent manual UI changes and AI/API recording changes obey conflict policy deterministically.
- [ ] Queue saturation returns `QUEUE_FULL_RETRY` with `retryAfterMs`; accepted writes are not dropped.

## 9. Audio/Performance Sanity
- [ ] No audio-thread violations under repeated record start/stop/feedback operations.
- [ ] No audible zipper noise during feedback automation in live_overdub.
- [ ] `validate` and `schedule` latency remains within SLA under moderate load.

## 10. Suggested Test Matrix
- [ ] Granular `replace`: start -> record 4 bars -> stop.
- [ ] Granular `live_overdub`: start with feedback 0.30 -> ramp to 0.70 over 2 bars -> stop.
- [ ] Loop `overdub`: start next bar -> feedback sweeps -> stop next bar.
- [ ] Loop `append`: two consecutive recording windows append as expected.
- [ ] Failure paths: duplicate start, duplicate stop, unsupported mode, out-of-range feedback.

## Sign-Off
- [ ] API contract verified against `ai-conversational-control-openapi.yaml`.
- [ ] Behavior verified against `ai-conversational-control-api-spec.md`.
- [ ] Recording acceptance criteria marked complete for both granular and loop voices.

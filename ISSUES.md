# Code Review Issues

Comprehensive code review findings, ordered by severity.

## Critical — C++ Audio Engine

### 1. ~~Heap allocation on audio thread~~ FIXED
**File:** `Source/Audio/Core/AudioEngine.cpp:606`
**Issue:** `std::vector<float*>` allocated inside `process()` when `numFrames > kMaxBufferSize`.
**Fix:** Replaced with pre-allocated `m_chunkOutputPtrs[kMaxOutputChannels]` member array.

### 2. ~~printf/fflush on audio thread~~ FIXED
**File:** `Source/Audio/Core/AudioEngine.cpp:1128-1131`
**Issue:** `printf` + `fflush(stdout)` in `processMultiChannel()` and processing loop.
**Fix:** Removed all printf/fflush from audio-priority threads. Kept startup/shutdown logs (main thread only).

### 3. ~~std::sort on audio thread~~ FIXED
**File:** `Source/Audio/Core/AudioEngine.cpp:657, 1197`
**Issue:** `std::sort` on `dueEvents` array — some stdlib implementations allocate internally.
**Fix:** Replaced with allocation-free insertion sort.

### 4. ~~Unbounded spinlock~~ FIXED
**File:** `Source/Audio/Core/AudioEngine.cpp:1511-1514`
**Issue:** Spin loop with 50,000 iterations and no CPU pause hint.
**Fix:** Added `__builtin_arm_yield()` (ARM64) / `__builtin_ia32_pause()` (x86) inside spin loops.

### 5. ~~Stack buffer overflow risk~~ FIXED
**File:** `Source/Audio/Core/AudioEngine.cpp:722, 1216`
**Issue:** `float tempL[kMaxBufferSize], tempR[kMaxBufferSize]` on stack inside voice rendering loops.
**Fix:** Moved to pre-allocated member buffers `m_tempVoiceL`, `m_tempVoiceR`, `m_tempDrumSeq`.

### 6. ~~No denormal flush~~ FIXED
**File:** `Source/Audio/Core/AudioEngine.cpp:204` (initialize)
**Issue:** No FTZ/DAZ flags set — denormalized floats in recursive filters cause CPU spikes.
**Fix:** Added `_MM_SET_FLUSH_ZERO_MODE` + `_MM_SET_DENORMALS_ZERO_MODE` for x86 at init (ARM64 flushes by default).

## High

### 7. ~~Copy-paste duplication: channelShortName~~ FIXED
**Files:** `Source/Application/GranularView.swift`, `Source/Application/LooperView.swift`
**Issue:** `channelShortName()` duplicated verbatim in both views.
**Fix:** Extracted to `MixerChannel.shortName()` in `Components/Common/MixerChannelNames.swift`. Also fixed "GR4" -> "GR2" naming inconsistency.

### 8. Timer.publish at property level
**Files:** `Source/Application/GranularView.swift`, `Source/Application/LooperView.swift`, `Source/Application/SequencerView.swift`
**Issue:** `Timer.publish(every:).autoconnect()` as a `let` property on the struct. SwiftUI may recreate the struct body frequently; each time the timer subscription is re-attached but the old publisher may not cancel.
**Fix:** Move timer into `.onAppear`/`.onDisappear` lifecycle, or use `.task` with `AsyncTimerSequence`.
**Status:** Deferred — low practical risk, SwiftUI handles Combine publisher lifecycle well for struct views.

### 9. Triple .onChange duplication
**Files:** `Source/Application/GranularView.swift`, `Source/Application/LooperView.swift`
**Issue:** Three nearly identical `.onChange` handlers for `recordSourceType`, `recordSourceChannel`, and `recordMode` all calling the same `setRecordingSource()`.
**Fix:** Consolidate into a single computed struct or use a `@State` struct to watch one value.
**Status:** Deferred — functionally correct, cosmetic issue.

## Medium

### 10. Polling-based sync (0.25s timer)
**Files:** `Source/Application/GranularView.swift`, `Source/Application/LooperView.swift`
**Issue:** A 4Hz timer polls the engine for state that could be pushed via Combine publishers. Wastes CPU cycles and introduces up to 250ms UI lag.
**Fix:** Use `@Published` properties on AudioEngineWrapper for recording state, playing state, etc.
**Status:** Deferred — works correctly, optimization opportunity.

### 11. ~~No BPM validation~~ NOT AN ISSUE
**File:** `Source/Audio/Core/AudioEngine.cpp`
**Assessment:** Already clamped to 10-330 BPM via `std::clamp` in `setClockBPM()`.

## Low

### 12. Magic numbers in audio processing
**File:** `Source/Audio/Core/AudioEngine.cpp`
**Issue:** Values like `0.95f`, `0.05f` (level smoothing), `0.3f` (delay time default), etc. are unexplained.
**Fix:** Define named constants.

### 13. ~~Inconsistent channel naming~~ FIXED
**File:** `Source/Application/LooperView.swift:396`
**Issue:** Channel 5 returns "GR4" but was renamed to "Granular 2" in the UI.
**Fix:** Fixed in `MixerChannel.shortName()` — now returns "GR2".

## Reassessed (Lower Risk Than Initially Reported)

### ConversationalControlBridge @unchecked Sendable
**File:** `Source/Application/Services/ConversationalControlBridge.swift`
**Initial concern:** Mutable dictionaries with `@unchecked Sendable`.
**Assessment:** All dictionary access is properly serialized through a private `DispatchQueue`. The `@unchecked` is necessary because Swift cannot automatically prove Sendability for `[String: Any]` element types. No actual thread safety issue.

### MonomeArcManager isConnected race condition
**File:** `Source/Application/Services/MonomeArcManager.swift`
**Initial concern:** `isConnected` accessed from timer callbacks.
**Assessment:** Class is `@MainActor`-isolated. Timer closures properly wrap access in `Task { @MainActor }`. No race condition.

---

*Generated from code review session, February 2026*

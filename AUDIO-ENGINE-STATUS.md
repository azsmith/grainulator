# Audio Engine Status Report

**Date:** February 4, 2025
**Status:** Legacy mode working, Multi-channel mode blocked

---

## Summary

We implemented a ring buffer-based multi-channel audio architecture to support AU plugin hosting on per-channel insert slots. While the ring buffer implementation is complete, we discovered that AVAudioEngine's source node callbacks are not being invoked in multi-channel mode, causing the system to fail. The app has been temporarily reverted to legacy mode to maintain functionality.

---

## Changes Made

### 1. Ring Buffer Implementation (C++)

**Files modified:**
- `Source/Audio/include/AudioEngine.h`
- `Source/Audio/Core/AudioEngine.cpp`
- `Source/Audio/include/AudioEngineBridge.h`
- `Source/Audio/Core/AudioEngineBridge.cpp`

**What was added:**
- `MultiChannelRingBuffer` class with lock-free producer/consumer pattern
- Background processing thread (`multiChannelProcessingLoop()`) that continuously calls `processMultiChannel()`
- Ring buffer sized for ~85ms of audio (4096 samples at 48kHz)
- C bridge functions: `AudioEngine_StartMultiChannelProcessing`, `AudioEngine_StopMultiChannelProcessing`, `AudioEngine_ReadChannelFromRingBuffer`

**Architecture:**
```
Background Thread (Producer)          Audio Render Thread (Consumer)
========================             ===========================

┌─────────────────────┐              ┌──────────────────┐
│ processMultiChannel │              │ AVAudioSourceNode│
│ called every ~4.8ms │──Ring────────│ Callback (×6)    │
│                     │  Buffers     │                  │
│ Updates sampleTime  │              │ Reads from buffer│
└─────────────────────┘              └──────────────────┘
```

### 2. SwiftUI Gesture Crash Fixes

**Files modified:**
- `Source/Application/Views/Mixer/AUInsertSectionView.swift`
- `Source/Application/Views/Effects/AUSendEffectsView.swift`
- `Source/Application/Audio/AUInsertSlot.swift`
- `Source/Application/Audio/AUSendSlot.swift`

**Problem:** SwiftUI's gesture system was crashing (`MainActor.assumeIsolated` in `_ButtonGesture.internalBody.getter`) when button views captured `@EnvironmentObject` references that became invalid during view hierarchy changes.

**Solution:**
1. Added thread-safe shadow state with `NSLock` to `AUInsertSlot` and `AUSendSlot`
2. Added `nonisolated` accessors (`hasPluginSafe`, `isBypassedSafe`, etc.)
3. Refactored child views to NOT use `@EnvironmentObject` directly
4. Pass all data as value types (`InsertSlotData`, `SendSlotData`) from parent
5. Pass all button actions as closures with explicit `[audioEngine]` capture lists

**Example pattern:**
```swift
// Parent view
AUSlotEditorByIndex(
    slotData: audioEngine.getInsertSlotData(...),
    onToggleBypass: { [audioEngine] in
        audioEngine.toggleInsertBypass(...)
    }
)

// Child view - NO @EnvironmentObject
struct AUSlotEditorByIndex: View {
    let slotData: InsertSlotData
    let onToggleBypass: () -> Void

    var body: some View {
        Button(action: onToggleBypass) { ... }
    }
}
```

### 3. Swift Integration

**Files modified:**
- `Source/Application/AudioEngineWrapper.swift`

**What was added:**
- Swift bridge function declarations for ring buffer operations
- Modified `setupMultiChannelGraph()` to start background processing thread
- Modified `teardownMultiChannelGraph()` to stop background processing
- Updated `getInsertSlotData()` and `getSendSlotData()` to use thread-safe accessors

---

## Current Bug: Multi-Channel Mode Not Working

### Symptom
When multi-channel mode is enabled:
1. Sequencer gets stuck on first step
2. No sounds are triggered
3. Ring buffer fills up and blocks

### Root Cause
**AVAudioSourceNode render callbacks are NOT being invoked**, even though:
- `AVAudioEngine.isRunning == true`
- All node formats match (48kHz stereo)
- Connections appear correct in debug output

### Evidence from Debug Logs
```
✓ Audio engine started - running=true
  outputNode format: 2 ch, 48000 Hz, Float32
  mainMixerNode numberOfInputs: 8
[RingBuffer] BLOCKED - buffer full, writable=255
[Sequencer] lookahead: now=3840 horizon=8640 nextPulse[0]=28800
```

Key observations:
- `now=3840` is STUCK - `m_currentSampleTime` never advances past initial buffer fill
- Ring buffer is perpetually full because consumers (source node callbacks) never run
- Sequencer schedules first note, then `nextPulseSample` exceeds `horizonSample`

### Why Callbacks Don't Fire
The source nodes are connected through a chain:
```
sourceNode → channelMixer → masterMixer → mainMixerNode → outputNode
```

Despite this appearing correct, AVAudioEngine is not pulling audio from the source nodes. Possible causes:
1. AVAudioEngine may require different connection patterns for source nodes
2. The intermediate mixer nodes may be preventing the pull-through
3. There may be a timing issue with when connections are made vs. when the engine starts

### Workaround
The app is currently set to **legacy mode** (`graphMode = .legacy`) which uses a single source node connected directly to the output. This mode works correctly.

---

## Files with Debug Logging (to be cleaned up)

The following files have debug print statements that should be removed once the issue is resolved:

1. `AudioEngine.cpp` - Ring buffer status, processMultiChannel skipping
2. `AudioEngineWrapper.swift` - Engine start info, connection debug, source node callbacks
3. `SequencerEngine.swift` - Lookahead debug logging

---

## Next Steps to Fix Multi-Channel Mode

1. **Try direct connection:** Connect source nodes directly to `mainMixerNode` instead of through intermediate mixers
2. **Check render format:** Ensure AVAudioSourceNode is created with the correct render format
3. **Investigate pull model:** AVAudioEngine uses a pull model - verify that something is actually requesting audio from the source nodes
4. **Test with single source:** Create a minimal test with just one source node to isolate the issue
5. **Check audio session:** On macOS, verify audio session/device configuration isn't blocking callbacks

---

## Testing the Current State

1. **Legacy mode (working):** Start the app, sequencer should work, sounds should play
2. **Multi-channel mode (broken):** Change `graphMode` to `.multiChannel` in `AudioEngineWrapper.swift` line 195

To switch modes for testing:
```swift
// In AudioEngineWrapper.swift, line 195
@Published var graphMode: AudioGraphMode = .legacy  // Currently set - WORKS
// @Published var graphMode: AudioGraphMode = .multiChannel  // BROKEN
```

# IambicKeyer Post-Mortem Analysis

**Date:** 2026-02-05
**PR Under Review:** #68 (feat: implement iambic Mode B keyer)
**Decision:** Revert to pre-PR#68 state

---

## Executive Summary

The IambicKeyer implementation introduced in PR #68 has fundamental architectural issues that make it unsuitable for production use. The core problems are:

1. **Thread/timing mismatches** between UI events, display link timing, and audio callback threads
2. **Two competing timeout mechanisms** that race against each other
3. **Missing Mode B behaviors** (no paddle memory/buffering)
4. **State synchronization bugs** that cause dropped input and incorrect pattern emission

This document details the technical analysis and provides a reference specification for a correct implementation.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Execution Path Analysis](#execution-path-analysis)
3. [Identified Bugs](#identified-bugs)
4. [Race Conditions](#race-conditions)
5. [Deviations from Iambic Mode B Specification](#deviations-from-iambic-mode-b-specification)
6. [Reference: Real Iambic Mode B Behavior](#reference-real-iambic-mode-b-behavior)
7. [Recommendations](#recommendations)

---

## Architecture Overview

### Component Diagram

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                           USER INPUT                                     │
│  Paddle Touch (UIKit) ─or─ Keyboard Press (SwiftUI)                     │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        SendTrainingViewModel                             │
│  @MainActor                                                              │
│  ├─ updatePaddle(dit:dah:) ─── queues elements + updates paddle state   │
│  ├─ queueElement(_:) ───────── discrete keyboard input                  │
│  ├─ currentPattern ─────────── @Published, synced from keyer            │
│  ├─ isWaitingForInput ──────── gates all input acceptance               │
│  └─ inputTimer ─────────────── COMPETING timeout mechanism              │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           IambicKeyer                                    │
│  Runs on Main Thread via CADisplayLink (60-120 FPS)                     │
│  ├─ phase: idle → playing → gap → idle                                  │
│  ├─ pendingElements: [MorseElement] ── queued discrete input            │
│  ├─ paddle: PaddleInput ────────────── continuous paddle state          │
│  ├─ currentPattern: String ─────────── accumulates "." and "-"          │
│  ├─ idleTimeout ────────────────────── COMPETING timeout mechanism      │
│  └─ Callbacks:                                                           │
│      ├─ onToneStart(frequency) ─────── triggers audio                   │
│      ├─ onToneStop() ───────────────── stops audio                      │
│      └─ onPatternComplete(pattern) ─── character boundary detected      │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         MorseAudioEngine                                 │
│  @MainActor                                                              │
│  └─ activateTone(frequency:) / deactivateTone()                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          ToneGenerator                                   │
│  Audio Real-Time Thread (AVAudioEngine callback)                        │
│  ├─ isToneActive ────── NSLock protected                                │
│  ├─ currentFrequency ── NSLock protected                                │
│  └─ Generates sine wave samples at 48kHz                                │
└─────────────────────────────────────────────────────────────────────────┘
```

### Thread Model

| Component | Thread | Timing |
|-----------|--------|--------|
| UIKit touch events | Main Thread | Event-driven (~instant) |
| SwiftUI view updates | Main Thread | Frame-driven (~60 FPS) |
| SendTrainingViewModel | Main Thread (@MainActor) | Event-driven |
| IambicKeyer tick loop | Main Thread (CADisplayLink) | 60-120 FPS (~8-16ms) |
| ToneGenerator audio callback | Audio Real-Time Thread | ~48kHz sample rate |

---

## Execution Path Analysis

### Complete Sequence: Paddle Press to Audio Output

```text
TIME    THREAD          ACTION                                      STATE CHANGE
─────────────────────────────────────────────────────────────────────────────────
T+0ms   UIKit           touchesBegan fires                          -
T+0ms   Main            onPressChange(true) callback                -
T+0ms   Main            viewModel.updatePaddle(dit:true)            -
T+0ms   Main            └─ keyer.queueElement(.dit)                 pendingElements += [.dit]
T+0ms   Main            └─ keyer.updatePaddle(dit:true)             paddle.ditPressed = true
T+0ms   Main            └─ if idle: startNextQueuedElement()        phase = .playing(.dit)
T+0ms   Main            └─ startElement() calls onToneStart         -
T+0ms   Main→Audio      └─ audioEngine.activateTone(700)            isToneActive = true
T+0ms   Audio RT        Audio callback generates tone               Speaker output begins

T+8ms   Main            CADisplayLink tick                          -
T+8ms   Main            └─ processTick(): elapsed=8ms < 92ms        No transition

T+16ms  Main            CADisplayLink tick                          -
T+16ms  Main            └─ processTick(): elapsed=16ms < 92ms       No transition

...continued ticking...

T+92ms  Main            CADisplayLink tick                          -
T+92ms  Main            └─ processTick(): elapsed≥92ms              phase = .gap
T+92ms  Main            └─ onToneStop()                             isToneActive = false
T+92ms  Audio RT        Audio callback stops generating tone        Speaker output ends

T+184ms Main            CADisplayLink tick (gap complete)           -
T+184ms Main            └─ processGapPhase(): check paddle/queue    -
T+184ms Main            └─ If paddle released & queue empty:        phase = .idle
                                                                     idleStartTime = now

T+598ms Main            CADisplayLink tick                          -
T+598ms Main            └─ processIdlePhase(): idle 414ms           -
T+598ms Main            └─ idleTimeout reached → emitPattern()      currentPattern = ""
T+598ms Main            └─ onPatternComplete(".")                   -
T+598ms Main            └─ Task @MainActor posted                   -
T+599ms Main            └─ handleKeyerPatternComplete(".")          isWaitingForInput = false
```

### Critical Timing Windows

```text
At 13 WPM:
├─ Dit duration:     92ms
├─ Dah duration:     277ms
├─ Element gap:      92ms
├─ Idle timeout:     415ms (1.5 × dah)
├─ Display tick:     8-16ms (60-120 FPS)
└─ Pattern complete: ~507ms after last element starts (92ms + 415ms)

For character "K" (-.-):
├─ Dah:              277ms
├─ Gap:              92ms
├─ Dit:              92ms
├─ Gap:              92ms
├─ Dah:              277ms
├─ Gap:              92ms
├─ Idle timeout:     415ms
└─ TOTAL:            1337ms until pattern emits
```

---

## Identified Bugs

### Bug 1: idleStartTime Never Reset on Re-Entry to Playing

**Severity:** HIGH
**Location:** `IambicKeyer.processIdlePhase()` / `startElement()`

**Description:**
When transitioning from idle to playing, `idleStartTime` is not reset. If the user pauses mid-character and resumes, the old timeout continues counting.

**Reproduction:**

```text
T=0ms:     Start pattern, send ".-"
T=500ms:   Release paddle, go idle, idleStartTime = 500
T=600ms:   Press paddle again (before 415ms timeout)
T=700ms:   Release paddle, go idle again
T=915ms:   idleTimeout check: 915 - 500 = 415ms → EMIT PATTERN
           Pattern emits with old timestamp, not from T=700ms
```

**Impact:** Patterns emit at unexpected times when user pauses and resumes.

---

### Bug 2: processIdlePhase() Doesn't Process Queued Elements Consistently

**Severity:** MEDIUM
**Location:** `IambicKeyer.processIdlePhase()` (current code after recent fix attempt)

**Description:**
The fix added a check for `pendingElements.isEmpty` before emitting, but the check for processing queued elements in idle was also added. This creates timing-dependent behavior where queued elements might be processed in idle instead of at gap-to-idle transition.

---

### Bug 3: Pattern Sync is Polling-Based, Not Event-Driven

**Severity:** HIGH
**Location:** `SendTrainingViewModel.updatePaddle()`

**Description:**
The ViewModel reads `keyer.currentPattern` synchronously after calling keyer methods, but the keyer's pattern isn't updated until the next display link tick processes the queued element.

```swift
// In updatePaddle():
keyer?.queueElement(.dit)
// Pattern NOT updated yet - keyer hasn't ticked
if let keyerPattern = keyer?.currentPattern {
    currentPattern = keyerPattern  // STALE VALUE
}
```

**Impact:** UI shows stale pattern until next paddle press or timeout.

---

### Bug 4: Two Competing Timeout Mechanisms

**Severity:** CRITICAL
**Location:** `SendTrainingViewModel.resetInputTimer()` vs `IambicKeyer.processIdlePhase()`

**Description:**
Two independent timers control input completion:

1. **Keyer idle timeout:** 415ms at 13 WPM, triggers `onPatternComplete`
2. **ViewModel input timer:** 1.0s + 0.8s per element, triggers `handleInputTimeout`

Race scenario:

```text
T=0ms:     showNextCharacter() starts inputTimer (e.g., 2.6s for 3 elements)
T=100ms:   User sends single dit
T=607ms:   Keyer idle timeout → onPatternComplete(".")
T=607ms:   handleKeyerPatternComplete sets isWaitingForInput = false
           [Input blocked, user can no longer add to pattern]

T=2600ms:  inputTimer fires → handleInputTimeout()
           guard isWaitingForInput else { return }  ← RETURNS (already false)
           [No double-completion, but timer was wasted]
```

Worse race:

```text
T=0ms:     showNextCharacter() starts inputTimer (2.6s)
T=2500ms:  User SLOWLY enters element, keyer in playing phase
T=2600ms:  inputTimer fires → completeCurrentInput()
           isWaitingForInput = false
T=2700ms:  User finishes element, keyer emits pattern
           onPatternComplete → handleKeyerPatternComplete
           guard isWaitingForInput else { return }  ← PATTERN LOST
```

**Impact:** Input can be lost if user types slowly and ViewModel timer fires first.

---

### Bug 5: clearPendingInput() Doesn't Stop Active Tone

**Severity:** LOW
**Location:** `IambicKeyer.clearPendingInput()`

**Description:**
If called while keyer is in `.playing` phase, the tone continues but pattern is cleared.

---

## Race Conditions

### Race 1: Paddle Release vs Display Link Tick

```text
User quickly taps dit (press and release within one tick):

T=0ms:    touchesBegan → updatePaddle(dit:true)
          keyer.queueElement(.dit) → pendingElements = [.dit]
          keyer.updatePaddle(dit:true) → paddle.ditPressed = true
          Phase is idle, so startNextQueuedElement() called
          pendingElements = [], phase = .playing(.dit)

T=5ms:    touchesEnded → updatePaddle(dit:false)
          keyer.updatePaddle(dit:false) → paddle.ditPressed = false
          ViewModel syncs: currentPattern = keyer.currentPattern
          BUT keyer.currentPattern was updated in startElement()
          So sync works... sometimes.

T=8ms:    Display link tick
          processTick(): element still playing

THE ISSUE: If the startNextQueuedElement() call DOESN'T happen because
keyer wasn't idle (e.g., previous element still in gap phase), then:
- Element is queued
- Paddle state set to true
- Paddle state set to false (release)
- Display link checks paddle state: false
- Queued element might not be seen if processed between ticks
```

### Race 2: Pattern Emission vs isWaitingForInput

```text
T=0ms:    Keyer emits pattern: onPatternComplete(".-.")
T=0ms:    Callback posts: Task { @MainActor in handleKeyerPatternComplete }
T=0ms:    Meanwhile, inputTimer also fires: handleInputTimeout()
          handleInputTimeout checks isWaitingForInput: true
          Calls completeCurrentInput()
          Sets isWaitingForInput = false

T+1ms:    Task runs: handleKeyerPatternComplete
          Checks: guard isWaitingForInput else { return }
          isWaitingForInput is FALSE → callback ignored
          Pattern ".-." is LOST
```

### Race 3: UI Update vs Keyer State

```text
SwiftUI body recomputes when @Published changes.
But currentPattern is only synced in updatePaddle().

Scenario:
- Keyer accumulates pattern via tick() calls
- currentPattern in keyer = ".-"
- User hasn't pressed paddle again
- ViewModel.currentPattern still = "." (from last sync)
- UI shows "." while keyer has ".-"
- After idle timeout, onPatternComplete(".") fires
- Pattern should have been ".-" but keyer emits what it has
```

---

## Deviations from Iambic Mode B Specification

### What Mode B Should Do

1. **Element always completes** even if paddle released mid-element → ✅ IMPLEMENTED
2. **Squeeze alternates** dit-dah-dit-dah → ✅ IMPLEMENTED
3. **Dot memory:** pressing dit during dah queues dit for immediate playback → ❌ NOT IMPLEMENTED
4. **Dash memory:** pressing dah during dit queues dah for immediate playback → ❌ NOT IMPLEMENTED
5. **Mode B release behavior:** when both paddles released during element, send one opposite element then stop → ❌ NOT IMPLEMENTED
6. **Character boundary via natural pause** (3+ dit gap) → ⚠️ USES ARBITRARY TIMEOUT

### Missing: Paddle Memory

Real Mode B keyers have "dot and dash memory" introduced by the Curtis 8044 chip:

> "If you press the dit paddle during a dah, that press is remembered and serviced after the dah completes."

Current implementation:

- `updatePaddle()` just sets boolean state
- No "latch" or "memory" mechanism
- If paddle released before keyer checks, press is lost

### Missing: Mode B Release Behavior

Mode B's defining characteristic:

> "When both paddles released during element, after current element completes, send one additional element opposite to the one just sent, then stop."

Current implementation:

- Checks `paddle.isPressed` at gap completion
- If not pressed, goes to idle
- No "send one more opposite" logic

---

## Reference: Real Iambic Mode B Behavior

### Timing Standards (PARIS Calibration)

| Element | Duration (dit units) | At 13 WPM |
|---------|---------------------|-----------|
| Dit | 1 | 92ms |
| Dah | 3 | 277ms |
| Inter-element gap | 1 | 92ms |
| Inter-character gap | 3 | 277ms |
| Word gap | 7 | 646ms |

### State Machine (Correct Implementation)

```text
States:
- IDLE: Waiting for input
- PREDOT: About to send dit (clears dot memory)
- SENDDOT: Generating dit tone
- DOTDELAY: Inter-element gap after dit
- DOTHELD: Dit complete, deciding next action
- PREDASH: About to send dah (clears dash memory)
- SENDDASH: Generating dah tone
- DASHDELAY: Inter-element gap after dah
- DASHHELD: Dah complete, deciding next action

Transitions at DOTHELD/DASHHELD (the critical decision point):
1. Same paddle still held → repeat same element
2. Opposite paddle pressed OR in memory → send opposite
3. Both released (Mode A) → IDLE
4. Both released (Mode B) → send one opposite, THEN IDLE

Memory is SET when opposite paddle pressed during element.
Memory is CLEARED when that element starts playing.
```

### Sources

- [Morse Code World - Timing](https://morsecode.world/international/timing/)
- [Ham Radio QRP - Squeeze Keying](https://www.hamradioqrp.com/2017/10/squeeze-keying-iambic-mode-operation.html)
- [Curtis 8044 Application Note](https://users.ox.ac.uk/~malcolm/radio/8044print.pdf)
- [n1gp/iambic-keyer GitHub](https://github.com/n1gp/iambic-keyer)

---

## Recommendations

### Immediate Action

**Revert to pre-PR#68 state.** The keyer implementation has too many fundamental issues to fix incrementally.

### For Future Implementation

1. **Single source of truth for timeouts:** Either the keyer owns character completion OR the ViewModel does, not both.

2. **Event-driven pattern sync:** Use callbacks (like `onPatternUpdated`) but ensure they don't race with completion handlers. Consider using Combine or AsyncStream.

3. **Implement proper paddle memory:** Add `ditMemory` and `dahMemory` boolean flags. Set memory when opposite paddle pressed during element. Clear when that element starts.

4. **Implement Mode B release behavior:** At element completion, if both paddles released but were pressed during element, send one opposite element.

5. **Separate keyboard input from paddle input:** Keyboard should queue discrete elements. Paddles should use continuous state + memory. Don't mix the two input models.

6. **Consider running keyer on dedicated thread:** CADisplayLink on main thread couples keyer timing to UI frame rate. A dedicated high-priority thread or dispatch source timer would be more precise.

7. **Add comprehensive integration tests:** Unit tests for keyer state machine passed, but real-world touch-to-audio path was never tested.

---

## Appendix: Files Changed in PR #68

```text
KochTrainer/Services/Keyer/IambicKeyer.swift (NEW)
KochTrainer/Services/Keyer/KeyerConfiguration.swift (NEW)
KochTrainer/Services/Keyer/KeyerClock.swift (NEW)
KochTrainer/Services/Keyer/MockClock.swift (NEW)
KochTrainer/ViewModels/SendTrainingViewModel.swift (MODIFIED)
KochTrainer/ViewModels/EarTrainingViewModel.swift (MODIFIED)
KochTrainer/ViewModels/VocabularyTrainingViewModel.swift (MODIFIED)
KochTrainer/ViewModels/MorseQSOViewModel.swift (MODIFIED)
KochTrainer/Views/Training/Send/PaddleView.swift (NEW)
KochTrainer/Views/Training/Send/SendTrainingView.swift (MODIFIED)
KochTrainerTests/Services/Keyer/IambicKeyerTests.swift (NEW)
```

---

*Post-mortem prepared by Claude Code with multi-agent peer review.*

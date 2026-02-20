# Swift Concurrency and Threading Best Practices

**Document Purpose:** Guide for implementing correct async/await patterns, protecting the UI thread, and ensuring fluid user experience in iOS applications.

**Context:** This document analyzes the Koch Trainer codebase, identifies threading patterns used, evaluates strengths and weaknesses, and provides recommendations for implementing real-time features like an iambic keyer.

---

## Table of Contents

1. [Swift Concurrency Model](#swift-concurrency-model)
2. [Thread Types in iOS Apps](#thread-types-in-ios-apps)
3. [Current Codebase Analysis](#current-codebase-analysis)
4. [Input-Animation-Audio Pipeline](#input-animation-audio-pipeline)
5. [Known Issues and Weaknesses](#known-issues-and-weaknesses)
6. [Iambic Keyer Requirements](#iambic-keyer-requirements)
7. [Best Practices Summary](#best-practices-summary)

---

## Swift Concurrency Model

### @MainActor

The `@MainActor` attribute guarantees code runs on the main thread. Use it for:

- All UI-related code (ViewModels, View logic)
- Anything that reads/writes `@Published` properties
- Code that calls UIKit/AppKit APIs

```swift
@MainActor
final class SendTrainingViewModel: ObservableObject {
    @Published var currentPattern: String = ""  // Safe: always accessed from main
}
```

**Cost:** Every call site must be on the main actor or use `await`. This prevents direct calls from non-main-actor contexts (like audio callbacks).

### Task { }

Creates a new asynchronous context. By default, inherits the actor context of the caller.

```swift
// On @MainActor class, this runs on main thread
Task {
    await audioEngine.playCharacter(char)  // Suspends, doesn't block
}
```

**Pitfall:** If you need the result immediately, `Task { }` won't help—it schedules work asynchronously.

### Task { @MainActor in }

Explicitly runs on the main actor, regardless of where the Task was created.

```swift
// From a callback that might be on any thread
onPatternComplete: { pattern in
    Task { @MainActor in
        self.handlePatternComplete(pattern)  // Safe: runs on main
    }
}
```

**Pitfall:** This introduces latency—the work is scheduled, not executed immediately.

### async/await

Suspends execution without blocking the thread. The system can do other work while waiting.

```swift
func playCharacter(_ char: Character) async {
    for element in pattern {
        await playToneElement(duration: element.duration)
        await playSilence(duration: gap)  // Suspends, doesn't block
    }
}
```

**Key insight:** `await` means "suspend here until this completes." The thread is freed to do other work.

### @unchecked Sendable

Used when you guarantee thread safety manually (via locks) but can't express it to the compiler.

```swift
final class Radio: @unchecked Sendable {
    private let lock = NSLock()
    private var _mode: RadioMode = .off

    var mode: RadioMode {
        lock.lock()
        defer { lock.unlock() }
        return _mode
    }
}
```

**When to use:** Real-time audio callbacks cannot await, so actors don't work. Manual locking is the only option.

---

## Thread Types in iOS Apps

### Main Thread (UI Thread)

| Responsibility | Latency Budget |
|---------------|----------------|
| Touch event delivery | ~16ms (60 FPS) |
| SwiftUI view body evaluation | ~16ms |
| @Published property updates | ~16ms |
| Animation frame calculation | ~16ms |

**Rule:** Never block the main thread. All work must complete within one frame (~16ms at 60 FPS, ~8ms at 120 FPS).

### Audio Real-Time Thread

| Responsibility | Latency Budget |
|---------------|----------------|
| Sample buffer generation | ~2.9ms (1024 samples at 44.1kHz) |
| No allocations allowed | — |
| No locks that might block | — |
| No Objective-C messaging | — |

**Rule:** Audio callbacks must be lock-free or use try-lock patterns. Never await, never allocate, never log.

### Background Threads

| Use Case | Pattern |
|----------|---------|
| File I/O | `Task.detached { }` |
| Network requests | URLSession (async/await) |
| Heavy computation | Actor with `nonisolated` methods |

---

## Current Codebase Analysis

### Architecture Overview

```text
┌─────────────────────────────────────────────────────────────────┐
│                         USER INPUT                               │
│  Button tap (SwiftUI) ─or─ Keyboard press (SwiftUI .onKeyPress) │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼ (immediate, main thread)
┌─────────────────────────────────────────────────────────────────┐
│                    ViewModel (@MainActor)                        │
│  SendTrainingViewModel / ReceiveTrainingViewModel               │
│  ├─ @Published state for UI binding                             │
│  ├─ Timer for countdown (fires on main thread)                  │
│  └─ Calls audio engine methods                                  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼ (async call)
┌─────────────────────────────────────────────────────────────────┐
│                  MorseAudioEngine (@MainActor)                   │
│  ├─ Orchestrates tone timing (await playSilence)                │
│  └─ Calls ToneGenerator for actual audio                        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼ (sync call with locks)
┌─────────────────────────────────────────────────────────────────┐
│                     ToneGenerator                                │
│  @unchecked Sendable (manual locking)                           │
│  ├─ AVAudioEngine runs continuously during session              │
│  ├─ AVAudioSourceNode callback generates samples                │
│  ├─ NSLock protects: isToneActive, currentFrequency, phase      │
│  └─ Radio state machine (also NSLock protected)                 │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼ (audio thread, ~44.1kHz)
┌─────────────────────────────────────────────────────────────────┐
│                    Audio Render Callback                         │
│  Reads locked state once per buffer (~1024 samples)             │
│  Generates sine wave samples into buffer                        │
└─────────────────────────────────────────────────────────────────┘
```

### Strengths

#### 1. Clean @MainActor Boundaries

All ViewModels are `@MainActor`, ensuring UI state updates are thread-safe:

```swift
@MainActor
final class SendTrainingViewModel: ObservableObject {
    @Published var currentPattern: String = ""
    @Published var isWaitingForInput: Bool = true
```

**Benefit:** No data races on `@Published` properties. SwiftUI bindings work correctly.

#### 2. Lock-Based Audio Thread Safety

The `ToneGenerator` and `Radio` classes use `NSLock` for state accessed from the audio callback:

```swift
var isToneActive: Bool {
    toneActiveLock.lock()
    defer { toneActiveLock.unlock() }
    return _isToneActive
}
```

**Benefit:** Audio callback can read state safely. Locks are held briefly (just reading a bool), minimizing contention.

#### 3. Continuous Audio Session Model

Rather than starting/stopping the audio engine per tone, the engine runs continuously and a flag controls output:

```swift
func startSession() {
    startContinuousAudio()  // Engine runs until endSession()
}

func activateTone(frequency: Double) throws {
    _isToneActive = true  // Audio callback checks this flag
}
```

**Benefit:** Eliminates audio glitches from engine start/stop latency (~50ms). Tones begin/end sample-accurately.

#### 4. View Identity Reset for Animation

The countdown timer uses `.id()` to force view recreation, destroying in-flight animations:

```swift
TimeoutProgressBar(progress: viewModel.inputProgress)
    .id(viewModel.timerCycleId)  // Increment resets animation
```

**Benefit:** Prevents animation state leaking between timer cycles.

### Weaknesses

#### 1. Pause/Resume Uses Different Patterns

Different ViewModels handle pause/resume inconsistently:

| ViewModel | Pause | Resume |
|-----------|-------|--------|
| ReceiveTrainingViewModel | `endSession()` | `startSession()` |
| SendTrainingViewModel | `stop()` | `startReceiving()` |

**Problem:** The `stop()` method sets `isStopped = true`, but `startReceiving()` doesn't clear it. Audio silently fails to play.

**See:** `docs/keyer-post-mortem.md` for detailed analysis of this bug.

#### 2. Timer-Driven Animation State

The countdown animation is driven by setting `inputTimeRemaining` and using `withAnimation`:

```swift
func resetInputTimer() {
    inputTimeRemaining = currentInputTimeout
    Task { @MainActor in
        withAnimation(.linear(duration: duration)) {
            inputTimeRemaining = 0
        }
    }
}
```

**Problem:** This pattern has a race:

1. Set value to full
2. Yield to event loop (Task)
3. Start animation

If step 3 runs before SwiftUI reads the full value, the animation starts from the wrong position.

#### 3. No Callback-Based Pattern Sync

In the failed keyer implementation, the ViewModel polled the keyer's pattern:

```swift
func updatePaddle(dit: Bool, dah: Bool) {
    keyer?.updatePaddle(...)
    currentPattern = keyer?.currentPattern ?? ""  // STALE
}
```

**Problem:** The keyer updates `currentPattern` on the next display link tick, not immediately. The ViewModel reads stale data.

#### 4. Two Competing Timeout Mechanisms

The failed keyer had both:

- Keyer idle timeout (415ms at 13 WPM)
- ViewModel input timer (variable, character-dependent)

**Problem:** These raced against each other. If ViewModel timer fired first, keyer pattern was lost.

---

## Input-Animation-Audio Pipeline

### Current Send Training Flow

```text
TIME        THREAD          EVENT                           STATE CHANGE
────────────────────────────────────────────────────────────────────────
T+0ms       Main            Button tap detected             —
T+0ms       Main            viewModel.inputDit()            currentPattern += "."
T+0ms       Main            @Published triggers view        UI shows "."
T+0ms       Main            playDit() creates Task          —
T+1ms       Main            Task starts audioEngine call    —
T+1ms       Main            activateTone(frequency)         isToneActive = true
T+1ms       Audio RT        Next buffer sees flag           Tone starts
T+60ms      Main            playSilence completes           —
T+60ms      Main            deactivateTone()                isToneActive = false
T+60ms      Audio RT        Next buffer sees flag           Tone stops
```

**Latency Analysis:**

- Touch to state update: <1ms (synchronous)
- State update to UI: <16ms (next SwiftUI render)
- State update to audio: <3ms (next audio buffer)

**Total perceived latency:** ~5ms (acceptable)

### Countdown Animation Flow

```text
TIME        THREAD          EVENT                           STATE CHANGE
────────────────────────────────────────────────────────────────────────
T+0ms       Main            showNextCharacter()             —
T+0ms       Main            resetInputTimer()               timerCycleId += 1
T+0ms       Main            View.body invalidated           —
T+0ms       Main            inputTimeRemaining = full       —
T+0ms       Main            Task { withAnimation }          (scheduled)
T+1ms       Main            Task runs                       —
T+1ms       Main            withAnimation starts            inputTimeRemaining = 0
T+1ms       Main            Animation interpolates          60 FPS updates
```

**Problem:** If SwiftUI reads `inputTimeRemaining` between T+0 and T+1ms (before Task runs), it may see the old value momentarily.

---

## Known Issues and Weaknesses

### Bug: Countdown Timer Doesn't Reset to 100%

**Symptom:** Sometimes the progress bar starts from mid-way instead of full.

**Root Cause:** Race between setting `inputTimeRemaining = full` and SwiftUI reading it.

**Fix Options:**

1. **Synchronous animation start:** Don't use Task, call withAnimation directly
2. **Two-phase update:** Set value, wait for render, then animate
3. **Timer-driven animation:** Use a repeating timer to decrement, not withAnimation

### Bug: Input Scored at Timeout Only

**Current Behavior:** User input is only evaluated when timeout fires.

**Trade-offs:**

| Approach | Pros | Cons |
|----------|------|------|
| Fixed timeout | Simple, allows corrections | Slow, user waits |
| Element count | Fast for correct input | No self-correction |
| Pause detection | Balances speed/flexibility | Complex timing logic |

---

## Iambic Keyer Requirements

Based on the post-mortem analysis, a correct iambic keyer implementation needs:

### 1. Single Source of Truth for Character Completion

**Problem:** Two competing timeouts raced.

**Solution:** Either the keyer owns character boundaries OR the ViewModel does, not both.

```swift
// Option A: Keyer owns boundaries
keyer.onPatternComplete = { pattern in
    // ViewModel just receives completed patterns
    self.handleCompletedPattern(pattern)
}

// Option B: ViewModel owns boundaries
keyer.onElementPlayed = { element in
    self.currentPattern.append(element)
    self.resetCharacterTimeout()  // ViewModel's single timer
}
```

### 2. Event-Driven State Sync

**Problem:** Polling reads stale state.

**Solution:** Use callbacks or Combine publishers.

```swift
// Callback approach
keyer.onPatternUpdated = { pattern in
    Task { @MainActor in
        self.currentPattern = pattern
    }
}

// Combine approach
keyer.$currentPattern
    .receive(on: DispatchQueue.main)
    .assign(to: &$currentPattern)
```

### 3. Thread-Safe Keyer State

**Problem:** Keyer on CADisplayLink (main thread) but callbacks could be called from anywhere.

**Solution:** Keep keyer on main thread, make all callbacks explicitly @MainActor:

```swift
init(
    onToneStart: @escaping @MainActor (Double) -> Void,
    onToneStop: @escaping @MainActor () -> Void,
    onPatternComplete: @escaping @MainActor (String) -> Void
)
```

### 4. Proper Mode B Paddle Memory

**Problem:** Quick taps lost if paddle released between display link ticks.

**Solution:** Latch paddle presses until serviced:

```swift
private var ditMemory: Bool = false
private var dahMemory: Bool = false

func updatePaddle(_ input: PaddleInput) {
    // Set memory on rising edge
    if input.ditPressed && !paddle.ditPressed {
        ditMemory = true
    }
    if input.dahPressed && !paddle.dahPressed {
        dahMemory = true
    }
    paddle = input
}

private func selectNextElement() -> MorseElement {
    if ditMemory {
        ditMemory = false  // Clear after servicing
        return .dit
    }
    // ... etc
}
```

### 5. Separate Timing Domains

| Domain | Thread | Timing Source | Responsibility |
|--------|--------|---------------|----------------|
| UI updates | Main | SwiftUI render loop | Display state |
| Keyer state machine | Main | CADisplayLink or Timer | Element timing |
| Audio output | Audio RT | Sample clock | Tone generation |

**Key insight:** Don't mix timing sources. The keyer should use a consistent clock, not try to sync with both UI frames and audio samples.

### 6. Recommended Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                     PaddleInputManager                          │
│  Handles touch events, manages paddle memory                    │
│  Thread: Main (UIKit events)                                    │
│  Output: PaddleState changes via callback                       │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      IambicKeyerEngine                          │
│  State machine with proper Mode B behavior                      │
│  Thread: Main (CADisplayLink at 120 FPS)                        │
│  Input: PaddleState                                             │
│  Output: ElementStarted/ElementEnded callbacks                  │
└─────────────────────────────────────────────────────────────────┘
                                │
                          ┌─────┴─────┐
                          ▼           ▼
┌──────────────────────────┐   ┌──────────────────────────┐
│     PatternTracker       │   │      AudioController     │
│  Accumulates elements    │   │  Translates to tones     │
│  Detects char boundary   │   │  Thread: Main→Audio      │
│  Single timeout owner    │   │                          │
└──────────────────────────┘   └──────────────────────────┘
                │                          │
                ▼                          ▼
┌──────────────────────────┐   ┌──────────────────────────┐
│      ViewModel           │   │     ToneGenerator        │
│  @MainActor              │   │  Continuous audio        │
│  Updates @Published      │   │  Lock-protected flags    │
└──────────────────────────┘   └──────────────────────────┘
```

---

## Best Practices Summary

### Do

1. **Mark ViewModels @MainActor** — Guarantees thread safety for @Published
2. **Use continuous audio sessions** — Avoids engine start/stop glitches
3. **Use NSLock for audio-thread-accessible state** — Actors can't work in RT context
4. **Use callbacks for state sync** — Polling reads stale data
5. **Single source of truth for timeouts** — Competing timers race
6. **Use .id() to reset animations** — Destroys in-flight state

### Don't

1. **Don't block main thread** — Use async/await, not Thread.sleep
2. **Don't mix timing domains** — Pick one clock source per component
3. **Don't poll state after async calls** — State may not be updated yet
4. **Don't use actors for RT audio** — They require await, which blocks
5. **Don't start animation in Task** — May race with render loop

### Thread Safety Patterns

| Pattern | Use Case |
|---------|----------|
| `@MainActor` | UI code, @Published properties |
| `NSLock` | Audio-thread-accessible state |
| `actor` | General async state isolation |
| `DispatchQueue.main.async` | Legacy code, avoid in new code |
| `Task { @MainActor in }` | Callback → main thread |

### Animation Patterns

| Pattern | Use Case |
|---------|----------|
| `.id(cycleId)` | Reset animation on state change |
| `withAnimation { }` | Immediate animation start |
| Timer + @Published | Controlled interpolation |
| `.animation(.linear)` | Automatic property animation |

---

## References

- [Apple: Concurrency](https://developer.apple.com/documentation/swift/concurrency)
- [WWDC21: Meet async/await in Swift](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [WWDC21: Protect mutable state with Swift actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [AVAudioEngine Programming Guide](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- `docs/keyer-post-mortem.md` — Analysis of failed iambic keyer implementation

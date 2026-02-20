# Plan: Z Specification Constraint Enforcement Analysis

## Summary

Analyze the 18 uncovered constraints from `docs/AUDIT.md` and determine the optimal enforcement strategy for each. The goal is to understand the tradeoffs between defensive coding, test coverage, and code complexity.

## Key Findings

The audit identified 18 uncovered constraints. After analysis:

| Category | Count | Recommended Action |
|----------|-------|-------------------|
| Missing domain model (radio) | 6 | **Create Radio type with throwing methods** |
| Missing domain model (counters) | 2 | **Create SessionCounter type** |
| Structurally enforced (other) | 6 | Add invariant tests only |
| Not applicable (no UI exposure) | 4 | Document in spec |

**Bottom line**: Create two domain types: `Radio` (half-duplex invariants) and `SessionCounter` (attempts invariant). ~15 tests total.

---

## Analysis by Constraint Type

### 1. Radio/Tone Half-Duplex Invariants

**Constraints**:

- `¬(radioMode = receiving ∧ toneActive)`
- `¬(radioMode = off ∧ toneActive)`

**Current state**: No domain model. `ToneGenerator` exposes independent `setRadioMode()` and `activateTone()` methods. Callers can create invalid state combinations. Defensive rendering masks the problem.

**Recommendation**: **Encapsulated Radio type** — Create a proper domain model that enforces invariants.

**Design**:

```swift
/// Half-duplex radio state machine.
/// Invariants:
/// - Can only key while transmitting
/// - Must stop before switching modes
final class Radio {
    enum Mode: Equatable, Sendable {
        case off, receiving, transmitting
    }

    enum RadioError: Error {
        case mustBeOff(current: Mode)
        case mustBeTransmitting(current: Mode)
        case alreadyOff
    }

    private(set) var mode: Mode = .off
    private(set) var isKeying: Bool = false

    func startReceiving() throws {
        guard mode == .off else {
            throw RadioError.mustBeOff(current: mode)
        }
        mode = .receiving
    }

    func startTransmitting() throws {
        guard mode == .off else {
            throw RadioError.mustBeOff(current: mode)
        }
        mode = .transmitting
    }

    func stop() throws {
        guard mode != .off else {
            throw RadioError.alreadyOff
        }
        isKeying = false
        mode = .off
    }

    func key() throws {
        guard mode == .transmitting else {
            throw RadioError.mustBeTransmitting(current: mode)
        }
        isKeying = true
    }

    func unkey() throws {
        guard mode == .transmitting else {
            throw RadioError.mustBeTransmitting(current: mode)
        }
        isKeying = false
    }
}
```

**Why throwing over preconditions**:

- Domain rule violations (not programmer errors) should be recoverable
- Type signature documents that failure is possible
- Callers forced to handle or propagate errors
- Errors include context for debugging
- Testable: verify correct error is thrown

**Benefits**:

1. Invalid states become impossible to construct
2. Throwing methods document and enforce invariants
3. Domain model matches Z specification exactly
4. Callers use operations (`key()`) not raw state (`activateTone()`)
5. No crashes in production

**Migration**:

- `ToneGenerator` owns a `Radio` instance
- Replace `setRadioMode(.transmitting)` + `activateTone()` with `radio.startTransmitting()` + `radio.key()`
- Audio callback reads `radio.mode` and `radio.isKeying`

**Files to modify**:

- New: `KochTrainer/Models/Radio.swift`
- Modify: `KochTrainer/Services/AudioEngine/ToneGenerator.swift`
- Modify: `KochTrainer/Services/AudioEngine/MorseAudioEngine.swift`
- Modify: `KochTrainer/ViewModels/MorseQSOViewModel.swift` (only place using transmitting)

---

### 2. Phase Transition Guards

**Constraints**:

- `PauseTraining: phase = training`
- `ResumeTraining: phase = paused`
- `ResetSession: phase = completed`

**Current enforcement**: Guards exist in ViewModels:

```swift
func pause() {
    guard case .training = phase else { return }
    // ...
}
```

**Tests exist**: `testPauseDuringIntroductionIsNoOp()`, `testResumeFromNonPausedIsNoOp()`

**Recommendation**: **No change** — Already complete.

---

### 3. Radio Mode Transitions

**Constraints**:

- `StartReceiving: radioMode = off`
- `StartTransmitting: radioMode = off`
- `StopRadio: radioMode ≠ off`

**Current enforcement**: None explicit. Radio mode is set directly without guards.

**Recommendation**: **Enforced via Radio type** — The new Radio type enforces these as part of its throwing API.

---

### 4. TrainingSession Counters

**Constraints**:

- `sessionCorrect ≤ sessionAttempts` (invariant)
- `phase = idle ⇒ sessionAttempts = 0`

**Current state**: Counters duplicated across 4 ViewModels as `@Published var`. Invariant structurally enforced but untested.

**Recommendation**: **Extract SessionCounter type** — Encapsulate counter logic with invariant enforcement.

**Design**:

```swift
/// Training session attempt counter with invariant enforcement.
/// Invariant: `correct ≤ attempts`
final class SessionCounter: ObservableObject {
    @Published private(set) var attempts: Int = 0
    @Published private(set) var correct: Int = 0

    var accuracy: Double {
        attempts > 0 ? Double(correct) / Double(attempts) : 0
    }

    func recordAttempt(wasCorrect: Bool) {
        attempts += 1
        if wasCorrect { correct += 1 }
    }

    func reset() {
        attempts = 0
        correct = 0
    }
}
```

**Benefits**:

1. Invariant `correct ≤ attempts` enforced by `recordAttempt()` API
2. No way to increment correct without incrementing attempts
3. Single source of truth for accuracy calculation
4. ViewModels use `@StateObject var counter = SessionCounter()`

**Why not extract full TrainingSession?**

- `SessionPhase` differs across ViewModels (vocabulary has no introduction, completed payloads differ)
- Phase transitions are tightly coupled to ViewModel-specific logic
- Counter extraction provides most of the value with minimal disruption

---

### 5. Ear Training Direction

**Constraints**:

- `AdvanceEarLevel: direction = receiveEar`
- `RecordEarAttempt: direction = receiveEar`

**Current enforcement**: Type-level. `EarTrainingViewModel` only calls `recordEarAttempt()`, never `recordReceiveAttempt()` or `recordSendAttempt()`. Separate fields prevent cross-contamination.

**Recommendation**: **No change** — Type system enforces direction implicitly.

---

## Impact Assessment

### Code Quality Impact

| Aspect | Impact |
|--------|--------|
| New domain types | **Radio + SessionCounter** |
| Production refactors | **ToneGenerator + 4 ViewModels** |
| New throwing methods | **5 in Radio** |
| Error type | **RadioError with 3 cases** |
| Test additions | **~18 tests** (Radio + SessionCounter) |

### Defensive Coding Analysis

The codebase uses two strategies with different appropriateness:

1. **Guard-based early returns** (ViewModels): `guard case .training = phase else { return }`
   - Idiomatic Swift for UI operations
   - Appropriate: Button taps during transitions should fail silently

2. **Defensive rendering** (Audio): Callback handles all state combinations
   - Masks invalid states rather than preventing them
   - Problem: Allows construction of invalid `radioMode + toneActive` combinations
   - **Not a design pattern** — a fallback when you can't control the API

**New approach for Radio**:

1. **Throwing domain operations** (Radio type)
   - Operations like `key()` throw on constraint violations
   - Invalid states are impossible to construct
   - Callers handle errors explicitly (log, ignore, show UI)
   - No crashes — recoverable errors
   - Audio callback still renders defensively as a safety net

**Verdict**: Different strategies for different layers:

- UI layer: Guard returns (graceful degradation for user actions)
- Domain layer: Throwing methods (explicit constraint violations)
- Audio layer: Defensive rendering (safety net only, not primary defense)

### Test Scaffolding Complexity

| Test Type | Setup Needed | Complexity |
|-----------|--------------|------------|
| Radio state machine tests | None - pure unit tests | **Low** |
| SessionCounter tests | None - pure unit tests | **Low** |
| MockAudioEngine updates | Add Radio operations to mock | **Low** |
| ViewModel test updates | Use real SessionCounter (ObservableObject) | **Low** |

**Total scaffolding cost**: Low. Both domain types are pure models with no external dependencies.

### Formal Model Value Proposition

**Benefits delivered**:

1. **Explicit invariants**: Spec documents `correctCount ≤ totalAttempts` even though code enforces it structurally
2. **Operation contracts**: `phase = training` precondition on `PauseSession` matches guard clause exactly
3. **Gap identification**: Audit found missing invariant test that wouldn't have been noticed otherwise
4. **Refactoring safety**: Tests against spec constraints catch regressions when code changes

**Costs**:

- Spec maintenance (low — focused on persistent state)
- Learning curve (medium — Z notation)
- Test additions (low — straightforward invariant tests)

---

## Implementation Plan

### Step 1: Create Radio Domain Model

**New file**: `KochTrainer/Models/Radio.swift`

```swift
/// Half-duplex radio state machine per Z specification.
///
/// Invariants enforced by throwing methods:
/// - `¬(mode = receiving ∧ isKeying)` — can only key while transmitting
/// - `¬(mode = off ∧ isKeying)` — can only key while transmitting
/// - Mode transitions require `mode = off`
final class Radio: @unchecked Sendable {
    enum Mode: Equatable, Sendable {
        case off, receiving, transmitting
    }

    enum RadioError: Error, Equatable {
        case mustBeOff(current: Mode)
        case mustBeTransmitting(current: Mode)
        case alreadyOff
    }

    private let lock = NSLock()
    private var _mode: Mode = .off
    private var _isKeying: Bool = false

    var mode: Mode {
        lock.lock()
        defer { lock.unlock() }
        return _mode
    }

    var isKeying: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isKeying
    }

    func startReceiving() throws {
        lock.lock()
        defer { lock.unlock() }
        guard _mode == .off else {
            throw RadioError.mustBeOff(current: _mode)
        }
        _mode = .receiving
    }

    func startTransmitting() throws {
        lock.lock()
        defer { lock.unlock() }
        guard _mode == .off else {
            throw RadioError.mustBeOff(current: _mode)
        }
        _mode = .transmitting
    }

    func stop() throws {
        lock.lock()
        defer { lock.unlock() }
        guard _mode != .off else {
            throw RadioError.alreadyOff
        }
        _isKeying = false
        _mode = .off
    }

    func key() throws {
        lock.lock()
        defer { lock.unlock() }
        guard _mode == .transmitting else {
            throw RadioError.mustBeTransmitting(current: _mode)
        }
        _isKeying = true
    }

    func unkey() throws {
        lock.lock()
        defer { lock.unlock() }
        guard _mode == .transmitting else {
            throw RadioError.mustBeTransmitting(current: _mode)
        }
        _isKeying = false
    }
}
```

### Step 2: Add Radio Tests

**New file**: `KochTrainerTests/Models/RadioTests.swift`

```swift
// Happy path tests
func testStartReceiving_fromOff_succeeds() throws
func testStartTransmitting_fromOff_succeeds() throws
func testStop_fromReceiving_succeeds() throws
func testKey_whileTransmitting_succeeds() throws
func testUnkey_whileTransmitting_succeeds() throws
func testStop_clearsKeying() throws

// Constraint violation tests
func testStartReceiving_fromReceiving_throws()
func testStartTransmitting_fromReceiving_throws()
func testStop_fromOff_throws()
func testKey_whileReceiving_throws()
func testKey_whileOff_throws()

// Error content tests
func testRadioError_includesCurrentMode()
```

### Step 3: Integrate Radio into ToneGenerator

**Modify**: `KochTrainer/Services/AudioEngine/ToneGenerator.swift`

- Add `let radio = Radio()` property
- Replace `_radioMode` and `_isToneActive` with `radio.mode` and `radio.isKeying`
- Update audio callback to read from `radio`
- Keep defensive rendering as safety net

### Step 4: Update MorseAudioEngine Interface

**Modify**: `KochTrainer/Services/AudioEngine/MorseAudioEngine.swift`

- Replace `setRadioMode(_ mode:)` with `startReceiving()`, `startTransmitting()`, `stop()`
- Replace `activateTone()`/`deactivateTone()` with `key()`/`unkey()` (internal use only)

### Step 5: Update AudioEngineProtocol

**Modify**: `KochTrainer/Services/AudioEngine/MorseAudioEngine.swift` (protocol)

Update protocol to use Radio operations instead of raw mode setting.

### Step 6: Update ViewModels

**Modify**:

- `MorseQSOViewModel.swift`: Use `audioEngine.startTransmitting()` + `audioEngine.key()` for keying
- Other ViewModels: Use `startReceiving()` and `stop()` instead of `setRadioMode()`

### Step 7: Create SessionCounter Domain Model

**New file**: `KochTrainer/Models/SessionCounter.swift`

```swift
/// Training session attempt counter per Z specification.
///
/// Invariant enforced: `correct ≤ attempts`
/// The only way to increment correct is via recordAttempt(wasCorrect: true),
/// which always increments attempts first.
import Foundation
import Combine

final class SessionCounter: ObservableObject {
    @Published private(set) var attempts: Int = 0
    @Published private(set) var correct: Int = 0

    var accuracy: Double {
        attempts > 0 ? Double(correct) / Double(attempts) : 0
    }

    func recordAttempt(wasCorrect: Bool) {
        attempts += 1
        if wasCorrect { correct += 1 }
    }

    func reset() {
        attempts = 0
        correct = 0
    }
}
```

### Step 8: Add SessionCounter Tests

**New file**: `KochTrainerTests/Models/SessionCounterTests.swift`

```swift
func testRecordAttempt_incrementsAttempts()
func testRecordAttempt_correct_incrementsBoth()
func testRecordAttempt_incorrect_onlyIncrementsAttempts()
func testInvariant_correctNeverExceedsAttempts()
func testAccuracy_calculatesCorrectly()
func testReset_clearsCounters()
```

### Step 9: Integrate SessionCounter into ViewModels

**Modify**:

- `ReceiveTrainingViewModel.swift`: Replace `correctCount`/`totalAttempts` with `@StateObject var counter = SessionCounter()`
- `SendTrainingViewModel.swift`: Same
- `EarTrainingViewModel.swift`: Same
- `VocabularyTrainingViewModel.swift`: Same

Update views to read `viewModel.counter.correct` and `viewModel.counter.attempts`.

### Step 10: Update AUDIT.md Coverage

Mark constraints as covered after tests added.

### Step 11: Run Tests

```bash
make test
```

---

## Verification

1. `make build` passes (format + lint + compile)
2. `make test` passes with new Radio and SessionCounter tests
3. Radio throws correct errors on constraint violations
4. SessionCounter enforces `correct ≤ attempts` invariant
5. Callers handle `RadioError` appropriately (try?, do-catch, or propagate)
6. MorseQSOViewModel keying works correctly with new Radio API
7. ViewModels use SessionCounter correctly (`counter.attempts`, `counter.correct`)
8. Update AUDIT.md coverage for enforced constraints

---

## Conclusion

The Z specification audit revealed missing domain abstractions:

1. **Radio** — `radioMode` and `toneActive` are coupled state that should be owned by a single type
2. **SessionCounter** — `correct` and `attempts` counters with invariant `correct ≤ attempts`

**Key insight**: Both cases share a pattern — coupled state with invariants was scattered across implementation details. The formal model identified the abstractions that should exist.

**The formal model's value**:

- Identified missing domain abstractions (Radio, SessionCounter)
- Provided the invariants each type must enforce
- Guides API design (operations match Z spec schemas)
- Leads to domain model that matches the specification structure

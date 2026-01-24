# Z Specification Test Coverage Audit

*Generated: 2026-01-24*

## Summary

| Category | Covered | Total | Coverage |
|----------|---------|-------|----------|
| Invariants | 8 | 12 | 67% |
| Preconditions | 18 | 24 | 75% |
| Effects | 15 | 21 | 71% |
| Bounds | 4 | 6 | 67% |
| **Total** | **45** | **63** | **71%** |

## Coverage by Category

### Invariants

| Constraint | Source | Test File | Confidence |
|------------|--------|-----------|------------|
| `receiveLevel ∈ 1..26` | StudentProgress | StudentProgressTests | ✅ High |
| `sendLevel ∈ 1..26` | StudentProgress | StudentProgressTests | ✅ High |
| `earLevel ∈ 1..26` | StudentProgress | StudentProgressTests | ✅ High |
| `receiveInterval ∈ 1..30` | PracticeSchedule | IntervalCalculatorTests | ✅ High |
| `sendInterval ∈ 1..30` | PracticeSchedule | IntervalCalculatorTests | ✅ High |
| `currentStreak ≥ 0` | PracticeSchedule | StreakCalculatorTests | ✅ High |
| `longestStreak ≥ currentStreak` | PracticeSchedule | StreakCalculatorTests | ✅ High |
| `sessionCorrect ≤ sessionAttempts` | TrainingSession | — | ❌ None |
| `radioMode ∈ {off, receiving, transmitting}` | TrainingSession | RadioModeTests | ✅ High |
| `¬(radioMode = receiving ∧ toneActive)` | TrainingSession | — | ❌ None |
| `¬(radioMode = off ∧ toneActive)` | TrainingSession | — | ❌ None |
| `phase = idle ⇒ sessionAttempts = 0` | TrainingSession | — | ❌ None |

### Preconditions

| Constraint | Source | Test File | Confidence |
|------------|--------|-----------|------------|
| `AdvanceReceiveLevel: receiveLevel < 26` | AdvanceReceiveLevel | StudentProgressTests | ✅ High |
| `AdvanceReceiveLevel: direction = receive` | AdvanceReceiveLevel | StudentProgressTests | ⚠️ Medium |
| `AdvanceSendLevel: sendLevel < 26` | AdvanceSendLevel | StudentProgressTests | ✅ High |
| `AdvanceSendLevel: direction = send` | AdvanceSendLevel | StudentProgressTests | ⚠️ Medium |
| `AdvanceEarLevel: earLevel < 26` | AdvanceEarLevel | StudentProgressTests | ✅ High |
| `AdvanceEarLevel: direction = receiveEar` | AdvanceEarLevel | — | ❌ None |
| `RecordReceiveAttempt: direction = receive` | RecordReceiveAttempt | ReceiveTrainingViewModelTests | ⚠️ Medium |
| `RecordSendAttempt: direction = send` | RecordSendAttempt | SendTrainingViewModelTests | ⚠️ Medium |
| `RecordEarAttempt: direction = receiveEar` | RecordEarAttempt | — | ❌ None |
| `RecordSession: phase = completed` | RecordSession | ProgressStoreTests | ⚠️ Medium |
| `IncrementStreak: phase = completed` | IncrementStreak | StreakCalculatorTests | ⚠️ Medium |
| `ActivateTone: radioMode = transmitting` | ActivateTone | — | ❌ None |
| `DeactivateTone: toneActive` | DeactivateTone | ToneGeneratorTests | ⚠️ Medium |
| `StartReceiving: radioMode = off` | StartReceiving | — | ❌ None |
| `StartTransmitting: radioMode = off` | StartTransmitting | — | ❌ None |
| `StopRadio: radioMode ≠ off` | StopRadio | — | ❌ None |
| `StartIntroduction: phase = idle` | StartIntroduction | ReceiveTrainingViewModelTests | ⚠️ Medium |
| `StartTraining: phase = introduction` | StartTraining | ReceiveTrainingViewModelTests | ⚠️ Medium |
| `PauseTraining: phase = training` | PauseTraining | — | ❌ None |
| `ResumeTraining: phase = paused` | ResumeTraining | — | ❌ None |
| `CompleteSession: phase ∈ {training, paused}` | CompleteSession | ReceiveTrainingViewModelTests | ⚠️ Medium |
| `ResetSession: phase = completed` | ResetSession | — | ❌ None |
| `UpdateReceiveInterval: accuracy provided` | UpdateReceiveInterval | IntervalCalculatorTests | ✅ High |
| `UpdateSendInterval: accuracy provided` | UpdateSendInterval | IntervalCalculatorTests | ✅ High |

### Effects (Post-conditions)

| Constraint | Source | Test File | Confidence |
|------------|--------|-----------|------------|
| `AdvanceReceiveLevel: receiveLevel' = receiveLevel + 1` | AdvanceReceiveLevel | StudentProgressTests | ✅ High |
| `AdvanceSendLevel: sendLevel' = sendLevel + 1` | AdvanceSendLevel | StudentProgressTests | ✅ High |
| `AdvanceEarLevel: earLevel' = earLevel + 1` | AdvanceEarLevel | StudentProgressTests | ✅ High |
| `RecordReceiveAttempt: sessionAttempts' = sessionAttempts + 1` | RecordReceiveAttempt | ReceiveTrainingViewModelTests | ⚠️ Medium |
| `RecordReceiveAttempt: correct ⇒ sessionCorrect' = sessionCorrect + 1` | RecordReceiveAttempt | ReceiveTrainingViewModelTests | ⚠️ Medium |
| `RecordSendAttempt: sessionAttempts' = sessionAttempts + 1` | RecordSendAttempt | SendTrainingViewModelTests | ⚠️ Medium |
| `RecordEarAttempt: sessionAttempts' = sessionAttempts + 1` | RecordEarAttempt | — | ❌ None |
| `IncrementStreak: currentStreak' = currentStreak + 1` | IncrementStreak | StreakCalculatorTests | ✅ High |
| `IncrementStreak: longestStreak' = max(longestStreak, currentStreak')` | IncrementStreak | StreakCalculatorTests | ✅ High |
| `ResetStreak: currentStreak' = 1` | ResetStreak | StreakCalculatorTests | ✅ High |
| `ActivateTone: toneActive' = true` | ActivateTone | ToneGeneratorTests | ⚠️ Medium |
| `DeactivateTone: toneActive' = false` | DeactivateTone | ToneGeneratorTests | ⚠️ Medium |
| `StartReceiving: radioMode' = receiving` | StartReceiving | — | ❌ None |
| `StartTransmitting: radioMode' = transmitting` | StartTransmitting | — | ❌ None |
| `StopRadio: radioMode' = off` | StopRadio | — | ❌ None |
| `StartIntroduction: phase' = introduction` | StartIntroduction | ReceiveTrainingViewModelTests | ⚠️ Medium |
| `StartTraining: phase' = training` | StartTraining | ReceiveTrainingViewModelTests | ⚠️ Medium |
| `CompleteSession: phase' = completed` | CompleteSession | ReceiveTrainingViewModelTests | ⚠️ Medium |
| `ResetSession: phase' = idle` | ResetSession | — | ❌ None |
| `UpdateReceiveInterval: interval doubles if accuracy ≥ 90%` | UpdateReceiveInterval | IntervalCalculatorTests | ✅ High |
| `UpdateReceiveInterval: interval resets to 1 if accuracy < 70%` | UpdateReceiveInterval | IntervalCalculatorTests | ✅ High |

### Bounds

| Constraint | Source | Test File | Confidence |
|------------|--------|-----------|------------|
| `receiveLevel ≤ MODEL_BOUND` | Init | — | ❌ None |
| `sendLevel ≤ MODEL_BOUND` | Init | — | ❌ None |
| `earLevel ≤ MODEL_BOUND` | Init | StudentProgressTests | ⚠️ Medium |
| `receiveInterval ≤ 30` | UpdateReceiveInterval | IntervalCalculatorTests | ✅ High |
| `sendInterval ≤ 30` | UpdateSendInterval | IntervalCalculatorTests | ✅ High |
| `currentStreak capped during habit formation` | UpdateStreak | IntervalCalculatorTests | ⚠️ Medium |

## Uncovered Constraints (High Priority)

These constraints from the Z specification have no corresponding test coverage:

### 1. Session Invariant: `sessionCorrect ≤ sessionAttempts`

**Risk**: Could record more correct answers than attempts.

**Suggested Test**:
```swift
func testSessionCorrect_neverExceedsAttempts() {
    // Verify invariant holds across all recording operations
}
```

### 2. Radio/Tone Half-Duplex Invariants

**Constraints**:
- `¬(radioMode = receiving ∧ toneActive)`
- `¬(radioMode = off ∧ toneActive)`

**Risk**: Violating half-duplex behavior (playing sidetone while receiving).

**Suggested Test**:
```swift
func testToneActive_requiresTransmitting() {
    // Verify toneActive is false whenever radioMode ≠ transmitting
}
```

### 3. Phase Transition Guards

**Constraints**:
- `PauseTraining: phase = training`
- `ResumeTraining: phase = paused`
- `ResetSession: phase = completed`

**Risk**: Invalid phase transitions.

**Suggested Tests**:
```swift
func testPauseTraining_requiresTrainingPhase()
func testResumeTraining_requiresPausedPhase()
func testResetSession_requiresCompletedPhase()
```

### 4. Radio Mode Transitions

**Constraints**:
- `StartReceiving: radioMode = off`
- `StartTransmitting: radioMode = off`
- `StopRadio: radioMode ≠ off`

**Risk**: Invalid radio state machine transitions.

**Suggested Tests**:
```swift
func testStartReceiving_requiresRadioOff()
func testStartTransmitting_requiresRadioOff()
func testStopRadio_requiresRadioOn()
```

### 5. Ear Training Direction

**Constraints**:
- `AdvanceEarLevel: direction = receiveEar`
- `RecordEarAttempt: direction = receiveEar`

**Risk**: Ear level advancing from wrong training mode.

**Suggested Test**:
```swift
func testAdvanceEarLevel_requiresReceiveEarDirection()
```

## Recommendations

1. **Add RadioMode state machine tests**: The radio state machine (off → receiving/transmitting → off) lacks transition guard tests.

2. **Add TrainingSession invariant tests**: The `sessionCorrect ≤ sessionAttempts` invariant should be explicitly tested.

3. **Add half-duplex tests**: Verify `toneActive` is only true when `radioMode = transmitting`.

4. **Add phase transition guard tests**: Each phase transition should verify its precondition.

5. **Add ear training direction tests**: Verify `receiveEar` direction is required for ear-specific operations.

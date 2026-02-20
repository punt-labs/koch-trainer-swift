# Koch Trainer Design Document

This document captures architectural decisions, design rationale, and implementation notes for the Koch Trainer iOS app.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Concepts](#core-concepts)
4. [Feature Design](#feature-design)
5. [Testing Strategy](#testing-strategy)
6. [Outstanding Work](#outstanding-work-design-notes)

---

## Overview

Koch Trainer teaches Morse code using the Koch method—a proven technique where students learn characters at full speed, adding one new character at a time after achieving 90% accuracy.

### Design Philosophy

- **Audio-first**: Morse code is an auditory skill. Visual aids support learning but audio is primary.
- **Spaced repetition**: Practice intervals adapt to performance, maximizing retention.
- **Realistic simulation**: QSO practice mirrors real ham radio operation.
- **Accessibility**: Morse code has historical significance for visually impaired users.

### Key Metrics

| Metric | Value |
|--------|-------|
| Koch character order | K M R S U A P T L O W I N J E F Y V G Q Z H B C D X |
| Character speed | 20 WPM (fixed) |
| Effective speed | 10-18 WPM (Farnsworth timing, user-adjustable) |
| Advancement threshold | 90% accuracy over 20+ attempts |

---

## Architecture

### Layer Overview

```text
┌─────────────────────────────────────────────────────┐
│                      Views                          │
│  (SwiftUI, declarative UI, minimal logic)           │
├─────────────────────────────────────────────────────┤
│                   ViewModels                        │
│  (State management, business logic, @Observable)    │
├─────────────────────────────────────────────────────┤
│                    Services                         │
│  (Audio, persistence, calculations, notifications)  │
├─────────────────────────────────────────────────────┤
│                     Models                          │
│  (Data structures, Codable, business rules)         │
└─────────────────────────────────────────────────────┘
```

### Data Flow

```text
User Input → View → ViewModel → Service → Model
                ↓
            State Change
                ↓
View ← ViewModel (Published properties)
```

### Key Architectural Decisions

#### 1. Separate Receive/Send Levels

Receive (listening) and send (keying) are distinct skills that progress independently:

- Users may excel at one before the other
- Separate tracking prevents frustration
- Each has its own spaced repetition schedule

#### 2. Session Types with Shared Infrastructure

```swift
enum SessionType {
    case receive, send           // Learn mode (affects levels/schedule)
    case receiveCustom, sendCustom   // Custom practice (stats only)
    case receiveVocabulary, sendVocabulary  // Vocabulary (stats only)
    case qso                     // QSO simulation (combined send/receive)
}
```

Only `.receive` and `.send` can advance levels and affect the spaced repetition schedule. This prevents custom/vocabulary practice from interfering with the core learning progression.

#### 3. Farnsworth Timing

Characters play at full speed (20 WPM) but with extended gaps between characters. This trains the ear to recognize patterns at speed while giving beginners time to process.

```text
Character speed: 20 WPM (60ms dit, 180ms dah)
Effective speed: User-selected 10-18 WPM
Gap extension: Calculated to achieve effective WPM
```

#### 4. Paused Session Persistence

Training sessions can be paused and resumed within 24 hours:

- Stored in UserDefaults as JSON
- Two slots: one for receive-direction, one for send-direction
- Validates session type and custom characters on restore
- Auto-expires after 24 hours

---

## Core Concepts

### Spaced Repetition Algorithm

The interval between practice sessions adapts based on performance:

| Accuracy | Interval Change |
|----------|-----------------|
| ≥90% | Double interval (max 30 days) |
| 70-89% | No change |
| <70% | Reset to 1 day |

**Special rules:**

- First 14 days: capped at 2 days (habit formation)
- Missed >2× interval: reset to 1 day (skill decay)

### Streak Tracking

Consecutive calendar days with at least one completed session:

- Same-day practice: streak unchanged
- Next calendar day: streak +1
- Skipped day: streak resets to 1

### Character Statistics

Per-character accuracy tracked separately by training direction:

```swift
struct CharacterStat: Codable {
    var receiveAttempts: Int
    var receiveCorrect: Int
    var sendAttempts: Int
    var sendCorrect: Int
    var earTrainingAttempts: Int
    var earTrainingCorrect: Int

    var kochAccuracy: Double  // Receive + send only, used for proficiency indicators
}
```

Note: Ear training stats are tracked separately and do not contribute to proficiency indicators,
as ear training focuses on dit/dah pattern recognition rather than character identification.

### Audio Engine

Serial queue ensures rapid key presses don't drop audio:

```swift
private let audioQueue = DispatchQueue(label: "com.kochtrainer.audioQueue")

func playElement(_ element: MorseElement) {
    audioQueue.async {
        // Generate and play tone
        // Wait for completion before returning
    }
}
```

**Timing constants (20 WPM):**

| Element | Duration |
|---------|----------|
| Dit | 60ms |
| Dah | 180ms |
| Inter-element gap | 60ms |
| Inter-character gap | ~420ms (Farnsworth-adjusted) |
| Inter-word gap | ~980ms (Farnsworth-adjusted) |

---

## Feature Design

### Character Proficiency Indicators

**Implementation**: Progress rings on character grid cells

- Circular cell backgrounds (60×60pt)
- Ring stroke on outer edge (4pt stroke, 2pt inset)
- Color tiers: orange (<50%) → yellow (50-79%) → green (≥80%)
- Ring hidden for unpracticed characters (consistent cell size)
- VoiceOver: "K, 95% proficiency, selected"

**Files:**

- `ProficiencyRingView.swift` - Ring overlay component
- `CharacterGridView.swift` - Circular cells with ring integration
- `PracticeView.swift` - Passes characterStats to grid

### QSO Simulation

**Design Philosophy**: Mirrors real ham radio operation

- User sends their transmissions by keying dit/dah
- User listens to remote station's Morse audio
- No separate "receive mode"—this IS how real QSOs work

**QSO Styles (Progression):**

1. **First Contact** (Beginner)
   - CQ → Callsign exchange → RST → 73
   - ~4 exchanges, simple vocabulary

2. **Signal Report** (Intermediate)
   - Adds NAME and basic pleasantries
   - ~6 exchanges

3. **Contest** (Advanced)
   - Full contest exchange with serial numbers

4. **Rag Chew** (Expert)
   - Extended conversation: QTH, rig, weather

**UI Flow:**

```text
1. AI transmits: [Morse audio] "CQ CQ CQ DE W1AW K"
2. Text reveals character-by-character with audio
   (or hidden in copy-by-ear mode)
3. User sees script to send with cursor indicator
4. User keys message using paddle/keyboard
5. System decodes and validates
6. Real-time WPM displayed during keying
7. Continue to next exchange
```

### Band Conditions Simulation

**Implementation** (BandConditionsProcessor.swift):

- **QRN (Noise)**: Pink noise filter for atmospheric simulation (more realistic than white noise)
- **QSB (Fading)**: Filtered random noise modulation (replaced sine wave for irregular, natural fading)
- **QRM (Interference)**: Random tones at offset frequencies
- **Continuous audio**: Half-duplex radio simulation with background noise during silence

**Design rationale**: Real HF conditions have irregular fading patterns and frequency-shaped noise. Pure sine wave QSB and white noise sound artificial. Pink noise (1/f spectrum) better matches atmospheric noise characteristics, and filtered random modulation produces the gradual, unpredictable fading heard on real bands.

**Files:**

- `BandConditionsProcessor.swift` - DSP processing for band conditions
- `ToneGenerator.swift` - Integrates via `processSample()`
- Settings view provides "Preview Sound" button for tuning

### Notification System

Anti-nag policy prevents notification fatigue:

| Rule | Value |
|------|-------|
| Max per day | 2 notifications |
| Minimum gap | 4 hours |
| Quiet hours | 10 PM - 8 AM (adjustable) |

**Notification Types:**

- Practice Due: when nextDate reached
- Streak Reminder: 8 PM if no practice today and streak ≥3
- Level Review: 7 days after level-up
- Welcome Back: 7+ days inactive

---

## Testing Strategy

### Test Pyramid

```text
        ┌─────────────┐
        │   UI Tests  │  ← Slow, integration-level
        │  (~70 tests)│    Tests full user flows
        ├─────────────┤
        │  Unit Tests │  ← Fast, isolated
        │ (~950 tests)│    Tests logic in isolation
        └─────────────┘
```

### Unit Tests

**Philosophy**: Test business logic in isolation. ViewModels and Services contain the logic; Views are thin wrappers.

**What We Test:**

- ViewModels: State transitions, input handling, calculated properties
- Services: Persistence, calculations, audio timing
- Models: Encoding/decoding, computed properties, validation

**What We Don't Test:**

- Views directly (tested via UI tests instead)
- Third-party framework behavior
- Trivial getters/setters

**Test Organization:**

```text
KochTrainerTests/
├── Models/
│   ├── StudentProgressTests.swift
│   ├── CharacterStatTests.swift
│   └── MorseCodeTests.swift
├── ViewModels/
│   ├── ReceiveTrainingViewModelTests.swift
│   ├── SendTrainingViewModelTests.swift
│   └── EarTrainingViewModelTests.swift
└── Services/
    ├── ProgressStoreTests.swift
    ├── IntervalCalculatorTests.swift
    └── StreakCalculatorTests.swift
```

### UI Tests

**Philosophy**: Test user flows end-to-end. UI tests verify that views, view models, and services work together correctly.

**What We Test:**

- Navigation between screens
- Training flow phases (intro → training → paused → completed)
- Button interactions and state changes
- Accessibility identifier presence (enables VoiceOver testing)

**Page Object Pattern:**

UI tests use page objects to encapsulate element queries and actions:

```swift
// Page object encapsulates element access
class LearnPage: BasePage {
    var earTrainingButton: XCUIElement {
        button(id: AccessibilityID.Learn.earTrainingButton)
    }

    func goToEarTraining() -> EarTrainingPage {
        earTrainingButton.tap()
        return EarTrainingPage(app: app)
    }
}

// Test reads like a user story
func testCompleteTrainingFlow() throws {
    let learnPage = LearnPage(app: app).waitForPage()
    let trainingPage = learnPage.goToEarTraining()
        .waitForIntro()
        .skipIntroduction()
        .waitForTraining()

    trainingPage.pause()
    trainingPage.endSession()
    trainingPage.tapDone()
        .assertDisplayed()
}
```

**Page Object Hierarchy:**

```text
KochTrainerUITests/
├── Pages/
│   ├── BasePage.swift           ← Common element accessors
│   ├── LearnPage.swift          ← Home/Learn screen
│   ├── TrainingPage.swift       ← Shared training elements
│   ├── ReceiveTrainingPage.swift
│   ├── SendTrainingPage.swift
│   └── EarTrainingPage.swift
├── ReceiveTrainingUITests.swift
├── SendTrainingUITests.swift
└── EarTrainingUITests.swift
```

### Accessibility Identifiers for UI Testing

**Problem**: SwiftUI's accessibility identifier inheritance can cause parent identifiers to propagate to children, making elements untestable.

**Solution**: Use `.accessibilityElement(children: .contain)` on container views:

```swift
// Without .contain, section's identifier propagates to button
VStack {
    NavigationLink { ... }
        .accessibilityIdentifier("button-id")  // ❌ Gets overwritten
}
.accessibilityIdentifier("section-id")

// With .contain, each element keeps its own identifier
VStack {
    NavigationLink { ... }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("button-id")  // ✓ Preserved
}
.accessibilityElement(children: .contain)
.accessibilityIdentifier("section-id")
```

**Centralized Identifiers:**

All accessibility identifiers are defined in `AccessibilityID.swift`:

```swift
enum AccessibilityID {
    enum Learn {
        static let view = "learn-view"
        static let earTrainingButton = "learn-ear-training-start-button"
        static let receiveTrainingButton = "learn-receive-training-start-button"
        // ...
    }

    enum Training {
        static let introView = "training-intro-view"
        static let nextCharacterButton = "training-next-character-button"
        static let pauseButton = "training-pause-button"
        // ...
    }
}
```

### Test Launch Configuration

UI tests launch with `--uitesting` argument to reset state:

```swift
override func setUpWithError() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
}
```

The app checks this flag to:

- Reset progress to level 1
- Clear any paused sessions
- Use predictable test data

### Coverage Targets

| Component | Current | Target |
|-----------|---------|--------|
| ViewModels | 75-86% | 90%+ |
| Services | 82-97% | 95%+ |
| Models | 70-100% | 85%+ |
| UI Flows | ~70 tests | All critical paths |

**Total**: ~950 unit tests + ~70 UI tests

---

## Outstanding Work: Design Notes

This section contains design notes for planned features tracked in beads. Use `bd show <id>` for current status.

### Accessibility Compliance (beads: koch-trainer-swift-cem)

**Why This Matters**: Morse code has historical significance for people with visual impairments. The app should be fully accessible.

**Completed:**

- Training feedback VoiceOver announcements (PR #17)
- Accessibility identifiers on testable UI elements (PR #21)

**iOS Accessibility Modifiers:**

```swift
.accessibilityLabel(_:)      // Meaningful descriptions
.accessibilityHint(_:)       // Context about actions
.accessibilityValue(_:)      // Current state for dynamic elements
.accessibilityElement(children: .combine)  // Group related elements
.accessibilityAddTraits(_:)  // Mark headers, buttons, etc.
.accessibilityHidden(_:)     // Hide decorative/hidden elements
```

**Remaining Work:**

| Task | Issue | Status |
|------|-------|--------|
| Full view accessibility audit | `koch-trainer-swift-mfr` | Open |
| Image-only button labels | `koch-trainer-swift-v0x` | Open |
| VoiceOver navigation testing | `koch-trainer-swift-5ge` | Open |
| Dynamic Type support | `koch-trainer-swift-qc3` | Open |
| Hide text from VoiceOver in copy-by-ear | `koch-trainer-swift-j3i` | Open (bug) |

**VoiceOver Behaviors Already Implemented:**

- Training feedback: Announces "Correct" or "Incorrect, the letter was K"

**VoiceOver Behaviors Remaining:**

- Character introduction pattern descriptions
- Progress indicator announcements
- Character grid proficiency descriptions

**References:**

- [iOS Accessibility Guidelines 2025](https://medium.com/@david-auerbach/ios-accessibility-guidelines-best-practices-for-2025-6ed0d256200e)
- [SwiftUI Accessibility Best Practices](https://commitstudiogs.medium.com/accessibility-in-swiftui-apps-best-practices-a15450ebf554)
- [CVS Health iOS Accessibility Techniques](https://github.com/cvs-health/ios-swiftui-accessibility-techniques)

---

### Test Coverage Plan (beads: koch-trainer-swift-jto)

**Current**: ~1,020 tests (950 unit + 70 UI)
**Target**: 90%+ on non-View code (Views tested via XCUITest)

**Strategy Decision (Completed):**
View testing uses XCUITest integration tests rather than unit-level ViewInspector or snapshot testing. This provides comprehensive end-to-end coverage of user flows.

**Completed Test Suites:**

| Component | Issue | Status |
|-----------|-------|--------|
| NotificationManager | — | Done (97%+) |
| Models (WordStat, QSOState, etc.) | — | Done (100%) |
| ReceiveTrainingViewModel | — | Done |
| VocabularyTrainingViewModel | `koch-trainer-swift-bzx` | Done |
| SendTrainingViewModel | `koch-trainer-swift-g1g` | Done |
| StudentProgress | `koch-trainer-swift-eho` | Done |
| AppSettings | `koch-trainer-swift-819` | Done |
| QSOEngine | `koch-trainer-swift-69q` | Done |
| MorseDecoder | `koch-trainer-swift-2h5` | Done |
| MorseAudioEngine | `koch-trainer-swift-82u` | Done |
| StreakCalculator | `koch-trainer-swift-sdq` | Done |

**UI Test Infrastructure (Completed):**

- Page object base classes (PR #27)
- Training-specific page objects (PR #28)
- UITesting configuration with silent audio engine (PR #24)

**Completed:**

- `koch-trainer-swift-0nx`: UI test coverage for core flows (PR #41)

**Remaining Work:**

- `koch-trainer-swift-ae4`: Pause/resume tests
- `koch-trainer-swift-atl`: Edge case UI tests

---

## Appendix: Code Quality Standards

### SwiftFormat + SwiftLint Alignment

Both tools run as part of `make build`:

| Setting | SwiftFormat | SwiftLint Rule |
|---------|-------------|----------------|
| Void type | `--voidtype void` | `void_return` |
| Trailing commas | `--commas inline` | `trailing_comma` |
| Brace placement | `--allman false` | `opening_brace` |

### File Length Limits

| Metric | Warning | Error |
|--------|---------|-------|
| File length | 500 lines | 1000 lines |
| Type body length | 300 lines | 500 lines |
| Function body length | 60 lines | 100 lines |

### Banned Patterns

- Force unwrapping (`value!`) - use guard/if let
- Implicitly unwrapped optionals (`var x: T!`) - use lazy or regular optional

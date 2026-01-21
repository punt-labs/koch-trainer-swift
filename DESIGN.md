# Koch Trainer Design Document

This document captures architectural decisions, design rationale, and implementation notes for the Koch Trainer iOS app.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Core Concepts](#core-concepts)
4. [Feature Design](#feature-design)
5. [Outstanding Work](#outstanding-work-design-notes)

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

```
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

```
User Input → View → ViewModel → Service → Model
                ↓
            State Change
                ↓
View ← ViewModel (Published properties)
```

### Key Architectural Decisions

**1. Separate Receive/Send Levels**

Receive (listening) and send (keying) are distinct skills that progress independently:
- Users may excel at one before the other
- Separate tracking prevents frustration
- Each has its own spaced repetition schedule

**2. Session Types with Shared Infrastructure**

```swift
enum SessionType {
    case receive, send           // Learn mode (affects levels/schedule)
    case receiveCustom, sendCustom   // Custom practice (stats only)
    case receiveVocabulary, sendVocabulary  // Vocabulary (stats only)
    case qso                     // QSO simulation (combined send/receive)
}
```

Only `.receive` and `.send` can advance levels and affect the spaced repetition schedule. This prevents custom/vocabulary practice from interfering with the core learning progression.

**3. Farnsworth Timing**

Characters play at full speed (20 WPM) but with extended gaps between characters. This trains the ear to recognize patterns at speed while giving beginners time to process.

```
Character speed: 20 WPM (60ms dit, 180ms dah)
Effective speed: User-selected 10-18 WPM
Gap extension: Calculated to achieve effective WPM
```

**4. Paused Session Persistence**

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

Per-character accuracy tracked across all session types:

```swift
struct CharacterStat: Codable {
    var receiveCorrect: Int
    var receiveTotal: Int
    var sendCorrect: Int
    var sendTotal: Int

    var combinedAccuracy: Double  // Used for proficiency indicators
}
```

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
```
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

**Current Implementation** (BandConditionsProcessor.swift):
- **QRN (Noise)**: Gaussian noise + occasional static crashes
- **QSB (Fading)**: Sinusoidal amplitude modulation
- **QRM (Interference)**: Random tones at offset frequencies

**Known Limitation**: Audio effects don't sound fully realistic. See [Outstanding Work](#band-conditions-tuning-beads-koch-trainer-swift-vh1) for research needed.

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

## Outstanding Work: Design Notes

This section contains design notes for planned features tracked in beads. Use `bd show <id>` for current status.

### Band Conditions Tuning (beads: koch-trainer-swift-vh1)

**Problem**: Current DSP implementation sounds artificial compared to real HF conditions.

**Research Needed:**
- Study real HF band recordings for reference waveforms
- Investigate pink noise vs white noise for atmospheric simulation
- Research proper QSB fading curves (not pure sine wave—real fading is irregular)
- Study impulse noise characteristics for static crashes
- Compare with Morse Runner's audio processing approach

**Implementation Notes:**
- All DSP in `BandConditionsProcessor.swift`
- Integrated into `ToneGenerator` via `processSample()`
- User will provide specific feedback on what sounds wrong

**Related beads issues:**
- `koch-trainer-swift-7cy`: Research HF band recordings
- `koch-trainer-swift-yc6`: Investigate pink vs white noise
- `koch-trainer-swift-653`: Study Morse Runner's approach

---

### Accessibility Compliance (beads: koch-trainer-swift-cem)

**Why This Matters**: Morse code has historical significance for people with visual impairments. The app should be fully accessible.

**iOS Accessibility Modifiers:**
```swift
.accessibilityLabel(_:)      // Meaningful descriptions
.accessibilityHint(_:)       // Context about actions
.accessibilityValue(_:)      // Current state for dynamic elements
.accessibilityElement(children: .combine)  // Group related elements
.accessibilityAddTraits(_:)  // Mark headers, buttons, etc.
.accessibilityHidden(_:)     // Hide decorative/hidden elements
```

**Views Requiring Audit:**

| View | Concern |
|------|---------|
| CharacterGridView | Letter + proficiency description |
| ReceiveTrainingView | Feedback announcements, timer status |
| SendTrainingView | Dit/dah button labels, pattern feedback |
| QSOSessionView | Message transcript, phase announcements |
| SettingsView | Slider values, toggle states |
| ResultsView | Statistics grouped logically |

**VoiceOver Behaviors to Implement:**

1. **Training Feedback**: Announce "Correct" or "Incorrect, the letter was K"
2. **Character Introduction**: "Letter K, dash dot dash" pattern description
3. **Progress Indicators**: Announce accuracy percentage and attempt count
4. **Character Grid**: "K, 85% proficiency" when navigating

**Critical Bug** (beads: koch-trainer-swift-j3i): QSO copy-by-ear mode uses visual opacity only. VoiceOver still reads "hidden" text. Need `accessibilityHidden(true)` modifier.

**Related beads issues:**
- `koch-trainer-swift-mfr`: Audit all views
- `koch-trainer-swift-v0x`: Add accessibilityLabel to image-only buttons
- `koch-trainer-swift-9mb`: Training feedback announcements
- `koch-trainer-swift-5ge`: Test VoiceOver navigation
- `koch-trainer-swift-qc3`: Support Dynamic Type

**References:**
- [iOS Accessibility Guidelines 2025](https://medium.com/@david-auerbach/ios-accessibility-guidelines-best-practices-for-2025-6ed0d256200e)
- [SwiftUI Accessibility Best Practices](https://commitstudiogs.medium.com/accessibility-in-swiftui-apps-best-practices-a15450ebf554)
- [CVS Health iOS Accessibility Techniques](https://github.com/cvs-health/ios-swiftui-accessibility-techniques)

---

### Test Coverage Plan (beads: koch-trainer-swift-jto)

**Current**: ~38% coverage, 519 tests
**Target**: 80% coverage

**Priority Order:**
1. ViewModels (highest value per line)
2. Services (critical paths)
3. Models (business logic)
4. Views (lower priority, need testing strategy decision)

**Coverage by Component:**

| Component | Current | Target | Status |
|-----------|---------|--------|--------|
| NotificationManager | 97% | 95%+ | Done |
| Models (WordStat, QSOState, etc.) | 100% | 100% | Done |
| ReceiveTrainingViewModel | 86% | 90%+ | Done |
| VocabularyTrainingViewModel | 75% | 90%+ | Pending |
| SendTrainingViewModel | 79% | 90%+ | Pending |
| StudentProgress | 70% | 85%+ | Pending |
| Services (QSOEngine, etc.) | 82-91% | 95%+ | Pending |
| Views | 0-1% | 50%+ | Blocked on strategy |

**View Testing Strategy** (beads: koch-trainer-swift-ex7):

Options to evaluate:
1. **ViewInspector**: Unit-style testing, inspect view hierarchy
2. **Snapshot testing**: Catch visual regressions
3. **UI tests**: Integration-level, slower but comprehensive

Decision needed before writing 12+ view test files.

**Related beads issues:**
- `koch-trainer-swift-bzx`: VocabularyTrainingViewModelTests
- `koch-trainer-swift-g1g`: SendTrainingViewModelTests
- `koch-trainer-swift-eho`: StudentProgressTests
- `koch-trainer-swift-819`: AppSettingsTests
- `koch-trainer-swift-69q`: QSOEngineTests
- `koch-trainer-swift-2h5`: MorseDecoderTests
- `koch-trainer-swift-82u`: MorseAudioEngineTests
- `koch-trainer-swift-sdq`: StreakCalculatorTests

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

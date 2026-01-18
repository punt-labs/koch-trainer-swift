# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS app implementing the Koch method for learning Morse code. Single-user, letters only (K M R S U A P T L O W I N J E F Y V G Q Z H B C D X).

## Build & Run

Uses XcodeGen for project configuration. The `project.yml` file defines the project structure.

```bash
# Regenerate Xcode project, build, and test
make generate  # Regenerate xcodeproj from project.yml
make build     # Build the app
make test      # Run all tests
make clean     # Clean build artifacts

# Or manually
xcodegen generate
xcodebuild -scheme KochTrainer -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Architecture

### Project Structure

```
KochTrainer/
├── Models/
│   ├── StudentProgress.swift    # Levels, stats, session history, schedule
│   ├── PracticeSchedule.swift   # Intervals, streaks, review dates
│   ├── NotificationSettings.swift
│   ├── SessionResult.swift
│   ├── CharacterStat.swift
│   └── MorseCode.swift
├── ViewModels/
│   ├── ReceiveTrainingViewModel.swift
│   └── SendTrainingViewModel.swift
├── Views/
│   ├── Home/         # HomeView with streak card, practice due indicators
│   ├── Training/
│   │   ├── CharacterIntroductionView.swift
│   │   ├── Receive/  # ReceiveTrainingView
│   │   └── Send/     # SendTrainingView
│   ├── Results/
│   └── Settings/     # SettingsView with notification toggles
├── Services/
│   ├── AudioEngine/  # MorseAudioEngine, ToneGenerator
│   ├── ProgressStore.swift
│   ├── IntervalCalculator.swift  # Spaced repetition intervals
│   ├── StreakCalculator.swift    # Consecutive day tracking
│   ├── NotificationManager.swift # Local notification scheduling
│   ├── MorseDecoder.swift
│   └── GroupGenerator.swift
└── Resources/
    └── Assets.xcassets/
```

### Training Flow

Both receive and send training follow the same phase pattern:

1. **Introduction** - Shows each unlocked character with pattern, auto-plays sound
2. **Training** - Call-and-response with timeout, tracks accuracy
3. **Paused** - Optional pause state
4. **Completed** - Shows results, level-up celebration if advanced

Auto-advance triggers when: `totalAttempts >= 20 && accuracy >= 90%`

### Separate Levels

Progress is tracked independently for receive and send:

```swift
struct StudentProgress {
    var receiveLevel: Int  // 1-26
    var sendLevel: Int     // 1-26
    var schedule: PracticeSchedule  // Intervals, streaks, review dates

    func level(for sessionType: SessionType) -> Int
    func unlockedCharacters(for sessionType: SessionType) -> [Character]
}
```

### Streak & Spaced Repetition

`PracticeSchedule` tracks practice intervals and streaks:

```swift
struct PracticeSchedule {
    var receiveInterval: Double     // Days until next practice (1.0 - 30.0)
    var sendInterval: Double
    var receiveNextDate: Date?      // Calculated: lastPractice + interval
    var sendNextDate: Date?
    var currentStreak: Int          // Consecutive calendar days practiced
    var longestStreak: Int
    var lastStreakDate: Date?
    var levelReviewDates: [Int: Date]  // Level -> review date (7 days after advancing)
}
```

**Interval Algorithm** (`IntervalCalculator`):
| Accuracy | Interval Change |
|----------|-----------------|
| ≥90% | Double (max 30 days) |
| 70-89% | Unchanged |
| <70% | Reset to 1 day |

- First 14 days: capped at 2 days (habit formation)
- Missed >2× interval: reset to 1 day

**Streak Rules** (`StreakCalculator`):
- Consecutive calendar days with at least one session
- Same-day practice: streak unchanged
- Next day: streak +1
- Skipped day: streak resets to 1

### Notifications

`NotificationManager` schedules local notifications with anti-nag policy:

| Type | Trigger | Identifier |
|------|---------|------------|
| Practice Due | nextDate reached | `practice.receive` / `practice.send` |
| Streak Reminder | 8 PM, no practice today, streak ≥3 | `streak.reminder` |
| Level Review | 7 days after level-up | `level.review.\(level)` |
| Welcome Back | 7+ days inactive | `welcome.back` |

**Anti-Nag Policy**:
- Max 2 notifications/day
- 4-hour minimum gap
- Quiet hours: 10 PM - 8 AM (adjustable)

### Receive Training

- Plays Morse audio for a character
- User types the letter on keyboard (hidden TextField captures input)
- 3-second timeout with progress bar
- Immediate feedback, replays character if wrong

### Send Training

- Shows target character (no pattern hint)
- User taps dit/dah buttons or uses keyboard:
  - `.` or `F` = dit
  - `-` or `J` = dah
- Audio feedback plays for each dit/dah
- 2-second timeout after input to complete character
- Pattern decoded and compared to target

### Audio Engine

`ToneGenerator` uses a serial queue to ensure rapid key presses don't drop audio:

```swift
private let audioQueue = DispatchQueue(label: "com.kochtrainer.audioQueue")
```

Each tone request is queued and waits for the previous to finish.

### Audio Timing (20 WPM character speed)

| Element | Duration |
|---------|----------|
| Dit | 60ms |
| Dah | 180ms |
| Inter-element | 60ms |
| Inter-character (Farnsworth) | ~420ms |
| Inter-word (Farnsworth) | ~980ms |
| Tone frequency | 600 Hz (configurable 400-800) |

### Key Protocols

```swift
// Shared intro behavior for both training modes
@MainActor
protocol CharacterIntroducing: ObservableObject {
    var introCharacters: [Character] { get }
    var currentIntroCharacter: Character? { get }
    var introProgress: String { get }
    var isLastIntroCharacter: Bool { get }
    func playCurrentIntroCharacter()
    func nextIntroCharacter()
}
```

## Technical Constraints

- iOS 16+, Swift 5.9+, SwiftUI
- Portrait only
- No external dependencies
- XcodeGen for project configuration

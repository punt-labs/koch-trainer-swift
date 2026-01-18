# Koch Morse Trainer — iOS App PRD

## Overview

A minimal iOS app implementing the Koch method for learning morse code (receive and send). Tracks one student's progress through the 26-letter US English alphabet.

## Koch Method Rules (Implemented)

| Parameter | Value |
|-----------|-------|
| Character speed | 20 WPM (fixed) |
| Effective speed | 10-15 WPM via Farnsworth spacing |
| Starting characters | 2 (K, M) |
| Advancement threshold | ≥90% accuracy over session |
| Session length | 5 minutes |
| Group format | Random letters, variable length (2-5) |

**Character Order (G4FON standard, letters only):**
K M R S U A P T L O W I N J E F Y V G Q Z H B C D X

## Data Model

```swift
struct StudentProgress: Codable {
    var currentLevel: Int          // 2-26 (number of unlocked characters)
    var sessionsCompleted: Int
    var lastSessionDate: Date?
    var characterStats: [Character: CharacterStat]
}

struct CharacterStat: Codable {
    var attempts: Int
    var correct: Int
    var accuracy: Double { Double(correct) / Double(max(attempts, 1)) }
}

struct SessionResult {
    let date: Date
    let accuracy: Double
    let charactersSent: Int
    let correctCount: Int
    let advancedLevel: Bool
}
```

Persistence: `UserDefaults` (single student, simple data).

## Screens

### 1. Home (Status)

Displays:
- Current level (e.g., "Level 5 of 26")
- Unlocked characters (e.g., "K M R S U")
- Next character to unlock (e.g., "Next: A")
- Overall accuracy %
- Sessions completed

Actions:
- **Train Receive** → Receive Training screen
- **Train Send** → Send Training screen
- **Reset Progress** (confirmation required)

### 2. Receive Training (Audio → Text)

*Koch method primary exercise.*

Flow:
1. Tap **Start**
2. App plays random groups using unlocked characters
3. Student types what they hear (iOS keyboard)
4. After 5 minutes, session ends automatically
5. Results screen shows: accuracy %, characters missed, level-up notification if applicable

UI elements:
- Timer (countdown from 5:00)
- Text field for input
- Pause/Resume button
- Stop button (ends early, still scores)

Audio parameters:
- Tone: 600 Hz sine wave
- Dit: 60ms at 20 WPM
- Dah: 180ms
- Inter-element gap: 60ms
- Inter-character gap: ~420ms (Farnsworth)
- Inter-word gap: ~980ms (Farnsworth)

### 3. Send Training (Text → Keying)

*Reverse exercise: see letters, tap morse.*

Flow:
1. Tap **Start**
2. App displays a random letter from unlocked set
3. Student taps a paddle area (dit/dah or straight key)
4. App decodes input, compares to target
5. Shows correct/incorrect, advances to next letter
6. After 5 minutes or N characters, session ends
7. Results screen

UI elements:
- Large letter display (current target)
- Keying area (bottom half of screen)
  - Option A: Two-button paddle (dit | dah)
  - Option B: Single tap area (timing-based)
- Timer
- Running score

Input decoding:
- Timeout after 1.5× dah length → character complete
- Compare decoded character to target

### 4. Results

Post-session summary:
- Accuracy percentage
- Total characters / correct
- Per-character breakdown (tap to expand)
- Level-up banner if threshold met
- **Continue** → Home

## Settings (minimal)

Accessible via gear icon on Home:
- Tone frequency: 400-800 Hz (default 600)
- Farnsworth effective speed: 10-18 WPM (default 12)
- Send input mode: Paddle / Straight key

## Audio Implementation

Use `AVAudioEngine` with `AVAudioSourceNode` for low-latency tone generation. Pre-render common patterns if latency is an issue.

## State Transitions

```
[Home] 
   │
   ├─► [Receive Training] ─► [Results] ─► [Home]
   │
   ├─► [Send Training] ─► [Results] ─► [Home]
   │
   └─► [Settings] ─► [Home]
```

## Advancement Logic

```swift
func shouldAdvance(sessionAccuracy: Double, currentLevel: Int) -> Bool {
    return sessionAccuracy >= 0.90 && currentLevel < 26
}
```

Student cannot regress levels. Poor sessions simply don't advance.

## Non-Requirements (Out of Scope)

- Multiple users/profiles
- Cloud sync
- Numbers or punctuation
- Words or QSO practice
- Leaderboards
- Custom character order

## Technical Constraints

- iOS 16+
- Swift 5.9+
- SwiftUI for UI
- No external dependencies required
- Portrait orientation only

## Success Metrics

- Student completes level 26 (all letters unlocked)
- Session completion rate >80%
- App launch to training start <3 taps

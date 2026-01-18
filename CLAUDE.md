# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS app implementing the Koch method for learning Morse code. Single-user, letters only (K M R S U A P T L O W I N J E F Y V G Q Z H B C D X).

## Build & Run

```bash
# Open in Xcode
open KochTrainer.xcodeproj

# Build from command line
xcodebuild -scheme KochTrainer -destination 'platform=iOS Simulator,name=iPhone 15'

# Run tests
xcodebuild test -scheme KochTrainer -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Architecture

### Core Components

- **Models/**: `StudentProgress`, `CharacterStat`, `SessionResult` - persistence via UserDefaults
- **Views/**: SwiftUI screens - Home, ReceiveTraining, SendTraining, Results, Settings
- **Audio/**: `AVAudioEngine` + `AVAudioSourceNode` for low-latency Morse tone generation
- **Services/**: Session management, Morse encoding/decoding, progress tracking

### Audio Timing (20 WPM character speed)

| Element | Duration |
|---------|----------|
| Dit | 60ms |
| Dah | 180ms |
| Inter-element | 60ms |
| Inter-character (Farnsworth) | ~420ms |
| Inter-word (Farnsworth) | ~980ms |
| Tone frequency | 600 Hz (configurable 400-800) |

### Key Logic

Advancement: ≥90% accuracy over 5-minute session unlocks next character. No regression.

```swift
func shouldAdvance(sessionAccuracy: Double, currentLevel: Int) -> Bool {
    sessionAccuracy >= 0.90 && currentLevel < 26
}
```

Send training decoder: character complete after 1.5× dah length (~270ms) timeout.

## Technical Constraints

- iOS 16+, Swift 5.9+, SwiftUI
- Portrait only
- No external dependencies

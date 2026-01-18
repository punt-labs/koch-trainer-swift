# Koch Trainer

An iOS app for learning Morse code using the Koch method—the scientifically-proven approach of learning characters at full speed from day one.

## Features

### Learn (Koch Method)

Progressive character training following the Koch order (K M R S U A P T L O W I N J E F Y V G Q Z H B C D X).

- **Receive Training** — Listen to Morse code, type what you hear
- **Send Training** — See a character, tap dit/dah to send it
- **Adaptive Difficulty** — Advance to the next character when you hit 90% accuracy
- **Separate Progression** — Track receive and send skills independently

### Practice (Custom Characters)

Drill specific characters you find challenging.

- Select any combination of the 26 letters
- Practice in receive or send mode
- Hear each character's sound when you select it
- Stats tracked but no level progression (won't advance you past characters you haven't learned)

### Vocabulary (Words & Callsigns)

Practice real words and callsigns used in amateur radio.

- **Built-in Sets:**
  - Common QSO words (CQ, DE, K, AR, SK, 73, RST, QTH, QSL...)
  - Sample callsign patterns (W1AW, K0ABC, VE3XYZ...)
- **Your Callsign** — Enter your callsign in Settings to practice it
- Tracks accuracy per word with weighted selection toward weak spots

### Settings

- **Your Callsign** — For personalized vocabulary practice
- **Tone Frequency** — Adjustable 400-800 Hz
- **Effective Speed** — Farnsworth spacing 10-18 WPM (character speed fixed at 20 WPM)
- **Notifications** — Practice reminders with streak protection

### Streaks & Spaced Repetition

- Daily streak tracking with personal best indicator
- Smart practice scheduling based on your accuracy
- Practice due indicators show when each skill needs attention

## The Koch Method

Traditional Morse learning starts slow and speeds up—but this creates bad habits. The Koch method, developed by German psychologist Ludwig Koch, teaches characters at full speed from the start. You learn to recognize the *sound pattern*, not count dots and dashes.

**How it works:**
1. Start with just 2 characters (K and M)
2. Practice until you hit 90% accuracy with enough attempts
3. Add one new character
4. Repeat until all 26 letters are mastered

This app implements Koch's method for both receiving (copying) and sending (keying) Morse code.

## Audio Timing

- **Character speed:** 20 WPM (60ms dit, 180ms dah)
- **Effective speed:** Adjustable 10-18 WPM via Farnsworth spacing
- **Tone:** 600 Hz default (configurable 400-800 Hz)

## Privacy

- All data stored locally on your device
- No accounts, no cloud sync, no tracking
- Notifications are local (not push)

## Requirements

- iOS 16.0 or later
- iPhone or iPad

## Building from Source

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate Xcode project and build
make generate  # Regenerate xcodeproj from project.yml
make build     # Build the app
make test      # Run all tests
```

## License

MIT License

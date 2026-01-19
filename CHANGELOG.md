# Changelog

All notable changes to Koch Trainer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Character proficiency indicators showing per-character accuracy as circular progress rings
- VoiceOver accessibility labels for proficiency percentages
- **Morse QSO Training**: Practice QSO conversations by keying dit/dah responses while listening to AI transmissions with progressive text reveal
- Configurable text reveal delay setting (0-2 seconds) for Morse QSO training
- **Number support (0-9)**: Morse code patterns for digits (ITU standard), enabling callsigns (e.g., W5ABC) and RST reports (e.g., 599) to play correctly
- **Answer CQ mode**: AI calls CQ first, user responds—more realistic practice flow
- **AI text hide toggle**: Hide received text during QSO to practice copying by ear
- **Real-time WPM display**: See your keying speed during QSO training turns
- **QSO style progression**: First Contact (beginner) → Signal Report → Contest → Rag Chew
- **Session history view**: Review past practice sessions in Settings
- **Acknowledgments view**: Third-party licenses and credits in Settings
- **License view**: Full MIT license text in Settings

### Changed
- Character grid cells now use circular backgrounds for visual consistency
- QSO text reveal now syncs with audio playback (character appears as it plays)

### Fixed
- CI workflow now uses iPhone 16 Pro simulator (available on GitHub runners)
- SwiftFormat/SwiftLint configuration alignment for multi-line conditions

## [1.0.0] - 2026-01-19

### Added
- **Koch Method Training**: Progressive character learning following the Koch method order (K, M, R, S, U, A, P, T, L, O, W, I, N, J, E, F, Y, V, G, Q, Z, H, B, C, D, X)
- **Receive Training**: Listen to Morse code and identify characters with immediate feedback
- **Send Training**: Key dit/dah patterns using on-screen paddles or keyboard (F/J keys)
- **Character Introduction**: Audio preview of each character's pattern before training sessions
- **Separate Progress Tracking**: Independent levels for receive (1-26) and send (1-26) modes
- **Custom Practice**: Select specific characters to practice from the full alphabet grid
- **Vocabulary Training**: Practice common words and phrases (Q-codes, abbreviations, common words)
- **QSO Simulation**: Practice realistic ham radio conversations (Contest and Rag Chew modes)
- **Band Conditions Simulation**: QRN (noise), QSB (fading), and QRM (interference) audio effects
- **Streak Tracking**: Daily practice streaks with personal best tracking
- **Spaced Repetition**: Adaptive practice intervals based on performance
- **Practice Reminders**: Local notifications for practice due dates and streak protection
- **Configurable Audio**: Adjustable tone frequency (400-800 Hz) and effective speed (10-18 WPM)
- **Dark Mode Support**: Full support for iOS light and dark appearance modes

### Technical
- SwiftUI-based iOS app (iOS 16+)
- XcodeGen for project configuration
- 419 unit tests with 40% code coverage
- SwiftLint and SwiftFormat for code quality
- GitHub Actions CI pipeline

[Unreleased]: https://github.com/punt-labs/koch-trainer-swift/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/punt-labs/koch-trainer-swift/releases/tag/v1.0.0

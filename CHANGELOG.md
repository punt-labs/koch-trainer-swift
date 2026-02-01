# Changelog

All notable changes to Koch Trainer will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-02-01

### Added
- **Accessibility compliance**: VoiceOver labels with spoken Morse patterns ("dit dah" instead of ".-"), accessibility hints on training buttons, Dynamic Type support with `@ScaledMetric`, hidden decorative elements, and automated `performAccessibilityAudit()` tests
- **Privacy manifest** (PrivacyInfo.xcprivacy): Declares UserDefaults API usage and no data collection
- **Notification usage description**: Explains why practice reminders and streak alerts are sent
- **Export compliance flag**: Marks app as using no non-exempt encryption
- **Internationalization (i18n)**: Full localization infrastructure with support for 6 languages
  - English (US) - base language
  - English (UK) - spelling variants (practise vs practice)
  - German (de)
  - French (fr)
  - Spanish (es)
  - Italian (it)
- Pluralization support via stringsdict for proper singular/plural handling
- Locale-aware number formatting for decimal values

### Fixed
- Software keyboard no longer covers dit/dah buttons on Send Training, Ear Training, QSO, and Vocabulary screens

### Changed
- Minimum deployment target raised to iOS 17.0
- Bundle identifier changed to com.puntlabs.kochtrainer

### Technical
- 1,041 tests (973 unit + 68 UI)
- SwiftLint warnings reduced to 0

## [0.9.0] - 2026-01-24

### Added
- **Ear Training Mode**: New training mode for pattern recognition—hear Morse audio and reproduce the pattern using dit/dah buttons. Progression by pattern length (1-5 elements) rather than Koch order.
- **Training Flow UI Tests**: Comprehensive UI test coverage for Receive, Send, and Ear training flows using page object pattern
- **Data Migration Safety**: Progress data is now protected with rolling backups and graceful degradation. If data becomes corrupted, the app recovers from backups instead of losing all progress. Schema versioning enables safe future updates.
- **Pause and Resume Training**: Paused sessions persist and automatically restore when returning to training (within 24 hours)
- Character proficiency indicators showing per-character accuracy as circular progress rings
- VoiceOver accessibility labels for proficiency percentages
- **VoiceOver training feedback**: Announces correct/incorrect responses, timeouts, level-ups, and session completion during training
- **Morse QSO Training**: Practice QSO conversations by keying dit/dah responses while listening to AI transmissions with progressive text reveal
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
- **Realistic QSB fading**: Band conditions fading now uses filtered random noise instead of predictable sine wave, better simulating real ionospheric conditions
- **Pink noise for QRN**: Atmospheric noise now uses pink noise filter for more realistic HF band simulation
- **Continuous band audio**: Background noise plays continuously with half-duplex radio behavior (noise fades during transmission)

### Fixed
- **Accessibility identifier inheritance**: Training view elements now correctly expose their own identifiers in the accessibility tree (fixed by adding `.accessibilityElement(children: .contain)` to container views)
- Custom and Vocabulary sessions no longer affect Learn mode spaced repetition schedule
- CI workflow now uses iPhone 16 Pro simulator (available on GitHub runners)
- SwiftFormat/SwiftLint configuration alignment for multi-line conditions
- **Notification timezone bug**: Preferred reminder time now preserves local hour/minute across timezone changes
- **Vocabulary receive auto-submit**: Answers now submit automatically when typed character count matches the expected word length, matching Learn mode behavior
- **Secondary button tap targets**: Outlined buttons (Next Character, etc.) now respond to taps across the entire button surface, not just near the text

## [0.7.0] - 2026-01-19

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
- SwiftUI-based iOS app
- XcodeGen for project configuration
- SwiftLint and SwiftFormat for code quality
- GitHub Actions CI pipeline


[1.0.0]: https://github.com/punt-labs/koch-trainer-swift/compare/v0.9.0...v1.0.0
[0.9.0]: https://github.com/punt-labs/koch-trainer-swift/compare/v0.7.0...v0.9.0
[0.7.0]: https://github.com/punt-labs/koch-trainer-swift/releases/tag/v0.7.0

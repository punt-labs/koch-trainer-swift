import Foundation

/// Centralized accessibility identifiers for UI testing.
/// Uses kebab-case naming convention for consistency.
/// These identifiers are stable across localizations.
enum AccessibilityID {

    // MARK: - Tab Bar

    enum Tab {
        static let learn = "tab-learn"
        static let practice = "tab-practice"
        static let vocab = "tab-vocab"
        static let settings = "tab-settings"
    }

    // MARK: - Learn View

    enum Learn {
        static let view = "learn-view"
        static let title = "learn-title"
        static let streakCard = "learn-streak-card"
        static let earTrainingSection = "learn-ear-training-section"
        static let receiveSection = "learn-receive-section"
        static let sendSection = "learn-send-section"
        static let earTrainingButton = "learn-ear-training-start-button"
        static let receiveTrainingButton = "learn-receive-training-start-button"
        static let sendTrainingButton = "learn-send-training-start-button"
        static let earTrainingLevel = "learn-ear-training-level"
        static let receiveLevel = "learn-receive-level"
        static let sendLevel = "learn-send-level"
        static let receivePracticeDue = "learn-receive-practice-due"
        static let sendPracticeDue = "learn-send-practice-due"
    }

    // MARK: - Training (shared patterns for receive/send/ear)

    enum Training {
        // Phase container views
        static let introView = "training-intro-view"
        static let trainingView = "training-phase-view"
        static let pausedView = "training-paused-view"
        static let completedView = "training-completed-view"

        // Introduction phase
        static let introProgress = "training-intro-progress"
        static let introCharacter = "training-intro-character"
        static let introPattern = "training-intro-pattern"
        static let playSoundButton = "training-play-sound-button"
        static let nextCharacterButton = "training-next-character-button"
        static let startTrainingButton = "training-start-button"

        // Training phase
        static let proficiencyProgress = "training-proficiency-progress"
        static let characterDisplay = "training-character-display"
        static let feedbackMessage = "training-feedback-message"
        static let progressBar = "training-progress-bar"
        static let scoreDisplay = "training-score-display"
        static let accuracyDisplay = "training-accuracy-display"
        static let pauseButton = "training-pause-button"

        // Paused phase
        static let pausedTitle = "training-paused-title"
        static let pausedScore = "training-paused-score"
        static let resumeButton = "training-resume-button"
        static let endSessionButton = "training-end-session-button"

        // Completed phase
        static let levelUpTitle = "training-level-up-title"
        static let sessionCompleteTitle = "training-session-complete-title"
        static let newCharacterDisplay = "training-new-character-display"
        static let finalScore = "training-final-score"
        static let finalAccuracy = "training-final-accuracy"
        static let continueButton = "training-continue-button"
        static let tryAgainButton = "training-try-again-button"
        static let doneButton = "training-done-button"

        // Feedback indicators
        static let feedbackCorrect = "training-feedback-correct"
        static let feedbackIncorrect = "training-feedback-incorrect"
        static let feedbackTimeout = "training-feedback-timeout"
    }

    // MARK: - Send Training Specific

    enum Send {
        static let ditButton = "send-dit-button"
        static let dahButton = "send-dah-button"
        static let patternDisplay = "send-pattern-display"
        static let keyboardHint = "send-keyboard-hint"
    }

    // MARK: - Practice View

    enum Practice {
        static let view = "practice-view"
        static let characterGrid = "practice-character-grid"
        static let receiveButton = "practice-receive-button"
        static let sendButton = "practice-send-button"
        static let instructionText = "practice-instruction-text"

        /// Returns identifier for a character cell in the practice grid.
        /// The character is lowercased in the identifier (e.g., 'K' → "practice-character-k").
        static func characterCell(_ char: Character) -> String {
            "practice-character-\(char.lowercased())"
        }
    }

    // MARK: - Vocabulary View

    enum Vocab {
        static let view = "vocab-view"
    }

    // MARK: - Settings View

    enum Settings {
        static let view = "settings-view"
    }
}

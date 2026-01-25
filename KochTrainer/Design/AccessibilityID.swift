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
        static let qsoButton = "vocab-qso-button"
        static let commonWordsReceiveButton = "vocab-common-words-receive-button"
        static let commonWordsSendButton = "vocab-common-words-send-button"
        static let callsignReceiveButton = "vocab-callsign-receive-button"
        static let callsignSendButton = "vocab-callsign-send-button"
    }

    // MARK: - Vocabulary Training View

    enum VocabTraining {
        // Container views by phase
        static let view = "vocab-training-view"
        static let receivePhaseView = "vocab-training-receive-phase"
        static let sendPhaseView = "vocab-training-send-phase"
        static let pausedView = "vocab-training-paused-view"
        static let completedView = "vocab-training-completed-view"

        // Common elements
        static let progressText = "vocab-training-progress"
        static let scoreText = "vocab-training-score"
        static let accuracyText = "vocab-training-accuracy"

        // Receive mode elements
        static let replayButton = "vocab-training-replay-button"
        static let listeningIndicator = "vocab-training-listening"
        static let waitingIndicator = "vocab-training-waiting"
        static let userInputDisplay = "vocab-training-user-input"

        // Send mode elements
        static let targetWord = "vocab-training-target-word"
        static let patternProgress = "vocab-training-pattern-progress"
        static let ditButton = "vocab-training-dit-button"
        static let dahButton = "vocab-training-dah-button"
        static let keyboardHint = "vocab-training-keyboard-hint"

        // Feedback
        static let feedbackView = "vocab-training-feedback"
        static let feedbackWord = "vocab-training-feedback-word"
        static let feedbackResult = "vocab-training-feedback-result"

        // Paused state
        static let pauseButton = "vocab-training-pause-button"
        static let resumeButton = "vocab-training-resume-button"
        static let endSessionButton = "vocab-training-end-session-button"
        static let pausedTitle = "vocab-training-paused-title"
        static let pausedScore = "vocab-training-paused-score"

        // Completed state
        static let completedTitle = "vocab-training-completed-title"
        static let completedStats = "vocab-training-completed-stats"
        static let doneButton = "vocab-training-done-button"
        static let setName = "vocab-training-set-name"
    }

    // MARK: - QSO Views

    enum QSO {
        // QSOView (mode selection)
        static let view = "qso-view"
        static let startModePicker = "qso-start-mode-picker"
        static let startButton = "qso-start-button"
        static let callsignDisplay = "qso-callsign-display"

        // MorseQSOView (session)
        static let sessionView = "qso-session-view"
        static let endButton = "qso-end-button"
        static let statusBar = "qso-status-bar"
        static let stationCallsign = "qso-station-callsign"
        static let turnStatus = "qso-turn-status"
        static let audioIndicator = "qso-audio-indicator"

        // AI message area
        static let aiMessageView = "qso-ai-message-view"
        static let aiTextToggle = "qso-ai-text-toggle"
        static let revealedText = "qso-revealed-text"

        // User keying area
        static let userKeyingView = "qso-user-keying-view"
        static let typedScript = "qso-typed-script"
        static let currentCharacter = "qso-current-character"
        static let currentPattern = "qso-current-pattern"
        static let wpmDisplay = "qso-wpm-display"
        static let lastKeyedFeedback = "qso-last-keyed-feedback"

        // Input area
        static let inputArea = "qso-input-area"
        static let ditButton = "qso-dit-button"
        static let dahButton = "qso-dah-button"
        static let keyboardHint = "qso-keyboard-hint"

        // Accuracy footer
        static let keyedCount = "qso-keyed-count"
        static let accuracyDisplay = "qso-accuracy-display"

        // Completed view
        static let completedView = "qso-completed-view"
        static let completedTitle = "qso-completed-title"
        static let completedCallsign = "qso-completed-callsign"
        static let doneButton = "qso-done-button"
        static let statsCard = "qso-stats-card"

        /// Returns identifier for a QSO style card (e.g., "qso-style-firstContact")
        static func styleCard(_ style: String) -> String {
            "qso-style-\(style)"
        }

    }

    // MARK: - Settings View

    enum Settings {
        static let view = "settings-view"
    }
}

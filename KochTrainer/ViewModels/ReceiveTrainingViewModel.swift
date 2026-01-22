import Foundation
import SwiftUI

// MARK: - ReceiveTrainingViewModel

/// ViewModel for receive training sessions.
/// Plays Morse audio one character at a time, waits for single keypress response.
@MainActor
final class ReceiveTrainingViewModel: ObservableObject, CharacterIntroducing {

    // MARK: Lifecycle

    init(audioEngine: AudioEngineProtocol? = nil) {
        self.audioEngine = audioEngine ?? MorseAudioEngine()
    }

    // MARK: Internal

    enum SessionPhase: Equatable {
        case introduction(characterIndex: Int)
        case training
        case paused
        case completed(didAdvance: Bool, newCharacter: Character?)
    }

    struct Feedback: Equatable {
        let wasCorrect: Bool
        let expectedCharacter: Character
        let userPressed: Character?
    }

    // MARK: - Published State

    @Published var phase: SessionPhase = .introduction(characterIndex: 0)
    @Published var timeRemaining: TimeInterval = 300 // 5 minutes (fallback max)
    @Published var isPlaying: Bool = false
    @Published var correctCount: Int = 0
    @Published var totalAttempts: Int = 0
    @Published var characterStats: [Character: CharacterStat] = [:]

    // Introduction state
    @Published var introCharacters: [Character] = []
    @Published var currentIntroCharacter: Character?

    // Training state
    @Published var currentCharacter: Character?
    @Published var responseTimeRemaining: TimeInterval = 0
    @Published var lastFeedback: Feedback?
    @Published var isWaitingForResponse: Bool = false

    // MARK: - Configuration

    let responseTimeout: TimeInterval = 3.0
    let proficiencyThreshold: Double = 0.90

    /// Custom characters for practice mode (nil = use level-based characters)
    private(set) var customCharacters: [Character]?

    var progressStore: ProgressStore?
    var settingsStore: SettingsStore?
    var sessionTimer: Timer?
    var responseTimer: Timer?
    var currentLevel: Int = 1
    var currentGroup: [Character] = []
    var currentGroupIndex: Int = 0

    // MARK: Internal (for extension access)

    let audioEngine: AudioEngineProtocol
    var sessionStartTime: Date?

    /// Minimum attempts scales with character count (5 per character, floor of 15)
    var minimumAttemptsForProficiency: Int {
        max(15, 5 * introCharacters.count)
    }

    /// Whether this is a custom practice session (no level advancement)
    var isCustomSession: Bool { customCharacters != nil }

    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var accuracyPercentage: Int {
        guard totalAttempts > 0 else { return 0 }
        return Int((Double(correctCount) / Double(totalAttempts) * 100).rounded())
    }

    var accuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctCount) / Double(totalAttempts)
    }

    var responseProgress: Double {
        guard responseTimeout > 0 else { return 0 }
        return responseTimeRemaining / responseTimeout
    }

    var introProgress: String {
        if case let .introduction(index) = phase {
            return "\(index + 1) of \(introCharacters.count)"
        }
        return ""
    }

    var isLastIntroCharacter: Bool {
        if case let .introduction(index) = phase {
            return index == introCharacters.count - 1
        }
        return false
    }

    var proficiencyProgress: String {
        if totalAttempts < minimumAttemptsForProficiency {
            return "\(totalAttempts)/\(minimumAttemptsForProficiency) attempts"
        } else {
            return "\(accuracyPercentage)% (need \(Int(proficiencyThreshold * 100))%)"
        }
    }

    /// Whether introduction phase has been completed
    var isIntroCompleted: Bool {
        if case .training = phase { return true }
        if case .paused = phase { return true }
        if case .completed = phase { return true }
        return false
    }

    func configure(progressStore: ProgressStore, settingsStore: SettingsStore) {
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        currentLevel = progressStore.progress.receiveLevel
        audioEngine.setFrequency(settingsStore.settings.toneFrequency)
        audioEngine.setEffectiveSpeed(settingsStore.settings.effectiveSpeed)
        audioEngine.configureBandConditions(from: settingsStore.settings)

        introCharacters = MorseCode.characters(forLevel: currentLevel)
    }

    /// Configure for custom practice with specific characters (no level advancement)
    func configure(progressStore: ProgressStore, settingsStore: SettingsStore, customCharacters: [Character]) {
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        self.customCharacters = customCharacters
        currentLevel = progressStore.progress.receiveLevel
        audioEngine.setFrequency(settingsStore.settings.toneFrequency)
        audioEngine.setEffectiveSpeed(settingsStore.settings.effectiveSpeed)
        audioEngine.configureBandConditions(from: settingsStore.settings)

        // For custom practice, use the selected characters as intro
        introCharacters = customCharacters
    }

    // MARK: - Introduction Phase

    func startIntroduction() {
        guard !introCharacters.isEmpty else {
            startTraining()
            return
        }

        phase = .introduction(characterIndex: 0)
        showIntroCharacter(at: 0)
    }

    func playCurrentIntroCharacter() {
        guard let char = currentIntroCharacter else { return }

        Task {
            guard let engine = audioEngine as? MorseAudioEngine else { return }
            engine.reset()
            await engine.playCharacter(char)
        }
    }

    func nextIntroCharacter() {
        if case let .introduction(index) = phase {
            let nextIndex = index + 1
            if nextIndex < introCharacters.count {
                showIntroCharacter(at: nextIndex)
            } else {
                startTraining()
            }
        }
    }

    func startSession() {
        startIntroduction()
    }

    func pause() {
        guard case .training = phase else { return }
        isPlaying = false
        phase = .paused
        sessionTimer?.invalidate()
        responseTimer?.invalidate()

        // Turn off radio (continuous audio goes silent)
        audioEngine.setRadioMode(.off)
        audioEngine.stop()
        isWaitingForResponse = false

        // Only persist paused session if there's actual progress
        if totalAttempts > 0, let snapshot = createPausedSessionSnapshot() {
            progressStore?.savePausedSession(snapshot)
        }
    }

    // MARK: - Paused Session Management

    func createPausedSessionSnapshot() -> PausedSession? {
        guard let startTime = sessionStartTime else { return nil }

        let sessionType: SessionType = isCustomSession ? .receiveCustom : .receive
        return PausedSession(
            sessionType: sessionType,
            startTime: startTime,
            pausedAt: Date(),
            correctCount: correctCount,
            totalAttempts: totalAttempts,
            characterStats: characterStats,
            introCharacters: introCharacters,
            introCompleted: isIntroCompleted,
            customCharacters: customCharacters,
            currentLevel: currentLevel
        )
    }

    func restoreFromPausedSession(_ session: PausedSession) {
        // Validate level matches current level
        guard session.currentLevel == currentLevel else {
            // Level changed since pause - don't restore
            return
        }

        // Validate custom session type matches
        let currentIsCustom = customCharacters != nil
        guard session.isCustomSession == currentIsCustom else { return }

        // If custom session, validate custom characters match
        if currentIsCustom {
            guard session.customCharacters == customCharacters else {
                // Custom characters differ from paused session - don't restore
                return
            }
        }

        // Restore state
        correctCount = session.correctCount
        totalAttempts = session.totalAttempts
        characterStats = session.characterStats
        introCharacters = session.introCharacters
        sessionStartTime = session.startTime

        if session.introCompleted {
            // Resume in paused state, user will tap "Resume" to continue training
            phase = .paused
        } else {
            // Restart from introduction
            phase = .introduction(characterIndex: 0)
        }
    }

    func resume() {
        guard phase == .paused else { return }

        // Clear the paused session now that user is actively resuming
        let sessionType: SessionType = isCustomSession ? .receiveCustom : .receive
        progressStore?.clearPausedSession(for: sessionType)

        phase = .training
        isPlaying = true

        // Resume receiving mode
        audioEngine.setRadioMode(.receiving)

        startSessionTimer()
        playNextGroup()
    }

    func endSession() {
        isPlaying = false
        sessionTimer?.invalidate()
        responseTimer?.invalidate()
        audioEngine.endSession()
        isWaitingForResponse = false

        // Clear any paused session since we're ending
        let sessionType: SessionType = isCustomSession ? .receiveCustom : .receive
        progressStore?.clearPausedSession(for: sessionType)

        guard let store = progressStore, let startTime = sessionStartTime else {
            phase = .completed(didAdvance: false, newCharacter: nil)
            return
        }

        // Don't record sessions with no attempts (e.g., immediately cancelled)
        guard totalAttempts > 0 else {
            phase = .completed(didAdvance: false, newCharacter: nil)
            return
        }

        let duration = Date().timeIntervalSince(startTime)
        let result = SessionResult(
            sessionType: sessionType,
            duration: duration,
            totalAttempts: totalAttempts,
            correctCount: correctCount,
            characterStats: characterStats
        )

        // Record session and check for advancement (custom sessions can't advance)
        let didAdvance = store.recordSession(result)
        let newCharacter: Character? = didAdvance ? store.progress.unlockedCharacters(for: .receive).last : nil

        phase = .completed(didAdvance: didAdvance, newCharacter: newCharacter)
    }

    func cleanup() {
        isPlaying = false
        sessionTimer?.invalidate()
        sessionTimer = nil
        responseTimer?.invalidate()
        responseTimer = nil
        audioEngine.endSession()
    }

    // MARK: - Input Handling

    func handleKeyPress(_ key: Character) {
        guard isWaitingForResponse, let expected = currentCharacter else { return }

        responseTimer?.invalidate()
        isWaitingForResponse = false

        let pressedUpper = Character(key.uppercased())
        let isCorrect = pressedUpper == expected

        recordResponse(expected: expected, wasCorrect: isCorrect, userPressed: pressedUpper)
        showFeedbackAndContinue(wasCorrect: isCorrect, expected: expected, userPressed: pressedUpper)
    }

    // MARK: - Proficiency Check

    func checkForProficiency() {
        guard totalAttempts >= minimumAttemptsForProficiency else { return }
        guard accuracy >= proficiencyThreshold else { return }

        // Proficiency achieved! End session and advance
        endSession()
    }

    // MARK: Private

    private func showIntroCharacter(at index: Int) {
        guard index < introCharacters.count else {
            startTraining()
            return
        }

        currentIntroCharacter = introCharacters[index]
        phase = .introduction(characterIndex: index)

        // Auto-play after a short delay to let the UI update
        Task {
            try? await Task.sleep(nanoseconds: TrainingTiming.introAutoPlayDelay)
            playCurrentIntroCharacter()
        }
    }

    // MARK: - Training Phase

    private func startTraining() {
        phase = .training
        sessionStartTime = Date()
        isPlaying = true

        // Start continuous audio session (radio starts in receiving mode)
        audioEngine.startSession()

        startSessionTimer()
        playNextGroup()
    }

}

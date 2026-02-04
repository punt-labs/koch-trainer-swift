import Foundation
import SwiftUI

// MARK: - ReceiveTrainingViewModel

/// ViewModel for receive training sessions.
/// Plays Morse audio one character at a time, waits for single keypress response.
@MainActor
final class ReceiveTrainingViewModel: ObservableObject, CharacterIntroducing {

    // MARK: Lifecycle

    init(audioEngine: AudioEngineProtocol? = nil, announcer: AccessibilityAnnouncer = AccessibilityAnnouncer()) {
        self.audioEngine = audioEngine ?? AudioEngineFactory.makeEngine()
        self.announcer = announcer
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
    @Published private(set) var characterStats: [Character: CharacterStat] = [:]

    /// Session attempt counter with invariant enforcement.
    let counter = SessionCounter()

    // Introduction state
    @Published var introCharacters: [Character] = []
    @Published var currentIntroCharacter: Character?

    // Training state
    @Published var currentCharacter: Character?
    @Published var responseTimeRemaining: TimeInterval = 0
    @Published var lastFeedback: Feedback?
    @Published var isWaitingForResponse: Bool = false
    @Published var timerCycleId: Int = 0

    // MARK: - Configuration

    let responseTimeout: TimeInterval = 3.0
    let proficiencyThreshold: Double = 0.90

    /// Custom characters for practice mode (nil = use level-based characters)
    private(set) var customCharacters: [Character]?

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
        Int((counter.accuracy * 100).rounded())
    }

    var accuracy: Double {
        counter.accuracy
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
        if counter.attempts < minimumAttemptsForProficiency {
            return "\(counter.attempts)/\(minimumAttemptsForProficiency) attempts"
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
        audioEngine.startSession()

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
            await audioEngine.playCharacter(char)
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
        audioEngine.endSession()
        isWaitingForResponse = false
        announcer.announcePaused()

        // Only persist paused session if there's actual progress
        if counter.attempts > 0, let snapshot = createPausedSessionSnapshot() {
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
            correctCount: counter.correct,
            totalAttempts: counter.attempts,
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
        counter.restore(correct: session.correctCount, attempts: session.totalAttempts)
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
        announcer.announceResumed()
        // Restart audio session (endSession() was called in pause())
        audioEngine.startSession()
        startSessionTimer()
        playNextGroup()
    }

    func endSession() {
        isPlaying = false
        sessionTimer?.invalidate()
        responseTimer?.invalidate()
        isWaitingForResponse = false

        // Clear any paused session since we're ending
        let sessionType: SessionType = isCustomSession ? .receiveCustom : .receive
        progressStore?.clearPausedSession(for: sessionType)

        guard let store = progressStore, let startTime = sessionStartTime else {
            phase = .completed(didAdvance: false, newCharacter: nil)
            return
        }

        // Don't record sessions with no attempts (e.g., immediately cancelled)
        guard counter.attempts > 0 else {
            phase = .completed(didAdvance: false, newCharacter: nil)
            return
        }

        let duration = Date().timeIntervalSince(startTime)
        let result = SessionResult(
            sessionType: sessionType,
            duration: duration,
            totalAttempts: counter.attempts,
            correctCount: counter.correct,
            characterStats: characterStats
        )

        // Record session and check for advancement (custom sessions can't advance)
        let didAdvance = store.recordSession(result)
        let newCharacter: Character? = didAdvance ? store.progress.unlockedCharacters(for: .receive).last : nil

        // Announce completion for VoiceOver
        if didAdvance, let char = newCharacter {
            announcer.announceLevelUp(newCharacter: char)
        } else {
            announcer.announceSessionComplete(accuracy: accuracyPercentage)
        }

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

    // MARK: Private

    private let audioEngine: AudioEngineProtocol
    private let announcer: AccessibilityAnnouncer
    private var progressStore: ProgressStore?
    private var settingsStore: SettingsStore?
    private var sessionTimer: Timer?
    private var responseTimer: Timer?
    private var sessionStartTime: Date?
    private var currentLevel: Int = 1

    private var currentGroup: [Character] = []
    private var currentGroupIndex: Int = 0

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
        startSessionTimer()
        playNextGroup()
    }

    // MARK: - Proficiency Check

    private func checkForProficiency() {
        guard counter.attempts >= minimumAttemptsForProficiency else { return }
        guard accuracy >= proficiencyThreshold else { return }

        // Proficiency achieved! End session and advance
        endSession()
    }

}

// MARK: - Private Helpers

extension ReceiveTrainingViewModel {
    func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickSession() }
        }
    }

    private func tickSession() {
        guard timeRemaining > 0 else { endSession()
            return
        }
        timeRemaining -= 1
    }

    func playNextGroup() {
        guard isPlaying else { return }
        currentGroup = Array(generateGroup())
        currentGroupIndex = 0
        playNextCharacterInGroup()
    }

    private func playNextCharacterInGroup() {
        guard isPlaying else { return }

        if currentGroupIndex >= currentGroup.count {
            Task {
                try? await Task.sleep(nanoseconds: TrainingTiming.correctAnswerDelay)
                if isPlaying { playNextGroup() }
            }
            return
        }

        let char = currentGroup[currentGroupIndex]
        currentCharacter = char
        lastFeedback = nil

        Task {
            await audioEngine.playCharacter(char)
            if isPlaying { startResponseTimer() }
        }
    }

    func startResponseTimer() {
        // Increment cycle ID first - causes view recreation (destroys in-flight animation)
        timerCycleId += 1

        isWaitingForResponse = true
        responseTimeRemaining = responseTimeout

        responseTimer?.invalidate()
        // Single-fire timer for timeout detection only
        responseTimer = Timer.scheduledTimer(withTimeInterval: responseTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.handleTimeout() }
        }

        // Yield to event loop so SwiftUI creates new view seeing responseTimeRemaining = full
        // Then animate countdown from full to zero on the NEW view (no in-flight animation)
        Task { @MainActor in
            withAnimation(.linear(duration: responseTimeout)) {
                responseTimeRemaining = 0
            }
        }
    }

    private func handleTimeout() {
        guard isWaitingForResponse else { return }
        responseTimer?.invalidate()
        isWaitingForResponse = false
        if let expected = currentCharacter {
            recordResponse(expected: expected, wasCorrect: false, userPressed: nil)
            showFeedbackAndContinue(wasCorrect: false, expected: expected, userPressed: nil)
        }
    }

    func recordResponse(expected: Character, wasCorrect: Bool, userPressed: Character?) {
        counter.recordAttempt(wasCorrect: wasCorrect)

        var stat = characterStats[expected] ?? CharacterStat()
        stat.receiveAttempts += 1
        if wasCorrect { stat.receiveCorrect += 1 }
        stat.lastPracticed = Date()
        characterStats[expected] = stat
    }

    func showFeedbackAndContinue(wasCorrect: Bool, expected: Character, userPressed: Character?) {
        lastFeedback = Feedback(wasCorrect: wasCorrect, expectedCharacter: expected, userPressed: userPressed)

        // Announce feedback for VoiceOver
        if wasCorrect {
            announcer.announceCorrect()
        } else if let pressed = userPressed {
            announcer.announceIncorrect(userEntered: pressed, expected: expected)
        } else {
            announcer.announceTimeout(expected: expected)
        }

        Task {
            if !wasCorrect {
                try? await Task.sleep(nanoseconds: TrainingTiming.preReplayDelay)
                if isPlaying { await audioEngine.playCharacter(expected) }
                try? await Task.sleep(nanoseconds: TrainingTiming.postReplayDelay)
            } else {
                try? await Task.sleep(nanoseconds: TrainingTiming.correctAnswerDelay)
            }

            checkForProficiency()
            if isPlaying {
                currentGroupIndex += 1
                playNextCharacterInGroup()
            }
        }
    }

    private func generateGroup() -> String {
        var combinedStats = progressStore?.progress.characterStats ?? [:]
        for (char, sessionStat) in characterStats {
            if var existing = combinedStats[char] {
                existing.merge(sessionStat)
                combinedStats[char] = existing
            } else {
                combinedStats[char] = sessionStat
            }
        }

        return GroupGenerator.generateMixedGroup(
            level: currentLevel,
            characterStats: combinedStats,
            sessionType: .receive,
            groupLength: Int.random(in: 3 ... 5),
            availableCharacters: customCharacters
        )
    }
}

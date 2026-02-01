import Foundation
import SwiftUI

// MARK: - SendTrainingViewModel

/// ViewModel for send training sessions.
/// Displays characters, accepts paddle/keyboard input, decodes Morse patterns with audio feedback.
@MainActor
final class SendTrainingViewModel: ObservableObject, CharacterIntroducing {

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
        let sentPattern: String
        let decodedCharacter: Character?
    }

    @Published var phase: SessionPhase = .introduction(characterIndex: 0)
    @Published var timeRemaining: TimeInterval = 300 // 5 minutes (fallback max)
    @Published var isPlaying: Bool = false
    @Published private(set) var characterStats: [Character: CharacterStat] = [:]

    /// Session attempt counter with invariant enforcement.
    let counter = SessionCounter()
    @Published var introCharacters: [Character] = []
    @Published var currentIntroCharacter: Character?
    @Published var targetCharacter: Character = "K"
    @Published var currentPattern: String = ""
    @Published var lastFeedback: Feedback?
    @Published var isWaitingForInput: Bool = true
    @Published var inputTimeRemaining: TimeInterval = 0

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

    var inputProgress: Double {
        guard currentInputTimeout > 0 else { return 0 }
        return inputTimeRemaining / currentInputTimeout
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

    /// Dynamic timeout based on current target character's pattern length
    var currentInputTimeout: TimeInterval {
        TrainingTiming.timeoutForCharacter(targetCharacter)
    }

    func configure(progressStore: ProgressStore, settingsStore: SettingsStore) {
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        currentLevel = progressStore.progress.sendLevel
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
        currentLevel = progressStore.progress.sendLevel
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
            audioEngine.reset()
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
        inputTimer?.invalidate()
        audioEngine.stop()
        try? audioEngine.stopRadio()
        isWaitingForInput = false
        announcer.announcePaused()

        // Only persist paused session if there's actual progress
        if counter.attempts > 0, let snapshot = createPausedSessionSnapshot() {
            progressStore?.savePausedSession(snapshot)
        }
    }

    // MARK: - Paused Session Management

    func createPausedSessionSnapshot() -> PausedSession? {
        guard let startTime = sessionStartTime else { return nil }

        let sessionType: SessionType = isCustomSession ? .sendCustom : .send
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
        let sessionType: SessionType = isCustomSession ? .sendCustom : .send
        progressStore?.clearPausedSession(for: sessionType)

        phase = .training
        isPlaying = true
        announcer.announceResumed()
        try? audioEngine.stopRadio()
        try? audioEngine.startReceiving()
        startSessionTimer()
        showNextCharacter()
    }

    func endSession() {
        isPlaying = false
        sessionTimer?.invalidate()
        inputTimer?.invalidate()
        audioEngine.stop()
        isWaitingForInput = false

        // Clear any paused session since we're ending
        let sessionType: SessionType = isCustomSession ? .sendCustom : .send
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
        let newCharacter: Character? = didAdvance ? store.progress.unlockedCharacters(for: .send).last : nil

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
        inputTimer?.invalidate()
        inputTimer = nil
        audioEngine.endSession()
    }

    // MARK: - Input Handling

    func handleKeyPress(_ key: Character) {
        guard isWaitingForInput else { return }

        let keyLower = Character(key.lowercased())

        // . or f = dit, - or j = dah
        if keyLower == "." || keyLower == "f" {
            inputDit()
        } else if keyLower == "-" || keyLower == "j" {
            inputDah()
        }
    }

    func inputDit() {
        guard isPlaying, isWaitingForInput else { return }
        currentPattern += "."
        lastInputTime = Date()
        playDit()
    }

    func inputDah() {
        guard isPlaying, isWaitingForInput else { return }
        currentPattern += "-"
        lastInputTime = Date()
        playDah()
    }

    // MARK: Private

    private let audioEngine: AudioEngineProtocol
    private let announcer: AccessibilityAnnouncer
    private let decoder = MorseDecoder()
    private var progressStore: ProgressStore?
    private var settingsStore: SettingsStore?
    private var sessionTimer: Timer?
    private var inputTimer: Timer?
    private var sessionStartTime: Date?
    private var currentLevel: Int = 1
    private var lastInputTime: Date?

    private func showIntroCharacter(at index: Int) {
        guard index < introCharacters.count else {
            startTraining()
            return
        }

        currentIntroCharacter = introCharacters[index]
        phase = .introduction(characterIndex: index)

        // Auto-play after a short delay
        Task {
            try? await Task.sleep(nanoseconds: TrainingTiming.introAutoPlayDelay)
            playCurrentIntroCharacter()
        }
    }

    private func startTraining() {
        phase = .training
        sessionStartTime = Date()
        isPlaying = true
        startSessionTimer()
        showNextCharacter()
    }

    private func checkForProficiency() {
        guard counter.attempts >= minimumAttemptsForProficiency else { return }
        guard accuracy >= proficiencyThreshold else { return }

        endSession()
    }

    private func playDit() {
        Task {
            await audioEngine.playDit()
        }
    }

    private func playDah() {
        Task {
            await audioEngine.playDah()
        }
    }
}

// MARK: - Private Helpers

extension SendTrainingViewModel {
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

    func resetInputTimer() {
        // Start at full (no animation for initial set)
        inputTimeRemaining = currentInputTimeout

        inputTimer?.invalidate()
        // Single-fire timer for timeout detection only
        inputTimer = Timer.scheduledTimer(withTimeInterval: currentInputTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.handleInputTimeout() }
        }

        // Animate countdown from full to zero
        let duration = currentInputTimeout
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: TrainingTiming.animationStartDelay)
            withAnimation(.linear(duration: duration)) {
                inputTimeRemaining = 0
            }
        }
    }

    private func handleInputTimeout() {
        guard isWaitingForInput else { return }
        inputTimer?.invalidate()
        completeCurrentInput()
    }

    private func completeCurrentInput() {
        isWaitingForInput = false

        let decodedChar = currentPattern.isEmpty ? nil : MorseCode.character(for: currentPattern)
        let isCorrect = !currentPattern.isEmpty && decodedChar == targetCharacter
        let displayPattern = currentPattern.isEmpty ? "(no response)" : currentPattern
        recordResponse(expected: targetCharacter, wasCorrect: isCorrect, pattern: displayPattern, decoded: decodedChar)
        showFeedbackAndContinue(
            wasCorrect: isCorrect,
            expected: targetCharacter,
            pattern: displayPattern,
            decoded: decodedChar
        )
    }

    func recordResponse(expected: Character, wasCorrect: Bool, pattern: String, decoded: Character?) {
        counter.recordAttempt(wasCorrect: wasCorrect)

        var stat = characterStats[expected] ?? CharacterStat()
        stat.sendAttempts += 1
        if wasCorrect { stat.sendCorrect += 1 }
        stat.lastPracticed = Date()
        characterStats[expected] = stat
    }

    func showFeedbackAndContinue(wasCorrect: Bool, expected: Character, pattern: String, decoded: Character?) {
        lastFeedback = Feedback(
            wasCorrect: wasCorrect,
            expectedCharacter: expected,
            sentPattern: pattern,
            decodedCharacter: decoded
        )

        // Announce feedback for VoiceOver
        if wasCorrect {
            announcer.announceCorrect()
        } else if pattern == "(no response)" {
            announcer.announceTimeout(expected: expected)
        } else {
            announcer.announceIncorrectPattern(sent: pattern, expected: expected)
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
            if isPlaying { showNextCharacter() }
        }
    }

    func showNextCharacter() {
        var combinedStats = progressStore?.progress.characterStats ?? [:]
        for (char, sessionStat) in characterStats {
            if var existing = combinedStats[char] {
                existing.merge(sessionStat)
                combinedStats[char] = existing
            } else {
                combinedStats[char] = sessionStat
            }
        }

        let group = GroupGenerator.generateMixedGroup(
            level: currentLevel,
            characterStats: combinedStats,
            sessionType: .send,
            groupLength: 1,
            availableCharacters: customCharacters
        )

        if let char = group.first { targetCharacter = char }
        currentPattern = ""
        lastFeedback = nil
        isWaitingForInput = true
        resetInputTimer()
    }
}

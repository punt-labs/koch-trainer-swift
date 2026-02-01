import Foundation
import SwiftUI

// MARK: - EarTrainingViewModel

/// ViewModel for ear training sessions.
/// Plays Morse audio, user reproduces pattern via dit/dah buttons.
/// Levels are based on pattern length (1-5), not Koch order.
@MainActor
final class EarTrainingViewModel: ObservableObject, CharacterIntroducing {

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
        case completed(didAdvance: Bool, newCharacters: [Character]?)
    }

    struct Feedback: Equatable {
        let wasCorrect: Bool
        let expectedCharacter: Character
        let expectedPattern: String
        let userPattern: String
    }

    // MARK: - Published State

    @Published var phase: SessionPhase = .introduction(characterIndex: 0)
    @Published var timeRemaining: TimeInterval = 300 // 5 minutes
    @Published var isPlaying: Bool = false
    @Published private(set) var characterStats: [Character: CharacterStat] = [:]

    /// Session attempt counter with invariant enforcement.
    let counter = SessionCounter()

    // Introduction state
    @Published var introCharacters: [Character] = []
    @Published var currentIntroCharacter: Character?

    // Training state
    @Published var targetCharacter: Character?
    @Published var currentPattern: String = ""
    @Published var lastFeedback: Feedback?
    @Published var isWaitingForInput: Bool = false
    @Published var inputTimeRemaining: TimeInterval = 0

    // MARK: - Configuration

    let proficiencyThreshold: Double = 0.90

    /// Current ear training level (1-5)
    private(set) var currentLevel: Int = 1

    /// Fixed minimum attempts for proficiency check
    let minimumAttemptsForProficiency: Int = 20

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
        guard let char = targetCharacter else {
            return TrainingTiming.timeoutForPattern(length: 1)
        }
        return TrainingTiming.timeoutForCharacter(char)
    }

    func configure(progressStore: ProgressStore, settingsStore: SettingsStore) {
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        currentLevel = progressStore.progress.earTrainingLevel
        audioEngine.setFrequency(settingsStore.settings.toneFrequency)
        audioEngine.setEffectiveSpeed(settingsStore.settings.effectiveSpeed)
        audioEngine.configureBandConditions(from: settingsStore.settings)

        introCharacters = MorseCode.charactersByPatternLength(upToLevel: currentLevel)
    }

    // MARK: - Session Lifecycle

    func startSession() {
        startIntroduction()
    }

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

        if counter.attempts > 0, let snapshot = createPausedSessionSnapshot() {
            progressStore?.savePausedSession(snapshot)
        }
    }

    func resume() {
        guard phase == .paused else { return }

        progressStore?.clearPausedSession(for: .earTraining)

        phase = .training
        isPlaying = true
        announcer.announceResumed()
        try? audioEngine.stopRadio()
        try? audioEngine.startReceiving()
        startSessionTimer()
        playNextCharacter()
    }

    func endSession() {
        isPlaying = false
        sessionTimer?.invalidate()
        inputTimer?.invalidate()
        audioEngine.stop()
        isWaitingForInput = false

        progressStore?.clearPausedSession(for: .earTraining)

        guard let store = progressStore, let startTime = sessionStartTime else {
            phase = .completed(didAdvance: false, newCharacters: nil)
            return
        }

        guard counter.attempts > 0 else {
            phase = .completed(didAdvance: false, newCharacters: nil)
            return
        }

        let duration = Date().timeIntervalSince(startTime)
        let result = SessionResult(
            sessionType: .earTraining,
            duration: duration,
            totalAttempts: counter.attempts,
            correctCount: counter.correct,
            characterStats: characterStats
        )

        let didAdvance = store.recordSession(result)
        let newCharacters: [Character]? = didAdvance
            ? MorseCode.charactersAtPatternLength(store.progress.earTrainingLevel)
            : nil

        // Announce completion for VoiceOver
        if didAdvance, let chars = newCharacters {
            announcer.announceLevelUp(newCharacters: chars)
        } else {
            announcer.announceSessionComplete(accuracy: accuracyPercentage)
        }

        phase = .completed(didAdvance: didAdvance, newCharacters: newCharacters)
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
        playDit()
    }

    func inputDah() {
        guard isPlaying, isWaitingForInput else { return }
        currentPattern += "-"
        playDah()
    }

    // MARK: - Paused Session Management

    func createPausedSessionSnapshot() -> PausedSession? {
        guard let startTime = sessionStartTime else { return nil }

        return PausedSession(
            sessionType: .earTraining,
            startTime: startTime,
            pausedAt: Date(),
            correctCount: counter.correct,
            totalAttempts: counter.attempts,
            characterStats: characterStats,
            introCharacters: introCharacters,
            introCompleted: isIntroCompleted,
            customCharacters: nil,
            currentLevel: currentLevel
        )
    }

    func restoreFromPausedSession(_ session: PausedSession) {
        guard session.currentLevel == currentLevel else { return }

        counter.restore(correct: session.correctCount, attempts: session.totalAttempts)
        characterStats = session.characterStats
        introCharacters = session.introCharacters
        sessionStartTime = session.startTime

        if session.introCompleted {
            phase = .paused
        } else {
            phase = .introduction(characterIndex: 0)
        }
    }

    // MARK: Private

    private let audioEngine: AudioEngineProtocol
    private let announcer: AccessibilityAnnouncer
    private var progressStore: ProgressStore?
    private var settingsStore: SettingsStore?
    private var sessionTimer: Timer?
    private var inputTimer: Timer?
    private var sessionStartTime: Date?

    private func showIntroCharacter(at index: Int) {
        guard index < introCharacters.count else {
            startTraining()
            return
        }

        currentIntroCharacter = introCharacters[index]
        phase = .introduction(characterIndex: index)

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
        playNextCharacter()
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

extension EarTrainingViewModel {
    func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickSession() }
        }
    }

    private func tickSession() {
        guard timeRemaining > 0 else {
            endSession()
            return
        }
        timeRemaining -= 1
    }

    func resetInputTimer() {
        // Start at full, animate to zero via SwiftUI animation
        inputTimeRemaining = currentInputTimeout

        inputTimer?.invalidate()
        // Single-fire timer for timeout detection only
        inputTimer = Timer.scheduledTimer(withTimeInterval: currentInputTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.handleInputTimeout() }
        }

        // Trigger animation by setting to zero after a brief delay to let SwiftUI see the initial value
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: TrainingTiming.animationStartDelay)
            inputTimeRemaining = 0
        }
    }

    private func handleInputTimeout() {
        guard isWaitingForInput else { return }
        inputTimer?.invalidate()
        completeCurrentInput()
    }

    private func completeCurrentInput() {
        isWaitingForInput = false

        let expectedPattern = MorseCode.pattern(for: targetCharacter ?? " ") ?? ""
        let isCorrect = !currentPattern.isEmpty && currentPattern == expectedPattern
        let userPattern = currentPattern.isEmpty ? "(no response)" : currentPattern

        recordResponse(expected: targetCharacter ?? " ", wasCorrect: isCorrect)
        showFeedbackAndContinue(
            wasCorrect: isCorrect,
            expectedChar: targetCharacter ?? " ",
            expectedPattern: expectedPattern,
            userPattern: userPattern
        )
    }

    func recordResponse(expected: Character, wasCorrect: Bool) {
        counter.recordAttempt(wasCorrect: wasCorrect)

        var stat = characterStats[expected] ?? CharacterStat(
            earTrainingAttempts: 0,
            earTrainingCorrect: 0
        )
        stat.earTrainingAttempts += 1
        if wasCorrect { stat.earTrainingCorrect += 1 }
        stat.lastPracticed = Date()
        characterStats[expected] = stat
    }

    func showFeedbackAndContinue(
        wasCorrect: Bool,
        expectedChar: Character,
        expectedPattern: String,
        userPattern: String
    ) {
        lastFeedback = Feedback(
            wasCorrect: wasCorrect,
            expectedCharacter: expectedChar,
            expectedPattern: expectedPattern,
            userPattern: userPattern
        )

        // Announce feedback for VoiceOver
        if wasCorrect {
            announcer.announceCorrect()
        } else if userPattern == "(no response)" {
            announcer.announceTimeout(expected: expectedChar)
        } else {
            announcer.announceIncorrectPattern(sent: userPattern, expected: expectedChar)
        }

        Task {
            if !wasCorrect {
                // Show feedback briefly, then replay correct pattern
                try? await Task.sleep(nanoseconds: TrainingTiming.preReplayDelay)
                if isPlaying {
                    await audioEngine.playCharacter(expectedChar)
                }
                try? await Task.sleep(nanoseconds: TrainingTiming.postReplayDelay)
            } else {
                try? await Task.sleep(nanoseconds: TrainingTiming.correctAnswerDelay)
            }

            checkForProficiency()
            if isPlaying { playNextCharacter() }
        }
    }

    func playNextCharacter() {
        // Pick random character from current level's character pool
        let availableChars = MorseCode.charactersByPatternLength(upToLevel: currentLevel)
        targetCharacter = availableChars.randomElement()
        currentPattern = ""
        lastFeedback = nil
        isWaitingForInput = false
        inputTimeRemaining = 0

        // Play the character audio
        Task {
            guard let char = targetCharacter else { return }
            audioEngine.reset()
            await audioEngine.playCharacter(char)

            // After audio finishes, start accepting input and start timer
            isWaitingForInput = true
            resetInputTimer()
        }
    }
}

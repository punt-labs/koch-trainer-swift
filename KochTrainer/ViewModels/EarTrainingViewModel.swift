import Foundation
import SwiftUI

// MARK: - EarTrainingViewModel

/// ViewModel for ear training sessions.
/// Plays Morse audio, user reproduces pattern via dit/dah buttons.
/// Levels are based on pattern length (1-5), not Koch order.
@MainActor
final class EarTrainingViewModel: ObservableObject, CharacterIntroducing {

    // MARK: Lifecycle

    init(audioEngine: AudioEngineProtocol? = nil) {
        self.audioEngine = audioEngine ?? MorseAudioEngine()
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
    @Published var correctCount: Int = 0
    @Published var totalAttempts: Int = 0
    @Published private(set) var characterStats: [Character: CharacterStat] = [:]

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
        guard totalAttempts > 0 else { return 0 }
        return Int((Double(correctCount) / Double(totalAttempts) * 100).rounded())
    }

    var accuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctCount) / Double(totalAttempts)
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

        // Turn off radio (continuous audio outputs silence, engine keeps running)
        audioEngine.setRadioMode(.off)
        isWaitingForInput = false

        if totalAttempts > 0, let snapshot = createPausedSessionSnapshot() {
            progressStore?.savePausedSession(snapshot)
        }
    }

    func resume() {
        guard phase == .paused else { return }

        progressStore?.clearPausedSession(for: .earTraining)

        phase = .training
        isPlaying = true

        // Resume receiving mode
        audioEngine.setRadioMode(.receiving)

        startSessionTimer()
        playNextCharacter()
    }

    func endSession() {
        isPlaying = false
        sessionTimer?.invalidate()
        inputTimer?.invalidate()
        audioEngine.endSession()
        isWaitingForInput = false

        progressStore?.clearPausedSession(for: .earTraining)

        guard let store = progressStore, let startTime = sessionStartTime else {
            phase = .completed(didAdvance: false, newCharacters: nil)
            return
        }

        guard totalAttempts > 0 else {
            phase = .completed(didAdvance: false, newCharacters: nil)
            return
        }

        let duration = Date().timeIntervalSince(startTime)
        let result = SessionResult(
            sessionType: .earTraining,
            duration: duration,
            totalAttempts: totalAttempts,
            correctCount: correctCount,
            characterStats: characterStats
        )

        let didAdvance = store.recordSession(result)
        let newCharacters: [Character]? = didAdvance
            ? MorseCode.charactersAtPatternLength(store.progress.earTrainingLevel)
            : nil

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
            correctCount: correctCount,
            totalAttempts: totalAttempts,
            characterStats: characterStats,
            introCharacters: introCharacters,
            introCompleted: isIntroCompleted,
            customCharacters: nil,
            currentLevel: currentLevel
        )
    }

    func restoreFromPausedSession(_ session: PausedSession) {
        guard session.currentLevel == currentLevel else { return }

        correctCount = session.correctCount
        totalAttempts = session.totalAttempts
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
    private var progressStore: ProgressStore?
    private var settingsStore: SettingsStore?
    private var sessionTimer: Timer?
    private var inputTimer: Timer?
    private var sessionStartTime: Date?

    /// Dynamic timeout based on current target character's pattern length
    private var currentInputTimeout: TimeInterval {
        guard let char = targetCharacter else {
            return TrainingTiming.timeoutForPattern(length: 1)
        }
        return TrainingTiming.timeoutForCharacter(char)
    }

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

        // Start continuous audio session (radio starts in receiving mode)
        audioEngine.startSession()

        startSessionTimer()
        playNextCharacter()
    }

    private func checkForProficiency() {
        guard totalAttempts >= minimumAttemptsForProficiency else { return }
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
        inputTimeRemaining = currentInputTimeout
        inputTimer?.invalidate()
        inputTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickInput() }
        }
    }

    private func tickInput() {
        inputTimeRemaining -= 0.05
        if inputTimeRemaining <= 0 {
            inputTimer?.invalidate()
            completeCurrentInput()
        }
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
        totalAttempts += 1
        if wasCorrect { correctCount += 1 }

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

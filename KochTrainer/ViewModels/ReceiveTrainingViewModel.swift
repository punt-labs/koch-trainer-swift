import Foundation
import SwiftUI

/// ViewModel for receive training sessions.
/// Plays Morse audio one character at a time, waits for single keypress response.
@MainActor
final class ReceiveTrainingViewModel: ObservableObject, CharacterIntroducing {
    // MARK: - Session Phase

    enum SessionPhase: Equatable {
        case introduction(characterIndex: Int)
        case training
        case paused
        case completed(didAdvance: Bool, newCharacter: Character?)
    }

    // MARK: - Published State

    @Published var phase: SessionPhase = .introduction(characterIndex: 0)
    @Published var timeRemaining: TimeInterval = 300 // 5 minutes (fallback max)
    @Published var isPlaying: Bool = false
    @Published var correctCount: Int = 0
    @Published var totalAttempts: Int = 0
    @Published private(set) var characterStats: [Character: CharacterStat] = [:]

    // Introduction state
    @Published var introCharacters: [Character] = []
    @Published var currentIntroCharacter: Character?

    // Training state
    @Published var currentCharacter: Character?
    @Published var responseTimeRemaining: TimeInterval = 0
    @Published var lastFeedback: Feedback?
    @Published var isWaitingForResponse: Bool = false

    struct Feedback: Equatable {
        let wasCorrect: Bool
        let expectedCharacter: Character
        let userPressed: Character?
    }

    // MARK: - Configuration

    let responseTimeout: TimeInterval = 3.0
    let masteryThreshold: Double = 0.90

    /// Minimum attempts scales with character count (5 per character, floor of 15)
    var minimumAttemptsForMastery: Int {
        max(15, 5 * introCharacters.count)
    }

    // MARK: - Dependencies

    private let audioEngine: AudioEngineProtocol
    private var progressStore: ProgressStore?
    private var settingsStore: SettingsStore?

    // MARK: - Internal State

    private var sessionTimer: Timer?
    private var responseTimer: Timer?
    private var sessionStartTime: Date?
    private var currentLevel: Int = 1

    private var currentGroup: [Character] = []
    private var currentGroupIndex: Int = 0

    /// Custom characters for practice mode (nil = use level-based characters)
    private var customCharacters: [Character]?

    /// Whether this is a custom practice session (no level advancement)
    var isCustomSession: Bool { customCharacters != nil }

    // MARK: - Computed Properties

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
        if case .introduction(let index) = phase {
            return "\(index + 1) of \(introCharacters.count)"
        }
        return ""
    }

    var isLastIntroCharacter: Bool {
        if case .introduction(let index) = phase {
            return index == introCharacters.count - 1
        }
        return false
    }

    var masteryProgress: String {
        if totalAttempts < minimumAttemptsForMastery {
            return "\(totalAttempts)/\(minimumAttemptsForMastery) attempts"
        } else {
            return "\(accuracyPercentage)% (need \(Int(masteryThreshold * 100))%)"
        }
    }

    // MARK: - Initialization

    init(audioEngine: AudioEngineProtocol = MorseAudioEngine()) {
        self.audioEngine = audioEngine
    }

    func configure(progressStore: ProgressStore, settingsStore: SettingsStore) {
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        self.currentLevel = progressStore.progress.receiveLevel
        audioEngine.setFrequency(settingsStore.settings.toneFrequency)
        audioEngine.setEffectiveSpeed(settingsStore.settings.effectiveSpeed)

        introCharacters = MorseCode.characters(forLevel: currentLevel)
    }

    /// Configure for custom practice with specific characters (no level advancement)
    func configure(progressStore: ProgressStore, settingsStore: SettingsStore, customCharacters: [Character]) {
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        self.customCharacters = customCharacters
        self.currentLevel = progressStore.progress.receiveLevel
        audioEngine.setFrequency(settingsStore.settings.toneFrequency)
        audioEngine.setEffectiveSpeed(settingsStore.settings.effectiveSpeed)

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

    private func showIntroCharacter(at index: Int) {
        guard index < introCharacters.count else {
            startTraining()
            return
        }

        currentIntroCharacter = introCharacters[index]
        phase = .introduction(characterIndex: index)

        // Auto-play after a short delay to let the UI update
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            playCurrentIntroCharacter()
        }
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
        if case .introduction(let index) = phase {
            let nextIndex = index + 1
            if nextIndex < introCharacters.count {
                showIntroCharacter(at: nextIndex)
            } else {
                startTraining()
            }
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

    func startSession() {
        startIntroduction()
    }

    func pause() {
        guard case .training = phase else { return }
        isPlaying = false
        phase = .paused
        sessionTimer?.invalidate()
        responseTimer?.invalidate()
        audioEngine.stop()
        isWaitingForResponse = false
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .training
        isPlaying = true
        startSessionTimer()
        playNextGroup()
    }

    func endSession() {
        isPlaying = false
        sessionTimer?.invalidate()
        responseTimer?.invalidate()
        audioEngine.stop()
        isWaitingForResponse = false

        guard let store = progressStore, let startTime = sessionStartTime else {
            phase = .completed(didAdvance: false, newCharacter: nil)
            return
        }

        let duration = Date().timeIntervalSince(startTime)
        let sessionType: SessionType = isCustomSession ? .receiveCustom : .receive
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
        audioEngine.stop()
    }

    // MARK: - Mastery Check

    private func checkForMastery() {
        guard totalAttempts >= minimumAttemptsForMastery else { return }
        guard accuracy >= masteryThreshold else { return }

        // Mastery achieved! End session and advance
        endSession()
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

    // MARK: - Private Methods

    private func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickSession()
            }
        }
    }

    private func tickSession() {
        guard timeRemaining > 0 else {
            endSession()
            return
        }
        timeRemaining -= 1
    }

    private func playNextGroup() {
        guard isPlaying else { return }

        let group = generateGroup()
        currentGroup = Array(group)
        currentGroupIndex = 0

        playNextCharacterInGroup()
    }

    private func playNextCharacterInGroup() {
        guard isPlaying else { return }

        if currentGroupIndex >= currentGroup.count {
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if isPlaying {
                    playNextGroup()
                }
            }
            return
        }

        let char = currentGroup[currentGroupIndex]
        currentCharacter = char
        lastFeedback = nil

        Task {
            guard let engine = audioEngine as? MorseAudioEngine else { return }
            engine.reset()
            await engine.playCharacter(char)

            if isPlaying {
                startResponseTimer()
            }
        }
    }

    private func startResponseTimer() {
        isWaitingForResponse = true
        responseTimeRemaining = responseTimeout

        responseTimer?.invalidate()
        responseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickResponse()
            }
        }
    }

    private func tickResponse() {
        responseTimeRemaining -= 0.05

        if responseTimeRemaining <= 0 {
            responseTimer?.invalidate()
            isWaitingForResponse = false

            if let expected = currentCharacter {
                recordResponse(expected: expected, wasCorrect: false, userPressed: nil)
                showFeedbackAndContinue(wasCorrect: false, expected: expected, userPressed: nil)
            }
        }
    }

    private func recordResponse(expected: Character, wasCorrect: Bool, userPressed: Character?) {
        totalAttempts += 1
        if wasCorrect {
            correctCount += 1
        }

        var stat = characterStats[expected] ?? CharacterStat()
        stat.receiveAttempts += 1
        if wasCorrect {
            stat.receiveCorrect += 1
        }
        stat.lastPracticed = Date()
        characterStats[expected] = stat
    }

    private func showFeedbackAndContinue(wasCorrect: Bool, expected: Character, userPressed: Character?) {
        lastFeedback = Feedback(
            wasCorrect: wasCorrect,
            expectedCharacter: expected,
            userPressed: userPressed
        )

        Task {
            if !wasCorrect {
                // Wait before playing correction to let visual feedback register
                try? await Task.sleep(nanoseconds: 400_000_000)
                if let engine = audioEngine as? MorseAudioEngine, isPlaying {
                    await engine.playCharacter(expected)
                }
                // Longer pause after correction so it doesn't blend into next trial
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            } else {
                // Brief pause after correct answer before next character
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            // Check for mastery after each response
            checkForMastery()

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
            groupLength: Int.random(in: 3...5),
            availableCharacters: customCharacters
        )
    }
}

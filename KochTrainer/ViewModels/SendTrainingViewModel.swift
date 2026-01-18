import Foundation
import SwiftUI

/// ViewModel for send training sessions.
/// Displays characters, accepts paddle/keyboard input, decodes Morse patterns with audio feedback.
@MainActor
final class SendTrainingViewModel: ObservableObject, CharacterIntroducing {
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
    @Published var targetCharacter: Character = "K"
    @Published var currentPattern: String = ""
    @Published var lastFeedback: Feedback?
    @Published var isWaitingForInput: Bool = true
    @Published var inputTimeRemaining: TimeInterval = 0

    struct Feedback: Equatable {
        let wasCorrect: Bool
        let expectedCharacter: Character
        let sentPattern: String
        let decodedCharacter: Character?
    }

    // MARK: - Configuration

    let inputTimeout: TimeInterval = 2.0  // Time to complete a character
    let masteryThreshold: Double = 0.90

    /// Minimum attempts scales with character count (5 per character, floor of 15)
    var minimumAttemptsForMastery: Int {
        max(15, 5 * introCharacters.count)
    }

    // MARK: - Dependencies

    private let audioEngine: AudioEngineProtocol
    private let decoder = MorseDecoder()
    private var progressStore: ProgressStore?
    private var settingsStore: SettingsStore?

    // MARK: - Internal State

    private var sessionTimer: Timer?
    private var inputTimer: Timer?
    private var sessionStartTime: Date?
    private var currentLevel: Int = 1
    private var lastInputTime: Date?

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

    var inputProgress: Double {
        guard inputTimeout > 0 else { return 0 }
        return inputTimeRemaining / inputTimeout
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

    init(audioEngine: AudioEngineProtocol? = nil) {
        self.audioEngine = audioEngine ?? MorseAudioEngine()
    }

    func configure(progressStore: ProgressStore, settingsStore: SettingsStore) {
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        self.currentLevel = progressStore.progress.sendLevel
        audioEngine.setFrequency(settingsStore.settings.toneFrequency)
        audioEngine.setEffectiveSpeed(settingsStore.settings.effectiveSpeed)

        introCharacters = MorseCode.characters(forLevel: currentLevel)
    }

    /// Configure for custom practice with specific characters (no level advancement)
    func configure(progressStore: ProgressStore, settingsStore: SettingsStore, customCharacters: [Character]) {
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        self.customCharacters = customCharacters
        self.currentLevel = progressStore.progress.sendLevel
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

        // Auto-play after a short delay
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
        showNextCharacter()
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
        isWaitingForInput = false
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .training
        isPlaying = true
        startSessionTimer()
        showNextCharacter()
    }

    func endSession() {
        isPlaying = false
        sessionTimer?.invalidate()
        inputTimer?.invalidate()
        audioEngine.stop()
        isWaitingForInput = false

        guard let store = progressStore, let startTime = sessionStartTime else {
            phase = .completed(didAdvance: false, newCharacter: nil)
            return
        }

        let duration = Date().timeIntervalSince(startTime)
        let sessionType: SessionType = isCustomSession ? .sendCustom : .send
        let result = SessionResult(
            sessionType: sessionType,
            duration: duration,
            totalAttempts: totalAttempts,
            correctCount: correctCount,
            characterStats: characterStats
        )

        // Record session and check for advancement (custom sessions can't advance)
        let didAdvance = store.recordSession(result)
        let newCharacter: Character? = didAdvance ? store.progress.unlockedCharacters(for: .send).last : nil

        phase = .completed(didAdvance: didAdvance, newCharacter: newCharacter)
    }

    func cleanup() {
        isPlaying = false
        sessionTimer?.invalidate()
        sessionTimer = nil
        inputTimer?.invalidate()
        inputTimer = nil
        audioEngine.stop()
    }

    // MARK: - Mastery Check

    private func checkForMastery() {
        guard totalAttempts >= minimumAttemptsForMastery else { return }
        guard accuracy >= masteryThreshold else { return }

        endSession()
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
        resetInputTimer()
    }

    func inputDah() {
        guard isPlaying, isWaitingForInput else { return }
        currentPattern += "-"
        lastInputTime = Date()
        playDah()
        resetInputTimer()
    }

    private func playDit() {
        Task {
            guard let engine = audioEngine as? MorseAudioEngine else { return }
            await engine.playDit()
        }
    }

    private func playDah() {
        Task {
            guard let engine = audioEngine as? MorseAudioEngine else { return }
            await engine.playDah()
        }
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

    private func resetInputTimer() {
        inputTimeRemaining = inputTimeout

        inputTimer?.invalidate()
        inputTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickInput()
            }
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
        guard !currentPattern.isEmpty else { return }

        isWaitingForInput = false

        // Decode the pattern
        let decodedChar = MorseCode.character(for: currentPattern)
        let isCorrect = decodedChar == targetCharacter

        recordResponse(expected: targetCharacter, wasCorrect: isCorrect, pattern: currentPattern, decoded: decodedChar)
        showFeedbackAndContinue(wasCorrect: isCorrect, expected: targetCharacter, pattern: currentPattern, decoded: decodedChar)
    }

    private func recordResponse(expected: Character, wasCorrect: Bool, pattern: String, decoded: Character?) {
        totalAttempts += 1
        if wasCorrect {
            correctCount += 1
        }

        var stat = characterStats[expected] ?? CharacterStat()
        stat.sendAttempts += 1
        if wasCorrect {
            stat.sendCorrect += 1
        }
        stat.lastPracticed = Date()
        characterStats[expected] = stat
    }

    private func showFeedbackAndContinue(wasCorrect: Bool, expected: Character, pattern: String, decoded: Character?) {
        lastFeedback = Feedback(
            wasCorrect: wasCorrect,
            expectedCharacter: expected,
            sentPattern: pattern,
            decodedCharacter: decoded
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
                // Brief pause after correct answer
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            checkForMastery()

            if isPlaying {
                showNextCharacter()
            }
        }
    }

    private func showNextCharacter() {
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

        if let char = group.first {
            targetCharacter = char
        }

        currentPattern = ""
        lastFeedback = nil
        isWaitingForInput = true
        inputTimeRemaining = 0  // No timer until first input
    }
}

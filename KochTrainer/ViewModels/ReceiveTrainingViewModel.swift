import Foundation
import SwiftUI

/// ViewModel for receive training sessions.
/// Plays Morse audio one character at a time, waits for single keypress response.
@MainActor
final class ReceiveTrainingViewModel: ObservableObject {
    // MARK: - Session Phase

    enum SessionPhase: Equatable {
        case introduction(characterIndex: Int)  // Showing character intros
        case training                           // Active training
        case paused
        case finished
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

    let responseTimeout: TimeInterval = 3.0 // seconds to respond

    // MARK: - Dependencies

    private let audioEngine: AudioEngineProtocol
    private var progressStore: ProgressStore?
    private var settingsStore: SettingsStore?

    // MARK: - Internal State

    private var sessionTimer: Timer?
    private var responseTimer: Timer?
    private var sessionStartTime: Date?
    private var currentLevel: Int = 1

    // Current group being played
    private var currentGroup: [Character] = []
    private var currentGroupIndex: Int = 0

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

    // MARK: - Initialization

    init(audioEngine: AudioEngineProtocol = MorseAudioEngine()) {
        self.audioEngine = audioEngine
    }

    func configure(progressStore: ProgressStore, settingsStore: SettingsStore) {
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        self.currentLevel = progressStore.progress.currentLevel
        audioEngine.setFrequency(settingsStore.settings.toneFrequency)
        audioEngine.setEffectiveSpeed(settingsStore.settings.effectiveSpeed)

        // Set up characters to introduce
        introCharacters = MorseCode.characters(forLevel: currentLevel)
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

    func endSession() -> SessionResult? {
        pause()
        cleanup()
        phase = .finished

        guard let startTime = sessionStartTime else { return nil }

        let duration = Date().timeIntervalSince(startTime)
        let result = SessionResult(
            sessionType: .receive,
            duration: duration,
            totalAttempts: totalAttempts,
            correctCount: correctCount,
            characterStats: characterStats
        )

        return result
    }

    func cleanup() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        responseTimer?.invalidate()
        responseTimer = nil
        audioEngine.stop()
    }

    // MARK: - Input Handling

    /// Called when user presses a key
    func handleKeyPress(_ key: Character) {
        guard isWaitingForResponse, let expected = currentCharacter else { return }

        // Stop the response timer
        responseTimer?.invalidate()
        isWaitingForResponse = false

        // Check if correct
        let pressedUpper = Character(key.uppercased())
        let isCorrect = pressedUpper == expected

        recordResponse(expected: expected, wasCorrect: isCorrect, userPressed: pressedUpper)

        // Show feedback briefly, then continue
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
            endSessionDueToTimeout()
            return
        }
        timeRemaining -= 1
    }

    private func endSessionDueToTimeout() {
        pause()
    }

    private func playNextGroup() {
        guard isPlaying else { return }

        // Generate a new group
        let group = generateGroup()
        currentGroup = Array(group)
        currentGroupIndex = 0

        playNextCharacterInGroup()
    }

    private func playNextCharacterInGroup() {
        guard isPlaying else { return }

        if currentGroupIndex >= currentGroup.count {
            // Group complete, start next group after brief pause
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second pause
                if isPlaying {
                    playNextGroup()
                }
            }
            return
        }

        let char = currentGroup[currentGroupIndex]
        currentCharacter = char
        lastFeedback = nil

        // Play the character audio
        Task {
            guard let engine = audioEngine as? MorseAudioEngine else { return }
            engine.reset()
            await engine.playCharacter(char)

            // After audio finishes, start response timer
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
            // Timeout - count as wrong
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

        // Update character stats
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

        // Move to next character after showing feedback
        Task {
            // If wrong, replay the correct sound
            if !wasCorrect {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 sec
                if let engine = audioEngine as? MorseAudioEngine, isPlaying {
                    await engine.playCharacter(expected)
                }
            }

            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec pause
            if isPlaying {
                currentGroupIndex += 1
                playNextCharacterInGroup()
            }
        }
    }

    private func generateGroup() -> String {
        // Combine historic stats with current session stats for weighting
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
            groupLength: Int.random(in: 3...5)
        )
    }
}

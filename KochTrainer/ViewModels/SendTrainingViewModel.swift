import Foundation
import SwiftUI

/// ViewModel for send training sessions.
/// Displays characters, accepts paddle input, decodes Morse patterns.
@MainActor
final class SendTrainingViewModel: ObservableObject {
    // MARK: - Published State

    @Published var timeRemaining: TimeInterval = 300 // 5 minutes
    @Published var targetCharacter: Character = "K"
    @Published var isPlaying: Bool = false
    @Published var correctCount: Int = 0
    @Published var totalAttempts: Int = 0
    @Published var feedbackText: String = ""
    @Published var feedbackColor: Color = .primary
    @Published private(set) var characterStats: [Character: CharacterStat] = [:]

    // MARK: - Dependencies

    private let decoder = MorseDecoder()
    private var progressStore: ProgressStore?
    private var settingsStore: SettingsStore?

    // MARK: - Internal State

    private var timer: Timer?
    private var sessionStartTime: Date?
    private var currentLevel: Int = 1

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

    var currentPattern: String {
        decoder.currentPattern
    }

    // MARK: - Initialization

    init() {
        decoder.onCharacterDecoded = { [weak self] result in
            Task { @MainActor in
                self?.handleDecodedResult(result)
            }
        }
    }

    func configure(progressStore: ProgressStore, settingsStore: SettingsStore) {
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        self.currentLevel = progressStore.progress.currentLevel
    }

    // MARK: - Session Control

    func startSession() {
        guard !isPlaying else { return }

        sessionStartTime = Date()
        isPlaying = true
        startTimer()
        showNextCharacter()
    }

    func pause() {
        isPlaying = false
        timer?.invalidate()
        decoder.reset()
    }

    func resume() {
        guard !isPlaying else { return }
        isPlaying = true
        startTimer()
    }

    func endSession() -> SessionResult? {
        pause()
        cleanup()

        guard let startTime = sessionStartTime else { return nil }

        let duration = Date().timeIntervalSince(startTime)
        let result = SessionResult(
            sessionType: .send,
            duration: duration,
            totalAttempts: totalAttempts,
            correctCount: correctCount,
            characterStats: characterStats
        )

        return result
    }

    func cleanup() {
        timer?.invalidate()
        timer = nil
        decoder.reset()
    }

    // MARK: - Input Handling

    func inputDit() {
        guard isPlaying else { return }
        if let result = decoder.processInput(.dit) {
            handleDecodedResult(result)
        }
    }

    func inputDah() {
        guard isPlaying else { return }
        if let result = decoder.processInput(.dah) {
            handleDecodedResult(result)
        }
    }

    // MARK: - Private Methods

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard timeRemaining > 0 else {
            endSessionDueToTimeout()
            return
        }
        timeRemaining -= 1
    }

    private func endSessionDueToTimeout() {
        pause()
    }

    private func handleDecodedResult(_ result: DecodedResult) {
        totalAttempts += 1

        let isCorrect: Bool
        switch result {
        case .character(let char):
            isCorrect = char == targetCharacter
            if isCorrect {
                correctCount += 1
                feedbackText = "Correct!"
                feedbackColor = Theme.Colors.success
            } else {
                feedbackText = "Sent: \(char)"
                feedbackColor = Theme.Colors.error
            }

        case .invalid(let pattern):
            isCorrect = false
            feedbackText = "Invalid: \(pattern)"
            feedbackColor = Theme.Colors.error
        }

        // Update character stats
        var stat = characterStats[targetCharacter] ?? CharacterStat()
        stat.totalAttempts += 1
        if isCorrect {
            stat.correctCount += 1
        }
        stat.lastPracticed = Date()
        characterStats[targetCharacter] = stat

        // Show feedback briefly, then next character
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            if isPlaying && timeRemaining > 0 {
                showNextCharacter()
            }
        }
    }

    private func showNextCharacter() {
        // Combine historic stats with current session stats for weighting
        var combinedStats = progressStore?.progress.characterStats ?? [:]
        for (char, sessionStat) in characterStats {
            if var existing = combinedStats[char] {
                existing.totalAttempts += sessionStat.totalAttempts
                existing.correctCount += sessionStat.correctCount
                combinedStats[char] = existing
            } else {
                combinedStats[char] = sessionStat
            }
        }

        // Generate a single-character "group" using weighted selection
        let group = GroupGenerator.generateMixedGroup(
            level: currentLevel,
            characterStats: combinedStats,
            groupLength: 1
        )

        if let char = group.first {
            targetCharacter = char
            feedbackText = MorseCode.pattern(for: char) ?? ""
            feedbackColor = .secondary
        }
        decoder.reset()
    }
}

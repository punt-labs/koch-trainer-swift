import Foundation
import SwiftUI

/// ViewModel for receive training sessions.
/// Plays Morse audio, accepts text input, tracks accuracy.
@MainActor
final class ReceiveTrainingViewModel: ObservableObject {
    // MARK: - Published State

    @Published var timeRemaining: TimeInterval = 300 // 5 minutes
    @Published var currentInput: String = ""
    @Published var currentGroup: String = ""
    @Published var isPlaying: Bool = false
    @Published var correctCount: Int = 0
    @Published var totalAttempts: Int = 0
    @Published private(set) var characterStats: [Character: CharacterStat] = [:]

    // MARK: - Dependencies

    private let audioEngine: AudioEngineProtocol
    private var progressStore: ProgressStore?
    private var settingsStore: SettingsStore?

    // MARK: - Internal State

    private var timer: Timer?
    private var sessionStartTime: Date?
    private var currentLevel: Int = 1
    private var playTask: Task<Void, Never>?

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
    }

    // MARK: - Session Control

    func startSession() {
        guard !isPlaying else { return }

        sessionStartTime = Date()
        isPlaying = true
        startTimer()
        playNextGroup()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        isPlaying = false
        timer?.invalidate()
        audioEngine.stop()
        playTask?.cancel()
    }

    func resume() {
        guard !isPlaying else { return }
        isPlaying = true
        startTimer()
        playNextGroup()
    }

    func endSession() -> SessionResult? {
        pause()
        cleanup()

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
        timer?.invalidate()
        timer = nil
        audioEngine.stop()
        playTask?.cancel()
        playTask = nil
    }

    // MARK: - Input Handling

    func submitInput() {
        let submitted = currentInput.uppercased().trimmingCharacters(in: .whitespaces)
        let expected = currentGroup.uppercased()

        guard !submitted.isEmpty else { return }

        // Compare character by character
        for (index, expectedChar) in expected.enumerated() {
            let submittedChar: Character? = index < submitted.count
                ? submitted[submitted.index(submitted.startIndex, offsetBy: index)]
                : nil

            totalAttempts += 1
            let isCorrect = submittedChar == expectedChar

            if isCorrect {
                correctCount += 1
            }

            // Update character stats
            var stat = characterStats[expectedChar] ?? CharacterStat()
            stat.totalAttempts += 1
            if isCorrect {
                stat.correctCount += 1
            }
            stat.lastPracticed = Date()
            characterStats[expectedChar] = stat
        }

        currentInput = ""

        // Play next group
        if isPlaying && timeRemaining > 0 {
            playNextGroup()
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
        // Session ends when timer reaches 0
        pause()
    }

    private func playNextGroup() {
        let group = generateGroup()
        currentGroup = group

        playTask = Task {
            guard let engine = audioEngine as? MorseAudioEngine else { return }
            engine.reset()
            await engine.playGroup(group)
        }
    }

    private func generateGroup() -> String {
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

        return GroupGenerator.generateMixedGroup(
            level: currentLevel,
            characterStats: combinedStats,
            groupLength: Int.random(in: 3...5)
        )
    }
}

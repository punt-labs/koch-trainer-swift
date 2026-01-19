import Foundation
import SwiftUI

/// ViewModel for vocabulary (word/callsign) training sessions.
/// Supports both receive (audio → text) and send (text → keying) modes.
@MainActor
final class VocabularyTrainingViewModel: ObservableObject {
    // MARK: - Session Phase

    enum SessionPhase: Equatable {
        case training
        case paused
        case completed
    }

    // MARK: - Published State

    @Published var phase: SessionPhase = .training
    @Published var isPlaying: Bool = false
    @Published var correctCount: Int = 0
    @Published var totalAttempts: Int = 0
    @Published private(set) var wordStats: [String: WordStat] = [:]

    // Training state
    @Published var currentWord: String = ""
    @Published var userInput: String = ""
    @Published var lastFeedback: Feedback?
    @Published var isWaitingForResponse: Bool = false
    @Published var responseTimeRemaining: TimeInterval = 0

    // Send mode state
    @Published var currentPattern: String = ""
    @Published var inputTimeRemaining: TimeInterval = 0

    struct Feedback: Equatable {
        let wasCorrect: Bool
        let expectedWord: String
        let userAnswer: String
    }

    // MARK: - Configuration

    let vocabularySet: VocabularySet
    let sessionType: SessionType
    let minimumAttempts: Int = 10

    /// Response timeout scales with word length
    var responseTimeout: TimeInterval {
        // Base 3 seconds + 1 second per character
        3.0 + Double(currentWord.count)
    }

    /// Input timeout for send mode (time to complete keying)
    let inputTimeout: TimeInterval = 2.0

    // MARK: - Dependencies

    private let audioEngine: AudioEngineProtocol
    private let decoder = MorseDecoder()
    private var progressStore: ProgressStore?
    private var settingsStore: SettingsStore?

    // MARK: - Internal State

    private var responseTimer: Timer?
    private var inputTimer: Timer?
    private var sessionStartTime: Date?
    private var recentWords: [String] = []
    private var currentCharIndex: Int = 0

    // MARK: - Computed Properties

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

    var inputProgress: Double {
        guard inputTimeout > 0 else { return 0 }
        return inputTimeRemaining / inputTimeout
    }

    var isReceiveMode: Bool {
        sessionType.baseType == .receive
    }

    var progressText: String {
        "\(totalAttempts)/\(minimumAttempts) words"
    }

    // MARK: - Initialization

    init(
        vocabularySet: VocabularySet,
        sessionType: SessionType,
        audioEngine: AudioEngineProtocol? = nil
    ) {
        self.vocabularySet = vocabularySet
        self.sessionType = sessionType
        self.audioEngine = audioEngine ?? MorseAudioEngine()
    }

    func configure(progressStore: ProgressStore, settingsStore: SettingsStore) {
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        audioEngine.setFrequency(settingsStore.settings.toneFrequency)
        audioEngine.setEffectiveSpeed(settingsStore.settings.effectiveSpeed)
        audioEngine.configureBandConditions(from: settingsStore.settings)

        // Merge existing word stats
        wordStats = progressStore.progress.wordStats
    }

    // MARK: - Session Control

    func startSession() {
        sessionStartTime = Date()
        isPlaying = true
        phase = .training
        showNextWord()
    }

    func pause() {
        guard phase == .training else { return }
        isPlaying = false
        phase = .paused
        responseTimer?.invalidate()
        inputTimer?.invalidate()
        audioEngine.stop()
        isWaitingForResponse = false
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .training
        isPlaying = true
        showNextWord()
    }

    func endSession() {
        isPlaying = false
        responseTimer?.invalidate()
        inputTimer?.invalidate()
        audioEngine.stop()
        isWaitingForResponse = false

        // Save word stats to progress store
        if var progress = progressStore?.progress {
            for (word, stat) in wordStats {
                if var existing = progress.wordStats[word] {
                    existing.merge(stat)
                    progress.wordStats[word] = existing
                } else {
                    progress.wordStats[word] = stat
                }
            }
            progressStore?.save(progress)
        }

        phase = .completed
    }

    func cleanup() {
        isPlaying = false
        responseTimer?.invalidate()
        responseTimer = nil
        inputTimer?.invalidate()
        inputTimer = nil
        audioEngine.stop()
    }

    // MARK: - Receive Mode Input

    func submitAnswer(_ answer: String) {
        guard isWaitingForResponse else { return }

        responseTimer?.invalidate()
        isWaitingForResponse = false

        let normalizedAnswer = answer.uppercased().trimmingCharacters(in: .whitespaces)
        let isCorrect = normalizedAnswer == currentWord

        recordResponse(expected: currentWord, wasCorrect: isCorrect, userAnswer: normalizedAnswer)
        showFeedbackAndContinue(wasCorrect: isCorrect, expected: currentWord, userAnswer: normalizedAnswer)
    }

    /// Replay the current word (receive mode)
    func replayWord() {
        guard isReceiveMode, !currentWord.isEmpty else { return }

        Task {
            guard let engine = audioEngine as? MorseAudioEngine else { return }
            engine.reset()
            await engine.playGroup(currentWord)
        }
    }

    // MARK: - Send Mode Input

    func handleKeyPress(_ key: Character) {
        guard !isReceiveMode, isWaitingForResponse else { return }

        let keyLower = Character(key.lowercased())

        if keyLower == "." || keyLower == "f" {
            inputDit()
        } else if keyLower == "-" || keyLower == "j" {
            inputDah()
        } else if keyLower == " " {
            // Space advances to next character in word
            advanceToNextCharacter()
        }
    }

    func inputDit() {
        guard isPlaying, isWaitingForResponse else { return }
        currentPattern += "."
        playDit()
        resetInputTimer()
    }

    func inputDah() {
        guard isPlaying, isWaitingForResponse else { return }
        currentPattern += "-"
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

    private func advanceToNextCharacter() {
        guard !currentPattern.isEmpty else { return }

        // Decode current pattern
        let decoded = MorseCode.character(for: currentPattern)
        userInput += decoded.map { String($0) } ?? "?"

        currentPattern = ""
        currentCharIndex += 1

        // Check if word is complete
        if currentCharIndex >= currentWord.count {
            completeWordInput()
        } else {
            // Reset timer for next character
            resetInputTimer()
        }
    }

    private func completeWordInput() {
        inputTimer?.invalidate()
        isWaitingForResponse = false

        let isCorrect = userInput == currentWord

        recordResponse(expected: currentWord, wasCorrect: isCorrect, userAnswer: userInput)
        showFeedbackAndContinue(wasCorrect: isCorrect, expected: currentWord, userAnswer: userInput)
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
            advanceToNextCharacter()
        }
    }
}

// MARK: - Private Helpers

extension VocabularyTrainingViewModel {
    func showNextWord() {
        guard isPlaying else { return }

        let combinedStats = mergeWordStats()
        guard let nextWord = VocabularyGroupGenerator.selectNextWord(
            from: vocabularySet, wordStats: combinedStats, sessionType: sessionType, avoiding: recentWords
        ) else { endSession(); return }

        currentWord = nextWord
        userInput = ""
        currentPattern = ""
        currentCharIndex = 0
        lastFeedback = nil

        recentWords.append(nextWord)
        if recentWords.count > 3 { recentWords.removeFirst() }

        if isReceiveMode {
            Task {
                guard let engine = audioEngine as? MorseAudioEngine else { return }
                engine.reset()
                await engine.playGroup(currentWord)
                if isPlaying { startResponseTimer() }
            }
        } else {
            isWaitingForResponse = true
            inputTimeRemaining = 0
        }
    }

    func startResponseTimer() {
        isWaitingForResponse = true
        responseTimeRemaining = responseTimeout

        responseTimer?.invalidate()
        responseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickResponse() }
        }
    }

    private func tickResponse() {
        responseTimeRemaining -= 0.05
        if responseTimeRemaining <= 0 {
            responseTimer?.invalidate()
            isWaitingForResponse = false
            recordResponse(expected: currentWord, wasCorrect: false, userAnswer: "")
            showFeedbackAndContinue(wasCorrect: false, expected: currentWord, userAnswer: "(timeout)")
        }
    }

    func recordResponse(expected: String, wasCorrect: Bool, userAnswer: String) {
        totalAttempts += 1
        if wasCorrect { correctCount += 1 }

        var stat = wordStats[expected] ?? WordStat()
        if isReceiveMode {
            stat.receiveAttempts += 1
            if wasCorrect { stat.receiveCorrect += 1 }
        } else {
            stat.sendAttempts += 1
            if wasCorrect { stat.sendCorrect += 1 }
        }
        stat.lastPracticed = Date()
        wordStats[expected] = stat
    }

    func showFeedbackAndContinue(wasCorrect: Bool, expected: String, userAnswer: String) {
        lastFeedback = Feedback(wasCorrect: wasCorrect, expectedWord: expected, userAnswer: userAnswer)

        Task {
            if !wasCorrect {
                try? await Task.sleep(nanoseconds: TrainingTiming.preReplayDelay)
                if let engine = audioEngine as? MorseAudioEngine, isPlaying { await engine.playGroup(expected) }
                try? await Task.sleep(nanoseconds: TrainingTiming.postReplayDelay)
            } else {
                try? await Task.sleep(nanoseconds: TrainingTiming.correctAnswerDelay)
            }

            if totalAttempts >= minimumAttempts {
                endSession()
            } else if isPlaying {
                showNextWord()
            }
        }
    }

    private func mergeWordStats() -> [String: WordStat] {
        var combined = progressStore?.progress.wordStats ?? [:]
        for (word, stat) in wordStats {
            if var existing = combined[word] {
                existing.merge(stat)
                combined[word] = existing
            } else {
                combined[word] = stat
            }
        }
        return combined
    }
}

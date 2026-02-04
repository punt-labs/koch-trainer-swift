import Foundation
import SwiftUI

// MARK: - VocabularyTrainingViewModel

/// ViewModel for vocabulary (word/callsign) training sessions.
/// Supports both receive (audio → text) and send (text → keying) modes.
@MainActor
final class VocabularyTrainingViewModel: ObservableObject {

    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        vocabularySet: VocabularySet,
        sessionType: SessionType,
        audioEngine: AudioEngineProtocol? = nil,
        announcer: AccessibilityAnnouncer = AccessibilityAnnouncer(),
        clock: KeyerClock = RealClock()
    ) {
        self.vocabularySet = vocabularySet
        self.sessionType = sessionType
        self.audioEngine = audioEngine ?? AudioEngineFactory.makeEngine()
        self.announcer = announcer
        self.clock = clock
    }

    // MARK: Internal

    // MARK: - Session Phase

    enum SessionPhase: Equatable {
        case training
        case paused
        case completed
    }

    struct Feedback: Equatable {
        let wasCorrect: Bool
        let expectedWord: String
        let userAnswer: String
    }

    // MARK: - Published State

    @Published var phase: SessionPhase = .training
    @Published var isPlaying: Bool = false
    @Published private(set) var wordStats: [String: WordStat] = [:]

    /// Session attempt counter with invariant enforcement.
    let counter = SessionCounter()

    // Training state
    @Published var currentWord: String = ""
    @Published var userInput: String = ""
    @Published var lastFeedback: Feedback?
    @Published var isWaitingForResponse: Bool = false
    @Published var responseTimeRemaining: TimeInterval = 0

    // Send mode state
    @Published var currentPattern: String = ""
    @Published var inputTimeRemaining: TimeInterval = 0
    @Published var timerCycleId: Int = 0

    // MARK: - Configuration

    let vocabularySet: VocabularySet
    let sessionType: SessionType
    let minimumAttempts: Int = 10

    /// Input timeout for send mode (time to complete keying)
    let inputTimeout: TimeInterval = 2.0

    /// Keyer for morse input timing. Internal for test access.
    var keyer: IambicKeyer?

    /// Response timeout scales with word length
    var responseTimeout: TimeInterval {
        // Base 3 seconds + 1 second per character
        3.0 + Double(currentWord.count)
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

    var inputProgress: Double {
        guard inputTimeout > 0 else { return 0 }
        return inputTimeRemaining / inputTimeout
    }

    var isReceiveMode: Bool {
        sessionType.baseType == .receive
    }

    var progressText: String {
        "\(counter.attempts)/\(minimumAttempts) words"
    }

    func configure(progressStore: ProgressStore, settingsStore: SettingsStore) {
        self.progressStore = progressStore
        self.settingsStore = settingsStore
        audioEngine.setFrequency(settingsStore.settings.toneFrequency)
        audioEngine.setEffectiveSpeed(settingsStore.settings.effectiveSpeed)
        audioEngine.configureBandConditions(from: settingsStore.settings)

        // Merge existing word stats
        wordStats = progressStore.progress.wordStats

        // Setup keyer for send mode
        if !isReceiveMode {
            setupKeyer(from: settingsStore.settings)
        }
    }

    // MARK: - Session Control

    func startSession() {
        // Clear any existing paused session since we're starting fresh
        progressStore?.clearPausedSession(for: sessionType)

        audioEngine.startSession()
        sessionStartTime = Date()
        isPlaying = true
        phase = .training
        // Start keyer for send mode
        if !isReceiveMode {
            keyer?.start()
        }
        showNextWord()
    }

    func pause() {
        guard phase == .training else { return }
        isPlaying = false
        phase = .paused
        responseTimer?.invalidate()
        inputTimer?.invalidate()
        keyer?.stop()
        audioEngine.stop()
        try? audioEngine.stopRadio()
        isWaitingForResponse = false
        announcer.announcePaused()

        // Save paused session snapshot only if there's actual progress
        if counter.attempts > 0, let snapshot = createPausedSessionSnapshot() {
            progressStore?.savePausedSession(snapshot)
        }
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .training
        isPlaying = true
        announcer.announceResumed()
        try? audioEngine.stopRadio()
        try? audioEngine.startReceiving()
        // Re-setup and start keyer for send mode
        if !isReceiveMode, let settings = settingsStore?.settings {
            setupKeyer(from: settings)
            keyer?.start()
        }
        showNextWord()
    }

    // MARK: - Paused Session Management

    /// Create a snapshot of the current session state for persistence
    func createPausedSessionSnapshot() -> PausedSession? {
        guard let startTime = sessionStartTime else { return nil }

        return PausedSession(
            sessionType: sessionType,
            startTime: startTime,
            pausedAt: Date(),
            correctCount: counter.correct,
            totalAttempts: counter.attempts,
            vocabularySetId: vocabularySet.id,
            wordStats: wordStats
        )
    }

    /// Restore session state from a paused session snapshot
    func restoreFromPausedSession(_ session: PausedSession) {
        // Validate vocabulary set matches
        guard session.vocabularySetId == vocabularySet.id else {
            // Session was for a different vocabulary set, start fresh
            startSession()
            return
        }

        sessionStartTime = session.startTime
        counter.restore(correct: session.correctCount, attempts: session.totalAttempts)

        // Restore word stats
        if let savedWordStats = session.wordStats {
            wordStats = savedWordStats
        }

        phase = .paused
        isPlaying = false
    }

    func endSession() {
        isPlaying = false
        responseTimer?.invalidate()
        inputTimer?.invalidate()
        keyer?.stop()
        audioEngine.stop()
        isWaitingForResponse = false

        // Clear any paused session since we're ending
        progressStore?.clearPausedSession(for: sessionType)

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

        // Announce completion for VoiceOver
        announcer.announceSessionComplete(accuracy: accuracyPercentage)

        phase = .completed
    }

    func cleanup() {
        isPlaying = false
        responseTimer?.invalidate()
        responseTimer = nil
        inputTimer?.invalidate()
        inputTimer = nil
        keyer?.stop()
        keyer = nil
        audioEngine.endSession()
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
            queueElement(.dit)
        } else if keyLower == "-" || keyLower == "j" {
            queueElement(.dah)
        } else if keyLower == " " {
            // Space advances to next character in word
            advanceToNextCharacter()
        }
    }

    /// Queue a discrete element for playback with proper timing.
    func queueElement(_ element: MorseElement) {
        guard isPlaying, isWaitingForResponse else { return }
        keyer?.queueElement(element)
        // Sync pattern from keyer for UI feedback
        if let keyerPattern = keyer?.currentPattern {
            currentPattern = keyerPattern
        }
        resetInputTimer()
    }

    /// Update paddle state for continuous iambic keying.
    func updatePaddle(dit: Bool, dah: Bool) {
        guard isPlaying, isWaitingForResponse else { return }
        keyer?.updatePaddle(PaddleInput(ditPressed: dit, dahPressed: dah))
        if let keyerPattern = keyer?.currentPattern {
            currentPattern = keyerPattern
        }
    }

    // MARK: Private

    // MARK: - Dependencies

    private let audioEngine: AudioEngineProtocol
    private let announcer: AccessibilityAnnouncer
    private let clock: KeyerClock
    private let decoder = MorseDecoder()
    private let hapticManager = HapticManager()
    private var progressStore: ProgressStore?
    private var settingsStore: SettingsStore?

    // MARK: - Internal State

    private var responseTimer: Timer?
    private var inputTimer: Timer?
    private var sessionStartTime: Date?
    private var recentWords: [String] = []
    private var currentCharIndex: Int = 0

    private func setupKeyer(from settings: AppSettings) {
        let config = KeyerConfiguration(
            wpm: settings.keyerWPM,
            frequency: settings.keyerFrequency,
            hapticEnabled: settings.keyerHapticEnabled
        )

        keyer = IambicKeyer(
            configuration: config,
            clock: clock,
            onToneStart: { [weak self] frequency in
                guard let self else { return }
                do {
                    try audioEngine.activateTone(frequency: frequency)
                } catch {
                    // Radio not in transmit mode, ignore
                }
            },
            onToneStop: { [weak self] in
                self?.audioEngine.deactivateTone()
            },
            onPatternComplete: { [weak self] pattern in
                guard let self else { return }
                Task { @MainActor in
                    self.handleKeyerPatternComplete(pattern)
                }
            },
            onHaptic: { [weak self] element in
                self?.hapticManager.playHaptic(for: element)
            }
        )
    }

    private func handleKeyerPatternComplete(_ pattern: String) {
        guard isWaitingForResponse else { return }
        currentPattern = pattern
        // In vocabulary send mode, pattern complete advances to next character
        advanceToNextCharacter()
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
        // Increment cycle ID first - causes view recreation (destroys in-flight animation)
        timerCycleId += 1

        inputTimeRemaining = inputTimeout

        inputTimer?.invalidate()
        // Single-fire timer for timeout detection only
        inputTimer = Timer.scheduledTimer(withTimeInterval: inputTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleInputTimeout()
            }
        }

        // Yield to event loop so SwiftUI creates new view seeing inputTimeRemaining = full
        // Then animate countdown from full to zero on the NEW view (no in-flight animation)
        Task { @MainActor in
            withAnimation(.linear(duration: inputTimeout)) {
                inputTimeRemaining = 0
            }
        }
    }

    private func handleInputTimeout() {
        guard isWaitingForResponse else { return }
        inputTimer?.invalidate()
        advanceToNextCharacter()
    }
}

// MARK: - Private Helpers

extension VocabularyTrainingViewModel {
    func showNextWord() {
        guard isPlaying else { return }

        let combinedStats = mergeWordStats()
        guard let nextWord = VocabularyGroupGenerator.selectNextWord(
            from: vocabularySet, wordStats: combinedStats, sessionType: sessionType, avoiding: recentWords
        ) else { endSession()
            return
        }

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
        // Increment cycle ID first - causes view recreation (destroys in-flight animation)
        timerCycleId += 1

        isWaitingForResponse = true
        responseTimeRemaining = responseTimeout

        responseTimer?.invalidate()
        // Single-fire timer for timeout detection only
        responseTimer = Timer.scheduledTimer(withTimeInterval: responseTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.handleResponseTimeout() }
        }

        // Yield to event loop so SwiftUI creates new view seeing responseTimeRemaining = full
        // Then animate countdown from full to zero on the NEW view (no in-flight animation)
        Task { @MainActor in
            withAnimation(.linear(duration: responseTimeout)) {
                responseTimeRemaining = 0
            }
        }
    }

    private func handleResponseTimeout() {
        guard isWaitingForResponse else { return }
        responseTimer?.invalidate()
        isWaitingForResponse = false
        recordResponse(expected: currentWord, wasCorrect: false, userAnswer: "")
        showFeedbackAndContinue(wasCorrect: false, expected: currentWord, userAnswer: "(timeout)")
    }

    func recordResponse(expected: String, wasCorrect: Bool, userAnswer: String) {
        counter.recordAttempt(wasCorrect: wasCorrect)

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

        // Announce feedback for VoiceOver
        if wasCorrect {
            announcer.announceCorrectWord()
        } else {
            announcer.announceIncorrectWord(expected: expected, userEntered: userAnswer)
        }

        Task {
            if !wasCorrect {
                try? await Task.sleep(nanoseconds: TrainingTiming.preReplayDelay)
                if let engine = audioEngine as? MorseAudioEngine, isPlaying { await engine.playGroup(expected) }
                try? await Task.sleep(nanoseconds: TrainingTiming.postReplayDelay)
            } else {
                try? await Task.sleep(nanoseconds: TrainingTiming.correctAnswerDelay)
            }

            if counter.attempts >= minimumAttempts {
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

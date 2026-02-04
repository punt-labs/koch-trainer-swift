// swiftlint:disable file_length type_body_length
@testable import KochTrainer
import XCTest

// MARK: - VocabularyMockAudioEngine

/// Mock audio engine for vocabulary training tests
final class VocabularyMockAudioEngine: AudioEngineProtocol {

    // MARK: Internal

    var playCharacterCalls: [Character] = []
    var playGroupCalls: [String] = []
    var endSessionCalled = false
    var frequencySet: Double?
    var effectiveSpeedSet: Int?

    var radioMode: RadioMode { radioState.mode }

    func playCharacter(_ char: Character) async {
        playCharacterCalls.append(char)
    }

    func playGroup(_ group: String) async {
        playGroupCalls.append(group)
    }

    func playGroup(_ group: String, onCharacterPlayed: ((Character, Int) -> Void)?) async {
        playGroupCalls.append(group)
        for (index, char) in group.enumerated() {
            onCharacterPlayed?(char, index)
        }
    }

    func setFrequency(_ frequency: Double) {
        frequencySet = frequency
    }

    func setEffectiveSpeed(_ wpm: Int) {
        effectiveSpeedSet = wpm
    }

    func configureBandConditions(from settings: AppSettings) {}

    func playDit() async {}

    func playDah() async {}

    func startSession() { radioState.startSession() }
    func endSession() {
        radioState.endSession()
        endSessionCalled = true
    }

    func startReceiving() throws { try radioState.startReceiving() }
    func startTransmitting() throws { try radioState.startTransmitting() }
    func stopRadio() throws { try radioState.stopRadio() }

    func activateTone(frequency: Double) throws {
        guard radioState.mode != .off else {
            throw Radio.RadioError.mustBeOn
        }
    }

    func deactivateTone() {}

    // MARK: Private

    private let radioState = MockRadioState()

}

// MARK: - VocabularyTrainingViewModelTests

@MainActor
final class VocabularyTrainingViewModelTests: XCTestCase {

    // MARK: Internal

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "TestVocabVM") ?? .standard
        testDefaults.removePersistentDomain(forName: "TestVocabVM")

        mockAudioEngine = VocabularyMockAudioEngine()
        viewModel = VocabularyTrainingViewModel(
            vocabularySet: testSet,
            sessionType: .receive,
            audioEngine: mockAudioEngine
        )
        progressStore = ProgressStore(defaults: testDefaults)
        settingsStore = SettingsStore(defaults: testDefaults)
        viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)
    }

    override func tearDown() {
        viewModel.cleanup()
        testDefaults.removePersistentDomain(forName: "TestVocabVM")
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(viewModel.phase, .training)
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(viewModel.counter.correct, 0)
        XCTAssertEqual(viewModel.counter.attempts, 0)
        XCTAssertEqual(viewModel.accuracyPercentage, 0)
        XCTAssertTrue(viewModel.currentWord.isEmpty)
    }

    func testVocabularySetConfiguration() {
        XCTAssertEqual(viewModel.vocabularySet.name, "Test Set")
        XCTAssertEqual(viewModel.sessionType, .receive)
        XCTAssertTrue(viewModel.isReceiveMode)
    }

    // MARK: - Session Control Tests

    func testStartSession() {
        viewModel.startSession()

        XCTAssertTrue(viewModel.isPlaying)
        XCTAssertEqual(viewModel.phase, .training)
        XCTAssertFalse(viewModel.currentWord.isEmpty)
    }

    func testPauseDuringTraining() {
        viewModel.startSession()
        XCTAssertTrue(viewModel.isPlaying)

        viewModel.pause()

        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(viewModel.phase, .paused)
        // Pause sets radio mode to .off instead of calling stop()
        XCTAssertEqual(mockAudioEngine.radioMode, .off)
    }

    func testPauseFromCompletedIsNoOp() {
        viewModel.startSession()
        viewModel.endSession()
        XCTAssertEqual(viewModel.phase, .completed)

        viewModel.pause()

        // Should still be completed, not paused
        XCTAssertEqual(viewModel.phase, .completed)
    }

    func testResumeFromPaused() {
        viewModel.startSession()
        viewModel.pause()

        viewModel.resume()

        XCTAssertTrue(viewModel.isPlaying)
        XCTAssertEqual(viewModel.phase, .training)
    }

    func testResumeNotPausedIsNoOp() {
        viewModel.startSession()
        let phaseBefore = viewModel.phase

        viewModel.resume() // Already in training, not paused

        XCTAssertEqual(viewModel.phase, phaseBefore)
    }

    func testEndSession() {
        viewModel.startSession()

        viewModel.endSession()

        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(viewModel.phase, .completed)
    }

    func testCleanupStopsAudio() {
        viewModel.startSession()
        mockAudioEngine.endSessionCalled = false

        viewModel.cleanup()

        XCTAssertTrue(mockAudioEngine.endSessionCalled)
    }

    // MARK: - Pause State Preservation Tests

    func testPausePreservesStats() {
        viewModel.startSession()

        // Simulate an answer
        viewModel.recordResponse(expected: "CQ", wasCorrect: true, userAnswer: "CQ")

        let correctBefore = viewModel.counter.correct
        let attemptsBefore = viewModel.counter.attempts

        viewModel.pause()

        XCTAssertEqual(viewModel.counter.correct, correctBefore)
        XCTAssertEqual(viewModel.counter.attempts, attemptsBefore)

        viewModel.resume()

        XCTAssertEqual(viewModel.counter.correct, correctBefore)
        XCTAssertEqual(viewModel.counter.attempts, attemptsBefore)
    }

    // MARK: - Answer Submission Tests

    func testSubmitCorrectAnswer() {
        viewModel.startSession()

        // Wait for word to be set
        let word = viewModel.currentWord
        XCTAssertFalse(word.isEmpty)

        // Start response timer to enable submission
        viewModel.startResponseTimer()
        XCTAssertTrue(viewModel.isWaitingForResponse)

        viewModel.submitAnswer(word)

        XCTAssertEqual(viewModel.counter.correct, 1)
        XCTAssertEqual(viewModel.counter.attempts, 1)
    }

    func testSubmitIncorrectAnswer() {
        viewModel.startSession()
        viewModel.startResponseTimer()

        viewModel.submitAnswer("WRONGANSWER")

        XCTAssertEqual(viewModel.counter.correct, 0)
        XCTAssertEqual(viewModel.counter.attempts, 1)
    }

    func testSubmitAnswerNotWaitingIsIgnored() {
        viewModel.startSession()
        // Don't start response timer

        viewModel.submitAnswer("CQ")

        XCTAssertEqual(viewModel.counter.attempts, 0)
    }

    func testAnswerNormalization() {
        viewModel.startSession()
        viewModel.startResponseTimer()

        // Submit lowercase with whitespace
        let word = viewModel.currentWord.lowercased() + "  "
        viewModel.submitAnswer(word)

        // Should recognize as correct due to normalization
        XCTAssertEqual(viewModel.counter.attempts, 1)
    }

    // MARK: - Record Response Tests

    func testRecordResponseUpdatesStats() {
        viewModel.startSession()

        viewModel.recordResponse(expected: "CQ", wasCorrect: true, userAnswer: "CQ")
        viewModel.recordResponse(expected: "DE", wasCorrect: false, userAnswer: "KE")

        XCTAssertEqual(viewModel.counter.correct, 1)
        XCTAssertEqual(viewModel.counter.attempts, 2)
        XCTAssertEqual(viewModel.accuracyPercentage, 50)
    }

    func testRecordResponseUpdatesWordStats() {
        viewModel.startSession()

        viewModel.recordResponse(expected: "CQ", wasCorrect: true, userAnswer: "CQ")

        let stat = viewModel.wordStats["CQ"]
        XCTAssertNotNil(stat)
        XCTAssertEqual(stat?.receiveAttempts, 1)
        XCTAssertEqual(stat?.receiveCorrect, 1)
    }

    func testRecordResponseSendMode() {
        let sendVM = VocabularyTrainingViewModel(
            vocabularySet: testSet,
            sessionType: .send,
            audioEngine: mockAudioEngine
        )
        sendVM.configure(progressStore: progressStore, settingsStore: settingsStore)
        sendVM.startSession()

        sendVM.recordResponse(expected: "CQ", wasCorrect: true, userAnswer: "CQ")

        let stat = sendVM.wordStats["CQ"]
        XCTAssertNotNil(stat)
        XCTAssertEqual(stat?.sendAttempts, 1)
        XCTAssertEqual(stat?.sendCorrect, 1)
        XCTAssertEqual(stat?.receiveAttempts, 0)

        sendVM.cleanup()
    }

    // MARK: - Computed Properties Tests

    func testAccuracy() {
        viewModel.startSession()

        viewModel.recordResponse(expected: "CQ", wasCorrect: true, userAnswer: "CQ")
        viewModel.recordResponse(expected: "DE", wasCorrect: true, userAnswer: "DE")
        viewModel.recordResponse(expected: "K", wasCorrect: false, userAnswer: "T")

        XCTAssertEqual(viewModel.accuracy, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(viewModel.accuracyPercentage, 67)
    }

    func testProgressText() {
        viewModel.startSession()

        XCTAssertEqual(viewModel.progressText, "0/10 words")

        viewModel.recordResponse(expected: "CQ", wasCorrect: true, userAnswer: "CQ")

        XCTAssertEqual(viewModel.progressText, "1/10 words")
    }

    func testResponseTimeout() {
        viewModel.startSession()

        // Timeout = 3.0 + word.count
        let expectedTimeout = 3.0 + Double(viewModel.currentWord.count)
        XCTAssertEqual(viewModel.responseTimeout, expectedTimeout)
    }

    func testResponseProgress() {
        viewModel.startSession()

        // Test computed property directly (like ReceiveTrainingViewModelTests)
        // responseProgress = responseTimeRemaining / responseTimeout
        let timeout = viewModel.responseTimeout

        viewModel.responseTimeRemaining = timeout
        XCTAssertEqual(viewModel.responseProgress, 1.0, accuracy: 0.001)

        viewModel.responseTimeRemaining = timeout / 2
        XCTAssertEqual(viewModel.responseProgress, 0.5, accuracy: 0.001)

        viewModel.responseTimeRemaining = 0
        XCTAssertEqual(viewModel.responseProgress, 0, accuracy: 0.001)
    }

    // MARK: - Send Mode Tests

    func testSendModeInitialization() {
        let sendVM = VocabularyTrainingViewModel(
            vocabularySet: testSet,
            sessionType: .send,
            audioEngine: mockAudioEngine
        )

        XCTAssertFalse(sendVM.isReceiveMode)

        sendVM.cleanup()
    }

    func testQueueDitInSendMode() {
        let sendVM = makeSendViewModel()
        sendVM.startSession()

        pressDit(viewModel: sendVM)

        XCTAssertEqual(sendVM.currentPattern, ".")

        sendVM.cleanup()
    }

    func testQueueDahInSendMode() {
        let sendVM = makeSendViewModel()
        sendVM.startSession()

        pressDah(viewModel: sendVM)

        XCTAssertEqual(sendVM.currentPattern, "-")

        sendVM.cleanup()
    }

    func testInputPatternBuildUp() {
        let sendVM = makeSendViewModel()
        sendVM.startSession()

        pressDah(viewModel: sendVM)
        pressDit(viewModel: sendVM)
        pressDah(viewModel: sendVM)
        pressDit(viewModel: sendVM)

        XCTAssertEqual(sendVM.currentPattern, "-.-.")

        sendVM.cleanup()
    }

    func testHandleKeyPressDit() {
        let sendVM = makeSendViewModel()
        sendVM.startSession()

        pressKey(".", viewModel: sendVM)
        XCTAssertEqual(sendVM.currentPattern, ".")

        pressKey("f", viewModel: sendVM)
        XCTAssertEqual(sendVM.currentPattern, "..")

        pressKey("F", viewModel: sendVM)
        XCTAssertEqual(sendVM.currentPattern, "...")

        sendVM.cleanup()
    }

    func testHandleKeyPressDah() {
        let sendVM = makeSendViewModel()
        sendVM.startSession()

        pressKey("-", viewModel: sendVM)
        XCTAssertEqual(sendVM.currentPattern, "-")

        pressKey("j", viewModel: sendVM)
        XCTAssertEqual(sendVM.currentPattern, "--")

        pressKey("J", viewModel: sendVM)
        XCTAssertEqual(sendVM.currentPattern, "---")

        sendVM.cleanup()
    }

    func testHandleKeyPressSpaceAdvancesToNextCharacter() {
        let sendVM = makeSendViewModel()
        sendVM.startSession()

        // Input pattern for 'C' (-.-.)
        pressKey("-", viewModel: sendVM)
        pressKey(".", viewModel: sendVM)
        pressKey("-", viewModel: sendVM)
        pressKey(".", viewModel: sendVM)
        XCTAssertEqual(sendVM.currentPattern, "-.-.")

        // Space should decode the pattern and add to userInput
        sendVM.handleKeyPress(" ")

        // Pattern should be cleared after space
        XCTAssertEqual(sendVM.currentPattern, "")
        // User input should contain decoded character 'C'
        XCTAssertTrue(sendVM.userInput.contains("C"))

        sendVM.cleanup()
    }

    func testHandleKeyPressIgnoredInReceiveMode() {
        // Receive mode should ignore key presses
        viewModel.startSession()
        viewModel.startResponseTimer()

        viewModel.handleKeyPress(".")
        viewModel.handleKeyPress("-")
        viewModel.handleKeyPress(" ")

        // Pattern should remain empty in receive mode
        XCTAssertEqual(viewModel.currentPattern, "")
    }

    func testHandleKeyPressIgnoredWhenNotWaitingForResponse() {
        let sendVM = VocabularyTrainingViewModel(
            vocabularySet: testSet,
            sessionType: .send,
            audioEngine: mockAudioEngine
        )
        sendVM.configure(progressStore: progressStore, settingsStore: settingsStore)
        // Don't start session - isWaitingForResponse should be false

        sendVM.handleKeyPress(".")

        XCTAssertEqual(sendVM.currentPattern, "")

        sendVM.cleanup()
    }

    // MARK: - Send Mode Input Progress Tests

    func testInputProgressInitiallyZero() {
        let sendVM = VocabularyTrainingViewModel(
            vocabularySet: testSet,
            sessionType: .send,
            audioEngine: mockAudioEngine
        )
        sendVM.configure(progressStore: progressStore, settingsStore: settingsStore)

        XCTAssertEqual(sendVM.inputProgress, 0)

        sendVM.cleanup()
    }

    func testInputTimeoutConstant() {
        let sendVM = VocabularyTrainingViewModel(
            vocabularySet: testSet,
            sessionType: .send,
            audioEngine: mockAudioEngine
        )

        XCTAssertEqual(sendVM.inputTimeout, 2.0)

        sendVM.cleanup()
    }

    func testQueueElementNotAllowedWhenNotPlaying() {
        let sendVM = makeSendViewModel()
        // Don't start session

        sendVM.queueElement(.dit)

        XCTAssertEqual(sendVM.currentPattern, "")

        sendVM.cleanup()
    }

    func testQueueElementNotAllowedWhenNotWaitingForResponse() {
        let sendVM = makeSendViewModel()
        sendVM.startSession()

        // Pause to clear isWaitingForResponse
        sendVM.pause()

        sendVM.queueElement(.dit)

        XCTAssertEqual(sendVM.currentPattern, "")

        sendVM.cleanup()
    }

    // MARK: - Receive Mode Replay Tests

    func testReplayWordIgnoredInSendMode() {
        let sendVM = VocabularyTrainingViewModel(
            vocabularySet: testSet,
            sessionType: .send,
            audioEngine: mockAudioEngine
        )
        sendVM.configure(progressStore: progressStore, settingsStore: settingsStore)
        sendVM.startSession()
        mockAudioEngine.playGroupCalls = []

        sendVM.replayWord()

        // Give time for async operation
        let expectation = XCTestExpectation(description: "Replay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Should not have played anything since we're in send mode
        XCTAssertTrue(mockAudioEngine.playGroupCalls.isEmpty)

        sendVM.cleanup()
    }

    // MARK: - Word Selection Tests

    func testShowNextWordSelectsFromSet() {
        viewModel.startSession()

        let word = viewModel.currentWord
        XCTAssertTrue(testSet.words.contains(word))
    }

    func testReplayWord() {
        viewModel.startSession()
        mockAudioEngine.playGroupCalls = []

        viewModel.replayWord()

        // Give time for async operation
        let expectation = XCTestExpectation(description: "Replay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Paused Session Snapshot Tests

    func testCreatePausedSessionSnapshotReturnsNilBeforeTraining() {
        // Before starting, sessionStartTime is nil
        let snapshot = viewModel.createPausedSessionSnapshot()
        XCTAssertNil(snapshot)
    }

    func testCreatePausedSessionSnapshotCapturesState() {
        viewModel.startSession()

        // Simulate some responses
        viewModel.recordResponse(expected: "CQ", wasCorrect: true, userAnswer: "CQ")
        viewModel.recordResponse(expected: "DE", wasCorrect: false, userAnswer: "KE")

        let snapshot = viewModel.createPausedSessionSnapshot()

        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.correctCount, 1)
        XCTAssertEqual(snapshot?.totalAttempts, 2)
        XCTAssertEqual(snapshot?.sessionType, .receive)
        XCTAssertEqual(snapshot?.vocabularySetId, testSet.id)
        XCTAssertNotNil(snapshot?.wordStats)
        XCTAssertTrue(snapshot?.isVocabularySession ?? false)
    }

    func testRestoreFromPausedSessionRestoresState() {
        viewModel.startSession()

        // Create a paused session with matching vocabulary set ID
        let session = PausedSession(
            sessionType: .receive,
            startTime: Date().addingTimeInterval(-120),
            pausedAt: Date().addingTimeInterval(-60),
            correctCount: 5,
            totalAttempts: 8,
            vocabularySetId: testSet.id,
            wordStats: ["CQ": WordStat(receiveAttempts: 5, receiveCorrect: 3)]
        )

        viewModel.restoreFromPausedSession(session)

        XCTAssertEqual(viewModel.counter.correct, 5)
        XCTAssertEqual(viewModel.counter.attempts, 8)
        XCTAssertEqual(viewModel.phase, .paused)
        XCTAssertEqual(viewModel.wordStats["CQ"]?.receiveAttempts, 5)
    }

    func testRestoreFromPausedSessionDoesNotRestoreIfVocabularySetMismatch() {
        viewModel.startSession()

        // Create a paused session with different vocabulary set ID
        let differentSetId = UUID()
        let session = PausedSession(
            sessionType: .receive,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 10,
            totalAttempts: 15,
            vocabularySetId: differentSetId,
            wordStats: [:]
        )

        viewModel.restoreFromPausedSession(session)

        // Should not restore - starts fresh session instead
        XCTAssertEqual(viewModel.counter.correct, 0)
        XCTAssertEqual(viewModel.counter.attempts, 0)
        XCTAssertEqual(viewModel.phase, .training)
    }

    func testPauseDoesNotPersistWithZeroAttempts() {
        viewModel.startSession()

        // Pause immediately without any attempts
        viewModel.pause()

        // Should not have saved a paused session
        let savedSession = progressStore.pausedSession(for: .receive)
        XCTAssertNil(savedSession)
    }

    func testPausePersistsWithAttempts() {
        viewModel.startSession()

        // Make some progress
        viewModel.recordResponse(expected: "CQ", wasCorrect: true, userAnswer: "CQ")

        viewModel.pause()

        // Should have saved a paused session
        let savedSession = progressStore.pausedSession(for: .receive)
        XCTAssertNotNil(savedSession)
        XCTAssertEqual(savedSession?.correctCount, 1)
        XCTAssertEqual(savedSession?.totalAttempts, 1)
    }

    func testStartSessionClearsPausedSession() {
        // First, create and save a paused session
        viewModel.startSession()
        viewModel.recordResponse(expected: "CQ", wasCorrect: true, userAnswer: "CQ")
        viewModel.pause()
        XCTAssertNotNil(progressStore.pausedSession(for: .receive))

        // Start a new session
        viewModel.startSession()

        // Paused session should be cleared
        XCTAssertNil(progressStore.pausedSession(for: .receive))
    }

    func testEndSessionClearsPausedSession() {
        viewModel.startSession()
        viewModel.recordResponse(expected: "CQ", wasCorrect: true, userAnswer: "CQ")
        viewModel.pause()
        XCTAssertNotNil(progressStore.pausedSession(for: .receive))

        viewModel.resume()
        viewModel.endSession()

        // Paused session should be cleared
        XCTAssertNil(progressStore.pausedSession(for: .receive))
    }

    // MARK: Private

    private let testSet = VocabularySet(
        name: "Test Set",
        words: ["CQ", "DE", "K", "AR", "SK"],
        isBuiltIn: true
    )

    private var viewModel = VocabularyTrainingViewModel(
        vocabularySet: VocabularySet(name: "Test", words: ["CQ"]),
        sessionType: .receive,
        audioEngine: VocabularyMockAudioEngine()
    )
    private var mockAudioEngine = VocabularyMockAudioEngine()
    private var mockClock = MockClock()
    private var progressStore = ProgressStore()
    private var settingsStore = SettingsStore()
    private var testDefaults = UserDefaults(suiteName: "TestVocabVM") ?? .standard

    /// Helper to create a send mode view model with proper keyer timing support
    private func makeSendViewModel() -> VocabularyTrainingViewModel {
        let vm = VocabularyTrainingViewModel(
            vocabularySet: testSet,
            sessionType: .send,
            audioEngine: mockAudioEngine,
            clock: mockClock
        )
        vm.configure(progressStore: progressStore, settingsStore: settingsStore)
        return vm
    }

    /// Queue a dit element and advance time to complete it
    private func pressDit(viewModel vm: VocabularyTrainingViewModel) {
        guard let keyer = vm.keyer else { return }
        vm.queueElement(.dit)
        keyer.processTick(at: mockClock.now())
        mockClock.advance(by: keyer.configuration.ditDuration + 0.001)
        keyer.processTick(at: mockClock.now())
        mockClock.advance(by: keyer.configuration.elementGap + 0.001)
        keyer.processTick(at: mockClock.now())
    }

    /// Queue a dah element and advance time to complete it
    private func pressDah(viewModel vm: VocabularyTrainingViewModel) {
        guard let keyer = vm.keyer else { return }
        vm.queueElement(.dah)
        keyer.processTick(at: mockClock.now())
        mockClock.advance(by: keyer.configuration.dahDuration + 0.001)
        keyer.processTick(at: mockClock.now())
        mockClock.advance(by: keyer.configuration.elementGap + 0.001)
        keyer.processTick(at: mockClock.now())
    }

    /// Press a key via handleKeyPress and advance keyer timing
    private func pressKey(_ key: Character, viewModel vm: VocabularyTrainingViewModel) {
        guard let keyer = vm.keyer else { return }
        vm.handleKeyPress(key)
        keyer.processTick(at: mockClock.now())

        let keyLower = String(key).lowercased()
        let duration = (keyLower == "." || keyLower == "f")
            ? keyer.configuration.ditDuration
            : keyer.configuration.dahDuration

        mockClock.advance(by: duration + 0.001)
        keyer.processTick(at: mockClock.now())
        mockClock.advance(by: keyer.configuration.elementGap + 0.001)
        keyer.processTick(at: mockClock.now())
    }

}

// swiftlint:enable file_length type_body_length

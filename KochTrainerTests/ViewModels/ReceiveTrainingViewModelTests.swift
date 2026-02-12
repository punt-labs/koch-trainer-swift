// swiftlint:disable type_body_length
@testable import KochTrainer
import XCTest

// MARK: - MockAudioEngine

/// Mock audio engine for testing without actual audio playback.
final class MockAudioEngine: AudioEngineProtocol {

    // MARK: Internal

    var playCharacterCalls: [Character] = []
    var playGroupCalls: [String] = []
    var stopCalled = false
    var endSessionCalled = false
    var frequencySet: Double?
    var effectiveSpeedSet: Int?

    var radioMode: RadioMode {
        radioState.mode
    }

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

    func stop() {
        stopCalled = true
    }

    func setFrequency(_ frequency: Double) {
        frequencySet = frequency
    }

    func setEffectiveSpeed(_ wpm: Int) {
        effectiveSpeedSet = wpm
    }

    func configureBandConditions(from settings: AppSettings) {
        // No-op for testing
    }

    func reset() {
        playCharacterCalls = []
        playGroupCalls = []
        stopCalled = false
    }

    func playDit() async {
        // No-op for testing
    }

    func playDah() async {
        // No-op for testing
    }

    func startSession() {
        radioState.startSession()
    }

    func endSession() {
        radioState.endSession()
        endSessionCalled = true
    }

    func startReceiving() throws {
        try radioState.startReceiving()
    }

    func startTransmitting() throws {
        try radioState.startTransmitting()
    }

    func stopRadio() throws {
        try radioState.stopRadio()
    }

    // MARK: Private

    private let radioState = MockRadioState()

}

// MARK: - ReceiveTrainingViewModelTests

@MainActor
final class ReceiveTrainingViewModelTests: XCTestCase {

    // MARK: Internal

    override func setUp() async throws {
        mockAudioEngine = MockAudioEngine()
        viewModel = ReceiveTrainingViewModel(audioEngine: mockAudioEngine)
        progressStore = ProgressStore()
        settingsStore = SettingsStore()
        viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)
    }

    override func tearDown() async throws {
        viewModel.cleanup()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        let vm = ReceiveTrainingViewModel(audioEngine: MockAudioEngine())

        XCTAssertEqual(vm.phase, .introduction(characterIndex: 0))
        XCTAssertEqual(vm.timeRemaining, 300)
        XCTAssertFalse(vm.isPlaying)
        XCTAssertEqual(vm.counter.correct, 0)
        XCTAssertEqual(vm.counter.attempts, 0)
        XCTAssertTrue(vm.characterStats.isEmpty)
        XCTAssertNil(vm.currentCharacter)
        XCTAssertNil(vm.lastFeedback)
        XCTAssertFalse(vm.isWaitingForResponse)
    }

    func testConfigureWithProgressAndSettings() {
        XCTAssertFalse(viewModel.introCharacters.isEmpty)
        XCTAssertEqual(mockAudioEngine.frequencySet, settingsStore.settings.toneFrequency)
        XCTAssertEqual(mockAudioEngine.effectiveSpeedSet, settingsStore.settings.effectiveSpeed)
    }

    func testConfigureWithCustomCharacters() {
        let customChars: [Character] = ["A", "B", "C"]
        let vm = ReceiveTrainingViewModel(audioEngine: MockAudioEngine())
        vm.configure(progressStore: progressStore, settingsStore: settingsStore, customCharacters: customChars)

        XCTAssertEqual(vm.introCharacters, customChars)
        XCTAssertTrue(vm.isCustomSession)
    }

    func testIsCustomSessionFalseForNormalSession() {
        XCTAssertFalse(viewModel.isCustomSession)
    }

    // MARK: - Computed Properties Tests

    func testFormattedTime() {
        viewModel.timeRemaining = 125 // 2:05
        XCTAssertEqual(viewModel.formattedTime, "2:05")

        viewModel.timeRemaining = 60 // 1:00
        XCTAssertEqual(viewModel.formattedTime, "1:00")

        viewModel.timeRemaining = 0
        XCTAssertEqual(viewModel.formattedTime, "0:00")
    }

    func testAccuracyPercentageWithZeroAttempts() {
        XCTAssertEqual(viewModel.accuracyPercentage, 0)
    }

    func testAccuracyPercentageWithAttempts() {
        viewModel.recordResponse(expected: "K", wasCorrect: true, userPressed: "K")
        viewModel.recordResponse(expected: "M", wasCorrect: true, userPressed: "M")
        viewModel.recordResponse(expected: "R", wasCorrect: false, userPressed: "S")

        // 2/3 = 66.67% rounded to 67%
        XCTAssertEqual(viewModel.accuracyPercentage, 67)
    }

    func testAccuracyDoubleWithZeroAttempts() {
        XCTAssertEqual(viewModel.accuracy, 0)
    }

    func testAccuracyDoubleWithAttempts() {
        viewModel.recordResponse(expected: "K", wasCorrect: true, userPressed: "K")
        viewModel.recordResponse(expected: "M", wasCorrect: false, userPressed: "R")

        XCTAssertEqual(viewModel.accuracy, 0.5, accuracy: 0.001)
    }

    func testTimerDeadlineInitiallyDistantPast() {
        XCTAssertEqual(viewModel.timerDeadline, .distantPast)
        XCTAssertEqual(viewModel.timerDuration, 0)
    }

    func testIntroProgressString() {
        viewModel.startSession()

        // Should be in introduction
        guard case .introduction = viewModel.phase else {
            XCTFail("Expected introduction phase")
            return
        }

        let progress = viewModel.introProgress
        XCTAssertTrue(progress.contains("1 of"))
    }

    func testIntroProgressStringWhenNotInIntro() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        XCTAssertEqual(viewModel.introProgress, "")
    }

    func testIsLastIntroCharacter() {
        viewModel.startSession()

        // Navigate to last intro character
        while case let .introduction(index) = viewModel.phase {
            if index == viewModel.introCharacters.count - 1 {
                XCTAssertTrue(viewModel.isLastIntroCharacter)
                return
            }
            XCTAssertFalse(viewModel.isLastIntroCharacter)
            viewModel.nextIntroCharacter()
        }
    }

    func testIsLastIntroCharacterFalseWhenNotInIntro() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        XCTAssertFalse(viewModel.isLastIntroCharacter)
    }

    func testProficiencyProgressNotEnoughAttempts() {
        viewModel.recordResponse(expected: "K", wasCorrect: true, userPressed: "K")

        let progress = viewModel.proficiencyProgress
        XCTAssertTrue(progress.contains("attempts"))
        XCTAssertTrue(progress.contains("1/"))
    }

    func testProficiencyProgressWithEnoughAttempts() {
        // Record enough attempts to pass minimum
        for _ in 0 ..< viewModel.minimumAttemptsForProficiency {
            viewModel.recordResponse(expected: "K", wasCorrect: true, userPressed: "K")
        }

        let progress = viewModel.proficiencyProgress
        XCTAssertTrue(progress.contains("%"))
        XCTAssertTrue(progress.contains("need"))
    }

    func testMinimumAttemptsForProficiency() {
        // With intro characters, minimum should be 5 * count with floor of 15
        let expected = max(15, 5 * viewModel.introCharacters.count)
        XCTAssertEqual(viewModel.minimumAttemptsForProficiency, expected)
    }

    // MARK: - Introduction Phase Tests

    func testStartIntroductionWithEmptyCharacters() {
        let vm = ReceiveTrainingViewModel(audioEngine: MockAudioEngine())
        // Don't configure - introCharacters will be empty

        vm.startIntroduction()

        // Should skip directly to training
        XCTAssertEqual(vm.phase, .training)
    }

    func testStartIntroductionSetsFirstCharacter() {
        viewModel.startSession()

        guard case let .introduction(index) = viewModel.phase else {
            XCTFail("Expected introduction phase")
            return
        }

        XCTAssertEqual(index, 0)
        XCTAssertEqual(viewModel.currentIntroCharacter, viewModel.introCharacters[0])
    }

    func testNextIntroCharacterAdvances() {
        viewModel.startSession()

        guard case let .introduction(indexBefore) = viewModel.phase else {
            XCTFail("Expected introduction phase")
            return
        }

        viewModel.nextIntroCharacter()

        if viewModel.introCharacters.count > 1 {
            guard case let .introduction(indexAfter) = viewModel.phase else {
                XCTFail("Expected introduction phase after advance")
                return
            }
            XCTAssertEqual(indexAfter, indexBefore + 1)
        }
    }

    func testNextIntroCharacterStartsTrainingAfterLast() {
        viewModel.startSession()

        // Skip through all intro characters
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        XCTAssertEqual(viewModel.phase, .training)
        XCTAssertTrue(viewModel.isPlaying)
    }

    // MARK: - Pause Tests

    func testPauseDuringTrainingTransitionsToPaused() {
        // Start session and skip intro to get to training
        viewModel.startSession()

        // Skip through introduction characters
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Verify we're in training
        guard case .training = viewModel.phase else {
            XCTFail("Expected training phase")
            return
        }

        XCTAssertTrue(viewModel.isPlaying)

        // Pause
        viewModel.pause()

        // Verify paused state
        XCTAssertEqual(viewModel.phase, .paused)
        XCTAssertFalse(viewModel.isPlaying)
        // Pause sets radio mode to .off instead of calling stop()
        XCTAssertEqual(mockAudioEngine.radioMode, .off)
    }

    func testPauseDuringIntroductionIsNoOp() {
        viewModel.startSession()

        // Should be in introduction phase
        guard case .introduction = viewModel.phase else {
            XCTFail("Expected introduction phase")
            return
        }

        // Try to pause
        viewModel.pause()

        // Should still be in introduction
        if case .introduction = viewModel.phase {
            // Expected
        } else {
            XCTFail("Pause should be no-op during introduction")
        }
    }

    func testPauseDuringPausedIsNoOp() {
        // Get to training
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Pause once
        viewModel.pause()
        XCTAssertEqual(viewModel.phase, .paused)

        // Pause again should be no-op
        viewModel.pause()
        XCTAssertEqual(viewModel.phase, .paused)
    }

    // MARK: - Resume Tests

    func testResumeFromPausedTransitionsToTraining() {
        // Get to training and pause
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }
        viewModel.pause()

        XCTAssertEqual(viewModel.phase, .paused)
        XCTAssertFalse(viewModel.isPlaying)

        // Resume
        viewModel.resume()

        // Should be back in training
        XCTAssertEqual(viewModel.phase, .training)
        XCTAssertTrue(viewModel.isPlaying)
    }

    func testResumeFromNonPausedIsNoOp() {
        viewModel.startSession()

        // Should be in introduction
        guard case .introduction = viewModel.phase else {
            XCTFail("Expected introduction phase")
            return
        }

        // Try to resume (should be no-op)
        viewModel.resume()

        // Should still be in introduction
        if case .introduction = viewModel.phase {
            // Expected
        } else {
            XCTFail("Resume should be no-op when not paused")
        }
    }

    // MARK: - State Preservation Tests

    func testPausePreservesSessionStats() async {
        // Get to training
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Wait for character to be presented
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Simulate some responses
        viewModel.handleKeyPress("K")
        try? await Task.sleep(nanoseconds: 100_000_000)

        let correctBefore = viewModel.counter.correct
        let attemptsBefore = viewModel.counter.attempts

        // Pause
        viewModel.pause()

        // Stats should be preserved
        XCTAssertEqual(viewModel.counter.correct, correctBefore)
        XCTAssertEqual(viewModel.counter.attempts, attemptsBefore)

        // Resume
        viewModel.resume()

        // Stats should still be preserved
        XCTAssertEqual(viewModel.counter.correct, correctBefore)
        XCTAssertEqual(viewModel.counter.attempts, attemptsBefore)
    }

    // MARK: - End Session Tests

    func testEndSessionFromTraining() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        viewModel.endSession()

        if case .completed = viewModel.phase {
            // Expected
        } else {
            XCTFail("Expected completed phase after endSession")
        }

        XCTAssertFalse(viewModel.isPlaying)
    }

    func testEndSessionFromPaused() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }
        viewModel.pause()

        viewModel.endSession()

        if case .completed = viewModel.phase {
            // Expected
        } else {
            XCTFail("Expected completed phase after endSession from paused")
        }
    }

    // MARK: - Cleanup Tests

    func testCleanupStopsAudio() {
        viewModel.startSession()
        mockAudioEngine.stopCalled = false

        viewModel.cleanup()

        XCTAssertTrue(mockAudioEngine.endSessionCalled)
    }

    func testCleanupSetsIsPlayingFalse() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        XCTAssertTrue(viewModel.isPlaying)

        viewModel.cleanup()

        XCTAssertFalse(viewModel.isPlaying)
    }

    // MARK: - Paused Session Snapshot Tests

    func testCreatePausedSessionSnapshotReturnsNilBeforeTraining() {
        // Before starting, sessionStartTime is nil
        let snapshot = viewModel.createPausedSessionSnapshot()
        XCTAssertNil(snapshot)
    }

    func testCreatePausedSessionSnapshotCapturesState() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Simulate some responses
        viewModel.recordResponse(expected: "K", wasCorrect: true, userPressed: "K")
        viewModel.recordResponse(expected: "M", wasCorrect: false, userPressed: "R")

        let snapshot = viewModel.createPausedSessionSnapshot()

        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.correctCount, 1)
        XCTAssertEqual(snapshot?.totalAttempts, 2)
        XCTAssertEqual(snapshot?.sessionType, .receive)
        XCTAssertTrue(snapshot?.introCompleted ?? false)
        XCTAssertNil(snapshot?.customCharacters)
    }

    func testCreatePausedSessionSnapshotForCustomSession() {
        let customChars: [Character] = ["A", "B", "C"]
        let vm = ReceiveTrainingViewModel(audioEngine: MockAudioEngine())
        vm.configure(progressStore: progressStore, settingsStore: settingsStore, customCharacters: customChars)
        vm.startSession()
        while case .introduction = vm.phase {
            vm.nextIntroCharacter()
        }

        let snapshot = vm.createPausedSessionSnapshot()

        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.sessionType, .receiveCustom)
        XCTAssertEqual(snapshot?.customCharacters, customChars)
        XCTAssertTrue(snapshot?.isCustomSession ?? false)
    }

    func testRestoreFromPausedSessionRestoresState() {
        // Create a paused session
        let session = PausedSession(
            sessionType: .receive,
            startTime: Date().addingTimeInterval(-120),
            pausedAt: Date().addingTimeInterval(-60),
            correctCount: 15,
            totalAttempts: 20,
            characterStats: [
                "K": CharacterStat(receiveAttempts: 10, receiveCorrect: 8),
                "M": CharacterStat(receiveAttempts: 10, receiveCorrect: 7)
            ],
            introCharacters: viewModel.introCharacters,
            introCompleted: true,
            customCharacters: nil,
            currentLevel: progressStore.progress.receiveLevel
        )

        viewModel.restoreFromPausedSession(session)

        XCTAssertEqual(viewModel.counter.correct, 15)
        XCTAssertEqual(viewModel.counter.attempts, 20)
        XCTAssertEqual(viewModel.characterStats["K"]?.receiveAttempts, 10)
        XCTAssertEqual(viewModel.phase, .paused)
    }

    func testRestoreFromPausedSessionDoesNotRestoreIfLevelChanged() {
        // Create a session with different level
        let session = PausedSession(
            sessionType: .receive,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 15,
            totalAttempts: 20,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 99 // Different level
        )

        viewModel.restoreFromPausedSession(session)

        // Should not restore
        XCTAssertEqual(viewModel.counter.correct, 0)
        XCTAssertEqual(viewModel.counter.attempts, 0)
    }

    func testRestoreFromPausedSessionRestartsIntroIfNotCompleted() {
        let session = PausedSession(
            sessionType: .receive,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 5,
            totalAttempts: 10,
            characterStats: [:],
            introCharacters: viewModel.introCharacters,
            introCompleted: false,
            customCharacters: nil,
            currentLevel: progressStore.progress.receiveLevel
        )

        viewModel.restoreFromPausedSession(session)

        // Should restart intro
        if case .introduction = viewModel.phase {
            // Expected
        } else {
            XCTFail("Expected introduction phase when intro not completed")
        }

        // But stats should be restored
        XCTAssertEqual(viewModel.counter.correct, 5)
        XCTAssertEqual(viewModel.counter.attempts, 10)
    }

    func testRestoreFromPausedSessionDoesNotRestoreIfCustomCharactersMismatch() {
        // Set up a custom session view model
        let customChars: [Character] = ["A", "B", "C"]
        let vm = ReceiveTrainingViewModel(audioEngine: MockAudioEngine())
        vm.configure(progressStore: progressStore, settingsStore: settingsStore, customCharacters: customChars)

        // Create a paused session with different custom characters
        let session = PausedSession(
            sessionType: .receiveCustom,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 5,
            totalAttempts: 10,
            characterStats: [:],
            introCharacters: ["D", "E", "F"],
            introCompleted: true,
            customCharacters: ["D", "E", "F"], // Different custom characters
            currentLevel: progressStore.progress.receiveLevel
        )

        vm.restoreFromPausedSession(session)

        // Should not restore because custom characters don't match
        XCTAssertEqual(vm.counter.correct, 0)
        XCTAssertEqual(vm.counter.attempts, 0)
    }

    func testIsIntroCompletedFalseInIntroduction() {
        viewModel.startSession()

        guard case .introduction = viewModel.phase else {
            XCTFail("Expected introduction phase")
            return
        }

        XCTAssertFalse(viewModel.isIntroCompleted)
    }

    func testIsIntroCompletedTrueInTraining() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        guard case .training = viewModel.phase else {
            XCTFail("Expected training phase")
            return
        }

        XCTAssertTrue(viewModel.isIntroCompleted)
    }

    func testIsIntroCompletedTrueInPaused() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }
        viewModel.pause()

        XCTAssertEqual(viewModel.phase, .paused)
        XCTAssertTrue(viewModel.isIntroCompleted)
    }

    // MARK: Private

    private var viewModel = ReceiveTrainingViewModel(audioEngine: MockAudioEngine())
    private var mockAudioEngine = MockAudioEngine()
    private var progressStore = ProgressStore()
    private var settingsStore = SettingsStore()

}

// swiftlint:enable type_body_length

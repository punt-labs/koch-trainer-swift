@testable import KochTrainer
import XCTest

// swiftlint:disable type_body_length
@MainActor
final class EarTrainingViewModelTests: XCTestCase {

    // MARK: Internal

    override func setUp() async throws {
        testDefaults.removePersistentDomain(forName: "TestEarTrainingVM")
        mockAudioEngine = MockAudioEngine()
        viewModel = EarTrainingViewModel(audioEngine: mockAudioEngine)
        progressStore = ProgressStore(defaults: testDefaults)
        settingsStore = SettingsStore(defaults: testDefaults)
        viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)
    }

    override func tearDown() async throws {
        viewModel.cleanup()
        testDefaults.removePersistentDomain(forName: "TestEarTrainingVM")
    }

    // MARK: - Initialization Tests

    func testInitialPhaseIsIntroduction() {
        viewModel.startSession()

        if case .introduction = viewModel.phase {
            // Expected
        } else {
            XCTFail("Expected introduction phase after startSession")
        }
    }

    func testMinimumAttemptsForProficiencyIs20() {
        XCTAssertEqual(viewModel.minimumAttemptsForProficiency, 20)
    }

    func testProficiencyThresholdIs90Percent() {
        XCTAssertEqual(viewModel.proficiencyThreshold, 0.90)
    }

    func testIntroCharactersSetFromLevel() {
        let expectedChars = MorseCode.charactersByPatternLength(upToLevel: progressStore.progress.earTrainingLevel)
        XCTAssertEqual(viewModel.introCharacters, expectedChars)
    }

    // MARK: - Introduction Phase Tests

    func testNextIntroCharacterAdvancesIndex() {
        viewModel.startSession()

        guard case let .introduction(index) = viewModel.phase else {
            XCTFail("Expected introduction phase")
            return
        }
        XCTAssertEqual(index, 0)

        viewModel.nextIntroCharacter()

        guard case let .introduction(newIndex) = viewModel.phase else {
            // May have transitioned to training if only 2 chars at level 1
            if case .training = viewModel.phase {
                return // This is fine - intro completed
            }
            XCTFail("Expected introduction or training phase")
            return
        }
        XCTAssertEqual(newIndex, 1)
    }

    func testIntroProgressString() {
        viewModel.startSession()

        guard case .introduction = viewModel.phase else {
            XCTFail("Expected introduction phase")
            return
        }

        XCTAssertEqual(viewModel.introProgress, "1 of \(viewModel.introCharacters.count)")
    }

    func testIsLastIntroCharacterFalseAtStart() {
        viewModel.startSession()
        XCTAssertFalse(viewModel.isLastIntroCharacter)
    }

    func testIsLastIntroCharacterTrueAtEnd() {
        viewModel.startSession()

        // Advance to last character
        while !viewModel.isLastIntroCharacter, case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        XCTAssertTrue(viewModel.isLastIntroCharacter)
    }

    func testNextIntroCharacterTransitionsToTrainingAtEnd() {
        viewModel.startSession()

        // Skip through all intro characters
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        XCTAssertEqual(viewModel.phase, .training)
        XCTAssertTrue(viewModel.isPlaying)
    }

    // MARK: - Pause Tests

    func testPauseDuringTrainingTransitionsToPaused() async {
        viewModel.startSession()

        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        guard case .training = viewModel.phase else {
            XCTFail("Expected training phase")
            return
        }
        XCTAssertTrue(viewModel.isPlaying)

        viewModel.pause()

        XCTAssertEqual(viewModel.phase, .paused)
        XCTAssertFalse(viewModel.isPlaying)
        // Pause sets radio mode to .off instead of calling stop()
        XCTAssertEqual(mockAudioEngine.radioMode, .off)
    }

    func testPauseDuringIntroductionIsNoOp() {
        viewModel.startSession()

        guard case .introduction = viewModel.phase else {
            XCTFail("Expected introduction phase")
            return
        }

        viewModel.pause()

        if case .introduction = viewModel.phase {
            // Expected
        } else {
            XCTFail("Pause should be no-op during introduction")
        }
    }

    func testPauseDuringPausedIsNoOp() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        viewModel.pause()
        XCTAssertEqual(viewModel.phase, .paused)

        viewModel.pause()
        XCTAssertEqual(viewModel.phase, .paused)
    }

    // MARK: - Resume Tests

    func testResumeFromPausedTransitionsToTraining() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }
        viewModel.pause()

        XCTAssertEqual(viewModel.phase, .paused)
        XCTAssertFalse(viewModel.isPlaying)

        viewModel.resume()

        XCTAssertEqual(viewModel.phase, .training)
        XCTAssertTrue(viewModel.isPlaying)
    }

    func testResumeFromNonPausedIsNoOp() {
        viewModel.startSession()

        guard case .introduction = viewModel.phase else {
            XCTFail("Expected introduction phase")
            return
        }

        viewModel.resume()

        if case .introduction = viewModel.phase {
            // Expected
        } else {
            XCTFail("Resume should be no-op when not paused")
        }
    }

    // MARK: - Input Tests

    func testKeyPressHandlesDitKeys() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Wait for async playNextCharacter Task to complete and set isWaitingForInput
        await waitForWaitingForInput()

        viewModel.handleKeyPress(".")
        XCTAssertEqual(viewModel.currentPattern, ".")

        viewModel.handleKeyPress("f")
        XCTAssertEqual(viewModel.currentPattern, "..")

        viewModel.handleKeyPress("F")
        XCTAssertEqual(viewModel.currentPattern, "...")
    }

    func testKeyPressHandlesDahKeys() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Wait for async playNextCharacter Task to complete and set isWaitingForInput
        await waitForWaitingForInput()

        viewModel.handleKeyPress("-")
        XCTAssertEqual(viewModel.currentPattern, "-")

        viewModel.handleKeyPress("j")
        XCTAssertEqual(viewModel.currentPattern, "--")

        viewModel.handleKeyPress("J")
        XCTAssertEqual(viewModel.currentPattern, "---")
    }

    func testInputIgnoredWhenNotWaitingForInput() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Before waiting for input (audio still playing)
        XCTAssertFalse(viewModel.isWaitingForInput)

        viewModel.inputDit()
        viewModel.inputDah()

        XCTAssertEqual(viewModel.currentPattern, "")
    }

    func testInputIgnoredWhenPaused() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        viewModel.pause()

        viewModel.inputDit()
        viewModel.inputDah()

        XCTAssertEqual(viewModel.currentPattern, "")
    }

    // MARK: - End Session Tests

    func testEndSessionFromTraining() async {
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

    func testEndSessionFromPaused() async {
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

    func testEndSessionWithNoAttemptsDoesNotAdvance() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        viewModel.endSession()

        if case let .completed(didAdvance, newCharacters) = viewModel.phase {
            XCTAssertFalse(didAdvance)
            XCTAssertNil(newCharacters)
        } else {
            XCTFail("Expected completed phase")
        }
    }

    // MARK: - Cleanup Tests

    func testCleanupStopsAudio() {
        viewModel.startSession()
        mockAudioEngine.endSessionCalled = false

        viewModel.cleanup()

        XCTAssertTrue(mockAudioEngine.endSessionCalled)
    }

    func testCleanupSetsIsPlayingToFalse() {
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
        let snapshot = viewModel.createPausedSessionSnapshot()
        XCTAssertNil(snapshot)
    }

    func testCreatePausedSessionSnapshotCapturesState() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        let snapshot = viewModel.createPausedSessionSnapshot()

        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.sessionType, .earTraining)
        XCTAssertTrue(snapshot?.introCompleted ?? false)
        XCTAssertNil(snapshot?.customCharacters)
    }

    func testRestoreFromPausedSessionRestoresState() async {
        let session = PausedSession(
            sessionType: .earTraining,
            startTime: Date().addingTimeInterval(-120),
            pausedAt: Date().addingTimeInterval(-60),
            correctCount: 15,
            totalAttempts: 20,
            characterStats: [
                "E": CharacterStat(earTrainingAttempts: 10, earTrainingCorrect: 8),
                "T": CharacterStat(earTrainingAttempts: 10, earTrainingCorrect: 7)
            ],
            introCharacters: viewModel.introCharacters,
            introCompleted: true,
            customCharacters: nil,
            currentLevel: progressStore.progress.earTrainingLevel
        )

        viewModel.restoreFromPausedSession(session)

        XCTAssertEqual(viewModel.correctCount, 15)
        XCTAssertEqual(viewModel.totalAttempts, 20)
        XCTAssertEqual(viewModel.characterStats["E"]?.earTrainingAttempts, 10)
        XCTAssertEqual(viewModel.phase, .paused)
    }

    func testRestoreFromPausedSessionDoesNotRestoreIfLevelChanged() {
        let session = PausedSession(
            sessionType: .earTraining,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 15,
            totalAttempts: 20,
            characterStats: [:],
            introCharacters: [],
            introCompleted: true,
            customCharacters: nil,
            currentLevel: 99
        )

        viewModel.restoreFromPausedSession(session)

        XCTAssertEqual(viewModel.correctCount, 0)
        XCTAssertEqual(viewModel.totalAttempts, 0)
    }

    func testRestoreFromPausedSessionRestartsIntroIfNotCompleted() {
        let session = PausedSession(
            sessionType: .earTraining,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 5,
            totalAttempts: 10,
            characterStats: [:],
            introCharacters: viewModel.introCharacters,
            introCompleted: false,
            customCharacters: nil,
            currentLevel: progressStore.progress.earTrainingLevel
        )

        viewModel.restoreFromPausedSession(session)

        if case .introduction = viewModel.phase {
            // Expected
        } else {
            XCTFail("Expected introduction phase when intro not completed")
        }

        XCTAssertEqual(viewModel.correctCount, 5)
        XCTAssertEqual(viewModel.totalAttempts, 10)
    }

    // MARK: - Computed Properties Tests

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

    func testIsIntroCompletedTrueInPaused() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }
        viewModel.pause()

        XCTAssertEqual(viewModel.phase, .paused)
        XCTAssertTrue(viewModel.isIntroCompleted)
    }

    func testAccuracyPercentageWithNoAttempts() {
        XCTAssertEqual(viewModel.accuracyPercentage, 0)
    }

    func testAccuracyWithNoAttempts() {
        XCTAssertEqual(viewModel.accuracy, 0)
    }

    func testInputProgressWithNoTimeout() {
        XCTAssertEqual(viewModel.inputProgress, 0)
    }

    func testProficiencyProgressShowsAttempts() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // With 0 attempts
        XCTAssertEqual(viewModel.proficiencyProgress, "0/20 attempts")
    }

    func testFormattedTime() {
        XCTAssertEqual(viewModel.formattedTime, "5:00")
    }

    // MARK: - Record Response Tests

    func testRecordResponseIncrementsTotal() {
        viewModel.recordResponse(expected: "E", wasCorrect: false)

        XCTAssertEqual(viewModel.totalAttempts, 1)
        XCTAssertEqual(viewModel.correctCount, 0)
    }

    func testRecordResponseIncrementsCorrect() {
        viewModel.recordResponse(expected: "E", wasCorrect: true)

        XCTAssertEqual(viewModel.totalAttempts, 1)
        XCTAssertEqual(viewModel.correctCount, 1)
    }

    func testRecordResponseUpdatesCharacterStats() {
        viewModel.recordResponse(expected: "E", wasCorrect: true)
        viewModel.recordResponse(expected: "E", wasCorrect: false)

        let stat = viewModel.characterStats["E"]
        XCTAssertNotNil(stat)
        XCTAssertEqual(stat?.earTrainingAttempts, 2)
        XCTAssertEqual(stat?.earTrainingCorrect, 1)
    }

    // MARK: Private

    private var viewModel = EarTrainingViewModel(audioEngine: MockAudioEngine())
    private var mockAudioEngine = MockAudioEngine()
    private var progressStore = ProgressStore()
    private var settingsStore = SettingsStore()
    private var testDefaults = UserDefaults(suiteName: "TestEarTrainingVM") ?? .standard

    /// Waits for the async Task in playNextCharacter to complete and set isWaitingForInput.
    /// With MockAudioEngine, playCharacter returns immediately, so this just needs
    /// to yield to let the Task complete.
    private func waitForWaitingForInput() async {
        // Give the Task a chance to run. With mock audio, it should be nearly instant,
        // but we need to yield to the async scheduler.
        for _ in 0 ..< 10 {
            if viewModel.isWaitingForInput {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        // If we get here, the flag wasn't set - test will fail with assertion
    }

}

// swiftlint:enable type_body_length

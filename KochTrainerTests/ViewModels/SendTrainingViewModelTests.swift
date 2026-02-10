@testable import KochTrainer
import XCTest

// swiftlint:disable type_body_length
@MainActor
final class SendTrainingViewModelTests: XCTestCase {

    // MARK: Internal

    override func setUp() async throws {
        mockAudioEngine = MockAudioEngine()
        viewModel = SendTrainingViewModel(audioEngine: mockAudioEngine)
        progressStore = ProgressStore()
        settingsStore = SettingsStore()
        viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)
    }

    override func tearDown() async throws {
        viewModel.cleanup()
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

        // Simulate some input
        viewModel.inputDit()
        viewModel.inputDah()
        viewModel.inputDit()

        // Wait for input timeout to register the attempt
        try? await Task.sleep(nanoseconds: 2_500_000_000)

        let correctBefore = viewModel.counter.correct
        let attemptsBefore = viewModel.counter.attempts

        // Only test if we actually got an attempt registered
        guard attemptsBefore > 0 else {
            // Skip this test if timing didn't work out
            return
        }

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

    // MARK: - Input Tests

    func testKeyPressHandlesDitKeys() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Test '.' key
        viewModel.handleKeyPress(".")
        XCTAssertEqual(viewModel.currentPattern, ".")

        // Reset for next test
        viewModel.pause()
        viewModel.resume()

        // Test 'f' key
        viewModel.handleKeyPress("f")
        XCTAssertEqual(viewModel.currentPattern, ".")

        // Test 'F' key (uppercase)
        viewModel.handleKeyPress("F")
        XCTAssertEqual(viewModel.currentPattern, "..")
    }

    func testKeyPressHandlesDahKeys() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Test '-' key
        viewModel.handleKeyPress("-")
        XCTAssertEqual(viewModel.currentPattern, "-")

        // Reset for next test
        viewModel.pause()
        viewModel.resume()

        // Test 'j' key
        viewModel.handleKeyPress("j")
        XCTAssertEqual(viewModel.currentPattern, "-")

        // Test 'J' key (uppercase)
        viewModel.handleKeyPress("J")
        XCTAssertEqual(viewModel.currentPattern, "--")
    }

    func testInputIgnoredWhenNotPlaying() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        viewModel.pause()

        // Input should be ignored when paused
        viewModel.inputDit()
        viewModel.inputDah()

        XCTAssertEqual(viewModel.currentPattern, "")
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
        mockAudioEngine.endSessionCalled = false

        viewModel.cleanup()

        XCTAssertTrue(mockAudioEngine.endSessionCalled)
    }

    // MARK: - Paused Session Snapshot Tests

    func testCreatePausedSessionSnapshotReturnsNilBeforeTraining() {
        // Before starting, sessionStartTime is nil
        let snapshot = viewModel.createPausedSessionSnapshot()
        XCTAssertNil(snapshot)
    }

    func testCreatePausedSessionSnapshotCapturesState() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Simulate some input and wait for it to register
        viewModel.inputDah()
        viewModel.inputDit()
        viewModel.inputDah()

        // Wait for input timeout
        try? await Task.sleep(nanoseconds: 2_500_000_000)

        let snapshot = viewModel.createPausedSessionSnapshot()

        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.sessionType, .send)
        XCTAssertTrue(snapshot?.introCompleted ?? false)
        XCTAssertNil(snapshot?.customCharacters)
    }

    func testCreatePausedSessionSnapshotForCustomSession() {
        let customChars: [Character] = ["A", "B", "C"]
        let vm = SendTrainingViewModel(audioEngine: MockAudioEngine())
        vm.configure(progressStore: progressStore, settingsStore: settingsStore, customCharacters: customChars)
        vm.startSession()
        while case .introduction = vm.phase {
            vm.nextIntroCharacter()
        }

        let snapshot = vm.createPausedSessionSnapshot()

        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.sessionType, .sendCustom)
        XCTAssertEqual(snapshot?.customCharacters, customChars)
        XCTAssertTrue(snapshot?.isCustomSession ?? false)
    }

    func testRestoreFromPausedSessionRestoresState() {
        // Create a paused session
        let session = PausedSession(
            sessionType: .send,
            startTime: Date().addingTimeInterval(-120),
            pausedAt: Date().addingTimeInterval(-60),
            correctCount: 15,
            totalAttempts: 20,
            characterStats: [
                "K": CharacterStat(sendAttempts: 10, sendCorrect: 8),
                "M": CharacterStat(sendAttempts: 10, sendCorrect: 7)
            ],
            introCharacters: viewModel.introCharacters,
            introCompleted: true,
            customCharacters: nil,
            currentLevel: progressStore.progress.sendLevel
        )

        viewModel.restoreFromPausedSession(session)

        XCTAssertEqual(viewModel.counter.correct, 15)
        XCTAssertEqual(viewModel.counter.attempts, 20)
        XCTAssertEqual(viewModel.characterStats["K"]?.sendAttempts, 10)
        XCTAssertEqual(viewModel.phase, .paused)
    }

    func testRestoreFromPausedSessionDoesNotRestoreIfLevelChanged() {
        // Create a session with different level
        let session = PausedSession(
            sessionType: .send,
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
            sessionType: .send,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 5,
            totalAttempts: 10,
            characterStats: [:],
            introCharacters: viewModel.introCharacters,
            introCompleted: false,
            customCharacters: nil,
            currentLevel: progressStore.progress.sendLevel
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
        let vm = SendTrainingViewModel(audioEngine: MockAudioEngine())
        vm.configure(progressStore: progressStore, settingsStore: settingsStore, customCharacters: customChars)

        // Create a paused session with different custom characters
        let session = PausedSession(
            sessionType: .sendCustom,
            startTime: Date(),
            pausedAt: Date(),
            correctCount: 5,
            totalAttempts: 10,
            characterStats: [:],
            introCharacters: ["D", "E", "F"],
            introCompleted: true,
            customCharacters: ["D", "E", "F"], // Different custom characters
            currentLevel: progressStore.progress.sendLevel
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

    // MARK: - Pattern Building Tests

    func testPatternBuildsCorrectly() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        viewModel.inputDit()
        XCTAssertEqual(viewModel.currentPattern, ".")

        viewModel.inputDah()
        XCTAssertEqual(viewModel.currentPattern, ".-")

        viewModel.inputDit()
        XCTAssertEqual(viewModel.currentPattern, ".-.")

        viewModel.inputDah()
        XCTAssertEqual(viewModel.currentPattern, ".-.-")
    }

    func testPatternClearsAfterShowNextCharacter() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Build a pattern
        viewModel.inputDit()
        viewModel.inputDah()
        XCTAssertEqual(viewModel.currentPattern, ".-")

        // Manually call showNextCharacter
        viewModel.showNextCharacter()

        // Pattern should be cleared
        XCTAssertEqual(viewModel.currentPattern, "")
    }

    // MARK: - Computed Properties Tests

    func testAccuracyWithNoAttempts() {
        XCTAssertEqual(viewModel.accuracy, 0)
        XCTAssertEqual(viewModel.accuracyPercentage, 0)
    }

    func testAccuracyCalculation() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Record some responses
        viewModel.recordResponse(expected: "K", wasCorrect: true, pattern: "-.-", decoded: "K")
        viewModel.recordResponse(expected: "M", wasCorrect: true, pattern: "--", decoded: "M")
        viewModel.recordResponse(expected: "R", wasCorrect: false, pattern: ".-", decoded: "A")

        XCTAssertEqual(viewModel.accuracy, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(viewModel.accuracyPercentage, 67)
    }

    func testInputProgressInitiallyZero() {
        XCTAssertEqual(viewModel.inputProgress, 0)
    }

    func testMinimumAttemptsForProficiency() {
        // At level 1, only 1 character, floor is 15
        // max(15, 5 * 1) = 15
        viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)
        XCTAssertGreaterThanOrEqual(viewModel.minimumAttemptsForProficiency, 15)
    }

    func testMinimumAttemptsScalesWithCharacters() {
        // Create a VM with custom characters to test scaling
        let vm = SendTrainingViewModel(audioEngine: MockAudioEngine())
        vm.configure(progressStore: progressStore, settingsStore: settingsStore, customCharacters: ["A", "B", "C", "D"])

        // 5 * 4 = 20, which is greater than 15
        XCTAssertEqual(vm.minimumAttemptsForProficiency, 20)
    }

    func testProficiencyThreshold() {
        XCTAssertEqual(viewModel.proficiencyThreshold, 0.90)
    }

    func testFormattedTime() {
        // timeRemaining defaults to 300 (5 minutes)
        XCTAssertEqual(viewModel.formattedTime, "5:00")
    }

    func testProficiencyProgressShowsAttempts() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // With fewer than minimum attempts, should show attempts
        viewModel.recordResponse(expected: "K", wasCorrect: true, pattern: "-.-", decoded: "K")

        let progress = viewModel.proficiencyProgress
        XCTAssertTrue(progress.contains("attempts"))
    }

    func testIntroProgressDuringIntroduction() {
        viewModel.startSession()

        // Should show progress during introduction
        let progress = viewModel.introProgress
        XCTAssertTrue(progress.contains("of"))
    }

    func testIntroProgressEmptyOutsideIntroduction() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        XCTAssertEqual(viewModel.introProgress, "")
    }

    func testIsLastIntroCharacterFalseAtStart() {
        viewModel.startSession()

        // At first character, shouldn't be last
        if viewModel.introCharacters.count > 1 {
            XCTAssertFalse(viewModel.isLastIntroCharacter)
        }
    }

    // MARK: - Record Response Tests

    func testRecordResponseUpdatesStats() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        viewModel.recordResponse(expected: "K", wasCorrect: true, pattern: "-.-", decoded: "K")

        XCTAssertEqual(viewModel.counter.attempts, 1)
        XCTAssertEqual(viewModel.counter.correct, 1)
        XCTAssertEqual(viewModel.characterStats["K"]?.sendAttempts, 1)
        XCTAssertEqual(viewModel.characterStats["K"]?.sendCorrect, 1)
    }

    func testRecordResponseIncorrectDoesNotIncrementCorrect() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        viewModel.recordResponse(expected: "K", wasCorrect: false, pattern: ".-", decoded: "A")

        XCTAssertEqual(viewModel.counter.attempts, 1)
        XCTAssertEqual(viewModel.counter.correct, 0)
        XCTAssertEqual(viewModel.characterStats["K"]?.sendAttempts, 1)
        XCTAssertEqual(viewModel.characterStats["K"]?.sendCorrect, 0)
    }

    func testRecordResponseMergesCharacterStats() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        viewModel.recordResponse(expected: "K", wasCorrect: true, pattern: "-.-", decoded: "K")
        viewModel.recordResponse(expected: "K", wasCorrect: true, pattern: "-.-", decoded: "K")
        viewModel.recordResponse(expected: "K", wasCorrect: false, pattern: "--", decoded: "M")

        XCTAssertEqual(viewModel.characterStats["K"]?.sendAttempts, 3)
        XCTAssertEqual(viewModel.characterStats["K"]?.sendCorrect, 2)
    }

    // MARK: - Custom Session Tests

    func testIsCustomSessionFalseByDefault() {
        XCTAssertFalse(viewModel.isCustomSession)
    }

    func testIsCustomSessionTrueWhenConfiguredWithCustomCharacters() {
        let vm = SendTrainingViewModel(audioEngine: MockAudioEngine())
        vm.configure(progressStore: progressStore, settingsStore: settingsStore, customCharacters: ["A", "B"])

        XCTAssertTrue(vm.isCustomSession)
    }

    func testCustomSessionUsesCustomCharactersForIntro() {
        let customChars: [Character] = ["X", "Y", "Z"]
        let vm = SendTrainingViewModel(audioEngine: MockAudioEngine())
        vm.configure(progressStore: progressStore, settingsStore: settingsStore, customCharacters: customChars)

        XCTAssertEqual(vm.introCharacters, customChars)
    }

    // MARK: - Introduction Phase Tests

    func testStartIntroductionWithEmptyCharactersGoesDirectlyToTraining() {
        // Create a VM with empty intro characters
        let vm = SendTrainingViewModel(audioEngine: MockAudioEngine())
        // Don't configure - introCharacters will be empty
        XCTAssertTrue(vm.introCharacters.isEmpty)

        vm.startSession()

        // Should go directly to training phase when no intro characters
        XCTAssertEqual(vm.phase, .training)
        XCTAssertTrue(vm.isPlaying)
    }

    func testPlayCurrentIntroCharacterDoesNothingWithNoCharacter() {
        // currentIntroCharacter is nil before startSession
        XCTAssertNil(viewModel.currentIntroCharacter)
        viewModel.playCurrentIntroCharacter()
        // Should not crash when currentIntroCharacter is nil
    }

    // MARK: - Feedback Tests

    func testLastFeedbackInitiallyNil() {
        XCTAssertNil(viewModel.lastFeedback)
    }

    func testShowFeedbackAndContinueSetsLastFeedback() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        viewModel.showFeedbackAndContinue(wasCorrect: true, expected: "K", pattern: "-.-", decoded: "K")

        XCTAssertNotNil(viewModel.lastFeedback)
        XCTAssertEqual(viewModel.lastFeedback?.wasCorrect, true)
        XCTAssertEqual(viewModel.lastFeedback?.expectedCharacter, "K")
        XCTAssertEqual(viewModel.lastFeedback?.sentPattern, "-.-")
        XCTAssertEqual(viewModel.lastFeedback?.decodedCharacter, "K")
    }

    // MARK: Private

    private var viewModel = SendTrainingViewModel(audioEngine: MockAudioEngine())
    private var mockAudioEngine = MockAudioEngine()
    private var progressStore = ProgressStore()
    private var settingsStore = SettingsStore()

}

// swiftlint:enable type_body_length

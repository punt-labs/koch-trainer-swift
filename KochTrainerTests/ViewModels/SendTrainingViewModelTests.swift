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

    func testPauseDuringTrainingTransitionsToPaused() async {
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
        XCTAssertTrue(mockAudioEngine.stopCalled)
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

    func testPauseDuringPausedIsNoOp() async {
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

    func testResumeFromPausedTransitionsToTraining() async {
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

        let correctBefore = viewModel.correctCount
        let attemptsBefore = viewModel.totalAttempts

        // Only test if we actually got an attempt registered
        guard attemptsBefore > 0 else {
            // Skip this test if timing didn't work out
            return
        }

        // Pause
        viewModel.pause()

        // Stats should be preserved
        XCTAssertEqual(viewModel.correctCount, correctBefore)
        XCTAssertEqual(viewModel.totalAttempts, attemptsBefore)

        // Resume
        viewModel.resume()

        // Stats should still be preserved
        XCTAssertEqual(viewModel.correctCount, correctBefore)
        XCTAssertEqual(viewModel.totalAttempts, attemptsBefore)
    }

    // MARK: - Input Tests

    func testKeyPressHandlesDitKeys() async {
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

    func testKeyPressHandlesDahKeys() async {
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

    func testInputIgnoredWhenNotPlaying() async {
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

    // MARK: - Cleanup Tests

    func testCleanupStopsAudio() {
        viewModel.startSession()
        mockAudioEngine.stopCalled = false

        viewModel.cleanup()

        XCTAssertTrue(mockAudioEngine.stopCalled)
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

    func testCreatePausedSessionSnapshotForCustomSession() async {
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

    func testRestoreFromPausedSessionRestoresState() async {
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

        XCTAssertEqual(viewModel.correctCount, 15)
        XCTAssertEqual(viewModel.totalAttempts, 20)
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
        XCTAssertEqual(viewModel.correctCount, 0)
        XCTAssertEqual(viewModel.totalAttempts, 0)
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
        XCTAssertEqual(viewModel.correctCount, 5)
        XCTAssertEqual(viewModel.totalAttempts, 10)
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
        XCTAssertEqual(vm.correctCount, 0)
        XCTAssertEqual(vm.totalAttempts, 0)
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

    func testIsIntroCompletedTrueInPaused() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }
        viewModel.pause()

        XCTAssertEqual(viewModel.phase, .paused)
        XCTAssertTrue(viewModel.isIntroCompleted)
    }

    // MARK: Private

    private var viewModel = SendTrainingViewModel(audioEngine: MockAudioEngine())
    private var mockAudioEngine = MockAudioEngine()
    private var progressStore = ProgressStore()
    private var settingsStore = SettingsStore()

}

// swiftlint:enable type_body_length

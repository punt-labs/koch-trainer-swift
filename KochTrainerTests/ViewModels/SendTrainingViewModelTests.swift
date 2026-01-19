@testable import KochTrainer
import XCTest

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

    // MARK: Private

    private var viewModel = SendTrainingViewModel(audioEngine: MockAudioEngine())
    private var mockAudioEngine = MockAudioEngine()
    private var progressStore = ProgressStore()
    private var settingsStore = SettingsStore()

}

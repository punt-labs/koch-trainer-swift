import XCTest
@testable import KochTrainer

/// Mock audio engine for testing without actual audio playback.
final class MockAudioEngine: AudioEngineProtocol {
    var playCharacterCalls: [Character] = []
    var playGroupCalls: [String] = []
    var stopCalled = false
    var frequencySet: Double?
    var effectiveSpeedSet: Int?

    func playCharacter(_ char: Character) async {
        playCharacterCalls.append(char)
    }

    func playGroup(_ group: String) async {
        playGroupCalls.append(group)
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

    func reset() {
        playCharacterCalls = []
        playGroupCalls = []
        stopCalled = false
    }
}

@MainActor
final class ReceiveTrainingViewModelTests: XCTestCase {

    private var viewModel: ReceiveTrainingViewModel!
    private var mockAudioEngine: MockAudioEngine!
    private var progressStore: ProgressStore!
    private var settingsStore: SettingsStore!

    override func setUp() async throws {
        mockAudioEngine = MockAudioEngine()
        viewModel = ReceiveTrainingViewModel(audioEngine: mockAudioEngine)
        progressStore = ProgressStore()
        settingsStore = SettingsStore()
        viewModel.configure(progressStore: progressStore, settingsStore: settingsStore)
    }

    override func tearDown() async throws {
        viewModel.cleanup()
        viewModel = nil
        mockAudioEngine = nil
        progressStore = nil
        settingsStore = nil
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

        // Wait for character to be presented
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Simulate some responses
        viewModel.handleKeyPress("K")
        try? await Task.sleep(nanoseconds: 100_000_000)

        let correctBefore = viewModel.correctCount
        let attemptsBefore = viewModel.totalAttempts

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
}

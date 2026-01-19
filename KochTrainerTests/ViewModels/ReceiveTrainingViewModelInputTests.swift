@testable import KochTrainer
import XCTest

/// Tests for input handling, response recording, and feedback in ReceiveTrainingViewModel.
@MainActor
final class ReceiveTrainingViewModelInputTests: XCTestCase {

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

    // MARK: - Input Handling Tests

    func testHandleKeyPressCorrect() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Wait for character to be presented
        try? await Task.sleep(nanoseconds: 200_000_000)

        guard let expected = viewModel.currentCharacter else {
            XCTFail("No current character")
            return
        }

        // Mark as waiting and handle correct key
        viewModel.startResponseTimer()
        let attemptsBefore = viewModel.totalAttempts
        let correctBefore = viewModel.correctCount

        viewModel.handleKeyPress(expected)

        XCTAssertEqual(viewModel.totalAttempts, attemptsBefore + 1)
        XCTAssertEqual(viewModel.correctCount, correctBefore + 1)
        XCTAssertNotNil(viewModel.lastFeedback)
        XCTAssertTrue(viewModel.lastFeedback?.wasCorrect ?? false)
    }

    func testHandleKeyPressIncorrect() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        try? await Task.sleep(nanoseconds: 200_000_000)

        guard let expected = viewModel.currentCharacter else {
            XCTFail("No current character")
            return
        }

        viewModel.startResponseTimer()
        let attemptsBefore = viewModel.totalAttempts
        let correctBefore = viewModel.correctCount

        // Press wrong key
        let wrongKey: Character = expected == "K" ? "M" : "K"
        viewModel.handleKeyPress(wrongKey)

        XCTAssertEqual(viewModel.totalAttempts, attemptsBefore + 1)
        XCTAssertEqual(viewModel.correctCount, correctBefore) // Unchanged
        XCTAssertNotNil(viewModel.lastFeedback)
        XCTAssertFalse(viewModel.lastFeedback?.wasCorrect ?? true)
    }

    func testHandleKeyPressCaseInsensitive() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        try? await Task.sleep(nanoseconds: 200_000_000)

        guard let expected = viewModel.currentCharacter else {
            XCTFail("No current character")
            return
        }

        viewModel.startResponseTimer()

        // Press lowercase version
        let lowercase = Character(expected.lowercased())
        viewModel.handleKeyPress(lowercase)

        XCTAssertTrue(viewModel.lastFeedback?.wasCorrect ?? false)
    }

    func testHandleKeyPressWhenNotWaiting() {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Not waiting for response
        XCTAssertFalse(viewModel.isWaitingForResponse)

        let attemptsBefore = viewModel.totalAttempts

        viewModel.handleKeyPress("K")

        // Should be ignored
        XCTAssertEqual(viewModel.totalAttempts, attemptsBefore)
    }

    // MARK: - Record Response Tests

    func testRecordResponseUpdatesStats() {
        let char: Character = "K"

        viewModel.recordResponse(expected: char, wasCorrect: true, userPressed: char)

        XCTAssertEqual(viewModel.totalAttempts, 1)
        XCTAssertEqual(viewModel.correctCount, 1)
        XCTAssertNotNil(viewModel.characterStats[char])
        XCTAssertEqual(viewModel.characterStats[char]?.receiveAttempts, 1)
        XCTAssertEqual(viewModel.characterStats[char]?.receiveCorrect, 1)
    }

    func testRecordResponseIncorrectUpdatesStats() {
        let char: Character = "M"

        viewModel.recordResponse(expected: char, wasCorrect: false, userPressed: "K")

        XCTAssertEqual(viewModel.totalAttempts, 1)
        XCTAssertEqual(viewModel.correctCount, 0)
        XCTAssertEqual(viewModel.characterStats[char]?.receiveAttempts, 1)
        XCTAssertEqual(viewModel.characterStats[char]?.receiveCorrect, 0)
    }

    func testRecordResponseAccumulatesStats() {
        let char: Character = "R"

        viewModel.recordResponse(expected: char, wasCorrect: true, userPressed: char)
        viewModel.recordResponse(expected: char, wasCorrect: true, userPressed: char)
        viewModel.recordResponse(expected: char, wasCorrect: false, userPressed: "S")

        XCTAssertEqual(viewModel.totalAttempts, 3)
        XCTAssertEqual(viewModel.correctCount, 2)
        XCTAssertEqual(viewModel.characterStats[char]?.receiveAttempts, 3)
        XCTAssertEqual(viewModel.characterStats[char]?.receiveCorrect, 2)
    }

    func testRecordResponseUpdatesLastPracticed() {
        let char: Character = "S"
        let before = Date()

        viewModel.recordResponse(expected: char, wasCorrect: true, userPressed: char)

        let lastPracticed = viewModel.characterStats[char]?.lastPracticed
        XCTAssertNotNil(lastPracticed)
        if let practiced = lastPracticed {
            XCTAssertGreaterThanOrEqual(practiced, before)
        }
    }

    // MARK: - Response Timer Tests

    func testStartResponseTimerSetsWaiting() {
        viewModel.startResponseTimer()

        XCTAssertTrue(viewModel.isWaitingForResponse)
        XCTAssertEqual(viewModel.responseTimeRemaining, viewModel.responseTimeout)
    }

    // MARK: - Session Timer Tests

    func testStartSessionTimerStartsTimer() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        let timeBefore = viewModel.timeRemaining

        // Wait for a tick
        try? await Task.sleep(nanoseconds: 1_100_000_000)

        XCTAssertLessThan(viewModel.timeRemaining, timeBefore)
    }

    // MARK: - Feedback Tests

    func testShowFeedbackAndContinueSetsLastFeedback() {
        let expected: Character = "K"
        let userPressed: Character = "K"

        viewModel.showFeedbackAndContinue(wasCorrect: true, expected: expected, userPressed: userPressed)

        XCTAssertNotNil(viewModel.lastFeedback)
        XCTAssertEqual(viewModel.lastFeedback?.wasCorrect, true)
        XCTAssertEqual(viewModel.lastFeedback?.expectedCharacter, expected)
        XCTAssertEqual(viewModel.lastFeedback?.userPressed, userPressed)
    }

    func testShowFeedbackIncorrectSetsLastFeedback() {
        let expected: Character = "M"
        let userPressed: Character = "K"

        viewModel.showFeedbackAndContinue(wasCorrect: false, expected: expected, userPressed: userPressed)

        XCTAssertNotNil(viewModel.lastFeedback)
        XCTAssertEqual(viewModel.lastFeedback?.wasCorrect, false)
        XCTAssertEqual(viewModel.lastFeedback?.expectedCharacter, expected)
        XCTAssertEqual(viewModel.lastFeedback?.userPressed, userPressed)
    }

    // MARK: - Play Next Group Tests

    func testPlayNextGroupSetsCurrentGroup() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Wait for group to be generated
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Current character should be set
        XCTAssertNotNil(viewModel.currentCharacter)
    }

    // MARK: - End Session Tests

    func testEndSessionRecordsResult() async {
        viewModel.startSession()
        while case .introduction = viewModel.phase {
            viewModel.nextIntroCharacter()
        }

        // Record some responses
        viewModel.recordResponse(expected: "K", wasCorrect: true, userPressed: "K")
        viewModel.recordResponse(expected: "M", wasCorrect: false, userPressed: "R")

        viewModel.endSession()

        guard case let .completed(didAdvance, _) = viewModel.phase else {
            XCTFail("Expected completed phase")
            return
        }

        // With only 2 attempts and 50% accuracy, should not advance
        XCTAssertFalse(didAdvance)
    }

    func testEndSessionWithCustomSessionDoesNotAdvance() async {
        let customChars: [Character] = ["K", "M"]
        let vm = ReceiveTrainingViewModel(audioEngine: MockAudioEngine())
        vm.configure(progressStore: progressStore, settingsStore: settingsStore, customCharacters: customChars)

        vm.startSession()
        while case .introduction = vm.phase {
            vm.nextIntroCharacter()
        }

        // Even with perfect performance, custom sessions don't advance
        for _ in 0 ..< 20 {
            vm.recordResponse(expected: "K", wasCorrect: true, userPressed: "K")
        }

        vm.endSession()

        guard case let .completed(didAdvance, _) = vm.phase else {
            XCTFail("Expected completed phase")
            return
        }

        // Custom sessions record as .receiveCustom and don't advance levels
        XCTAssertFalse(didAdvance)
    }

    // MARK: - Feedback Struct Tests

    func testFeedbackEquatable() {
        let feedback1 = ReceiveTrainingViewModel.Feedback(wasCorrect: true, expectedCharacter: "K", userPressed: "K")
        let feedback2 = ReceiveTrainingViewModel.Feedback(wasCorrect: true, expectedCharacter: "K", userPressed: "K")
        let feedback3 = ReceiveTrainingViewModel.Feedback(wasCorrect: false, expectedCharacter: "K", userPressed: "M")

        XCTAssertEqual(feedback1, feedback2)
        XCTAssertNotEqual(feedback1, feedback3)
    }

    // MARK: - SessionPhase Tests

    func testSessionPhaseEquatable() {
        XCTAssertEqual(
            ReceiveTrainingViewModel.SessionPhase.introduction(characterIndex: 0),
            ReceiveTrainingViewModel.SessionPhase.introduction(characterIndex: 0)
        )
        XCTAssertNotEqual(
            ReceiveTrainingViewModel.SessionPhase.introduction(characterIndex: 0),
            ReceiveTrainingViewModel.SessionPhase.introduction(characterIndex: 1)
        )
        XCTAssertEqual(
            ReceiveTrainingViewModel.SessionPhase.training,
            ReceiveTrainingViewModel.SessionPhase.training
        )
        XCTAssertEqual(
            ReceiveTrainingViewModel.SessionPhase.paused,
            ReceiveTrainingViewModel.SessionPhase.paused
        )
        XCTAssertEqual(
            ReceiveTrainingViewModel.SessionPhase.completed(didAdvance: true, newCharacter: "X"),
            ReceiveTrainingViewModel.SessionPhase.completed(didAdvance: true, newCharacter: "X")
        )
    }

    // MARK: Private

    private var viewModel = ReceiveTrainingViewModel(audioEngine: MockAudioEngine())
    private var mockAudioEngine = MockAudioEngine()
    private var progressStore = ProgressStore()
    private var settingsStore = SettingsStore()
}

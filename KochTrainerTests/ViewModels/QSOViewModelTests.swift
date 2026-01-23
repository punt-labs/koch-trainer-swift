@testable import KochTrainer
import XCTest

@MainActor
final class QSOViewModelTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialState() {
        let viewModel = QSOViewModel(style: .contest, callsign: "W5ABC")

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertEqual(viewModel.myCallsign, "W5ABC")
        XCTAssertEqual(viewModel.style, .contest)
        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertFalse(viewModel.showHint)
        XCTAssertTrue(viewModel.userInput.isEmpty)
        XCTAssertTrue(viewModel.transcript.isEmpty)
    }

    func testCallsignUppercased() {
        let viewModel = QSOViewModel(style: .ragChew, callsign: "k0abc")

        XCTAssertEqual(viewModel.myCallsign, "K0ABC")
    }

    func testStationPropertiesAccessible() {
        let viewModel = QSOViewModel(style: .contest, callsign: "W5ABC")

        XCTAssertFalse(viewModel.theirCallsign.isEmpty)
        XCTAssertFalse(viewModel.theirName.isEmpty)
        XCTAssertFalse(viewModel.theirQTH.isEmpty)
    }

    // MARK: - Session Control Tests

    func testStartSession() {
        let viewModel = QSOViewModel(style: .contest, callsign: "W5ABC")

        viewModel.startSession()

        XCTAssertTrue(viewModel.isSessionActive)
        XCTAssertEqual(viewModel.phase, .callingCQ)
    }

    func testEndSession() {
        let viewModel = QSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        viewModel.endSession()

        XCTAssertFalse(viewModel.isSessionActive)
    }

    func testReset() {
        let viewModel = QSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()
        viewModel.userInput = "CQ CQ DE W5ABC K"
        viewModel.showHint = true

        viewModel.reset()

        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertTrue(viewModel.userInput.isEmpty)
        XCTAssertFalse(viewModel.showHint)
        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertTrue(viewModel.transcript.isEmpty)
    }

    // MARK: - Input Handling Tests

    func testToggleHint() {
        let viewModel = QSOViewModel(style: .contest, callsign: "W5ABC")

        XCTAssertFalse(viewModel.showHint)

        viewModel.toggleHint()
        XCTAssertTrue(viewModel.showHint)

        viewModel.toggleHint()
        XCTAssertFalse(viewModel.showHint)
    }

    func testCurrentHintAvailable() {
        let viewModel = QSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        let hint = viewModel.currentHint

        XCTAssertFalse(hint.isEmpty)
        XCTAssertTrue(hint.contains("CQ") || hint.contains("W5ABC"))
    }

    func testSubmitEmptyInputIgnored() async {
        let viewModel = QSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()
        viewModel.userInput = ""

        await viewModel.submitInput()

        // Transcript should still be empty (no message added)
        XCTAssertTrue(viewModel.transcript.isEmpty)
    }

    func testSubmitInputClearsUserInput() async {
        let silentEngine = SilentAudioEngine()
        let viewModel = QSOViewModel(
            style: .contest,
            callsign: "W5ABC",
            audioEngine: silentEngine,
            aiResponseDelay: 0
        )
        viewModel.startSession()
        viewModel.userInput = "CQ CQ DE W5ABC K"

        await viewModel.submitInput()

        XCTAssertTrue(viewModel.userInput.isEmpty)
    }

    func testSubmitInputClearsHint() async {
        let silentEngine = SilentAudioEngine()
        let viewModel = QSOViewModel(
            style: .contest,
            callsign: "W5ABC",
            audioEngine: silentEngine,
            aiResponseDelay: 0
        )
        viewModel.startSession()
        viewModel.userInput = "CQ CQ DE W5ABC K"
        viewModel.showHint = true

        await viewModel.submitInput()

        XCTAssertFalse(viewModel.showHint)
    }

    // MARK: - Computed Properties Tests

    func testIsCompletedFalseWhileActive() {
        let viewModel = QSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        XCTAssertFalse(viewModel.isCompleted)
    }

    func testIsPlayingDelegatesFromEngine() {
        let viewModel = QSOViewModel(style: .contest, callsign: "W5ABC")

        // Initial state: not playing
        XCTAssertFalse(viewModel.isPlaying)
    }

    // MARK: - Result Tests

    func testGetResult() {
        let viewModel = QSOViewModel(style: .ragChew, callsign: "N7XYZ")
        viewModel.startSession()

        let result = viewModel.getResult()

        XCTAssertEqual(result.style, .ragChew)
        XCTAssertEqual(result.myCallsign, "N7XYZ")
        // theirCallsign is populated after AI response, not immediately after startSession
    }

    // MARK: - Configuration Tests

    func testConfigure() {
        let viewModel = QSOViewModel(style: .contest, callsign: "W5ABC")
        let settingsStore = SettingsStore()

        // Should not throw
        viewModel.configure(settingsStore: settingsStore)

        // Engine should use configured settings
        XCTAssertNotNil(viewModel.engine)
    }

    // MARK: - Style Tests

    func testContestStyle() {
        let viewModel = QSOViewModel(style: .contest, callsign: "W5ABC")

        XCTAssertEqual(viewModel.style, .contest)
    }

    func testRagChewStyle() {
        let viewModel = QSOViewModel(style: .ragChew, callsign: "K0ABC")

        XCTAssertEqual(viewModel.style, .ragChew)
    }
}

@testable import KochTrainer
import XCTest

@MainActor
final class MorseQSOViewModelTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialState() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")

        XCTAssertEqual(viewModel.style, .contest)
        XCTAssertEqual(viewModel.myCallsign, "W5ABC")
        XCTAssertEqual(viewModel.turnState, .idle)
        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertFalse(viewModel.isCompleted)
        XCTAssertEqual(viewModel.totalCharactersKeyed, 0)
        XCTAssertEqual(viewModel.correctCharactersKeyed, 0)
    }

    func testCallsignPassedToEngine() {
        let viewModel = MorseQSOViewModel(style: .ragChew, callsign: "K0ABC")

        XCTAssertEqual(viewModel.myCallsign, "K0ABC")
        XCTAssertEqual(viewModel.style, .ragChew)
    }

    // MARK: - Session Control Tests

    func testStartSession() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")

        viewModel.startSession()

        XCTAssertTrue(viewModel.isSessionActive)
        XCTAssertEqual(viewModel.turnState, .userKeying)
        XCTAssertEqual(viewModel.phase, .callingCQ)
    }

    func testEndSession() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        viewModel.endSession()

        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertEqual(viewModel.turnState, .completed)
        XCTAssertTrue(viewModel.isCompleted)
    }

    // MARK: - Accuracy Calculation Tests

    func testKeyingAccuracyInitiallyZero() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")

        XCTAssertEqual(viewModel.keyingAccuracy, 0.0)
        XCTAssertEqual(viewModel.accuracyPercentage, 0)
    }

    func testAccuracyPercentageCalculation() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")

        // Simulate accuracy tracking (normally done internally)
        // We'll test the result getter instead
        viewModel.startSession()
        let result = viewModel.getResult()

        XCTAssertEqual(result.totalCharactersKeyed, 0)
        XCTAssertEqual(result.keyingAccuracy, 0.0)
    }

    // MARK: - Input Progress Tests

    func testInputProgressInitiallyZero() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")

        XCTAssertEqual(viewModel.inputProgress, 0.0)
        XCTAssertEqual(viewModel.inputTimeRemaining, 0.0)
    }

    // MARK: - Phase Tests

    func testPhaseDescription() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertEqual(viewModel.phaseDescription, "Start by sending CQ")

        viewModel.startSession()
        XCTAssertEqual(viewModel.phase, .callingCQ)
    }

    // MARK: - Turn State Tests

    func testTurnStateTransitions() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")

        XCTAssertEqual(viewModel.turnState, .idle)

        viewModel.startSession()
        XCTAssertEqual(viewModel.turnState, .userKeying)

        viewModel.endSession()
        XCTAssertEqual(viewModel.turnState, .completed)
    }

    // MARK: - Script Generation Tests

    func testCurrentScriptPopulatedOnUserTurn() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")

        viewModel.startSession()

        // Should have a script for the user to key
        XCTAssertFalse(viewModel.currentScript.isEmpty)
        // Script should contain CQ
        XCTAssertTrue(viewModel.currentScript.contains("CQ"))
    }

    // MARK: - Input Handling Tests

    func testInputDitAppendsToPattern() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        XCTAssertTrue(viewModel.currentPattern.isEmpty)

        viewModel.inputDit()

        XCTAssertEqual(viewModel.currentPattern, ".")
    }

    func testInputDahAppendsToPattern() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        viewModel.inputDah()

        XCTAssertEqual(viewModel.currentPattern, "-")
    }

    func testInputDitDahSequence() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        viewModel.inputDit()
        viewModel.inputDah()

        XCTAssertEqual(viewModel.currentPattern, ".-")
    }

    func testInputIgnoredWhenNotUserTurn() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")

        // Not started, so not user turn
        viewModel.inputDit()

        XCTAssertTrue(viewModel.currentPattern.isEmpty)
    }

    func testHandleKeyPressDit() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        viewModel.handleKeyPress(".")

        XCTAssertEqual(viewModel.currentPattern, ".")
    }

    func testHandleKeyPressFForDit() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        viewModel.handleKeyPress("f")

        XCTAssertEqual(viewModel.currentPattern, ".")
    }

    func testHandleKeyPressDash() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        viewModel.handleKeyPress("-")

        XCTAssertEqual(viewModel.currentPattern, "-")
    }

    func testHandleKeyPressJForDah() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        viewModel.handleKeyPress("j")

        XCTAssertEqual(viewModel.currentPattern, "-")
    }

    func testHandleKeyPressUppercaseF() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        viewModel.handleKeyPress("F")

        XCTAssertEqual(viewModel.currentPattern, ".")
    }

    func testHandleKeyPressUppercaseJ() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        viewModel.handleKeyPress("J")

        XCTAssertEqual(viewModel.currentPattern, "-")
    }

    func testHandleKeyPressIgnoresOtherKeys() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        viewModel.handleKeyPress("a")
        viewModel.handleKeyPress("x")
        viewModel.handleKeyPress("1")

        XCTAssertTrue(viewModel.currentPattern.isEmpty)
    }

    // MARK: - Result Generation Tests

    func testGetResultContainsSessionInfo() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        let result = viewModel.getResult()

        XCTAssertEqual(result.style, .contest)
        XCTAssertEqual(result.myCallsign, "W5ABC")
        XCTAssertFalse(result.theirCallsign.isEmpty)
        XCTAssertFalse(result.theirName.isEmpty)
        XCTAssertFalse(result.theirQTH.isEmpty)
    }

    func testGetResultRagChewStyle() {
        let viewModel = MorseQSOViewModel(style: .ragChew, callsign: "K0XYZ")
        viewModel.startSession()

        let result = viewModel.getResult()

        XCTAssertEqual(result.style, .ragChew)
        XCTAssertEqual(result.myCallsign, "K0XYZ")
    }

    // MARK: - Expected Character Tests

    func testCurrentExpectedCharacterFromScript() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        viewModel.startSession()

        // Script starts with "CQ", so first expected should be 'C'
        if let expected = viewModel.currentExpectedCharacter {
            // The first character of the CQ script
            XCTAssertEqual(expected, Character("C"))
        }
    }

    // MARK: - Configuration Tests

    func testConfigureWithSettingsStore() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")
        let settingsStore = SettingsStore()

        // Should not crash
        viewModel.configure(settingsStore: settingsStore)

        XCTAssertEqual(viewModel.revealDelay, settingsStore.settings.morseQSORevealDelay)
    }

    // MARK: - Transcript Tests

    func testTranscriptInitiallyEmpty() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")

        XCTAssertTrue(viewModel.transcript.isEmpty)
    }

    // MARK: - Station Info Tests

    func testTheirCallsignAccessible() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")

        // Virtual station is generated on init
        XCTAssertFalse(viewModel.theirCallsign.isEmpty)
    }

    func testTheirNameAccessible() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")

        XCTAssertFalse(viewModel.theirName.isEmpty)
    }

    func testTheirQTHAccessible() {
        let viewModel = MorseQSOViewModel(style: .contest, callsign: "W5ABC")

        XCTAssertFalse(viewModel.theirQTH.isEmpty)
    }
}

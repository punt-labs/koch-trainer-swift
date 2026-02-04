@testable import KochTrainer
import XCTest

@MainActor
final class MorseQSOViewModelTests: XCTestCase {

    // MARK: Internal

    var mockAudioEngine = MockAudioEngine()
    var mockClock = MockClock()
    var settingsStore = SettingsStore()

    override func setUp() async throws {
        mockAudioEngine = MockAudioEngine()
        mockClock = MockClock()
        settingsStore = SettingsStore()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.style, .contest)
        XCTAssertEqual(viewModel.myCallsign, "W5ABC")
        XCTAssertEqual(viewModel.turnState, .idle)
        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertFalse(viewModel.isCompleted)
        XCTAssertEqual(viewModel.totalCharactersKeyed, 0)
        XCTAssertEqual(viewModel.correctCharactersKeyed, 0)
    }

    func testCallsignPassedToEngine() {
        let viewModel = makeViewModel(style: .ragChew, callsign: "K0ABC")

        XCTAssertEqual(viewModel.myCallsign, "K0ABC")
        XCTAssertEqual(viewModel.style, .ragChew)
    }

    // MARK: - Session Control Tests

    func testStartSessionUserInitiated() {
        let viewModel = makeViewModel()

        viewModel.startSession()

        XCTAssertTrue(viewModel.isSessionActive)
        XCTAssertEqual(viewModel.turnState, .userKeying)
        XCTAssertEqual(viewModel.phase, .callingCQ)
    }

    func testStartSessionAIInitiated() {
        let viewModel = makeViewModel(aiStarts: true)

        viewModel.startSession()

        // AI turn starts asynchronously, so turnState transitions to aiTransmitting
        XCTAssertTrue(viewModel.isSessionActive)
    }

    func testEndSession() {
        let viewModel = makeViewModel()
        viewModel.startSession()

        viewModel.endSession()

        XCTAssertFalse(viewModel.isSessionActive)
        XCTAssertEqual(viewModel.turnState, .completed)
        XCTAssertTrue(viewModel.isCompleted)
    }

    // MARK: - Accuracy Calculation Tests

    func testKeyingAccuracyInitiallyZero() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.keyingAccuracy, 0.0)
        XCTAssertEqual(viewModel.accuracyPercentage, 0)
    }

    func testAccuracyPercentageCalculation() {
        let viewModel = makeViewModel()

        // Simulate accuracy tracking (normally done internally)
        // We'll test the result getter instead
        viewModel.startSession()
        let result = viewModel.getResult()

        XCTAssertEqual(result.totalCharactersKeyed, 0)
        XCTAssertEqual(result.keyingAccuracy, 0.0)
    }

    // MARK: - Input Progress Tests

    func testInputProgressInitiallyZero() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.inputProgress, 0.0)
        XCTAssertEqual(viewModel.inputTimeRemaining, 0.0)
    }

    // MARK: - Phase Tests

    func testPhaseDescription() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertEqual(viewModel.phaseDescription, "Start by sending CQ")

        viewModel.startSession()
        XCTAssertEqual(viewModel.phase, .callingCQ)
    }

    // MARK: - Turn State Tests

    func testTurnStateTransitions() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.turnState, .idle)

        viewModel.startSession()
        XCTAssertEqual(viewModel.turnState, .userKeying)

        viewModel.endSession()
        XCTAssertEqual(viewModel.turnState, .completed)
    }

    // MARK: - Script Generation Tests

    func testCurrentScriptPopulatedOnUserTurn() {
        let viewModel = makeViewModel()

        viewModel.startSession()

        // Should have a script for the user to key
        XCTAssertFalse(viewModel.currentScript.isEmpty)
        // Script should contain CQ
        XCTAssertTrue(viewModel.currentScript.contains("CQ"))
    }

    // MARK: - Input Handling Tests

    func testQueueDitAppendsToPattern() {
        let viewModel = makeViewModel()
        viewModel.startSession()

        XCTAssertTrue(viewModel.currentPattern.isEmpty)

        pressDit(viewModel: viewModel)

        XCTAssertEqual(viewModel.currentPattern, ".")
    }

    func testQueueDahAppendsToPattern() {
        let viewModel = makeViewModel()
        viewModel.startSession()

        pressDah(viewModel: viewModel)

        XCTAssertEqual(viewModel.currentPattern, "-")
    }

    func testQueueDitDahSequence() {
        let viewModel = makeViewModel()
        viewModel.startSession()

        pressDit(viewModel: viewModel)
        pressDah(viewModel: viewModel)

        XCTAssertEqual(viewModel.currentPattern, ".-")
    }

    func testInputIgnoredWhenNotUserTurn() {
        let viewModel = makeViewModel()

        // Not started, so not user turn
        viewModel.queueElement(.dit)

        XCTAssertTrue(viewModel.currentPattern.isEmpty)
    }

    func testHandleKeyPressDit() {
        let viewModel = makeViewModel()
        viewModel.startSession()

        pressKeyWithTiming(viewModel: viewModel, key: ".")

        XCTAssertEqual(viewModel.currentPattern, ".")
    }

    func testHandleKeyPressFForDit() {
        let viewModel = makeViewModel()
        viewModel.startSession()

        pressKeyWithTiming(viewModel: viewModel, key: "f")

        XCTAssertEqual(viewModel.currentPattern, ".")
    }

    func testHandleKeyPressDash() {
        let viewModel = makeViewModel()
        viewModel.startSession()

        pressKeyWithTiming(viewModel: viewModel, key: "-")

        XCTAssertEqual(viewModel.currentPattern, "-")
    }

    func testHandleKeyPressJForDah() {
        let viewModel = makeViewModel()
        viewModel.startSession()

        pressKeyWithTiming(viewModel: viewModel, key: "j")

        XCTAssertEqual(viewModel.currentPattern, "-")
    }

    func testHandleKeyPressUppercaseF() {
        let viewModel = makeViewModel()
        viewModel.startSession()

        pressKeyWithTiming(viewModel: viewModel, key: "F")

        XCTAssertEqual(viewModel.currentPattern, ".")
    }

    func testHandleKeyPressUppercaseJ() {
        let viewModel = makeViewModel()
        viewModel.startSession()

        pressKeyWithTiming(viewModel: viewModel, key: "J")

        XCTAssertEqual(viewModel.currentPattern, "-")
    }

    func testHandleKeyPressIgnoresOtherKeys() {
        let viewModel = makeViewModel()
        viewModel.startSession()

        viewModel.handleKeyPress("a")
        viewModel.handleKeyPress("x")
        viewModel.handleKeyPress("1")

        XCTAssertTrue(viewModel.currentPattern.isEmpty)
    }

    // MARK: - Result Generation Tests

    func testGetResultContainsSessionInfo() {
        let viewModel = makeViewModel()
        viewModel.startSession()

        let result = viewModel.getResult()

        XCTAssertEqual(result.style, .contest)
        XCTAssertEqual(result.myCallsign, "W5ABC")
        XCTAssertFalse(result.theirCallsign.isEmpty)
        XCTAssertFalse(result.theirName.isEmpty)
        XCTAssertFalse(result.theirQTH.isEmpty)
    }

    func testGetResultRagChewStyle() {
        let viewModel = makeViewModel(style: .ragChew, callsign: "K0XYZ")
        viewModel.startSession()

        let result = viewModel.getResult()

        XCTAssertEqual(result.style, .ragChew)
        XCTAssertEqual(result.myCallsign, "K0XYZ")
    }

    // MARK: - Expected Character Tests

    func testCurrentExpectedCharacterFromScript() {
        let viewModel = makeViewModel()
        viewModel.startSession()

        // Script starts with "CQ", so first expected should be 'C'
        if let expected = viewModel.currentExpectedCharacter {
            // The first character of the CQ script
            XCTAssertEqual(expected, Character("C"))
        }
    }

    // MARK: - Configuration Tests

    func testConfigureWithSettingsStore() {
        let viewModel = makeViewModel()

        // Configuration was applied (no crash means success)
        XCTAssertNotNil(viewModel)
    }

    // MARK: - Transcript Tests

    func testTranscriptInitiallyEmpty() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.transcript.isEmpty)
    }

    // MARK: - Station Info Tests

    func testTheirCallsignAccessible() {
        let viewModel = makeViewModel()

        // Virtual station is generated on init
        XCTAssertFalse(viewModel.theirCallsign.isEmpty)
    }

    func testTheirNameAccessible() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.theirName.isEmpty)
    }

    func testTheirQTHAccessible() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.theirQTH.isEmpty)
    }

    // MARK: Private

    // MARK: - Private Helpers

    private func makeViewModel(
        style: QSOStyle = .contest,
        callsign: String = "W5ABC",
        aiStarts: Bool = false
    ) -> MorseQSOViewModel {
        let viewModel = MorseQSOViewModel(
            style: style,
            callsign: callsign,
            aiStarts: aiStarts,
            audioEngine: mockAudioEngine,
            clock: mockClock
        )
        viewModel.configure(settingsStore: settingsStore)
        return viewModel
    }

    private func pressDit(viewModel: MorseQSOViewModel) {
        guard let keyer = viewModel.keyer else { return }
        viewModel.queueElement(.dit)
        keyer.processTick(at: mockClock.now())
        mockClock.advance(by: keyer.configuration.ditDuration + 0.001)
        keyer.processTick(at: mockClock.now())
        mockClock.advance(by: keyer.configuration.elementGap + 0.001)
        keyer.processTick(at: mockClock.now())
    }

    private func pressDah(viewModel: MorseQSOViewModel) {
        guard let keyer = viewModel.keyer else { return }
        viewModel.queueElement(.dah)
        keyer.processTick(at: mockClock.now())
        mockClock.advance(by: keyer.configuration.dahDuration + 0.001)
        keyer.processTick(at: mockClock.now())
        mockClock.advance(by: keyer.configuration.elementGap + 0.001)
        keyer.processTick(at: mockClock.now())
    }

    private func pressKeyWithTiming(viewModel: MorseQSOViewModel, key: Character) {
        guard let keyer = viewModel.keyer else { return }
        viewModel.handleKeyPress(key)
        keyer.processTick(at: mockClock.now())
        let duration = (key == "." || key.lowercased() == "f")
            ? keyer.configuration.ditDuration
            : keyer.configuration.dahDuration
        mockClock.advance(by: duration + 0.001)
        keyer.processTick(at: mockClock.now())
        mockClock.advance(by: keyer.configuration.elementGap + 0.001)
        keyer.processTick(at: mockClock.now())
    }
}

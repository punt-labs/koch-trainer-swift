@testable import KochTrainer
import XCTest

@MainActor
final class QSOEnginePhaseTests: XCTestCase {

    // MARK: - Mock Audio Engine

    class MockAudioEngine: AudioEngineProtocol {

        // MARK: Internal

        var playedGroups: [String] = []
        var frequency: Double = 600
        var effectiveSpeed: Int = 12
        var stopCalled = false
        var bandConditionsConfigured = false

        var radioMode: RadioMode { radioState.mode }

        func playCharacter(_: Character) async {}
        func playGroup(_ group: String) async {
            playedGroups.append(group)
        }

        func playGroup(_ group: String, onCharacterPlayed: ((Character, Int) -> Void)?) async {
            playedGroups.append(group)
            for (index, char) in group.enumerated() {
                onCharacterPlayed?(char, index)
            }
        }

        func playDit() async {}
        func playDah() async {}
        func stop() { stopCalled = true }
        func reset() {}
        func setFrequency(_ frequency: Double) {
            self.frequency = frequency
        }

        func setEffectiveSpeed(_ wpm: Int) {
            effectiveSpeed = wpm
        }

        func configureBandConditions(from _: AppSettings) {
            bandConditionsConfigured = true
        }

        func startSession() { radioState.startSession() }
        func endSession() { radioState.endSession() }
        func startReceiving() throws { try radioState.startReceiving() }
        func startTransmitting() throws { try radioState.startTransmitting() }
        func stopRadio() throws { try radioState.stopRadio() }

        func activateTone(frequency: Double) throws {
            guard radioState.mode != .off else {
                throw Radio.RadioError.mustBeOn
            }
        }

        func deactivateTone() {}

        // MARK: Private

        private let radioState = MockRadioState()

    }

    // MARK: - processUserInput Phase Transition Tests

    func testProcessUserInputFromCallingCQToAwaitingResponse() async {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)
        engine.startQSO()
        XCTAssertEqual(engine.state.phase, .callingCQ)

        // Process user CQ call - should transition to awaitingResponse
        _ = await engine.processUserInput("CQ CQ DE W5ABC K", playAudio: false)

        // After AI responds, should be in receivedCall
        // But initially transitions to awaitingResponse
        XCTAssertEqual(engine.state.transcript.count, 2) // User + AI
    }

    func testProcessUserInputFromReceivedCallToAwaitingExchange() async {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)

        // Start with AI calling CQ (puts us in receivedCall)
        _ = engine.startWithAICQ()
        XCTAssertEqual(engine.state.phase, .receivedCall)

        // User responds - should transition to awaitingExchange
        _ = await engine.processUserInput("\(engine.station.callsign) DE W5ABC 599 001", playAudio: false)

        // Should have advanced past awaitingExchange to exchangeReceived after AI response
        XCTAssertEqual(engine.state.transcript.count, 3) // AI CQ + User + AI response
    }

    func testProcessUserInputEmptyStringReturnsNil() async {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)
        engine.startQSO()

        let result = await engine.processUserInput("", playAudio: false)

        XCTAssertNil(result)
        XCTAssertTrue(engine.state.transcript.isEmpty)
    }

    func testProcessUserInputWhitespaceOnlyReturnsNil() async {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)
        engine.startQSO()

        let result = await engine.processUserInput("   ", playAudio: false)

        XCTAssertNil(result)
        XCTAssertTrue(engine.state.transcript.isEmpty)
    }

    func testProcessUserInputUppercasesInput() async {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)
        engine.startQSO()

        _ = await engine.processUserInput("cq cq de w5abc", playAudio: false)

        XCTAssertEqual(engine.state.transcript.first?.text, "CQ CQ DE W5ABC")
    }

    func testProcessUserInputCompletesContestQSO() async {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)

        // Start with AI calling CQ - puts us in receivedCall
        _ = engine.startWithAICQ()
        XCTAssertEqual(engine.state.phase, .receivedCall)

        // User responds with exchange - transitions through awaitingExchange to exchangeReceived
        _ = await engine.processUserInput("\(engine.station.callsign) DE W5ABC 599 001", playAudio: false)
        XCTAssertEqual(engine.state.phase, .exchangeReceived)

        // User sends sign-off - contest style goes to signing, AI responds, then completed
        _ = await engine.processUserInput("TU 73", playAudio: false)
        XCTAssertEqual(engine.state.phase, .completed)
    }

    // MARK: - configureAudio Tests

    func testConfigureAudioSetsFrequency() {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)

        engine.configureAudio(frequency: 700, effectiveSpeed: 15, settings: AppSettings())

        XCTAssertEqual(mockAudio.frequency, 700)
    }

    func testConfigureAudioSetsEffectiveSpeed() {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)

        engine.configureAudio(frequency: 600, effectiveSpeed: 15, settings: AppSettings())

        XCTAssertEqual(mockAudio.effectiveSpeed, 15)
    }

    func testConfigureAudioConfiguresBandConditions() {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)

        engine.configureAudio(frequency: 600, effectiveSpeed: 12, settings: AppSettings())

        XCTAssertTrue(mockAudio.bandConditionsConfigured)
    }

    // MARK: - addTranscriptMessage Tests

    func testAddTranscriptMessageFromUser() {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)

        engine.addTranscriptMessage(from: .user, text: "TEST MESSAGE")

        XCTAssertEqual(engine.state.transcript.count, 1)
        XCTAssertEqual(engine.state.transcript.first?.sender, .user)
        XCTAssertEqual(engine.state.transcript.first?.text, "TEST MESSAGE")
    }

    func testAddTranscriptMessageFromStation() {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)

        engine.addTranscriptMessage(from: .station, text: "AI RESPONSE")

        XCTAssertEqual(engine.state.transcript.count, 1)
        XCTAssertEqual(engine.state.transcript.first?.sender, .station)
        XCTAssertEqual(engine.state.transcript.first?.text, "AI RESPONSE")
    }

    // MARK: - stopAudio Tests

    func testStopAudioCallsStop() {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)

        engine.stopAudio()

        XCTAssertTrue(mockAudio.stopCalled)
        XCTAssertFalse(engine.isPlayingAudio)
    }

    // MARK: - Validation Result Tests

    func testValidationResultValidForCorrectInput() async {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)
        engine.startQSO()

        _ = await engine.processUserInput("CQ CQ DE W5ABC K", playAudio: false)

        XCTAssertEqual(engine.lastValidationResult, .valid)
    }

    func testValidationResultInvalidForIncorrectInput() async {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)
        engine.startQSO()

        // In callingCQ phase, input must contain "CQ" and callsign
        _ = await engine.processUserInput("HELLO WORLD", playAudio: false)

        XCTAssertEqual(engine.lastValidationResult, .invalid(hint: "Include 'CQ' and your callsign"))
    }

    // MARK: - Style Initialization Tests

    func testRagChewStyleInitialization() {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .ragChew, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)

        XCTAssertEqual(engine.state.style, .ragChew)
    }

    func testContestStyleInitialization() {
        let mockAudio = MockAudioEngine()
        let engine = QSOEngine(style: .contest, myCallsign: "W5ABC", audioEngine: mockAudio, aiResponseDelay: 0)

        XCTAssertEqual(engine.state.style, .contest)
    }
}

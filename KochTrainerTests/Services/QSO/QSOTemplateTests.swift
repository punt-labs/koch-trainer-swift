@testable import KochTrainer
import XCTest

final class QSOTemplateTests: XCTestCase {

    // MARK: - User Hint Tests

    func testUserHintForIdle() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .idle

        let hint = QSOTemplate.userHint(for: state)

        XCTAssertTrue(hint.contains("CQ"))
        XCTAssertTrue(hint.contains("W5ABC"))
    }

    func testUserHintForCallingCQ() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .callingCQ

        let hint = QSOTemplate.userHint(for: state)

        XCTAssertTrue(hint.contains("CQ"))
        XCTAssertTrue(hint.contains("W5ABC"))
    }

    func testUserHintForAwaitingResponse() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .awaitingResponse

        let hint = QSOTemplate.userHint(for: state)

        XCTAssertTrue(hint.lowercased().contains("wait"))
    }

    func testUserHintForReceivedCallContest() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .receivedCall
        state.theirCallsign = "K0XYZ"

        let hint = QSOTemplate.userHint(for: state)

        XCTAssertTrue(hint.contains("K0XYZ"))
    }

    func testUserHintForReceivedCallRagChew() {
        var state = QSOState(style: .ragChew, myCallsign: "W5ABC")
        state.phase = .receivedCall
        state.theirCallsign = "K0XYZ"

        let hint = QSOTemplate.userHint(for: state)

        XCTAssertTrue(hint.contains("K0XYZ"))
        XCTAssertTrue(hint.contains("RST") || hint.contains("NAME"))
    }

    func testUserHintForSendingExchangeContest() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .sendingExchange

        let hint = QSOTemplate.userHint(for: state)

        // Contest exchange should have RST
        XCTAssertTrue(hint.contains("5") || hint.contains("9"))
    }

    func testUserHintForSendingExchangeRagChew() {
        var state = QSOState(style: .ragChew, myCallsign: "W5ABC")
        state.phase = .sendingExchange

        let hint = QSOTemplate.userHint(for: state)

        XCTAssertTrue(hint.contains("RST") || hint.contains("NAME"))
    }

    func testUserHintForAwaitingExchange() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .awaitingExchange

        let hint = QSOTemplate.userHint(for: state)

        XCTAssertTrue(hint.lowercased().contains("wait"))
    }

    func testUserHintForExchangeReceivedContestEnding() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .exchangeReceived

        let hint = QSOTemplate.userHint(for: state)

        XCTAssertTrue(hint.contains("73") || hint.contains("TU"))
    }

    func testUserHintForExchangeReceivedRagChewContinuing() {
        var state = QSOState(style: .ragChew, myCallsign: "W5ABC")
        state.phase = .exchangeReceived
        state.exchangeCount = 1 // Still continuing

        let hint = QSOTemplate.userHint(for: state)

        XCTAssertTrue(hint.contains("RIG") || hint.contains("WX") || hint.contains("K"))
    }

    func testUserHintForExchangeReceivedRagChewEnding() {
        var state = QSOState(style: .ragChew, myCallsign: "W5ABC")
        state.phase = .exchangeReceived
        state.exchangeCount = 3 // Time to end

        let hint = QSOTemplate.userHint(for: state)

        XCTAssertTrue(hint.contains("73") || hint.contains("TNX"))
    }

    func testUserHintForSigning() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .signing

        let hint = QSOTemplate.userHint(for: state)

        XCTAssertTrue(hint.contains("73"))
    }

    func testUserHintForCompleted() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .completed

        let hint = QSOTemplate.userHint(for: state)

        XCTAssertTrue(hint.lowercased().contains("complete"))
    }

    // MARK: - AI Response Tests

    func testAIResponseForIdle() {
        let state = QSOState(style: .contest, myCallsign: "W5ABC")
        let station = VirtualStation.random()

        let response = QSOTemplate.aiResponse(for: state, station: station)

        XCTAssertTrue(response.isEmpty) // AI doesn't initiate
    }

    func testAIResponseForCallingCQ() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .callingCQ
        let station = VirtualStation.random()

        let response = QSOTemplate.aiResponse(for: state, station: station)

        XCTAssertTrue(response.contains(state.myCallsign))
        XCTAssertTrue(response.contains(station.callsign))
    }

    func testAIResponseForAwaitingResponse() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .awaitingResponse
        let station = VirtualStation.random()

        let response = QSOTemplate.aiResponse(for: state, station: station)

        XCTAssertFalse(response.isEmpty)
        XCTAssertTrue(response.contains("DE"))
    }

    func testAIResponseForReceivedCall() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .receivedCall
        let station = VirtualStation.random()

        let response = QSOTemplate.aiResponse(for: state, station: station)

        XCTAssertTrue(response.isEmpty) // User sends exchange first
    }

    func testAIResponseForSendingExchangeContest() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .sendingExchange
        let station = VirtualStation.random()

        let response = QSOTemplate.aiResponse(for: state, station: station)

        // Contest exchange has RST and serial
        XCTAssertFalse(response.isEmpty)
    }

    func testAIResponseForSendingExchangeRagChew() {
        var state = QSOState(style: .ragChew, myCallsign: "W5ABC")
        state.phase = .sendingExchange
        let station = VirtualStation.random()

        let response = QSOTemplate.aiResponse(for: state, station: station)

        // Rag chew has name/QTH
        XCTAssertFalse(response.isEmpty)
        XCTAssertTrue(response.contains(station.name) || response.contains(station.qth))
    }

    func testAIResponseForAwaitingExchangeContest() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .awaitingExchange
        let station = VirtualStation.random()

        let response = QSOTemplate.aiResponse(for: state, station: station)

        XCTAssertFalse(response.isEmpty)
    }

    func testAIResponseForExchangeReceivedContest() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .exchangeReceived
        let station = VirtualStation.random()

        let response = QSOTemplate.aiResponse(for: state, station: station)

        XCTAssertTrue(response.contains("TU"))
    }

    func testAIResponseForExchangeReceivedRagChewContinuing() {
        var state = QSOState(style: .ragChew, myCallsign: "W5ABC")
        state.phase = .exchangeReceived
        state.exchangeCount = 1
        let station = VirtualStation.random()

        let response = QSOTemplate.aiResponse(for: state, station: station)

        // Should have rig/wx info
        XCTAssertFalse(response.isEmpty)
    }

    func testAIResponseForExchangeReceivedRagChewEnding() {
        var state = QSOState(style: .ragChew, myCallsign: "W5ABC")
        state.phase = .exchangeReceived
        state.exchangeCount = 3
        let station = VirtualStation.random()

        let response = QSOTemplate.aiResponse(for: state, station: station)

        XCTAssertTrue(response.contains("73") || response.contains("TNX"))
    }

    func testAIResponseForSigning() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .signing
        let station = VirtualStation.random()

        let response = QSOTemplate.aiResponse(for: state, station: station)

        XCTAssertTrue(response.contains("73"))
    }

    func testAIResponseForCompleted() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .completed
        let station = VirtualStation.random()

        let response = QSOTemplate.aiResponse(for: state, station: station)

        XCTAssertTrue(response.isEmpty)
    }

    // MARK: - Validation Tests

    func testValidateUserInputIdlePhase() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .idle

        let validResult = QSOTemplate.validateUserInput("CQ CQ DE W5ABC K", for: state)
        XCTAssertTrue(validResult.isValid)

        let invalidResult = QSOTemplate.validateUserInput("HELLO", for: state)
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertNotNil(invalidResult.hint)
    }

    func testValidateUserInputCQPhase() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .callingCQ

        let validResult = QSOTemplate.validateUserInput("CQ CQ DE W5ABC K", for: state)
        XCTAssertTrue(validResult.isValid)

        let invalidResult = QSOTemplate.validateUserInput("HELLO", for: state)
        XCTAssertFalse(invalidResult.isValid)
    }

    func testValidateUserInputReceivedCallPhase() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .receivedCall
        state.theirCallsign = "K0XYZ"

        let validResult = QSOTemplate.validateUserInput("K0XYZ 599 001", for: state)
        XCTAssertTrue(validResult.isValid)

        let invalidResult = QSOTemplate.validateUserInput("HELLO", for: state)
        XCTAssertFalse(invalidResult.isValid)
    }

    func testValidateUserInputSendingExchangePhase() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .sendingExchange
        state.theirCallsign = "K0XYZ"

        let validResult = QSOTemplate.validateUserInput("599 002", for: state)
        XCTAssertTrue(validResult.isValid)

        let invalidResult = QSOTemplate.validateUserInput("HELLO", for: state)
        XCTAssertFalse(invalidResult.isValid)
    }

    func testValidateUserInputExchangeReceivedPhase() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .exchangeReceived

        let validTU = QSOTemplate.validateUserInput("TU 73", for: state)
        XCTAssertTrue(validTU.isValid)

        let validTNX = QSOTemplate.validateUserInput("TNX QSO", for: state)
        XCTAssertTrue(validTNX.isValid)

        let valid73 = QSOTemplate.validateUserInput("73", for: state)
        XCTAssertTrue(valid73.isValid)

        let validK = QSOTemplate.validateUserInput("FB K", for: state)
        XCTAssertTrue(validK.isValid)

        let invalidResult = QSOTemplate.validateUserInput("HELLO", for: state)
        XCTAssertFalse(invalidResult.isValid)
    }

    func testValidateUserInputSigningPhase() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .signing

        let validResult = QSOTemplate.validateUserInput("73 SK", for: state)
        XCTAssertTrue(validResult.isValid)

        let valid73 = QSOTemplate.validateUserInput("73 DE W5ABC", for: state)
        XCTAssertTrue(valid73.isValid)

        let invalidResult = QSOTemplate.validateUserInput("HELLO", for: state)
        XCTAssertFalse(invalidResult.isValid)
    }

    func testValidateUserInputDefaultPhases() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .awaitingResponse

        let result = QSOTemplate.validateUserInput("ANYTHING", for: state)
        XCTAssertTrue(result.isValid) // Default phases accept anything
    }

    func testValidateUserInputCaseInsensitive() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .callingCQ

        let result = QSOTemplate.validateUserInput("cq cq de w5abc k", for: state)
        XCTAssertTrue(result.isValid)
    }

    func testValidateUserInputTrimsWhitespace() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")
        state.phase = .callingCQ

        let result = QSOTemplate.validateUserInput("  CQ CQ DE W5ABC K  ", for: state)
        XCTAssertTrue(result.isValid)
    }

    // MARK: - ValidationResult Tests

    func testValidationResultIsValid() {
        let valid = ValidationResult.valid
        let invalid = ValidationResult.invalid(hint: "Test hint")

        XCTAssertTrue(valid.isValid)
        XCTAssertFalse(invalid.isValid)
    }

    func testValidationResultHint() {
        let valid = ValidationResult.valid
        let invalid = ValidationResult.invalid(hint: "Test hint")

        XCTAssertNil(valid.hint)
        XCTAssertEqual(invalid.hint, "Test hint")
    }

    func testValidationResultEquatable() {
        XCTAssertEqual(ValidationResult.valid, ValidationResult.valid)
        XCTAssertEqual(
            ValidationResult.invalid(hint: "Test"),
            ValidationResult.invalid(hint: "Test")
        )
        XCTAssertNotEqual(ValidationResult.valid, ValidationResult.invalid(hint: "Test"))
    }
}

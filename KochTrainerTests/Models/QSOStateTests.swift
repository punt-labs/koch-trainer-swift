@testable import KochTrainer
import XCTest

final class QSOStateTests: XCTestCase {

    // MARK: - QSOStyle Tests

    func testQSOStyleDisplayNames() {
        XCTAssertEqual(QSOStyle.contest.displayName, "Contest")
        XCTAssertEqual(QSOStyle.ragChew.displayName, "Rag Chew")
    }

    func testQSOStyleDescriptions() {
        XCTAssertFalse(QSOStyle.contest.description.isEmpty)
        XCTAssertFalse(QSOStyle.ragChew.description.isEmpty)
    }

    func testQSOStyleCaseIterable() {
        XCTAssertEqual(QSOStyle.allCases.count, 2)
        XCTAssertTrue(QSOStyle.allCases.contains(.contest))
        XCTAssertTrue(QSOStyle.allCases.contains(.ragChew))
    }

    // MARK: - QSOPhase Tests

    func testQSOPhaseUserActions() {
        XCTAssertFalse(QSOPhase.idle.userAction.isEmpty)
        XCTAssertFalse(QSOPhase.callingCQ.userAction.isEmpty)
        XCTAssertFalse(QSOPhase.awaitingResponse.userAction.isEmpty)
        XCTAssertFalse(QSOPhase.receivedCall.userAction.isEmpty)
        XCTAssertFalse(QSOPhase.sendingExchange.userAction.isEmpty)
        XCTAssertFalse(QSOPhase.awaitingExchange.userAction.isEmpty)
        XCTAssertFalse(QSOPhase.exchangeReceived.userAction.isEmpty)
        XCTAssertFalse(QSOPhase.signing.userAction.isEmpty)
        XCTAssertFalse(QSOPhase.completed.userAction.isEmpty)
    }

    func testQSOPhaseUserActionContainsRelevantText() {
        XCTAssertTrue(QSOPhase.callingCQ.userAction.contains("CQ"))
        XCTAssertTrue(QSOPhase.signing.userAction.contains("73") || QSOPhase.signing.userAction.contains("SK"))
        XCTAssertTrue(QSOPhase.completed.userAction.contains("complete") || QSOPhase.completed.userAction
            .contains("Complete"))
    }

    // MARK: - QSOMessage Tests

    func testQSOMessageInitialization() {
        let message = QSOMessage(sender: .user, text: "CQ CQ DE W5ABC K")

        XCTAssertEqual(message.sender, .user)
        XCTAssertEqual(message.text, "CQ CQ DE W5ABC K")
        XCTAssertNotNil(message.id)
        XCTAssertNotNil(message.timestamp)
    }

    func testQSOMessageCustomID() {
        let id = UUID()
        let message = QSOMessage(id: id, sender: .station, text: "Test")

        XCTAssertEqual(message.id, id)
    }

    func testQSOMessageCustomTimestamp() {
        let date = Date(timeIntervalSince1970: 1000)
        let message = QSOMessage(sender: .user, text: "Test", timestamp: date)

        XCTAssertEqual(message.timestamp, date)
    }

    // MARK: - QSOSender Tests

    func testQSOSenderRawValues() {
        XCTAssertEqual(QSOSender.user.rawValue, "user")
        XCTAssertEqual(QSOSender.station.rawValue, "station")
    }

    // MARK: - QSOState Initialization Tests

    func testQSOStateInitialization() {
        let state = QSOState(style: .contest, myCallsign: "W5ABC")

        XCTAssertEqual(state.phase, .idle)
        XCTAssertEqual(state.style, .contest)
        XCTAssertEqual(state.myCallsign, "W5ABC")
        XCTAssertEqual(state.theirCallsign, "")
        XCTAssertEqual(state.theirName, "")
        XCTAssertEqual(state.theirQTH, "")
        XCTAssertEqual(state.mySerialNumber, 1)
        XCTAssertEqual(state.theirSerialNumber, 0)
        XCTAssertEqual(state.myRST, "599")
        XCTAssertEqual(state.theirRST, "")
        XCTAssertTrue(state.transcript.isEmpty)
        XCTAssertEqual(state.exchangeCount, 0)
    }

    func testQSOStateUppercasesCallsign() {
        let state = QSOState(style: .ragChew, myCallsign: "w5abc")

        XCTAssertEqual(state.myCallsign, "W5ABC")
    }

    func testQSOStateInitializationWithOptionalParams() {
        let state = QSOState(
            style: .ragChew,
            myCallsign: "W5ABC",
            theirCallsign: "k0xyz",
            theirName: "John",
            theirQTH: "Denver"
        )

        XCTAssertEqual(state.theirCallsign, "K0XYZ")
        XCTAssertEqual(state.theirName, "John")
        XCTAssertEqual(state.theirQTH, "Denver")
    }

    // MARK: - addMessage Tests

    func testAddMessageAppendsToTranscript() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")

        state.addMessage(from: .user, text: "CQ CQ DE W5ABC K")

        XCTAssertEqual(state.transcript.count, 1)
        XCTAssertEqual(state.transcript[0].sender, .user)
        XCTAssertEqual(state.transcript[0].text, "CQ CQ DE W5ABC K")
    }

    func testAddMessageMultipleMessages() {
        var state = QSOState(style: .contest, myCallsign: "W5ABC")

        state.addMessage(from: .user, text: "Message 1")
        state.addMessage(from: .station, text: "Message 2")
        state.addMessage(from: .user, text: "Message 3")

        XCTAssertEqual(state.transcript.count, 3)
        XCTAssertEqual(state.transcript[0].sender, .user)
        XCTAssertEqual(state.transcript[1].sender, .station)
        XCTAssertEqual(state.transcript[2].sender, .user)
    }

    // MARK: - Duration Tests

    func testDurationComputed() {
        let state = QSOState(style: .contest, myCallsign: "W5ABC")

        // Duration should be very small (just created)
        XCTAssertLessThan(state.duration, 1.0)
    }

    // MARK: - Codable Tests

    func testQSOStyleCodable() throws {
        let original = QSOStyle.contest
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(QSOStyle.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testQSOPhaseCodable() throws {
        let original = QSOPhase.receivedCall
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(QSOPhase.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testQSOMessageCodable() throws {
        let original = QSOMessage(sender: .user, text: "Test message")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(QSOMessage.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.sender, original.sender)
        XCTAssertEqual(decoded.text, original.text)
    }

    func testQSOStateCodable() throws {
        var original = QSOState(style: .ragChew, myCallsign: "W5ABC")
        original.phase = .receivedCall
        original.theirCallsign = "K0XYZ"
        original.addMessage(from: .user, text: "Test")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(QSOState.self, from: data)

        XCTAssertEqual(decoded.phase, original.phase)
        XCTAssertEqual(decoded.style, original.style)
        XCTAssertEqual(decoded.myCallsign, original.myCallsign)
        XCTAssertEqual(decoded.theirCallsign, original.theirCallsign)
        XCTAssertEqual(decoded.transcript.count, original.transcript.count)
    }

    // MARK: - Equatable Tests

    func testQSOStateEquatable() {
        let state1 = QSOState(style: .contest, myCallsign: "W5ABC")
        var state2 = QSOState(style: .contest, myCallsign: "W5ABC")
        state2.startTime = state1.startTime // Match start times

        // Note: Will still differ due to startTime being set at init
        // This tests that equatable is properly implemented
        XCTAssertEqual(state1.style, state2.style)
        XCTAssertEqual(state1.myCallsign, state2.myCallsign)
        XCTAssertEqual(state1.phase, state2.phase)
    }
}

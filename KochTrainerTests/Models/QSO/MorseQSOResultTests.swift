@testable import KochTrainer
import XCTest

final class MorseQSOResultTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization() {
        let result = MorseQSOResult(
            style: .contest,
            myCallsign: "W5ABC",
            theirCallsign: "K0XYZ",
            theirName: "Mike",
            theirQTH: "Denver",
            duration: 120,
            totalCharactersKeyed: 50,
            correctCharactersKeyed: 45,
            exchangesCompleted: 2
        )

        XCTAssertEqual(result.style, .contest)
        XCTAssertEqual(result.myCallsign, "W5ABC")
        XCTAssertEqual(result.theirCallsign, "K0XYZ")
        XCTAssertEqual(result.theirName, "Mike")
        XCTAssertEqual(result.theirQTH, "Denver")
        XCTAssertEqual(result.duration, 120)
        XCTAssertEqual(result.totalCharactersKeyed, 50)
        XCTAssertEqual(result.correctCharactersKeyed, 45)
        XCTAssertEqual(result.exchangesCompleted, 2)
    }

    // MARK: - Accuracy Calculation Tests

    func testKeyingAccuracyWithCorrectCharacters() {
        let result = MorseQSOResult(
            style: .contest,
            myCallsign: "W5ABC",
            theirCallsign: "K0XYZ",
            theirName: "Mike",
            theirQTH: "Denver",
            duration: 60,
            totalCharactersKeyed: 100,
            correctCharactersKeyed: 90,
            exchangesCompleted: 1
        )

        XCTAssertEqual(result.keyingAccuracy, 0.9, accuracy: 0.001)
    }

    func testKeyingAccuracyPerfect() {
        let result = MorseQSOResult(
            style: .ragChew,
            myCallsign: "W5ABC",
            theirCallsign: "K0XYZ",
            theirName: "Mike",
            theirQTH: "Denver",
            duration: 60,
            totalCharactersKeyed: 50,
            correctCharactersKeyed: 50,
            exchangesCompleted: 1
        )

        XCTAssertEqual(result.keyingAccuracy, 1.0, accuracy: 0.001)
    }

    func testKeyingAccuracyZeroCharacters() {
        let result = MorseQSOResult(
            style: .contest,
            myCallsign: "W5ABC",
            theirCallsign: "K0XYZ",
            theirName: "Mike",
            theirQTH: "Denver",
            duration: 60,
            totalCharactersKeyed: 0,
            correctCharactersKeyed: 0,
            exchangesCompleted: 0
        )

        XCTAssertEqual(result.keyingAccuracy, 0.0)
    }

    func testKeyingAccuracyAllIncorrect() {
        let result = MorseQSOResult(
            style: .contest,
            myCallsign: "W5ABC",
            theirCallsign: "K0XYZ",
            theirName: "Mike",
            theirQTH: "Denver",
            duration: 60,
            totalCharactersKeyed: 20,
            correctCharactersKeyed: 0,
            exchangesCompleted: 1
        )

        XCTAssertEqual(result.keyingAccuracy, 0.0)
    }

    // MARK: - Formatting Tests

    func testFormattedDurationMinutesAndSeconds() {
        let result = MorseQSOResult(
            style: .contest,
            myCallsign: "W5ABC",
            theirCallsign: "K0XYZ",
            theirName: "Mike",
            theirQTH: "Denver",
            duration: 125, // 2:05
            totalCharactersKeyed: 10,
            correctCharactersKeyed: 10,
            exchangesCompleted: 1
        )

        XCTAssertEqual(result.formattedDuration, "2:05")
    }

    func testFormattedDurationSecondsOnly() {
        let result = MorseQSOResult(
            style: .contest,
            myCallsign: "W5ABC",
            theirCallsign: "K0XYZ",
            theirName: "Mike",
            theirQTH: "Denver",
            duration: 45,
            totalCharactersKeyed: 10,
            correctCharactersKeyed: 10,
            exchangesCompleted: 1
        )

        XCTAssertEqual(result.formattedDuration, "0:45")
    }

    func testFormattedAccuracyPercentage() {
        let result = MorseQSOResult(
            style: .contest,
            myCallsign: "W5ABC",
            theirCallsign: "K0XYZ",
            theirName: "Mike",
            theirQTH: "Denver",
            duration: 60,
            totalCharactersKeyed: 100,
            correctCharactersKeyed: 87,
            exchangesCompleted: 1
        )

        XCTAssertEqual(result.formattedAccuracy, "87%")
    }

    func testFormattedAccuracyRounding() {
        let result = MorseQSOResult(
            style: .contest,
            myCallsign: "W5ABC",
            theirCallsign: "K0XYZ",
            theirName: "Mike",
            theirQTH: "Denver",
            duration: 60,
            totalCharactersKeyed: 3,
            correctCharactersKeyed: 2, // 66.67%
            exchangesCompleted: 1
        )

        XCTAssertEqual(result.formattedAccuracy, "66%")
    }

    // MARK: - QSO Style Tests

    func testContestStyle() {
        let result = MorseQSOResult(
            style: .contest,
            myCallsign: "W5ABC",
            theirCallsign: "K0XYZ",
            theirName: "Mike",
            theirQTH: "Denver",
            duration: 60,
            totalCharactersKeyed: 10,
            correctCharactersKeyed: 10,
            exchangesCompleted: 1
        )

        XCTAssertEqual(result.style.displayName, "Contest")
    }

    func testRagChewStyle() {
        let result = MorseQSOResult(
            style: .ragChew,
            myCallsign: "W5ABC",
            theirCallsign: "K0XYZ",
            theirName: "Mike",
            theirQTH: "Denver",
            duration: 60,
            totalCharactersKeyed: 10,
            correctCharactersKeyed: 10,
            exchangesCompleted: 2
        )

        XCTAssertEqual(result.style.displayName, "Rag Chew")
    }
}

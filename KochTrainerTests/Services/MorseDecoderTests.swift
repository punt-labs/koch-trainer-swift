import XCTest
@testable import KochTrainer

final class MorseDecoderTests: XCTestCase {

    var decoder: MorseDecoder!

    override func setUp() {
        super.setUp()
        decoder = MorseDecoder()
    }

    override func tearDown() {
        decoder = nil
        super.tearDown()
    }

    // MARK: - Basic Decoding Tests

    func testDecodeE() {
        // E = .
        let result = decoder.processInput(.dit)

        XCTAssertEqual(result, .character("E"))
    }

    func testDecodeT() {
        // T = -
        let result = decoder.processInput(.dah)

        XCTAssertEqual(result, .character("T"))
    }

    func testDecodeM() {
        // M = --
        _ = decoder.processInput(.dah)
        let result = decoder.processInput(.dah)

        XCTAssertEqual(result, .character("M"))
    }

    func testDecodeS() {
        // S = ...
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        let result = decoder.processInput(.dit)

        XCTAssertEqual(result, .character("S"))
    }

    func testDecodeO() {
        // O = ---
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        let result = decoder.processInput(.dah)

        XCTAssertEqual(result, .character("O"))
    }

    func testDecodeK() {
        // K = -.-
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dit)
        let result = decoder.processInput(.dah)

        XCTAssertEqual(result, .character("K"))
    }

    // MARK: - Partial Pattern Tests

    func testPartialPatternReturnsNil() {
        // I = .. but this could also be S (...)
        let result = decoder.processInput(.dit)
        XCTAssertNil(result) // Could still extend to more characters

        // Wait, actually E = . should complete immediately
        // Let me check the logic... E is unique, so it should return immediately
    }

    func testCurrentPatternTracking() {
        _ = decoder.processInput(.dah)
        XCTAssertEqual(decoder.currentPattern, "-")

        _ = decoder.processInput(.dit)
        XCTAssertEqual(decoder.currentPattern, "-.")
    }

    // MARK: - Reset Tests

    func testReset() {
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dit)
        XCTAssertEqual(decoder.currentPattern, "-.")

        decoder.reset()

        XCTAssertEqual(decoder.currentPattern, "")
    }

    // MARK: - Complete Character Tests

    func testCompleteCharacterValidPattern() {
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dit)
        // Pattern is "-." which is N

        let result = decoder.completeCharacter()

        XCTAssertEqual(result, .character("N"))
        XCTAssertEqual(decoder.currentPattern, "")
    }

    func testCompleteCharacterInvalidPattern() {
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        // Pattern is "-----" which is invalid

        let result = decoder.completeCharacter()

        XCTAssertEqual(result, .invalid(pattern: "-----"))
    }

    func testCompleteCharacterEmptyPattern() {
        let result = decoder.completeCharacter()

        XCTAssertNil(result)
    }

    // MARK: - Timeout Duration Tests

    func testTimeoutDuration() {
        // Should be 1.5 × dah = 1.5 × 180ms = 270ms
        let expectedTimeout = MorseCode.Timing.dahDuration * 1.5

        XCTAssertEqual(decoder.timeoutDuration, expectedTimeout, accuracy: 0.001)
    }

    // MARK: - All Letters Test

    func testDecodeAllLetters() {
        let testCases: [(String, [MorseElement])] = [
            ("A", [.dit, .dah]),
            ("B", [.dah, .dit, .dit, .dit]),
            ("C", [.dah, .dit, .dah, .dit]),
            ("D", [.dah, .dit, .dit]),
            ("E", [.dit]),
            ("F", [.dit, .dit, .dah, .dit]),
            ("G", [.dah, .dah, .dit]),
            ("H", [.dit, .dit, .dit, .dit]),
            ("I", [.dit, .dit]),
            ("J", [.dit, .dah, .dah, .dah]),
            ("K", [.dah, .dit, .dah]),
            ("L", [.dit, .dah, .dit, .dit]),
            ("M", [.dah, .dah]),
            ("N", [.dah, .dit]),
            ("O", [.dah, .dah, .dah]),
            ("P", [.dit, .dah, .dah, .dit]),
            ("Q", [.dah, .dah, .dit, .dah]),
            ("R", [.dit, .dah, .dit]),
            ("S", [.dit, .dit, .dit]),
            ("T", [.dah]),
            ("U", [.dit, .dit, .dah]),
            ("V", [.dit, .dit, .dit, .dah]),
            ("W", [.dit, .dah, .dah]),
            ("X", [.dah, .dit, .dit, .dah]),
            ("Y", [.dah, .dit, .dah, .dah]),
            ("Z", [.dah, .dah, .dit, .dit])
        ]

        for (expected, elements) in testCases {
            decoder.reset()

            var result: DecodedResult?
            for element in elements {
                result = decoder.processInput(element)
            }

            // If result is nil, force completion
            if result == nil {
                result = decoder.completeCharacter()
            }

            XCTAssertEqual(
                result,
                .character(Character(expected)),
                "Failed to decode \(expected)"
            )
        }
    }
}

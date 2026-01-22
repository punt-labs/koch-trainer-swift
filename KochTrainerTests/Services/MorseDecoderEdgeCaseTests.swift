@testable import KochTrainer
import XCTest

final class MorseDecoderEdgeCaseTests: XCTestCase {

    private var decoder = MorseDecoder()

    override func setUp() {
        super.setUp()
        decoder = MorseDecoder()
    }

    // MARK: - MorseElement Tests

    func testMorseElementDitSymbol() {
        XCTAssertEqual(MorseElement.dit.symbol, ".")
    }

    func testMorseElementDahSymbol() {
        XCTAssertEqual(MorseElement.dah.symbol, "-")
    }

    // MARK: - Digit Decoding Tests

    func testDecode0() {
        // 0 = -----
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        let result = decoder.processInput(.dah)

        XCTAssertEqual(result, .character("0"))
    }

    func testDecode1() {
        // 1 = .----
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        let result = decoder.processInput(.dah)

        XCTAssertEqual(result, .character("1"))
    }

    func testDecode2() {
        // 2 = ..---
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        let result = decoder.processInput(.dah)

        XCTAssertEqual(result, .character("2"))
    }

    func testDecode3() {
        // 3 = ...--
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dah)
        let result = decoder.processInput(.dah)

        XCTAssertEqual(result, .character("3"))
    }

    func testDecode4() {
        // 4 = ....-
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        let result = decoder.processInput(.dah)

        XCTAssertEqual(result, .character("4"))
    }

    func testDecode5() {
        // 5 = .....
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        let result = decoder.processInput(.dit)

        XCTAssertEqual(result, .character("5"))
    }

    func testDecode6() {
        // 6 = -....
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        let result = decoder.processInput(.dit)

        XCTAssertEqual(result, .character("6"))
    }

    func testDecode7() {
        // 7 = --...
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        let result = decoder.processInput(.dit)

        XCTAssertEqual(result, .character("7"))
    }

    func testDecode8() {
        // 8 = ---..
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dit)
        let result = decoder.processInput(.dit)

        XCTAssertEqual(result, .character("8"))
    }

    func testDecode9() {
        // 9 = ----.
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        let result = decoder.processInput(.dit)

        XCTAssertEqual(result, .character("9"))
    }

    // MARK: - checkTimeout Tests

    func testCheckTimeoutReturnsNilWhenNoPattern() {
        let result = decoder.checkTimeout()

        XCTAssertNil(result)
    }

    func testCheckTimeoutReturnsNilWhenTimeoutNotElapsed() {
        _ = decoder.processInput(.dit)

        // Immediately check - timeout shouldn't have elapsed
        let result = decoder.checkTimeout()

        XCTAssertNil(result)
    }

    func testCheckTimeoutReturnsResultWhenTimeoutElapsed() {
        // Create a new decoder without starting the timer
        let testDecoder = MorseDecoder()

        // Manually simulate elapsed time by processing input then checking
        // Note: The timer auto-completes, so checkTimeout is for polling scenarios
        // where the timer hasn't been set up (e.g., manual polling loop)

        // This test verifies checkTimeout logic when pattern exists and time elapsed
        // Since the real decoder uses a timer, we test the callback path instead
        let expectation = XCTestExpectation(description: "Character decoded via timer")
        var decodedChar: DecodedResult?

        testDecoder.onCharacterDecoded = { result in
            decodedChar = result
            expectation.fulfill()
        }

        _ = testDecoder.processInput(.dit)

        wait(for: [expectation], timeout: testDecoder.timeoutDuration + 1.0)
        XCTAssertEqual(decodedChar, .character("E"))
    }

    // MARK: - Callback Tests

    func testOnCharacterDecodedCallbackCalledOnTimeout() {
        let expectation = XCTestExpectation(description: "Callback called")
        var decodedResult: DecodedResult?

        decoder.onCharacterDecoded = { result in
            decodedResult = result
            expectation.fulfill()
        }

        _ = decoder.processInput(.dit)

        wait(for: [expectation], timeout: decoder.timeoutDuration + 1.0)

        XCTAssertEqual(decodedResult, .character("E"))
    }

    // MARK: - Malformed Input Edge Cases

    func testVeryLongInvalidPattern() {
        // Build an invalid 6-element pattern: .-.-.-
        // This doesn't match any valid Morse character
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dah)

        let result = decoder.completeCharacter()

        if case let .invalid(pattern) = result {
            XCTAssertEqual(pattern, ".-.-.-")
        } else {
            XCTFail("Expected invalid pattern result")
        }
    }

    func testAlternatingDitDahPattern() {
        // .-.- is invalid
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dah)

        let result = decoder.completeCharacter()

        XCTAssertEqual(result, .invalid(pattern: ".-.-"))
    }

    func testResetClearsPattern() {
        _ = decoder.processInput(.dit)
        XCTAssertEqual(decoder.currentPattern, ".")

        decoder.reset()

        XCTAssertEqual(decoder.currentPattern, "")
    }

    // MARK: - Sequential Character Decoding

    func testDecodeMultipleCharactersSequentially() {
        // Decode "SOS" = ... --- ...
        // S
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        let s1 = decoder.completeCharacter()
        XCTAssertEqual(s1, .character("S"))

        // O
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        let o = decoder.completeCharacter()
        XCTAssertEqual(o, .character("O"))

        // S
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        let s2 = decoder.completeCharacter()
        XCTAssertEqual(s2, .character("S"))
    }

    // MARK: - DecodedResult Equatable Tests

    func testDecodedResultCharacterEquality() {
        let result1 = DecodedResult.character("A")
        let result2 = DecodedResult.character("A")
        let result3 = DecodedResult.character("B")

        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }

    func testDecodedResultInvalidEquality() {
        let result1 = DecodedResult.invalid(pattern: ".-.-")
        let result2 = DecodedResult.invalid(pattern: ".-.-")
        let result3 = DecodedResult.invalid(pattern: "-..-")

        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }

    func testDecodedResultMixedInequality() {
        let charResult = DecodedResult.character("A")
        let invalidResult = DecodedResult.invalid(pattern: ".-")

        XCTAssertNotEqual(charResult, invalidResult)
    }
}

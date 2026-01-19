@testable import KochTrainer
import XCTest

final class MorseDecoderTests: XCTestCase {

    // MARK: Internal

    override func setUp() {
        super.setUp()
        decoder = MorseDecoder()
    }

    // MARK: - Basic Decoding Tests

    func testDecodeE() {
        // E = . (has extensions like .., .- so needs explicit completion)
        _ = decoder.processInput(.dit)
        let result = decoder.completeCharacter()

        XCTAssertEqual(result, .character("E"))
    }

    func testDecodeT() {
        // T = - (has extensions like --, -. so needs explicit completion)
        _ = decoder.processInput(.dah)
        let result = decoder.completeCharacter()

        XCTAssertEqual(result, .character("T"))
    }

    func testDecodeM() {
        // M = -- (has extensions like ---, --. so needs explicit completion)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        let result = decoder.completeCharacter()

        XCTAssertEqual(result, .character("M"))
    }

    func testDecodeS() {
        // S = ... (has extension .... = H so needs explicit completion)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        let result = decoder.completeCharacter()

        XCTAssertEqual(result, .character("S"))
    }

    func testDecodeO() {
        // O = --- (no valid extensions, should return immediately)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        let result = decoder.processInput(.dah)

        XCTAssertEqual(result, .character("O"))
    }

    func testDecodeK() {
        // K = -.- (has extension -.-. = C so needs explicit completion)
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dah)
        let result = decoder.completeCharacter()

        XCTAssertEqual(result, .character("K"))
    }

    // MARK: - Immediate Completion Tests

    func testImmediateCompletionForO() {
        // O = --- has no valid extensions, should complete immediately
        _ = decoder.processInput(.dah)
        _ = decoder.processInput(.dah)
        let result = decoder.processInput(.dah)

        XCTAssertEqual(result, .character("O"))
        XCTAssertEqual(decoder.currentPattern, "") // Should be reset
    }

    func testImmediateCompletionForH() {
        // H = .... has no valid extensions (5 dits would be invalid)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        _ = decoder.processInput(.dit)
        let result = decoder.processInput(.dit)

        XCTAssertEqual(result, .character("H"))
    }

    // MARK: - Partial Pattern Tests

    func testPartialPatternReturnsNil() {
        // Single dit could extend to many patterns
        let result = decoder.processInput(.dit)
        XCTAssertNil(result) // Waiting for more input or timeout
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
        // Build pattern ".-.-" which is invalid (not a Morse letter)
        // Each prefix has extensions so no early return:
        // "." → has extensions, ".-" → has extensions (A), ".-." → has extensions (R→L)
        _ = decoder.processInput(.dit) // .
        _ = decoder.processInput(.dah) // .-
        _ = decoder.processInput(.dit) // .-.
        _ = decoder.processInput(.dah) // .-.-  (invalid pattern)

        let result = decoder.completeCharacter()

        XCTAssertEqual(result, .invalid(pattern: ".-.-"))
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

    // MARK: Private

    private var decoder = MorseDecoder()

}

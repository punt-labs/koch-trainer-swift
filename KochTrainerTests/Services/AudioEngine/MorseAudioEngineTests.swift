@testable import KochTrainer
import XCTest

@MainActor
final class MorseAudioEngineTests: XCTestCase {

    // MARK: - Initialization Tests

    func testEngineInitializes() {
        let engine = MorseAudioEngine()

        // Verify engine can be configured without error
        engine.setFrequency(600)
        engine.setEffectiveSpeed(12)
    }

    // MARK: - setFrequency Tests

    func testSetFrequencyWithinRange() async {
        let engine = MorseAudioEngine()

        engine.setFrequency(700)

        await engine.playDit()
    }

    func testSetFrequencyBelowRangeHandledGracefully() async {
        let engine = MorseAudioEngine()

        engine.setFrequency(100) // Below 400 minimum, clamped internally

        await engine.playDit()
    }

    func testSetFrequencyAboveRangeHandledGracefully() async {
        let engine = MorseAudioEngine()

        engine.setFrequency(1000) // Above 800 maximum, clamped internally

        await engine.playDit()
    }

    // MARK: - setEffectiveSpeed Tests

    func testSetEffectiveSpeedWithinRange() async {
        let engine = MorseAudioEngine()

        engine.setEffectiveSpeed(15)

        await engine.playDit()
    }

    func testSetEffectiveSpeedBelowRangeHandledGracefully() async {
        let engine = MorseAudioEngine()

        engine.setEffectiveSpeed(5) // Below 10 minimum, clamped internally

        await engine.playDit()
    }

    func testSetEffectiveSpeedAboveRangeHandledGracefully() async {
        let engine = MorseAudioEngine()

        engine.setEffectiveSpeed(25) // Above 18 maximum, clamped internally

        await engine.playDit()
    }

    // MARK: - configureBandConditions Tests

    func testConfigureBandConditions() async {
        let engine = MorseAudioEngine()
        let settings = AppSettings(
            bandConditionsEnabled: true,
            noiseLevel: 0.5,
            fadingEnabled: true,
            fadingDepth: 0.3
        )

        engine.configureBandConditions(from: settings)

        // Verify by playing a character (no crash means success)
        await engine.playDit()
    }

    // MARK: - playDit Tests

    func testPlayDit() async {
        let engine = MorseAudioEngine()

        // This should complete without crash
        await engine.playDit()
    }

    func testPlayDitWhenStopped() async {
        let engine = MorseAudioEngine()
        engine.stop()

        // Should return immediately when stopped
        await engine.playDit()
    }

    // MARK: - playDah Tests

    func testPlayDah() async {
        let engine = MorseAudioEngine()

        await engine.playDah()
    }

    func testPlayDahWhenStopped() async {
        let engine = MorseAudioEngine()
        engine.stop()

        await engine.playDah()
    }

    // MARK: - playCharacter Tests

    func testPlayCharacterValidLetter() async {
        let engine = MorseAudioEngine()

        await engine.playCharacter("K")
    }

    func testPlayCharacterValidDigit() async {
        let engine = MorseAudioEngine()

        await engine.playCharacter("5")
    }

    func testPlayCharacterUnknown() async {
        let engine = MorseAudioEngine()

        // Unknown character should be handled gracefully (just prints)
        await engine.playCharacter("@")
    }

    func testPlayCharacterWhenStopped() async {
        let engine = MorseAudioEngine()
        engine.stop()

        await engine.playCharacter("K")
    }

    // MARK: - playGroup Tests

    func testPlayGroupSingleCharacter() async {
        let engine = MorseAudioEngine()

        await engine.playGroup("K")
    }

    func testPlayGroupMultipleCharacters() async {
        let engine = MorseAudioEngine()

        await engine.playGroup("CQ")
    }

    func testPlayGroupWithSpace() async {
        let engine = MorseAudioEngine()

        await engine.playGroup("CQ CQ")
    }

    func testPlayGroupLowercaseConverted() async {
        let engine = MorseAudioEngine()

        await engine.playGroup("cq")
    }

    func testPlayGroupWhenStopped() async {
        let engine = MorseAudioEngine()
        engine.stop()

        await engine.playGroup("CQ")
    }

    // MARK: - playGroup with Callback Tests

    func testPlayGroupWithCallback() async {
        let engine = MorseAudioEngine()
        var playedCharacters: [Character] = []
        var indices: [Int] = []

        await engine.playGroup("AB") { char, index in
            playedCharacters.append(char)
            indices.append(index)
        }

        XCTAssertEqual(playedCharacters, ["A", "B"])
        XCTAssertEqual(indices, [0, 1])
    }

    func testPlayGroupWithCallbackIncludesSpaces() async {
        let engine = MorseAudioEngine()
        var playedCharacters: [Character] = []

        await engine.playGroup("A B") { char, _ in
            playedCharacters.append(char)
        }

        XCTAssertEqual(playedCharacters, ["A", " ", "B"])
    }

    func testPlayGroupWithNilCallback() async {
        let engine = MorseAudioEngine()

        await engine.playGroup("AB", onCharacterPlayed: nil)
    }

    // MARK: - stop Tests

    func testStop() async {
        let engine = MorseAudioEngine()

        engine.stop()

        // Subsequent plays should return immediately
        await engine.playDit()
    }

    func testStopDuringPlayback() async {
        let engine = MorseAudioEngine()

        // Start a long playback
        Task {
            await engine.playGroup("ABCDEFGHIJ")
        }

        // Stop immediately
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        engine.stop()
    }

    // MARK: - reset Tests

    func testReset() async {
        let engine = MorseAudioEngine()
        engine.stop()

        engine.reset()

        // Should be able to play again
        await engine.playDit()
    }

    func testResetAfterStop() async {
        let engine = MorseAudioEngine()
        engine.stop()

        // Verify stopped
        await engine.playDit() // Should return immediately

        engine.reset()

        // Now should play
        await engine.playDit()
    }

    // MARK: - Timing Tests

    func testTimingInitialization() {
        let timing = MorseAudioEngine.Timing(effectiveWPM: 12)

        XCTAssertEqual(timing.ditDuration, MorseCode.Timing.ditDuration)
        XCTAssertEqual(timing.dahDuration, MorseCode.Timing.dahDuration)
        XCTAssertEqual(timing.elementGap, MorseCode.Timing.elementGap)
    }

    func testTimingFarnsworthGaps() {
        let timing12 = MorseAudioEngine.Timing(effectiveWPM: 12)
        let timing15 = MorseAudioEngine.Timing(effectiveWPM: 15)

        // Slower effective speed = longer gaps
        XCTAssertGreaterThan(timing12.characterGap, timing15.characterGap)
        XCTAssertGreaterThan(timing12.wordGap, timing15.wordGap)
    }

    func testTimingWordGapGreaterThanCharacterGap() {
        let timing = MorseAudioEngine.Timing(effectiveWPM: 12)

        XCTAssertGreaterThan(timing.wordGap, timing.characterGap)
    }

    // MARK: - Tone Serialization Tests

    func testRapidDahsAreSerializedWithGap() async {
        let engine = MorseAudioEngine()
        let timing = MorseAudioEngine.Timing(effectiveWPM: 12)

        // Two dahs played back-to-back should take at least:
        // dahDuration + elementGap + dahDuration
        let expectedMinimum = timing.dahDuration * 2 + timing.elementGap
        let start = Date()

        // Fire both concurrently (simulates rapid button taps)
        async let first: Void = engine.playDah()
        async let second: Void = engine.playDah()
        _ = await (first, second)

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThanOrEqual(
            elapsed,
            expectedMinimum * 0.9, // 10% tolerance for scheduling jitter
            "Two rapid dahs should be serialized: expected ≥\(expectedMinimum)s, got \(elapsed)s"
        )
    }

    func testRapidDitDahSerializedWithGap() async {
        let engine = MorseAudioEngine()
        let timing = MorseAudioEngine.Timing(effectiveWPM: 12)

        let expectedMinimum = timing.ditDuration + timing.elementGap + timing.dahDuration
        let start = Date()

        async let first: Void = engine.playDit()
        async let second: Void = engine.playDah()
        _ = await (first, second)

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertGreaterThanOrEqual(
            elapsed,
            expectedMinimum * 0.9,
            "Dit then dah should be serialized: expected ≥\(expectedMinimum)s, got \(elapsed)s"
        )
    }

    func testSingleDahHasNoExtraGap() async {
        let engine = MorseAudioEngine()
        let timing = MorseAudioEngine.Timing(effectiveWPM: 12)

        let start = Date()
        await engine.playDah()
        let elapsed = Date().timeIntervalSince(start)

        // Should take approximately dahDuration, not dahDuration + elementGap
        let maxExpected = timing.dahDuration + timing.elementGap
        XCTAssertLessThan(
            elapsed,
            maxExpected,
            "Single dah should not include an element gap"
        )
    }

    func testResetClearsSerializationChain() async {
        let engine = MorseAudioEngine()
        let timing = MorseAudioEngine.Timing(effectiveWPM: 12)

        // Play a dah, then reset (simulates new character)
        await engine.playDah()
        engine.stop()
        engine.reset()

        // Next dah should NOT wait for or add a gap from the previous
        let start = Date()
        await engine.playDah()
        let elapsed = Date().timeIntervalSince(start)

        let maxExpected = timing.dahDuration + timing.elementGap
        XCTAssertLessThan(
            elapsed,
            maxExpected,
            "After reset, first dah should not include a stale element gap"
        )
    }
}

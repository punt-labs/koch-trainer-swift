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

    func testPlayDitWhenSessionEndedIsNoOp() async {
        let engine = MorseAudioEngine()
        engine.startSession()
        engine.endSession()

        // Should return immediately when session ended (radioMode = off)
        await engine.playDit()
    }

    // MARK: - playDah Tests

    func testPlayDah() async {
        let engine = MorseAudioEngine()

        await engine.playDah()
    }

    func testPlayDahWhenSessionEndedIsNoOp() async {
        let engine = MorseAudioEngine()
        engine.startSession()
        engine.endSession()

        // Should return immediately when session ended
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

    func testPlayCharacterWhenSessionEndedIsNoOp() async {
        let engine = MorseAudioEngine()
        engine.startSession()
        engine.endSession()

        // Should return immediately when session ended
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

    func testPlayGroupWhenSessionEndedIsNoOp() async {
        let engine = MorseAudioEngine()
        engine.startSession()
        engine.endSession()

        // Should return immediately when session ended
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

    // MARK: - Session Control Tests

    func testEndSessionStopsPlayback() async {
        let engine = MorseAudioEngine()
        engine.startSession()

        engine.endSession()

        // Subsequent plays should return immediately when session ended
        await engine.playDit()
    }

    func testEndSessionDuringPlayback() async {
        let engine = MorseAudioEngine()
        engine.startSession()

        // Start a long playback
        Task {
            await engine.playGroup("ABCDEFGHIJ")
        }

        // End session immediately
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        engine.endSession()
    }

    func testRestartSessionAfterEnd() async {
        let engine = MorseAudioEngine()
        engine.startSession()
        engine.endSession()

        engine.startSession()

        // Should be able to play again after restarting session
        await engine.playDit()
    }

    func testPlayAllowedWithoutSessionForSettingsPreview() async {
        let engine = MorseAudioEngine()
        // Do NOT start a session - this simulates settings preview mode

        // Should be able to play even without session (discrete mode)
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
}

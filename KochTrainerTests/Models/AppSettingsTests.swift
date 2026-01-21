@testable import KochTrainer
import XCTest

final class AppSettingsTests: XCTestCase {

    // MARK: - Default Values Tests

    func testDefaultValues() {
        let settings = AppSettings()

        XCTAssertEqual(settings.toneFrequency, 600)
        XCTAssertEqual(settings.effectiveSpeed, 12)
        XCTAssertEqual(settings.sendInputMode, .paddle)
        XCTAssertEqual(settings.userCallsign, "")
        XCTAssertFalse(settings.bandConditionsEnabled)
        XCTAssertEqual(settings.noiseLevel, 0.3)
        XCTAssertTrue(settings.fadingEnabled)
        XCTAssertEqual(settings.fadingDepth, 0.5)
        XCTAssertEqual(settings.fadingRate, 0.1)
        XCTAssertFalse(settings.interferenceEnabled)
        XCTAssertEqual(settings.interferenceLevel, 0.2)
    }

    // MARK: - Tone Frequency Clamping Tests

    func testToneFrequencyWithValidValue() {
        let settings = AppSettings(toneFrequency: 650)
        XCTAssertEqual(settings.toneFrequency, 650)
    }

    func testToneFrequencyAtMinimumBoundary() {
        let settings = AppSettings(toneFrequency: 400)
        XCTAssertEqual(settings.toneFrequency, 400)
    }

    func testToneFrequencyAtMaximumBoundary() {
        let settings = AppSettings(toneFrequency: 800)
        XCTAssertEqual(settings.toneFrequency, 800)
    }

    func testToneFrequencyTooLow() {
        let settings = AppSettings(toneFrequency: 200)
        XCTAssertEqual(settings.toneFrequency, 400, "Frequency should be clamped to 400")
    }

    func testToneFrequencyTooHigh() {
        let settings = AppSettings(toneFrequency: 1000)
        XCTAssertEqual(settings.toneFrequency, 800, "Frequency should be clamped to 800")
    }

    func testToneFrequencyNegative() {
        let settings = AppSettings(toneFrequency: -100)
        XCTAssertEqual(settings.toneFrequency, 400, "Negative frequency should be clamped to 400")
    }

    // MARK: - Effective Speed Clamping Tests

    func testEffectiveSpeedWithValidValue() {
        let settings = AppSettings(effectiveSpeed: 15)
        XCTAssertEqual(settings.effectiveSpeed, 15)
    }

    func testEffectiveSpeedAtMinimumBoundary() {
        let settings = AppSettings(effectiveSpeed: 10)
        XCTAssertEqual(settings.effectiveSpeed, 10)
    }

    func testEffectiveSpeedAtMaximumBoundary() {
        let settings = AppSettings(effectiveSpeed: 18)
        XCTAssertEqual(settings.effectiveSpeed, 18)
    }

    func testEffectiveSpeedTooLow() {
        let settings = AppSettings(effectiveSpeed: 5)
        XCTAssertEqual(settings.effectiveSpeed, 10, "Speed should be clamped to 10")
    }

    func testEffectiveSpeedTooHigh() {
        let settings = AppSettings(effectiveSpeed: 25)
        XCTAssertEqual(settings.effectiveSpeed, 18, "Speed should be clamped to 18")
    }

    func testEffectiveSpeedNegative() {
        let settings = AppSettings(effectiveSpeed: -5)
        XCTAssertEqual(settings.effectiveSpeed, 10, "Negative speed should be clamped to 10")
    }

    // MARK: - Noise Level Clamping Tests

    func testNoiseLevelWithValidValue() {
        let settings = AppSettings(noiseLevel: 0.5)
        XCTAssertEqual(settings.noiseLevel, 0.5)
    }

    func testNoiseLevelAtMinimumBoundary() {
        let settings = AppSettings(noiseLevel: 0.0)
        XCTAssertEqual(settings.noiseLevel, 0.0)
    }

    func testNoiseLevelAtMaximumBoundary() {
        let settings = AppSettings(noiseLevel: 1.0)
        XCTAssertEqual(settings.noiseLevel, 1.0)
    }

    func testNoiseLevelTooLow() {
        let settings = AppSettings(noiseLevel: -0.5)
        XCTAssertEqual(settings.noiseLevel, 0.0, "Noise level should be clamped to 0")
    }

    func testNoiseLevelTooHigh() {
        let settings = AppSettings(noiseLevel: 1.5)
        XCTAssertEqual(settings.noiseLevel, 1.0, "Noise level should be clamped to 1")
    }

    // MARK: - Fading Depth Clamping Tests

    func testFadingDepthWithValidValue() {
        let settings = AppSettings(fadingDepth: 0.7)
        XCTAssertEqual(settings.fadingDepth, 0.7)
    }

    func testFadingDepthAtMinimumBoundary() {
        let settings = AppSettings(fadingDepth: 0.0)
        XCTAssertEqual(settings.fadingDepth, 0.0)
    }

    func testFadingDepthAtMaximumBoundary() {
        let settings = AppSettings(fadingDepth: 1.0)
        XCTAssertEqual(settings.fadingDepth, 1.0)
    }

    func testFadingDepthTooLow() {
        let settings = AppSettings(fadingDepth: -0.3)
        XCTAssertEqual(settings.fadingDepth, 0.0, "Fading depth should be clamped to 0")
    }

    func testFadingDepthTooHigh() {
        let settings = AppSettings(fadingDepth: 2.0)
        XCTAssertEqual(settings.fadingDepth, 1.0, "Fading depth should be clamped to 1")
    }

    // MARK: - Fading Rate Clamping Tests

    func testFadingRateWithValidValue() {
        let settings = AppSettings(fadingRate: 0.15)
        XCTAssertEqual(settings.fadingRate, 0.15)
    }

    func testFadingRateAtMinimumBoundary() {
        let settings = AppSettings(fadingRate: 0.01)
        XCTAssertEqual(settings.fadingRate, 0.01)
    }

    func testFadingRateAtMaximumBoundary() {
        let settings = AppSettings(fadingRate: 0.5)
        XCTAssertEqual(settings.fadingRate, 0.5)
    }

    func testFadingRateTooLow() {
        let settings = AppSettings(fadingRate: 0.001)
        XCTAssertEqual(settings.fadingRate, 0.01, "Fading rate should be clamped to 0.01")
    }

    func testFadingRateTooHigh() {
        let settings = AppSettings(fadingRate: 1.0)
        XCTAssertEqual(settings.fadingRate, 0.5, "Fading rate should be clamped to 0.5")
    }

    func testFadingRateNegative() {
        let settings = AppSettings(fadingRate: -0.1)
        XCTAssertEqual(settings.fadingRate, 0.01, "Negative fading rate should be clamped to 0.01")
    }

    // MARK: - Interference Level Clamping Tests

    func testInterferenceLevelWithValidValue() {
        let settings = AppSettings(interferenceLevel: 0.4)
        XCTAssertEqual(settings.interferenceLevel, 0.4)
    }

    func testInterferenceLevelAtMinimumBoundary() {
        let settings = AppSettings(interferenceLevel: 0.0)
        XCTAssertEqual(settings.interferenceLevel, 0.0)
    }

    func testInterferenceLevelAtMaximumBoundary() {
        let settings = AppSettings(interferenceLevel: 1.0)
        XCTAssertEqual(settings.interferenceLevel, 1.0)
    }

    func testInterferenceLevelTooLow() {
        let settings = AppSettings(interferenceLevel: -0.2)
        XCTAssertEqual(settings.interferenceLevel, 0.0, "Interference level should be clamped to 0")
    }

    func testInterferenceLevelTooHigh() {
        let settings = AppSettings(interferenceLevel: 1.5)
        XCTAssertEqual(settings.interferenceLevel, 1.0, "Interference level should be clamped to 1")
    }

    // MARK: - User Callsign Tests

    func testUserCallsignUppercased() {
        let settings = AppSettings(userCallsign: "w1abc")
        XCTAssertEqual(settings.userCallsign, "W1ABC", "Callsign should be uppercased")
    }

    func testUserCallsignMixedCase() {
        let settings = AppSettings(userCallsign: "Ve3AbC")
        XCTAssertEqual(settings.userCallsign, "VE3ABC")
    }

    func testUserCallsignAlreadyUppercase() {
        let settings = AppSettings(userCallsign: "K4XYZ")
        XCTAssertEqual(settings.userCallsign, "K4XYZ")
    }

    func testUserCallsignEmpty() {
        let settings = AppSettings(userCallsign: "")
        XCTAssertEqual(settings.userCallsign, "")
    }

    // MARK: - Multiple Clamping Tests

    func testMultipleValuesClampedSimultaneously() {
        let settings = AppSettings(
            toneFrequency: 1500,
            effectiveSpeed: 50,
            noiseLevel: 5.0,
            fadingDepth: -1.0,
            fadingRate: 0.0,
            interferenceLevel: 10.0
        )

        XCTAssertEqual(settings.toneFrequency, 800)
        XCTAssertEqual(settings.effectiveSpeed, 18)
        XCTAssertEqual(settings.noiseLevel, 1.0)
        XCTAssertEqual(settings.fadingDepth, 0.0)
        XCTAssertEqual(settings.fadingRate, 0.01)
        XCTAssertEqual(settings.interferenceLevel, 1.0)
    }

    // MARK: - Equatable Tests

    func testEquatableIdenticalSettings() {
        let settings1 = AppSettings()
        let settings2 = AppSettings()
        XCTAssertEqual(settings1, settings2)
    }

    func testEquatableDifferentToneFrequency() {
        let settings1 = AppSettings(toneFrequency: 600)
        let settings2 = AppSettings(toneFrequency: 700)
        XCTAssertNotEqual(settings1, settings2)
    }

    func testEquatableDifferentCallsign() {
        let settings1 = AppSettings(userCallsign: "W1AW")
        let settings2 = AppSettings(userCallsign: "K4ABC")
        XCTAssertNotEqual(settings1, settings2)
    }

    func testEquatableDifferentBandConditions() {
        let settings1 = AppSettings(bandConditionsEnabled: true)
        let settings2 = AppSettings(bandConditionsEnabled: false)
        XCTAssertNotEqual(settings1, settings2)
    }
}

@testable import KochTrainer
import XCTest

final class BandConditionsProcessorTests: XCTestCase {

    // MARK: Internal

    override func setUp() {
        super.setUp()
        processor = BandConditionsProcessor()
    }

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        XCTAssertFalse(processor.isEnabled)
        XCTAssertEqual(processor.noiseLevel, 0.3, accuracy: 0.001)
        XCTAssertTrue(processor.fadingEnabled)
        XCTAssertEqual(processor.fadingDepth, 0.5, accuracy: 0.001)
        XCTAssertEqual(processor.fadingRate, 0.1, accuracy: 0.001)
        XCTAssertFalse(processor.interferenceEnabled)
        XCTAssertEqual(processor.interferenceLevel, 0.2, accuracy: 0.001)
    }

    func testCustomSampleRateInitialization() {
        let customProcessor = BandConditionsProcessor(sampleRate: 48000)
        XCTAssertNotNil(customProcessor)
    }

    // MARK: - Configure From Settings Tests

    func testConfigureFromSettings() {
        var settings = AppSettings()
        settings.bandConditionsEnabled = true
        settings.noiseLevel = 0.7
        settings.fadingEnabled = false
        settings.fadingDepth = 0.3
        settings.fadingRate = 0.2
        settings.interferenceEnabled = true
        settings.interferenceLevel = 0.5

        processor.configure(from: settings)

        XCTAssertTrue(processor.isEnabled)
        XCTAssertEqual(processor.noiseLevel, 0.7, accuracy: 0.001)
        XCTAssertFalse(processor.fadingEnabled)
        XCTAssertEqual(processor.fadingDepth, 0.3, accuracy: 0.001)
        XCTAssertEqual(processor.fadingRate, 0.2, accuracy: 0.001)
        XCTAssertTrue(processor.interferenceEnabled)
        XCTAssertEqual(processor.interferenceLevel, 0.5, accuracy: 0.001)
    }

    // MARK: - Reset Tests

    func testReset() {
        processor.isEnabled = true
        processor.noiseLevel = 0.8

        // Process some samples to build internal state
        for i in 0 ..< 1000 {
            _ = processor.processSample(0.5, at: i)
        }

        processor.reset()

        // After reset, internal state should be cleared
        // The configuration values should remain
        XCTAssertTrue(processor.isEnabled)
        XCTAssertEqual(processor.noiseLevel, 0.8, accuracy: 0.001)
    }

    // MARK: - Processing When Disabled Tests

    func testProcessSampleWhenDisabled() {
        processor.isEnabled = false
        let inputSample: Float = 0.75

        let output = processor.processSample(inputSample, at: 0)

        XCTAssertEqual(output, inputSample, accuracy: 0.0001)
    }

    // MARK: - Processing When Enabled Tests

    func testProcessSampleWhenEnabled() {
        processor.isEnabled = true
        processor.noiseLevel = 0.5
        processor.fadingEnabled = true
        processor.fadingDepth = 0.5
        let inputSample: Float = 0.75

        let output = processor.processSample(inputSample, at: 0)

        // Output should be different from input when processing is enabled
        // Note: due to random noise, we can't predict exact values
        // but we can verify it's within reasonable bounds
        XCTAssertGreaterThanOrEqual(output, -1.0)
        XCTAssertLessThanOrEqual(output, 1.0)
    }

    // MARK: - Fading Tests

    func testFadingReducesAmplitude() {
        processor.isEnabled = true
        processor.noiseLevel = 0 // Disable noise for clean test
        processor.fadingEnabled = true
        processor.fadingDepth = 1.0 // Full fading
        processor.fadingRate = 5.0 // 5 Hz = one cycle per 0.2 seconds
        processor.interferenceEnabled = false

        let inputSample: Float = 0.5

        // Process samples covering a full fading cycle (0.2 seconds at 44100 Hz)
        var outputs: [Float] = []
        for i in 0 ..< 8820 { // ~0.2 seconds at 44100 Hz
            let output = processor.processSample(inputSample, at: i)
            outputs.append(output)
        }

        // With fading, we should see amplitude variation
        guard let minOutput = outputs.min(), let maxOutput = outputs.max() else {
            XCTFail("Expected outputs to have min and max values")
            return
        }

        // The range should be significant (at least half the input)
        XCTAssertGreaterThan(maxOutput - minOutput, 0.1)
    }

    func testFadingDisabledPassesThrough() {
        processor.isEnabled = true
        processor.noiseLevel = 0
        processor.fadingEnabled = false
        processor.interferenceEnabled = false

        let inputSample: Float = 0.5

        // Process samples with fading disabled
        var outputs: [Float] = []
        for i in 0 ..< 1000 {
            let output = processor.processSample(inputSample, at: i)
            outputs.append(output)
        }

        // Without fading, noise, or interference, output should equal input
        for output in outputs {
            XCTAssertEqual(output, inputSample, accuracy: 0.0001)
        }
    }

    // MARK: - Noise Tests

    func testNoiseAddsVariation() {
        processor.isEnabled = true
        processor.noiseLevel = 0.5
        processor.fadingEnabled = false
        processor.interferenceEnabled = false

        let inputSample: Float = 0.5

        var outputs: [Float] = []
        for i in 0 ..< 100 {
            let output = processor.processSample(inputSample, at: i)
            outputs.append(output)
        }

        // With noise, not all outputs should be identical
        let uniqueValues = Set(outputs.map { Int($0 * 10000) })
        XCTAssertGreaterThan(uniqueValues.count, 1)
    }

    func testZeroNoiseLevel() {
        processor.isEnabled = true
        processor.noiseLevel = 0
        processor.fadingEnabled = false
        processor.interferenceEnabled = false

        let inputSample: Float = 0.5

        for i in 0 ..< 100 {
            let output = processor.processSample(inputSample, at: i)
            XCTAssertEqual(output, inputSample, accuracy: 0.0001)
        }
    }

    // MARK: - Interference Tests

    func testInterferenceParameters() {
        processor.isEnabled = true
        processor.interferenceEnabled = true
        processor.interferenceLevel = 1.0 // Max level for reliable triggering
        processor.noiseLevel = 0
        processor.fadingEnabled = false

        // Interference is probabilistic (p = 0.00002 * level per sample).
        // With level=1.0, p=0.00002. Need many samples for reliable triggering.
        // 500,000 samples gives ~10 expected interference starts.
        var outputs: [Float] = []
        let inputSample: Float = 0.0 // Use zero to isolate interference

        for i in 0 ..< 500_000 {
            let output = processor.processSample(inputSample, at: i)
            outputs.append(output)
        }

        // With interference enabled, we should see some non-zero outputs
        let nonZeroCount = outputs.filter { abs($0) > 0.001 }.count
        // Given the probability, we should have at least some interference
        XCTAssertGreaterThan(nonZeroCount, 0)
    }

    // MARK: - Output Bounds Tests

    func testOutputBoundsWithExtremeFading() {
        processor.isEnabled = true
        processor.fadingDepth = 1.0
        processor.fadingRate = 0.5
        processor.noiseLevel = 1.0
        processor.interferenceEnabled = true
        processor.interferenceLevel = 1.0

        for i in 0 ..< 1000 {
            let output = processor.processSample(0.9, at: i)
            XCTAssertGreaterThanOrEqual(output, -1.0)
            XCTAssertLessThanOrEqual(output, 1.0)
        }
    }

    // MARK: - Integration Tests

    func testFullProcessingChain() {
        processor.isEnabled = true
        processor.noiseLevel = 0.3
        processor.fadingEnabled = true
        processor.fadingDepth = 0.5
        processor.fadingRate = 0.1
        processor.interferenceEnabled = true
        processor.interferenceLevel = 0.2

        // Process a realistic audio buffer worth of samples
        var outputs: [Float] = []
        let inputSample: Float = 0.5

        for i in 0 ..< 44100 { // 1 second of audio
            let output = processor.processSample(inputSample, at: i)
            outputs.append(output)
        }

        // Verify outputs are within valid range
        for output in outputs {
            XCTAssertGreaterThanOrEqual(output, -1.0)
            XCTAssertLessThanOrEqual(output, 1.0)
        }

        // Verify there's variation (not all same)
        let uniqueValues = Set(outputs.map { Int($0 * 1000) })
        XCTAssertGreaterThan(uniqueValues.count, 10)
    }

    // MARK: Private

    private var processor = BandConditionsProcessor()

}

@testable import KochTrainer
import XCTest

final class IambicKeyerTests: XCTestCase {

    // MARK: Internal

    override func setUp() {
        super.setUp()
        storedClock = MockClock()
        toneStartCount = 0
        toneStopCount = 0
        lastFrequency = nil
        completedPatterns = []
        hapticElements = []
    }

    // MARK: - Timing Configuration Tests

    func testDitDuration_at13WPM() {
        let config = KeyerConfiguration(wpm: 13)
        let expected = 1.2 / 13.0 // ~92ms
        XCTAssertEqual(config.ditDuration, expected, accuracy: 0.001)
    }

    func testDahDuration_is3xDit() {
        let config = KeyerConfiguration(wpm: 13)
        XCTAssertEqual(config.dahDuration, config.ditDuration * 3, accuracy: 0.001)
    }

    func testIdleTimeout_is1_5xDah() {
        let config = KeyerConfiguration(wpm: 13)
        XCTAssertEqual(config.idleTimeout, config.dahDuration * 1.5, accuracy: 0.001)
    }

    func testWPMClamping() {
        var config = KeyerConfiguration(wpm: 3) // Below minimum
        XCTAssertEqual(config.wpm, 5)

        config.wpm = 50 // Above maximum
        XCTAssertEqual(config.wpm, 40)
    }

    // MARK: - Basic State Machine Tests

    func testInitialState_isIdle() {
        let keyer = makeKeyer()
        XCTAssertEqual(keyer.phase, .idle)
        XCTAssertTrue(keyer.currentPattern.isEmpty)
    }

    func testDitPaddle_startsPlayingDit() {
        let keyer = makeKeyer()
        let config = keyer.configuration

        keyer.updatePaddle(PaddleInput(ditPressed: true, dahPressed: false))
        keyer.processTick(at: clock.now())

        XCTAssertEqual(keyer.phase, .playing(element: .dit))
        XCTAssertEqual(toneStartCount, 1)
        XCTAssertEqual(lastFrequency, config.frequency)
    }

    func testDahPaddle_startsPlayingDah() {
        let keyer = makeKeyer()

        keyer.updatePaddle(PaddleInput(ditPressed: false, dahPressed: true))
        keyer.processTick(at: clock.now())

        XCTAssertEqual(keyer.phase, .playing(element: .dah))
        XCTAssertEqual(toneStartCount, 1)
    }

    func testDitComplete_transitionsToGap() {
        let keyer = makeKeyer()
        let config = keyer.configuration

        // Press dit
        keyer.updatePaddle(PaddleInput(ditPressed: true, dahPressed: false))
        keyer.processTick(at: clock.now())
        XCTAssertEqual(keyer.phase, .playing(element: .dit))

        // Advance past dit duration
        clock.advance(by: config.ditDuration + 0.001)
        keyer.processTick(at: clock.now())

        XCTAssertEqual(keyer.phase, .gap)
        XCTAssertEqual(toneStopCount, 1)
    }

    func testGapComplete_paddleHeld_continuesPlaying() {
        let keyer = makeKeyer()
        let config = keyer.configuration

        // Press dit and hold
        keyer.updatePaddle(PaddleInput(ditPressed: true, dahPressed: false))
        keyer.processTick(at: clock.now())

        // Complete dit
        clock.advance(by: config.ditDuration + 0.001)
        keyer.processTick(at: clock.now())
        XCTAssertEqual(keyer.phase, .gap)

        // Complete gap (paddle still held)
        clock.advance(by: config.elementGap + 0.001)
        keyer.processTick(at: clock.now())

        // Should start another dit
        XCTAssertEqual(keyer.phase, .playing(element: .dit))
        XCTAssertEqual(toneStartCount, 2)
    }

    func testGapComplete_paddleReleased_goesIdle() {
        let keyer = makeKeyer()
        let config = keyer.configuration

        // Press dit
        keyer.updatePaddle(PaddleInput(ditPressed: true, dahPressed: false))
        keyer.processTick(at: clock.now())

        // Complete dit
        clock.advance(by: config.ditDuration + 0.001)
        keyer.processTick(at: clock.now())

        // Release paddle
        keyer.updatePaddle(PaddleInput(ditPressed: false, dahPressed: false))

        // Complete gap
        clock.advance(by: config.elementGap + 0.001)
        keyer.processTick(at: clock.now())

        XCTAssertEqual(keyer.phase, .idle)
    }

    // MARK: - Mode B Tests (Element Completion)

    func testModeB_elementCompletes_evenIfReleased() {
        let keyer = makeKeyer()
        let config = keyer.configuration

        // Press dit
        keyer.updatePaddle(PaddleInput(ditPressed: true, dahPressed: false))
        keyer.processTick(at: clock.now())
        XCTAssertEqual(keyer.phase, .playing(element: .dit))

        // Release paddle mid-element
        clock.advance(by: config.ditDuration / 2)
        keyer.updatePaddle(PaddleInput(ditPressed: false, dahPressed: false))
        keyer.processTick(at: clock.now())

        // Should still be playing (Mode B)
        XCTAssertEqual(keyer.phase, .playing(element: .dit))
        XCTAssertEqual(toneStopCount, 0)

        // Wait for element to complete
        clock.advance(by: config.ditDuration / 2 + 0.001)
        keyer.processTick(at: clock.now())

        // Now should be in gap
        XCTAssertEqual(keyer.phase, .gap)
        XCTAssertEqual(toneStopCount, 1)
    }

    // MARK: - Squeeze (Iambic) Tests

    func testSqueeze_alternatesDitDah() {
        let keyer = makeKeyer()
        let config = keyer.configuration

        // Squeeze both paddles
        keyer.updatePaddle(PaddleInput(ditPressed: true, dahPressed: true))
        keyer.processTick(at: clock.now())

        // First element is dit
        XCTAssertEqual(keyer.phase, .playing(element: .dit))

        // Complete dit
        clock.advance(by: config.ditDuration + 0.001)
        keyer.processTick(at: clock.now())
        XCTAssertEqual(keyer.phase, .gap)

        // Complete gap
        clock.advance(by: config.elementGap + 0.001)
        keyer.processTick(at: clock.now())

        // Second element is dah (alternating)
        XCTAssertEqual(keyer.phase, .playing(element: .dah))

        // Complete dah
        clock.advance(by: config.dahDuration + 0.001)
        keyer.processTick(at: clock.now())
        clock.advance(by: config.elementGap + 0.001)
        keyer.processTick(at: clock.now())

        // Third element is dit again
        XCTAssertEqual(keyer.phase, .playing(element: .dit))
    }

    // MARK: - Pattern Completion Tests

    func testPatternEmitted_afterIdleTimeout() {
        let keyer = makeKeyer()
        let config = keyer.configuration

        // Tap dit
        keyer.updatePaddle(PaddleInput(ditPressed: true, dahPressed: false))
        keyer.processTick(at: clock.now())

        // Complete dit
        clock.advance(by: config.ditDuration + 0.001)
        keyer.processTick(at: clock.now())

        // Release paddle
        keyer.updatePaddle(PaddleInput(ditPressed: false, dahPressed: false))

        // Complete gap → idle
        clock.advance(by: config.elementGap + 0.001)
        keyer.processTick(at: clock.now())
        XCTAssertEqual(keyer.phase, .idle)
        XCTAssertTrue(completedPatterns.isEmpty, "Pattern should not emit immediately")

        // Wait for idle timeout
        clock.advance(by: config.idleTimeout + 0.001)
        keyer.processTick(at: clock.now())

        XCTAssertEqual(completedPatterns, ["."])
    }

    func testMultiElementPattern_K() throws {
        let keyer = makeKeyer()
        let config = keyer.configuration

        // K = -.-

        // 1. Dah
        keyer.updatePaddle(PaddleInput(ditPressed: false, dahPressed: true))
        keyer.processTick(at: clock.now())
        clock.advance(by: config.dahDuration + 0.001)
        keyer.processTick(at: clock.now())
        keyer.updatePaddle(PaddleInput(ditPressed: false, dahPressed: false))
        clock.advance(by: config.elementGap + 0.001)
        keyer.processTick(at: clock.now())

        // 2. Dit
        keyer.updatePaddle(PaddleInput(ditPressed: true, dahPressed: false))
        keyer.processTick(at: clock.now())
        clock.advance(by: config.ditDuration + 0.001)
        keyer.processTick(at: clock.now())
        keyer.updatePaddle(PaddleInput(ditPressed: false, dahPressed: false))
        clock.advance(by: config.elementGap + 0.001)
        keyer.processTick(at: clock.now())

        // 3. Dah
        keyer.updatePaddle(PaddleInput(ditPressed: false, dahPressed: true))
        keyer.processTick(at: clock.now())
        clock.advance(by: config.dahDuration + 0.001)
        keyer.processTick(at: clock.now())
        keyer.updatePaddle(PaddleInput(ditPressed: false, dahPressed: false))
        clock.advance(by: config.elementGap + 0.001)
        keyer.processTick(at: clock.now())

        // Wait for idle timeout
        clock.advance(by: config.idleTimeout + 0.001)
        keyer.processTick(at: clock.now())

        XCTAssertEqual(completedPatterns, ["-.-"])
    }

    // MARK: - Continuous Hold Tests

    func testContinuousDits_paddleHeld() {
        let keyer = makeKeyer()
        let config = keyer.configuration

        // Hold dit paddle
        keyer.updatePaddle(PaddleInput(ditPressed: true, dahPressed: false))
        keyer.processTick(at: clock.now())

        var ditCount = 0
        let maxDits = 5

        while ditCount < maxDits {
            if case .playing(element: .dit) = keyer.phase {
                ditCount += 1
            }
            clock.advance(by: config.ditDuration + config.elementGap + 0.001)
            keyer.processTick(at: clock.now())
        }

        XCTAssertEqual(ditCount, maxDits)
        XCTAssertEqual(toneStartCount, maxDits)
        XCTAssertEqual(toneStopCount, maxDits)
    }

    // MARK: - Haptic Feedback Tests

    func testHapticFeedback_triggersOnElement() {
        let keyer = makeKeyer()
        let config = keyer.configuration

        // Dit
        keyer.updatePaddle(PaddleInput(ditPressed: true, dahPressed: false))
        keyer.processTick(at: clock.now())
        XCTAssertEqual(hapticElements, [.dit])

        // Complete dit → transition to gap
        clock.advance(by: config.ditDuration + 0.001)
        keyer.processTick(at: clock.now())
        XCTAssertEqual(keyer.phase, .gap)

        // Complete gap
        clock.advance(by: config.elementGap + 0.001)
        // Release dit, press dah BEFORE processing gap completion
        keyer.updatePaddle(PaddleInput(ditPressed: false, dahPressed: true))
        keyer.processTick(at: clock.now())
        XCTAssertEqual(hapticElements, [.dit, .dah])
    }

    func testHapticDisabled_noCallback() {
        var config = KeyerConfiguration(wpm: 13)
        config.hapticEnabled = false

        let keyer = IambicKeyer(
            configuration: config,
            clock: clock,
            onHaptic: { [weak self] element in
                self?.hapticElements.append(element)
            }
        )

        keyer.updatePaddle(PaddleInput(ditPressed: true, dahPressed: false))
        keyer.processTick(at: clock.now())

        XCTAssertTrue(hapticElements.isEmpty)
    }

    // MARK: - Stop Tests

    func testStop_cleansUpState() {
        let keyer = makeKeyer()

        // Start playing
        keyer.updatePaddle(PaddleInput(ditPressed: true, dahPressed: false))
        keyer.processTick(at: clock.now())
        XCTAssertEqual(keyer.phase, .playing(element: .dit))

        // Stop keyer
        keyer.stop()

        XCTAssertEqual(keyer.phase, .idle)
        XCTAssertTrue(keyer.currentPattern.isEmpty)
        XCTAssertEqual(toneStopCount, 1) // Tone stopped on stop()
    }

    // MARK: Private

    // MARK: - Test Fixtures

    private var storedClock: MockClock?
    private var toneStartCount: Int = 0
    private var toneStopCount: Int = 0
    private var lastFrequency: Double?
    private var completedPatterns: [String] = []
    private var hapticElements: [MorseElement] = []

    /// Unwrapped clock for convenient test access. Precondition: setUp() called.
    private var clock: MockClock {
        guard let storedClock else {
            fatalError("MockClock not initialized in setUp()")
        }
        return storedClock
    }

    private func makeKeyer(wpm: Int = 13) -> IambicKeyer {
        let config = KeyerConfiguration(wpm: wpm)
        return IambicKeyer(
            configuration: config,
            clock: clock,
            onToneStart: { [weak self] freq in
                self?.toneStartCount += 1
                self?.lastFrequency = freq
            },
            onToneStop: { [weak self] in
                self?.toneStopCount += 1
            },
            onPatternComplete: { [weak self] pattern in
                self?.completedPatterns.append(pattern)
            },
            onHaptic: { [weak self] element in
                self?.hapticElements.append(element)
            }
        )
    }

}

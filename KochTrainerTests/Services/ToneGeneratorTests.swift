@testable import KochTrainer
import XCTest

final class ToneGeneratorTests: XCTestCase {

    // MARK: - Sequential Playback Tests (Race Condition Fix)

    /// Verifies that rapid consecutive tone requests are all processed sequentially,
    /// not dropped due to race conditions.
    func testRapidToneRequestsAreAllProcessed() async {
        let toneGenerator = ToneGenerator()
        let toneCount = 5
        let toneDuration: TimeInterval = 0.05 // 50ms each

        let startTime = Date()

        // Fire multiple tone requests rapidly (simulating rapid key presses)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< toneCount {
                group.addTask {
                    await toneGenerator.playTone(frequency: 600, duration: toneDuration)
                }
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // If tones are queued sequentially, total time should be at least toneCount * toneDuration
        // Allow some margin for scheduling overhead
        let minimumExpectedTime = Double(toneCount) * toneDuration * 0.8 // 80% of expected
        XCTAssertGreaterThan(
            elapsed,
            minimumExpectedTime,
            "Elapsed time (\(elapsed)s) suggests tones were skipped. Expected at least \(minimumExpectedTime)s for \(toneCount) sequential tones."
        )
    }

    /// Verifies that the serial queue prevents tone overlap - each tone completes before next starts.
    func testTonesPlaySequentiallyNotConcurrently() async {
        let toneGenerator = ToneGenerator()
        let toneDuration: TimeInterval = 0.1 // 100ms each

        let startTime = Date()

        // Request 3 tones simultaneously
        async let tone1: () = toneGenerator.playTone(frequency: 600, duration: toneDuration)
        async let tone2: () = toneGenerator.playTone(frequency: 600, duration: toneDuration)
        async let tone3: () = toneGenerator.playTone(frequency: 600, duration: toneDuration)

        _ = await (tone1, tone2, tone3)

        let elapsed = Date().timeIntervalSince(startTime)

        // If concurrent, would take ~100ms. If sequential, should take ~300ms.
        // Use 200ms as threshold (allows for some variance but confirms sequential behavior)
        XCTAssertGreaterThan(
            elapsed,
            0.2,
            "Elapsed time (\(elapsed)s) suggests tones played concurrently instead of sequentially."
        )
    }

    /// Simulates the exact pattern that caused the original bug: rapid alternating inputs (jfj or fjf).
    func testRapidAlternatingInputPattern() async {
        let toneGenerator = ToneGenerator()
        let ditDuration: TimeInterval = 0.06 // 60ms (dit at 20 WPM)
        let dahDuration: TimeInterval = 0.18 // 180ms (dah at 20 WPM)

        var completedTones = 0
        let expectedTones = 3

        let startTime = Date()

        // Simulate "jfj" pattern: dah-dit-dah
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await toneGenerator.playTone(frequency: 600, duration: dahDuration)
                completedTones += 1
            }
            group.addTask {
                await toneGenerator.playTone(frequency: 600, duration: ditDuration)
                completedTones += 1
            }
            group.addTask {
                await toneGenerator.playTone(frequency: 600, duration: dahDuration)
                completedTones += 1
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // All tones should complete
        XCTAssertEqual(
            completedTones,
            expectedTones,
            "Expected \(expectedTones) tones to complete, but only \(completedTones) did."
        )

        // Total time should reflect all three tones played: 180 + 60 + 180 = 420ms minimum
        let minimumExpectedTime = (dahDuration + ditDuration + dahDuration) * 0.8
        XCTAssertGreaterThan(
            elapsed,
            minimumExpectedTime,
            "Elapsed time (\(elapsed)s) suggests some tones were dropped."
        )
    }

    // MARK: - Basic Functionality Tests

    func testPlayToneCompletesWithinExpectedTime() async {
        let toneGenerator = ToneGenerator()
        let duration: TimeInterval = 0.1

        let startTime = Date()
        await toneGenerator.playTone(frequency: 600, duration: duration)
        let elapsed = Date().timeIntervalSince(startTime)

        // Should complete in roughly the specified duration
        // Allow extra overhead for audio engine startup on first call
        XCTAssertGreaterThan(elapsed, duration * 0.9, "Tone completed too quickly")
        XCTAssertLessThan(elapsed, duration * 3.0, "Tone took too long (>3x expected)")
    }

    func testPlaySilenceCompletesWithinExpectedTime() async {
        let toneGenerator = ToneGenerator()
        let duration: TimeInterval = 0.1

        let startTime = Date()
        await toneGenerator.playSilence(duration: duration)
        let elapsed = Date().timeIntervalSince(startTime)

        XCTAssertGreaterThan(elapsed, duration * 0.9, "Silence completed too quickly")
        XCTAssertLessThan(elapsed, duration * 1.5, "Silence took too long")
    }

    func testStopToneIsIdempotent() {
        let toneGenerator = ToneGenerator()

        // Calling stop when not playing should not crash
        toneGenerator.stopTone()
        toneGenerator.stopTone()
        toneGenerator.stopTone()

        // If we get here without crashing, test passes
    }

    func testStartAndStopTone() {
        let toneGenerator = ToneGenerator()

        // Start tone
        toneGenerator.startTone(frequency: 600)

        // Give it a moment to start
        Thread.sleep(forTimeInterval: 0.05)

        // Stop tone
        toneGenerator.stopTone()

        // Should be able to start again after stopping
        toneGenerator.startTone(frequency: 700)
        Thread.sleep(forTimeInterval: 0.05)
        toneGenerator.stopTone()

        // If we get here without crashing, test passes
    }
}

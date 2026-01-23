import XCTest

/// Page object for ear training UI tests.
/// Extends TrainingPage with dit/dah input and level display accessors.
/// Ear training plays a pattern and the user reproduces it with dit/dah buttons.
final class EarTrainingPage: TrainingPage, MorseInputPage {

    // MARK: - Ear Training Specific Elements

    /// Dit button for tapping short tones.
    var ditButton: XCUIElement {
        button(id: "send-dit-button")
    }

    /// Dah button for tapping long tones.
    var dahButton: XCUIElement {
        button(id: "send-dah-button")
    }

    /// Pattern display showing the user's current input.
    var patternDisplay: XCUIElement {
        staticText(id: "send-pattern-display")
    }

    // MARK: - Pattern Verification

    /// Get the current pattern text.
    var currentPatternText: String {
        patternDisplay.label
    }

    // MARK: - Feedback Verification

    /// Check if correct feedback is displayed.
    var showsCorrectFeedback: Bool {
        feedbackCorrect.exists
    }

    /// Check if incorrect feedback is displayed.
    var showsIncorrectFeedback: Bool {
        feedbackIncorrect.exists
    }

    // MARK: - Waiting for Audio

    /// Brief delay to allow audio pattern to start playing.
    /// Note: This is a fixed delay, not a true wait on UI state.
    @discardableResult
    func waitForPatternToPlay(timeout: TimeInterval = 3) -> Self {
        usleep(UInt32(timeout * 1_000_000))
        return self
    }

    /// Wait until input is accepted (buttons become active).
    @discardableResult
    func waitForInputReady(timeout: TimeInterval = 5) -> Self {
        // Wait for dit button to be hittable
        _ = ditButton.waitForExistence(timeout: timeout)
        return self
    }

    /// Assert the pattern display shows the expected pattern.
    func assertPattern(_ expected: String) {
        XCTAssertEqual(currentPatternText, expected, "Pattern should be '\(expected)'")
    }

    /// Assert the pattern display is empty.
    func assertPatternEmpty() {
        let text = currentPatternText.trimmingCharacters(in: .whitespaces)
        XCTAssertTrue(text.isEmpty, "Pattern should be empty")
    }

    /// Assert correct feedback is shown.
    func assertCorrectFeedback() {
        XCTAssertTrue(showsCorrectFeedback, "Should show correct feedback")
    }

    /// Assert incorrect feedback is shown.
    func assertIncorrectFeedback() {
        XCTAssertTrue(showsIncorrectFeedback, "Should show incorrect feedback")
    }

    // MARK: - Combined Actions

    /// Reproduce a pattern after hearing it.
    /// Waits briefly for audio to finish, then inputs the pattern.
    @discardableResult
    func reproducePattern(_ pattern: String, waitTime: TimeInterval = 1) -> Self {
        Thread.sleep(forTimeInterval: waitTime)
        _ = inputPattern(pattern)
        return self
    }

    /// Send an incorrect pattern.
    @discardableResult
    func sendIncorrectPattern() -> Self {
        // Send a pattern that won't match
        _ = inputPattern("..--..--")
        return self
    }

    /// Wait for the input timeout to complete (pattern submission).
    @discardableResult
    func waitForPatternSubmission(timeout: TimeInterval = 3) -> Self {
        Thread.sleep(forTimeInterval: timeout)
        return self
    }
}

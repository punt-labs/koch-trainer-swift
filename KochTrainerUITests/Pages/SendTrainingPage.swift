import XCTest

/// Page object for send training UI tests.
/// Extends TrainingPage with dit/dah button accessors, pattern display, and keyboard input.
final class SendTrainingPage: TrainingPage, MorseInputPage {

    // MARK: - Send-Specific Elements

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

    /// Keyboard hint text.
    var keyboardHint: XCUIElement {
        staticText(id: "send-keyboard-hint")
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

    // MARK: - Pattern Input

    /// Input the correct pattern for a character using the test pattern table.
    @discardableResult
    func inputCorrectPattern(for char: Character) -> Self {
        if let pattern = MorsePatterns.pattern(for: char) {
            _ = inputPattern(pattern)
        }
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

    /// Send the correct pattern for a character.
    @discardableResult
    func sendCorrectPattern(for char: Character) -> Self {
        inputCorrectPattern(for: char)
    }

    /// Send an incorrect pattern.
    @discardableResult
    func sendIncorrectPattern() -> Self {
        // Send a pattern that won't match any character
        _ = inputPattern("..--..--")
        return self
    }

    /// Wait for feedback to appear after pattern submission.
    @discardableResult
    func waitForFeedback(timeout: TimeInterval = 5) -> Self {
        // Wait until feedback appears rather than sleeping
        _ = feedbackCorrect.waitForExistence(timeout: timeout)
            || feedbackIncorrect.waitForExistence(timeout: 0.1)
        return self
    }
}

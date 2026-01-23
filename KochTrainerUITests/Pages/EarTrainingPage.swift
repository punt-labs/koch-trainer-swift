import XCTest

/// Page object for ear training UI tests.
/// Extends TrainingPage with dit/dah input and level display accessors.
/// Ear training plays a pattern and the user reproduces it with dit/dah buttons.
final class EarTrainingPage: TrainingPage {

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

    // MARK: - Button Actions

    /// Tap the dit button.
    @discardableResult
    func tapDit() -> Self {
        ditButton.tap()
        return self
    }

    /// Tap the dah button.
    @discardableResult
    func tapDah() -> Self {
        dahButton.tap()
        return self
    }

    /// Tap dit multiple times.
    @discardableResult
    func tapDit(count: Int) -> Self {
        for _ in 0 ..< count {
            tapDit()
            usleep(50000) // 50ms between taps
        }
        return self
    }

    /// Tap dah multiple times.
    @discardableResult
    func tapDah(count: Int) -> Self {
        for _ in 0 ..< count {
            tapDah()
            usleep(50000) // 50ms between taps
        }
        return self
    }

    // MARK: - Keyboard Input

    /// Type dit using keyboard (. or F).
    @discardableResult
    func typeDit() -> Self {
        app.typeText(".")
        return self
    }

    /// Type dah using keyboard (- or J).
    @discardableResult
    func typeDah() -> Self {
        app.typeText("-")
        return self
    }

    // MARK: - Pattern Input

    /// Input a Morse pattern using dit/dah buttons.
    /// Pattern should be a string of '.' (dit) and '-' (dah).
    @discardableResult
    func inputPattern(_ pattern: String) -> Self {
        for element in pattern {
            switch element {
            case ".":
                tapDit()
            case "-":
                tapDah()
            default:
                break // Ignore spaces or other characters
            }
            usleep(50000) // 50ms between elements
        }
        return self
    }

    /// Input a Morse pattern using keyboard.
    @discardableResult
    func typePattern(_ pattern: String) -> Self {
        app.typeText(pattern)
        return self
    }

    // MARK: - Waiting for Audio

    /// Wait for the audio pattern to finish playing.
    /// In ear training, audio plays first, then user reproduces it.
    @discardableResult
    func waitForPatternToPlay(timeout: TimeInterval = 3) -> Self {
        // Wait for the "Reproduce the pattern" prompt or input timeout bar
        usleep(UInt32(timeout * 500_000)) // Half the timeout as estimate
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
        inputPattern(pattern)
        return self
    }

    /// Send an incorrect pattern.
    @discardableResult
    func sendIncorrectPattern() -> Self {
        // Send a pattern that won't match
        inputPattern("..--..--")
        return self
    }

    /// Wait for the input timeout to complete (pattern submission).
    @discardableResult
    func waitForPatternSubmission(timeout: TimeInterval = 3) -> Self {
        Thread.sleep(forTimeInterval: timeout)
        return self
    }
}

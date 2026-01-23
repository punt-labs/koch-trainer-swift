import XCTest

/// Page object for receive training UI tests.
/// Extends TrainingPage with keyboard input simulation and feedback verification.
final class ReceiveTrainingPage: TrainingPage {

    // MARK: - Feedback Verification

    /// Check if correct feedback is displayed.
    var showsCorrectFeedback: Bool {
        feedbackCorrect.exists
    }

    /// Check if incorrect feedback is displayed.
    var showsIncorrectFeedback: Bool {
        feedbackIncorrect.exists
    }

    /// Check if timeout feedback is displayed.
    var showsTimeoutFeedback: Bool {
        feedbackTimeout.exists
    }

    // MARK: - Keyboard Input

    /// Type a character using keyboard input.
    /// In receive training, users hear Morse and type the letter.
    @discardableResult
    func typeCharacter(_ char: Character) -> Self {
        app.typeText(String(char))
        return self
    }

    /// Type multiple characters in sequence.
    @discardableResult
    func typeCharacters(_ chars: String) -> Self {
        for char in chars {
            typeCharacter(char)
            usleep(100_000) // 100ms between inputs
        }
        return self
    }

    // MARK: - Waiting for Audio

    /// Wait for audio to finish playing (indicated by "?" prompt).
    /// Returns self for chaining.
    @discardableResult
    func waitForPrompt(timeout: TimeInterval = 5) -> Self {
        // The "?" character appears when waiting for user response
        let predicate = NSPredicate(format: "label CONTAINS '?'")
        let questionMark = app.staticTexts.matching(predicate).firstMatch
        _ = questionMark.waitForExistence(timeout: timeout)
        return self
    }

    /// Brief delay to allow audio to start playing.
    /// Note: This is a fixed 200ms delay, not a true wait on UI state.
    @discardableResult
    func waitForListening() -> Self {
        usleep(200_000) // 200ms
        return self
    }

    /// Assert correct feedback is shown.
    func assertCorrectFeedback() {
        XCTAssertTrue(showsCorrectFeedback, "Should show correct feedback")
    }

    /// Assert incorrect feedback is shown.
    func assertIncorrectFeedback() {
        XCTAssertTrue(showsIncorrectFeedback, "Should show incorrect feedback")
    }

    /// Assert timeout feedback is shown.
    func assertTimeoutFeedback() {
        XCTAssertTrue(showsTimeoutFeedback, "Should show timeout feedback")
    }

    // MARK: - Combined Actions

    /// Wait for prompt and answer with the given character.
    @discardableResult
    func answerWith(_ char: Character, waitTimeout: TimeInterval = 5) -> Self {
        waitForPrompt(timeout: waitTimeout)
        typeCharacter(char)
        return self
    }

    /// Answer correctly by typing the character currently being tested.
    /// Note: This requires knowing what character is expected.
    @discardableResult
    func answerCorrectly(with char: Character) -> Self {
        waitForPrompt()
        typeCharacter(char)
        return self
    }

    /// Answer incorrectly by typing a wrong character.
    @discardableResult
    func answerIncorrectly(expected: Character) -> Self {
        waitForPrompt()
        // Type a character different from expected
        let wrongChar: Character = expected == "K" ? "M" : "K"
        typeCharacter(wrongChar)
        return self
    }

    /// Wait for timeout feedback to appear (without answering).
    @discardableResult
    func waitForTimeout(timeout: TimeInterval = 5) -> Self {
        waitForPrompt()
        // Wait until timeout feedback appears
        _ = feedbackTimeout.waitForExistence(timeout: timeout)
        return self
    }
}

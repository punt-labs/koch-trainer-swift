import XCTest

/// Page object for send training UI tests.
/// Extends TrainingPage with dit/dah button accessors, pattern display, and keyboard input.
final class SendTrainingPage: TrainingPage {

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

    /// Input the correct pattern for a character.
    /// Uses MorseCode lookup to find the pattern.
    @discardableResult
    func inputCorrectPattern(for char: Character) -> Self {
        // Common patterns for Koch method characters
        let patterns: [Character: String] = [
            "K": "-.-", "M": "--", "R": ".-.", "S": "...", "U": "..-",
            "A": ".-", "P": ".--.", "T": "-", "L": ".-..", "O": "---",
            "W": ".--", "I": "..", "N": "-.", "J": ".---", "E": ".",
            "F": "..-.", "Y": "-.--", "V": "...-", "G": "--.", "Q": "--.-",
            "Z": "--..", "H": "....", "B": "-...", "C": "-.-.", "D": "-..",
            "X": "-..-",
            "0": "-----", "1": ".----", "2": "..---", "3": "...--",
            "4": "....-", "5": ".....", "6": "-....", "7": "--...",
            "8": "---..", "9": "----."
        ]

        if let pattern = patterns[char.uppercased().first ?? char] {
            inputPattern(pattern)
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

    /// Send the correct pattern for the currently displayed character.
    /// Waits for training phase, then inputs the pattern.
    @discardableResult
    func sendCorrectPattern(for char: Character) -> Self {
        inputCorrectPattern(for: char)
        return self
    }

    /// Send an incorrect pattern.
    @discardableResult
    func sendIncorrectPattern() -> Self {
        // Send a pattern that won't match any character
        inputPattern("..--..--")
        return self
    }

    /// Wait for the input timeout to complete (pattern submission).
    @discardableResult
    func waitForPatternSubmission(timeout: TimeInterval = 3) -> Self {
        // The 2-second timeout auto-submits the pattern
        Thread.sleep(forTimeInterval: timeout)
        return self
    }
}

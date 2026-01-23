import XCTest

// MARK: - MorseInputPage

/// Protocol for pages that support Morse code input via dit/dah buttons.
/// Provides shared implementation for pattern input to avoid duplication.
protocol MorseInputPage: BasePage {
    var ditButton: XCUIElement { get }
    var dahButton: XCUIElement { get }
}

extension MorseInputPage {

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
            _ = tapDit()
            usleep(50000) // 50ms between taps
        }
        return self
    }

    /// Tap dah multiple times.
    @discardableResult
    func tapDah(count: Int) -> Self {
        for _ in 0 ..< count {
            _ = tapDah()
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
                _ = tapDit()
            case "-":
                _ = tapDah()
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
}

// MARK: - MorsePatterns

/// Standard Morse code patterns for all Koch method characters.
/// Used by test pages to input correct patterns.
enum MorsePatterns {
    static let patterns: [Character: String] = [
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

    /// Get the Morse pattern for a character.
    static func pattern(for char: Character) -> String? {
        patterns[char.uppercased().first ?? char]
    }
}

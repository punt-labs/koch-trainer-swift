import Foundation
import UIKit

// MARK: - AccessibilityProtocol

/// Protocol for abstracting UIAccessibility for testability.
protocol AccessibilityProtocol {
    var isVoiceOverRunning: Bool { get }
    func post(notification: UIAccessibility.Notification, argument: Any?)
}

// MARK: - UIAccessibilityAdapter

/// Default implementation using the real UIAccessibility.
struct UIAccessibilityAdapter: AccessibilityProtocol {
    var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    func post(notification: UIAccessibility.Notification, argument: Any?) {
        UIAccessibility.post(notification: notification, argument: argument)
    }
}

// MARK: - AccessibilityAnnouncer

/// Posts VoiceOver announcements for training feedback.
/// All announcements are no-ops when VoiceOver is not running.
final class AccessibilityAnnouncer {

    // MARK: Lifecycle

    init(accessibility: AccessibilityProtocol = UIAccessibilityAdapter()) {
        self.accessibility = accessibility
    }

    // MARK: Internal

    // MARK: - Announcement Methods

    /// Announce a correct response.
    func announceCorrect() {
        post("Correct")
    }

    /// Announce an incorrect response with the expected answer.
    func announceIncorrect(expected: Character) {
        post("Incorrect. The answer was \(expected)")
    }

    /// Announce an incorrect response with what the user entered and the expected answer.
    func announceIncorrect(userEntered: Character, expected: Character) {
        post("Incorrect. You entered \(userEntered). The answer was \(expected)")
    }

    /// Announce an incorrect pattern (send mode).
    func announceIncorrectPattern(sent: String, expected: Character) {
        let decoded = MorseCode.character(for: sent)
        if let decoded {
            post("Incorrect. You sent \(decoded). The answer was \(expected)")
        } else {
            post("Incorrect. Pattern not recognized. The answer was \(expected)")
        }
    }

    /// Announce a timeout.
    func announceTimeout() {
        post("Time's up")
    }

    /// Announce a timeout with the expected answer.
    func announceTimeout(expected: Character) {
        post("Time's up. The answer was \(expected)")
    }

    /// Announce level advancement with new character.
    func announceLevelUp(newCharacter: Character) {
        let pattern = MorseCode.pattern(for: newCharacter) ?? ""
        post("Level up! New character: \(newCharacter). Pattern: \(spokenPattern(pattern))")
    }

    /// Announce level advancement (ear training with multiple characters).
    func announceLevelUp(newCharacters: [Character]) {
        let charList = newCharacters.map { String($0) }.joined(separator: ", ")
        post("Level up! New characters: \(charList)")
    }

    /// Announce session completion without advancement.
    func announceSessionComplete(accuracy: Int) {
        post("Session complete. \(accuracy) percent accuracy")
    }

    /// Announce session paused.
    func announcePaused() {
        post("Session paused")
    }

    /// Announce session resumed.
    func announceResumed() {
        post("Session resumed")
    }

    // MARK: - Vocabulary Training

    /// Announce correct word response.
    func announceCorrectWord() {
        post("Correct")
    }

    /// Announce incorrect word response.
    func announceIncorrectWord(expected: String, userEntered: String) {
        if userEntered.isEmpty || userEntered == "(timeout)" {
            post("Time's up. The word was \(spelledOut(expected))")
        } else {
            post("Incorrect. The word was \(spelledOut(expected))")
        }
    }

    // MARK: Private

    private let accessibility: AccessibilityProtocol

    private func post(_ message: String) {
        guard accessibility.isVoiceOverRunning else { return }
        accessibility.post(notification: .announcement, argument: message)
    }

    /// Convert pattern to spoken form: ".-" becomes "dit dah"
    private func spokenPattern(_ pattern: String) -> String {
        pattern.map { $0 == "." ? "dit" : "dah" }.joined(separator: " ")
    }

    /// Spell out word for clarity (e.g., callsigns)
    private func spelledOut(_ word: String) -> String {
        word.map { String($0) }.joined(separator: " ")
    }
}

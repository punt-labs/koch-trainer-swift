@testable import KochTrainer
import XCTest

final class AccessibilityAnnouncerTests: XCTestCase {

    // MARK: - Spoken Pattern Tests

    func testSpokenPatternConvertsDitCorrectly() {
        let result = AccessibilityAnnouncer.spokenPattern(".")
        XCTAssertEqual(result, "dit")
    }

    func testSpokenPatternConvertsDahCorrectly() {
        let result = AccessibilityAnnouncer.spokenPattern("-")
        XCTAssertEqual(result, "dah")
    }

    func testSpokenPatternConvertsMultipleElements() {
        // ".-" (A) should become "dit dah"
        let result = AccessibilityAnnouncer.spokenPattern(".-")
        XCTAssertEqual(result, "dit dah")
    }

    func testSpokenPatternConvertsComplexPattern() {
        // "-.-" (K) should become "dah dit dah"
        let result = AccessibilityAnnouncer.spokenPattern("-.-")
        XCTAssertEqual(result, "dah dit dah")
    }

    func testSpokenPatternHandlesEmptyString() {
        let result = AccessibilityAnnouncer.spokenPattern("")
        XCTAssertEqual(result, "")
    }

    func testSpokenPatternHandlesAllDits() {
        // "..." (S) should become "dit dit dit"
        let result = AccessibilityAnnouncer.spokenPattern("...")
        XCTAssertEqual(result, "dit dit dit")
    }

    func testSpokenPatternHandlesAllDahs() {
        // "---" (O) should become "dah dah dah"
        let result = AccessibilityAnnouncer.spokenPattern("---")
        XCTAssertEqual(result, "dah dah dah")
    }

    // MARK: - Spelled Out Tests

    func testSpelledOutSingleCharacter() {
        let result = AccessibilityAnnouncer.spelledOut("A")
        XCTAssertEqual(result, "A")
    }

    func testSpelledOutMultipleCharacters() {
        let result = AccessibilityAnnouncer.spelledOut("CQ")
        XCTAssertEqual(result, "C Q")
    }

    func testSpelledOutCallsign() {
        let result = AccessibilityAnnouncer.spelledOut("W1AW")
        XCTAssertEqual(result, "W 1 A W")
    }

    func testSpelledOutEmptyString() {
        let result = AccessibilityAnnouncer.spelledOut("")
        XCTAssertEqual(result, "")
    }

    func testSpelledOutLongerWord() {
        let result = AccessibilityAnnouncer.spelledOut("HELLO")
        XCTAssertEqual(result, "H E L L O")
    }

    // MARK: - Announcement Method Tests (No Crash)

    // Verify announcement methods don't crash when VoiceOver is off.
    // These tests ensure the API is callable; actual VoiceOver behavior
    // requires manual testing on device.

    func testAnnounceCorrectDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceCorrect()
    }

    func testAnnounceIncorrectWithExpectedDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceIncorrect(expected: "K")
    }

    func testAnnounceIncorrectWithUserEnteredDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceIncorrect(userEntered: "M", expected: "K")
    }

    func testAnnounceIncorrectPatternDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceIncorrectPattern(sent: "-.-", expected: "K")
    }

    func testAnnounceIncorrectPatternWithUnrecognizedPatternDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceIncorrectPattern(sent: "-----", expected: "K")
    }

    func testAnnounceTimeoutDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceTimeout()
    }

    func testAnnounceTimeoutWithExpectedDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceTimeout(expected: "K")
    }

    func testAnnounceLevelUpWithSingleCharacterDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceLevelUp(newCharacter: "R")
    }

    func testAnnounceLevelUpWithMultipleCharactersDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceLevelUp(newCharacters: ["A", "I", "M", "N"])
    }

    func testAnnounceSessionCompleteDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceSessionComplete(accuracy: 85)
    }

    func testAnnouncePausedDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announcePaused()
    }

    func testAnnounceResumedDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceResumed()
    }

    func testAnnounceCorrectWordDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceCorrectWord()
    }

    func testAnnounceIncorrectWordDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceIncorrectWord(expected: "CQ", userEntered: "DE")
    }

    func testAnnounceIncorrectWordWithTimeoutDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceIncorrectWord(expected: "CQ", userEntered: "(timeout)")
    }

    func testAnnounceIncorrectWordWithEmptyInputDoesNotCrash() {
        let announcer = AccessibilityAnnouncer()
        announcer.announceIncorrectWord(expected: "CQ", userEntered: "")
    }
}

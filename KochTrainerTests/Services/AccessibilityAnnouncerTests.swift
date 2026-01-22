@testable import KochTrainer
import XCTest

// MARK: - MockAccessibility

/// Mock accessibility implementation for testing.
final class MockAccessibility: AccessibilityProtocol {
    var isVoiceOverRunning: Bool = false
    var postedAnnouncements: [(notification: UIAccessibility.Notification, argument: String)] = []

    func post(notification: UIAccessibility.Notification, argument: Any?) {
        if let message = argument as? String {
            postedAnnouncements.append((notification, message))
        }
    }

    func reset() {
        postedAnnouncements.removeAll()
    }
}

// MARK: - AccessibilityAnnouncerTests

final class AccessibilityAnnouncerTests: XCTestCase {

    // MARK: Internal

    override func setUp() {
        super.setUp()
        mockAccessibility = MockAccessibility()
        announcer = AccessibilityAnnouncer(accessibility: mockAccessibility)
    }

    // MARK: - VoiceOver Disabled Tests

    func testAnnouncementsSkippedWhenVoiceOverDisabled() {
        mockAccessibility.isVoiceOverRunning = false

        announcer.announceCorrect()

        XCTAssertTrue(mockAccessibility.postedAnnouncements.isEmpty)
    }

    func testMultipleAnnouncementsSkippedWhenVoiceOverDisabled() {
        mockAccessibility.isVoiceOverRunning = false

        announcer.announceCorrect()
        announcer.announceIncorrect(expected: "K")
        announcer.announceTimeout()

        XCTAssertTrue(mockAccessibility.postedAnnouncements.isEmpty)
    }

    // MARK: - VoiceOver Enabled Tests

    func testAnnounceCorrect() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceCorrect()

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].notification, .announcement)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Correct")
    }

    func testAnnounceIncorrectWithExpected() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceIncorrect(expected: "K")

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Incorrect. The answer was K")
    }

    func testAnnounceIncorrectWithUserEntered() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceIncorrect(userEntered: "M", expected: "K")

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Incorrect. You entered M. The answer was K")
    }

    func testAnnounceIncorrectPatternWithDecodedCharacter() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceIncorrectPattern(sent: ".-", expected: "K")

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Incorrect. You sent A. The answer was K")
    }

    func testAnnounceIncorrectPatternWithUnrecognizedPattern() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceIncorrectPattern(sent: ".....", expected: "K")

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Incorrect. Pattern not recognized. The answer was K")
    }

    func testAnnounceTimeout() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceTimeout()

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Time's up")
    }

    func testAnnounceTimeoutWithExpected() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceTimeout(expected: "K")

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Time's up. The answer was K")
    }

    func testAnnounceLevelUpWithNewCharacter() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceLevelUp(newCharacter: "K")

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Level up! New character: K. Pattern: dah dit dah")
    }

    func testAnnounceLevelUpWithMultipleCharacters() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceLevelUp(newCharacters: ["K", "M"])

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Level up! New characters: K, M")
    }

    func testAnnounceSessionComplete() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceSessionComplete(accuracy: 95)

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Session complete. 95 percent accuracy")
    }

    func testAnnouncePaused() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announcePaused()

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Session paused")
    }

    func testAnnounceResumed() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceResumed()

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Session resumed")
    }

    // MARK: - Vocabulary Training Tests

    func testAnnounceCorrectWord() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceCorrectWord()

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Correct")
    }

    func testAnnounceIncorrectWordWithTimeout() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceIncorrectWord(expected: "CQ", userEntered: "(timeout)")

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Time's up. The word was C Q")
    }

    func testAnnounceIncorrectWordWithEmptyResponse() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceIncorrectWord(expected: "CQ", userEntered: "")

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Time's up. The word was C Q")
    }

    func testAnnounceIncorrectWordWithUserEntered() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceIncorrectWord(expected: "CQ", userEntered: "CO")

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Incorrect. The word was C Q")
    }

    // MARK: - Pattern Conversion Tests

    func testSpokenPatternConversion() {
        mockAccessibility.isVoiceOverRunning = true

        // Test dit-dah pattern (A)
        announcer.announceLevelUp(newCharacter: "A")
        XCTAssertTrue(mockAccessibility.postedAnnouncements[0].argument.contains("dit dah"))

        mockAccessibility.reset()

        // Test dah pattern (T)
        announcer.announceLevelUp(newCharacter: "T")
        XCTAssertTrue(mockAccessibility.postedAnnouncements[0].argument.contains("dah"))

        mockAccessibility.reset()

        // Test dit pattern (E)
        announcer.announceLevelUp(newCharacter: "E")
        XCTAssertTrue(mockAccessibility.postedAnnouncements[0].argument.contains("dit"))
    }

    func testSpelledOutWord() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceIncorrectWord(expected: "K1ABC", userEntered: "wrong")

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 1)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Incorrect. The word was K 1 A B C")
    }

    // MARK: - Multiple Announcements Tests

    func testMultipleAnnouncementsWhenVoiceOverEnabled() {
        mockAccessibility.isVoiceOverRunning = true

        announcer.announceCorrect()
        announcer.announceCorrect()
        announcer.announceIncorrect(expected: "K")

        XCTAssertEqual(mockAccessibility.postedAnnouncements.count, 3)
        XCTAssertEqual(mockAccessibility.postedAnnouncements[0].argument, "Correct")
        XCTAssertEqual(mockAccessibility.postedAnnouncements[1].argument, "Correct")
        XCTAssertEqual(mockAccessibility.postedAnnouncements[2].argument, "Incorrect. The answer was K")
    }

    // MARK: Private

    private var mockAccessibility: MockAccessibility!
    private var announcer: AccessibilityAnnouncer!
}

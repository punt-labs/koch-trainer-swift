import XCTest

/// Page object for the MorseQSO session screen.
/// Handles QSO session interaction including keying and completion.
final class MorseQSOPage: BasePage {

    // MARK: Lifecycle

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: Internal

    let app: XCUIApplication

    // MARK: - Status Bar Elements

    var statusBar: XCUIElement {
        element(id: "qso-status-bar")
    }

    var stationCallsign: XCUIElement {
        staticText(id: "qso-station-callsign")
    }

    var turnStatus: XCUIElement {
        staticText(id: "qso-turn-status")
    }

    var audioIndicator: XCUIElement {
        element(id: "qso-audio-indicator")
    }

    var endButton: XCUIElement {
        button(id: "qso-end-button")
    }

    // MARK: - AI Message Elements

    var aiMessageView: XCUIElement {
        element(id: "qso-ai-message-view")
    }

    var aiTextToggle: XCUIElement {
        button(id: "qso-ai-text-toggle")
    }

    var revealedText: XCUIElement {
        staticText(id: "qso-revealed-text")
    }

    // MARK: - User Keying Elements

    var userKeyingView: XCUIElement {
        element(id: "qso-user-keying-view")
    }

    var typedScript: XCUIElement {
        staticText(id: "qso-typed-script")
    }

    var currentCharacter: XCUIElement {
        staticText(id: "qso-current-character")
    }

    var currentPattern: XCUIElement {
        staticText(id: "qso-current-pattern")
    }

    var wpmDisplay: XCUIElement {
        staticText(id: "qso-wpm-display")
    }

    var lastKeyedFeedback: XCUIElement {
        element(id: "qso-last-keyed-feedback")
    }

    // MARK: - Input Area Elements

    var inputArea: XCUIElement {
        element(id: "qso-input-area")
    }

    var ditButton: XCUIElement {
        button(id: "qso-dit-button")
    }

    var dahButton: XCUIElement {
        button(id: "qso-dah-button")
    }

    var keyboardHint: XCUIElement {
        staticText(id: "qso-keyboard-hint")
    }

    // MARK: - Accuracy Footer Elements

    var keyedCount: XCUIElement {
        staticText(id: "qso-keyed-count")
    }

    var accuracyDisplay: XCUIElement {
        staticText(id: "qso-accuracy-display")
    }

    // MARK: - Completed View Elements

    var completedView: XCUIElement {
        element(id: "qso-completed-view")
    }

    var completedTitle: XCUIElement {
        staticText(id: "qso-completed-title")
    }

    var completedCallsign: XCUIElement {
        staticText(id: "qso-completed-callsign")
    }

    var doneButton: XCUIElement {
        button(id: "qso-done-button")
    }

    var statsCard: XCUIElement {
        element(id: "qso-stats-card")
    }

    // MARK: - State Detection

    /// Check if AI is transmitting (audio indicator visible).
    var isAITransmitting: Bool {
        audioIndicator.exists
    }

    /// Check if user turn is active (keying view visible).
    var isUserTurn: Bool {
        userKeyingView.exists || inputArea.exists
    }

    /// Check if session is completed.
    var isCompleted: Bool {
        completedView.exists || doneButton.exists
    }

    // MARK: - Wait Helpers

    /// Wait for the session to start.
    @discardableResult
    func waitForSession(timeout: TimeInterval = 10) -> Self {
        _ = statusBar.waitForExistence(timeout: timeout)
        return self
    }

    /// Wait for user turn to begin.
    @discardableResult
    func waitForUserTurn(timeout: TimeInterval = 30) -> Self {
        // Wait for either the input area or keying view to appear
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: inputArea)
        _ = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return self
    }

    /// Wait for session to complete.
    @discardableResult
    func waitForCompleted(timeout: TimeInterval = 60) -> Self {
        _ = completedView.waitForExistence(timeout: timeout)
        return self
    }

    // MARK: - Input Actions

    /// Tap the dit button.
    @discardableResult
    func tapDit() -> Self {
        _ = ditButton.waitForExistence(timeout: 3)
        ditButton.tap()
        return self
    }

    /// Tap the dah button.
    @discardableResult
    func tapDah() -> Self {
        _ = dahButton.waitForExistence(timeout: 3)
        dahButton.tap()
        return self
    }

    /// Input a Morse pattern using dit and dah buttons.
    @discardableResult
    func inputPattern(_ pattern: String) -> Self {
        for char in pattern {
            switch char {
            case ".":
                tapDit()
            case "-":
                tapDah()
            default:
                break
            }
            usleep(50000) // 50ms between inputs
        }
        return self
    }

    /// Toggle AI text visibility.
    @discardableResult
    func toggleAIText() -> Self {
        _ = aiTextToggle.waitForExistence(timeout: 3)
        aiTextToggle.tap()
        return self
    }

    /// End the QSO session early.
    @discardableResult
    func endSession() -> Self {
        if endButton.waitForExistence(timeout: 2) {
            endButton.tap()
        }
        return self
    }

    // MARK: - Completion Actions

    /// Tap Done button to return from completion.
    @discardableResult
    func tapDone() -> VocabPage {
        _ = doneButton.waitForExistence(timeout: 5)
        doneButton.tap()
        return VocabPage(app: app)
    }

    // MARK: - Assertions

    /// Assert session has started.
    func assertSessionStarted() {
        XCTAssertTrue(statusBar.exists, "Status bar should be visible")
    }

    /// Assert user turn is active.
    func assertUserTurn() {
        XCTAssertTrue(isUserTurn, "User turn should be active")
    }

    /// Assert session is completed.
    func assertCompleted() {
        XCTAssertTrue(isCompleted, "Session should be completed")
    }

    /// Assert dit/dah buttons are visible.
    func assertInputButtonsVisible() {
        XCTAssertTrue(ditButton.exists, "Dit button should be visible")
        XCTAssertTrue(dahButton.exists, "Dah button should be visible")
    }
}

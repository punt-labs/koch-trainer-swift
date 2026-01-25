import XCTest

/// Page object for the VocabularyTraining session screen.
/// Handles vocabulary training for both receive and send modes.
final class VocabularyTrainingPage: BasePage {

    // MARK: Lifecycle

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: Internal

    let app: XCUIApplication

    // MARK: - Container View Elements

    var view: XCUIElement {
        element(id: "vocab-training-view")
    }

    var receivePhaseView: XCUIElement {
        element(id: "vocab-training-receive-phase")
    }

    var sendPhaseView: XCUIElement {
        element(id: "vocab-training-send-phase")
    }

    var pausedView: XCUIElement {
        element(id: "vocab-training-paused-view")
    }

    var completedView: XCUIElement {
        element(id: "vocab-training-completed-view")
    }

    // MARK: - Common Elements

    var progressText: XCUIElement {
        staticText(id: "vocab-training-progress")
    }

    var scoreText: XCUIElement {
        staticText(id: "vocab-training-score")
    }

    var accuracyText: XCUIElement {
        staticText(id: "vocab-training-accuracy")
    }

    // MARK: - Receive Mode Elements

    var replayButton: XCUIElement {
        button(id: "vocab-training-replay-button")
    }

    var listeningIndicator: XCUIElement {
        element(id: "vocab-training-listening")
    }

    var waitingIndicator: XCUIElement {
        element(id: "vocab-training-waiting")
    }

    var userInputDisplay: XCUIElement {
        staticText(id: "vocab-training-user-input")
    }

    // MARK: - Send Mode Elements

    var targetWord: XCUIElement {
        staticText(id: "vocab-training-target-word")
    }

    var patternProgress: XCUIElement {
        element(id: "vocab-training-pattern-progress")
    }

    var ditButton: XCUIElement {
        button(id: "vocab-training-dit-button")
    }

    var dahButton: XCUIElement {
        button(id: "vocab-training-dah-button")
    }

    var keyboardHint: XCUIElement {
        staticText(id: "vocab-training-keyboard-hint")
    }

    // MARK: - Feedback Elements

    var feedbackView: XCUIElement {
        element(id: "vocab-training-feedback")
    }

    var feedbackWord: XCUIElement {
        staticText(id: "vocab-training-feedback-word")
    }

    var feedbackResult: XCUIElement {
        staticText(id: "vocab-training-feedback-result")
    }

    // MARK: - Paused State Elements

    var pauseButton: XCUIElement {
        button(id: "vocab-training-pause-button")
    }

    var resumeButton: XCUIElement {
        button(id: "vocab-training-resume-button")
    }

    var endSessionButton: XCUIElement {
        button(id: "vocab-training-end-session-button")
    }

    var pausedTitle: XCUIElement {
        staticText(id: "vocab-training-paused-title")
    }

    var pausedScore: XCUIElement {
        staticText(id: "vocab-training-paused-score")
    }

    // MARK: - Completed State Elements

    var completedTitle: XCUIElement {
        staticText(id: "vocab-training-completed-title")
    }

    var completedStats: XCUIElement {
        element(id: "vocab-training-completed-stats")
    }

    var doneButton: XCUIElement {
        button(id: "vocab-training-done-button")
    }

    var setName: XCUIElement {
        staticText(id: "vocab-training-set-name")
    }

    // MARK: - State Detection

    /// Check if in receive training phase.
    var isReceivePhase: Bool {
        receivePhaseView.exists
    }

    /// Check if in send training phase.
    var isSendPhase: Bool {
        sendPhaseView.exists
    }

    /// Check if paused.
    var isPaused: Bool {
        pausedView.exists || pausedTitle.exists
    }

    /// Check if session is completed.
    var isCompleted: Bool {
        completedView.exists || completedTitle.exists
    }

    /// Check if waiting for user response (receive mode).
    var isWaitingForResponse: Bool {
        waitingIndicator.exists
    }

    /// Check if listening to playback.
    var isListening: Bool {
        listeningIndicator.exists
    }

    // MARK: - Wait Helpers

    /// Wait for training to start.
    @discardableResult
    func waitForTraining(timeout: TimeInterval = 10) -> Self {
        _ = view.waitForExistence(timeout: timeout)
        return self
    }

    /// Wait for receive phase.
    @discardableResult
    func waitForReceivePhase(timeout: TimeInterval = 10) -> Self {
        _ = receivePhaseView.waitForExistence(timeout: timeout)
        return self
    }

    /// Wait for send phase.
    @discardableResult
    func waitForSendPhase(timeout: TimeInterval = 10) -> Self {
        _ = sendPhaseView.waitForExistence(timeout: timeout)
        return self
    }

    /// Wait for waiting indicator (receive mode).
    @discardableResult
    func waitForWaiting(timeout: TimeInterval = 15) -> Self {
        _ = waitingIndicator.waitForExistence(timeout: timeout)
        return self
    }

    /// Wait for paused state.
    @discardableResult
    func waitForPaused(timeout: TimeInterval = 5) -> Self {
        _ = pausedView.waitForExistence(timeout: timeout)
        return self
    }

    /// Wait for completed state.
    @discardableResult
    func waitForCompleted(timeout: TimeInterval = 60) -> Self {
        _ = completedView.waitForExistence(timeout: timeout)
        return self
    }

    // MARK: - Input Actions (Send Mode)

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

    // MARK: - Receive Mode Actions

    /// Tap replay button.
    @discardableResult
    func tapReplay() -> Self {
        _ = replayButton.waitForExistence(timeout: 3)
        replayButton.tap()
        return self
    }

    // MARK: - Control Actions

    /// Pause the session.
    @discardableResult
    func pause() -> Self {
        if pauseButton.waitForExistence(timeout: 2) {
            pauseButton.tap()
        }
        return self
    }

    /// Resume from paused state.
    @discardableResult
    func resume() -> Self {
        if resumeButton.waitForExistence(timeout: 2) {
            resumeButton.tap()
        }
        return self
    }

    /// End the session early.
    @discardableResult
    func endSession() -> Self {
        if endSessionButton.waitForExistence(timeout: 2) {
            endSessionButton.tap()
        }
        return self
    }

    /// Tap Done button to return from completion.
    @discardableResult
    func tapDone() -> VocabPage {
        _ = doneButton.waitForExistence(timeout: 5)
        doneButton.tap()
        return VocabPage(app: app)
    }

    // MARK: - Assertions

    /// Assert receive phase is active.
    func assertReceivePhase() {
        XCTAssertTrue(isReceivePhase, "Should be in receive phase")
    }

    /// Assert send phase is active.
    func assertSendPhase() {
        XCTAssertTrue(isSendPhase, "Should be in send phase")
    }

    /// Assert paused state.
    func assertPaused() {
        XCTAssertTrue(isPaused, "Should be paused")
    }

    /// Assert completed state.
    func assertCompleted() {
        XCTAssertTrue(isCompleted, "Should be completed")
    }

    /// Assert dit/dah buttons are visible (send mode).
    func assertInputButtonsVisible() {
        XCTAssertTrue(ditButton.exists, "Dit button should be visible")
        XCTAssertTrue(dahButton.exists, "Dah button should be visible")
    }

    /// Assert replay button is visible (receive mode).
    func assertReplayButtonVisible() {
        XCTAssertTrue(replayButton.exists, "Replay button should be visible")
    }
}

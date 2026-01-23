import XCTest

/// Base page object for training screens (Receive, Send, Ear).
/// Provides access to common training elements shared across all modes.
class TrainingPage: BasePage {

    // MARK: Lifecycle

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: Internal

    let app: XCUIApplication

    // MARK: - Introduction Phase Elements

    var introView: XCUIElement {
        element(id: "training-intro-view")
    }

    var introProgress: XCUIElement {
        staticText(id: "training-intro-progress")
    }

    var introCharacter: XCUIElement {
        staticText(id: "training-intro-character")
    }

    var introPattern: XCUIElement {
        staticText(id: "training-intro-pattern")
    }

    var playSoundButton: XCUIElement {
        button(id: "training-play-sound-button")
    }

    var nextCharacterButton: XCUIElement {
        button(id: "training-next-character-button")
    }

    var startTrainingButton: XCUIElement {
        button(id: "training-start-button")
    }

    // MARK: - Training Phase Elements

    var trainingView: XCUIElement {
        element(id: "training-phase-view")
    }

    var proficiencyProgress: XCUIElement {
        staticText(id: "training-proficiency-progress")
    }

    var characterDisplay: XCUIElement {
        staticText(id: "training-character-display")
    }

    var feedbackMessage: XCUIElement {
        staticText(id: "training-feedback-message")
    }

    var progressBar: XCUIElement {
        element(id: "training-progress-bar")
    }

    var scoreDisplay: XCUIElement {
        staticText(id: "training-score-display")
    }

    var accuracyDisplay: XCUIElement {
        staticText(id: "training-accuracy-display")
    }

    var pauseButton: XCUIElement {
        button(id: "training-pause-button")
    }

    // MARK: - Paused Phase Elements

    var pausedView: XCUIElement {
        element(id: "training-paused-view")
    }

    var resumeButton: XCUIElement {
        button(id: "training-resume-button")
    }

    var endSessionButton: XCUIElement {
        button(id: "training-end-session-button")
    }

    // MARK: - Completed Phase Elements

    var completedView: XCUIElement {
        element(id: "training-completed-view")
    }

    var levelUpTitle: XCUIElement {
        staticText(id: "training-level-up-title")
    }

    var sessionCompleteTitle: XCUIElement {
        staticText(id: "training-session-complete-title")
    }

    var newCharacterDisplay: XCUIElement {
        staticText(id: "training-new-character-display")
    }

    var finalScore: XCUIElement {
        staticText(id: "training-final-score")
    }

    var finalAccuracy: XCUIElement {
        staticText(id: "training-final-accuracy")
    }

    var continueButton: XCUIElement {
        button(id: "training-continue-button")
    }

    var tryAgainButton: XCUIElement {
        button(id: "training-try-again-button")
    }

    var doneButton: XCUIElement {
        button(id: "training-done-button")
    }

    // MARK: - Feedback Indicators

    var feedbackCorrect: XCUIElement {
        element(id: "training-feedback-correct")
    }

    var feedbackIncorrect: XCUIElement {
        element(id: "training-feedback-incorrect")
    }

    var feedbackTimeout: XCUIElement {
        element(id: "training-feedback-timeout")
    }

    // MARK: - Phase Detection

    /// Check if currently in introduction phase.
    var isInIntroPhase: Bool {
        introView.exists || nextCharacterButton.exists || startTrainingButton.exists
    }

    /// Check if currently in training phase.
    var isInTrainingPhase: Bool {
        trainingView.exists || pauseButton.exists
    }

    /// Check if currently paused.
    var isPaused: Bool {
        pausedView.exists || resumeButton.exists
    }

    /// Check if session is completed.
    var isCompleted: Bool {
        completedView.exists || doneButton.exists || continueButton.exists
    }

    // MARK: - Introduction Phase Actions

    /// Wait for introduction phase to load.
    @discardableResult
    func waitForIntro(timeout: TimeInterval = 5) -> Self {
        // Wait for either intro view or intro elements
        let introElements = [introCharacter, introPattern, nextCharacterButton, startTrainingButton]
        _ = introElements.first { $0.waitForExistence(timeout: timeout) }
        return self
    }

    /// Tap Play Sound button.
    @discardableResult
    func tapPlaySound() -> Self {
        tapButton(id: "training-play-sound-button")
        return self
    }

    /// Tap Next Character button.
    @discardableResult
    func tapNextCharacter() -> Self {
        tapButton(id: "training-next-character-button")
        return self
    }

    /// Tap Start Training button (appears on last intro character).
    @discardableResult
    func tapStartTraining() -> Self {
        tapButton(id: "training-start-button")
        return self
    }

    /// Skip through all introduction characters to start training.
    @discardableResult
    func skipIntroduction(maxIterations: Int = 50) -> Self {
        for _ in 0 ..< maxIterations {
            // Check for Start Training button (appears on last intro character)
            if startTrainingButton.waitForExistence(timeout: 0.5) {
                startTrainingButton.tap()
                return self
            }

            // Otherwise tap Next Character
            if nextCharacterButton.waitForExistence(timeout: 0.5) {
                nextCharacterButton.tap()
                usleep(100_000) // 100ms delay for UI update
            } else {
                // Neither button exists - might be in training already
                return self
            }
        }
        return self
    }

    // MARK: - Training Phase Actions

    /// Wait for training phase to load.
    @discardableResult
    func waitForTraining(timeout: TimeInterval = 5) -> Self {
        _ = trainingView.waitForExistence(timeout: timeout)
        return self
    }

    /// Pause the training session.
    @discardableResult
    func pause() -> Self {
        tapButton(id: "training-pause-button")
        return self
    }

    // MARK: - Paused Phase Actions

    /// Resume a paused session.
    @discardableResult
    func resume() -> Self {
        tapButton(id: "training-resume-button")
        return self
    }

    /// End the session from paused state.
    @discardableResult
    func endSession() -> Self {
        tapButton(id: "training-end-session-button")
        return self
    }

    // MARK: - Completed Phase Actions

    /// Wait for completed phase to appear.
    @discardableResult
    func waitForCompleted(timeout: TimeInterval = 10) -> Self {
        _ = completedView.waitForExistence(timeout: timeout)
        return self
    }

    /// Tap Continue button after level up.
    @discardableResult
    func tapContinue() -> Self {
        tapButton(id: "training-continue-button")
        return self
    }

    /// Tap Try Again button.
    @discardableResult
    func tapTryAgain() -> Self {
        tapButton(id: "training-try-again-button")
        return self
    }

    /// Tap Done button to return to home.
    @discardableResult
    func tapDone() -> LearnPage {
        tapButton(id: "training-done-button")
        return LearnPage(app: app)
    }

    // MARK: - Assertions

    /// Assert currently in introduction phase.
    func assertInIntroPhase() {
        XCTAssertTrue(isInIntroPhase, "Should be in introduction phase")
    }

    /// Assert currently in training phase.
    func assertInTrainingPhase() {
        XCTAssertTrue(isInTrainingPhase, "Should be in training phase")
    }

    /// Assert session is paused.
    func assertPaused() {
        XCTAssertTrue(isPaused, "Session should be paused")
    }

    /// Assert session is completed.
    func assertCompleted() {
        XCTAssertTrue(isCompleted, "Session should be completed")
    }
}

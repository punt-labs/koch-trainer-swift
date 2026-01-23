import XCTest

/// Page object for the Learn (home) screen.
/// Provides navigation to training modes and access to home screen elements.
final class LearnPage: BasePage {

    // MARK: Lifecycle

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: Internal

    let app: XCUIApplication

    // MARK: - Element Accessors

    var view: XCUIElement {
        element(id: "learn-view")
    }

    var streakCard: XCUIElement {
        element(id: "learn-streak-card")
    }

    var earTrainingButton: XCUIElement {
        button(id: "learn-ear-training-start-button")
    }

    var receiveTrainingButton: XCUIElement {
        button(id: "learn-receive-training-start-button")
    }

    var sendTrainingButton: XCUIElement {
        button(id: "learn-send-training-start-button")
    }

    var earTrainingLevel: XCUIElement {
        staticText(id: "learn-ear-training-level")
    }

    var receiveLevel: XCUIElement {
        staticText(id: "learn-receive-level")
    }

    var sendLevel: XCUIElement {
        staticText(id: "learn-send-level")
    }

    // MARK: - Wait Helpers

    /// Wait for Learn page to load.
    @discardableResult
    func waitForPage(timeout: TimeInterval = 5) -> Self {
        _ = view.waitForExistence(timeout: timeout)
        return self
    }

    // MARK: - Navigation Actions

    /// Navigate to Ear Training.
    @discardableResult
    func goToEarTraining() -> EarTrainingPage {
        _ = earTrainingButton.waitForExistence(timeout: 5)
        earTrainingButton.tap()
        return EarTrainingPage(app: app)
    }

    /// Navigate to Receive Training.
    @discardableResult
    func goToReceiveTraining() -> ReceiveTrainingPage {
        _ = receiveTrainingButton.waitForExistence(timeout: 5)
        receiveTrainingButton.tap()
        return ReceiveTrainingPage(app: app)
    }

    /// Navigate to Send Training.
    @discardableResult
    func goToSendTraining() -> SendTrainingPage {
        _ = sendTrainingButton.waitForExistence(timeout: 5)
        sendTrainingButton.tap()
        return SendTrainingPage(app: app)
    }

    // MARK: - Assertions

    /// Assert Learn page is displayed.
    func assertDisplayed() {
        assertExists(id: "learn-view", message: "Learn view should be displayed")
    }

    /// Assert all training buttons are visible.
    func assertTrainingButtonsVisible() {
        XCTAssertTrue(earTrainingButton.exists, "Ear training button should exist")
        XCTAssertTrue(receiveTrainingButton.exists, "Receive training button should exist")
        XCTAssertTrue(sendTrainingButton.exists, "Send training button should exist")
    }
}

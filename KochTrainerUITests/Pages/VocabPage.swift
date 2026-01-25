import XCTest

/// Page object for the Vocabulary screen.
/// Provides navigation to QSO practice and vocabulary training modes.
final class VocabPage: BasePage {

    // MARK: Lifecycle

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: Internal

    let app: XCUIApplication

    // MARK: - Element Accessors

    var view: XCUIElement {
        element(id: "vocab-view")
    }

    var qsoButton: XCUIElement {
        element(id: "vocab-qso-button")
    }

    var commonWordsReceiveButton: XCUIElement {
        element(id: "vocab-common-words-receive-button")
    }

    var commonWordsSendButton: XCUIElement {
        element(id: "vocab-common-words-send-button")
    }

    var callsignReceiveButton: XCUIElement {
        element(id: "vocab-callsign-receive-button")
    }

    var callsignSendButton: XCUIElement {
        element(id: "vocab-callsign-send-button")
    }

    // MARK: - Wait Helpers

    /// Wait for Vocab page to load.
    @discardableResult
    func waitForPage(timeout: TimeInterval = 5) -> Self {
        _ = view.waitForExistence(timeout: timeout)
        return self
    }

    // MARK: - Navigation Actions

    /// Navigate to QSO practice.
    @discardableResult
    func goToQSO() -> QSOPage {
        let qso = qsoButton
        XCTAssertTrue(qso.waitForExistence(timeout: 5), "QSO button should exist")
        qso.tap()
        return QSOPage(app: app)
    }

    /// Navigate to Common Words receive training.
    @discardableResult
    func goToCommonWordsReceive() -> VocabularyTrainingPage {
        let button = commonWordsReceiveButton
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Common Words Receive button should exist")
        button.tap()
        return VocabularyTrainingPage(app: app)
    }

    /// Navigate to Common Words send training.
    @discardableResult
    func goToCommonWordsSend() -> VocabularyTrainingPage {
        let button = commonWordsSendButton
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Common Words Send button should exist")
        button.tap()
        return VocabularyTrainingPage(app: app)
    }

    /// Navigate to Callsign Patterns receive training.
    @discardableResult
    func goToCallsignReceive() -> VocabularyTrainingPage {
        let button = callsignReceiveButton
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Callsign Receive button should exist")
        button.tap()
        return VocabularyTrainingPage(app: app)
    }

    /// Navigate to Callsign Patterns send training.
    @discardableResult
    func goToCallsignSend() -> VocabularyTrainingPage {
        let button = callsignSendButton
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Callsign Send button should exist")
        button.tap()
        return VocabularyTrainingPage(app: app)
    }

    // MARK: - Assertions

    /// Assert Vocab page is displayed.
    func assertDisplayed() {
        assertExists(id: "vocab-view", message: "Vocab view should be displayed")
    }

    /// Assert vocabulary set buttons exist.
    func assertVocabularyButtonsExist() {
        XCTAssertTrue(
            commonWordsReceiveButton.waitForExistence(timeout: 3),
            "Common Words Receive button should exist"
        )
        XCTAssertTrue(commonWordsSendButton.exists, "Common Words Send button should exist")
        XCTAssertTrue(callsignReceiveButton.exists, "Callsign Receive button should exist")
        XCTAssertTrue(callsignSendButton.exists, "Callsign Send button should exist")
    }
}

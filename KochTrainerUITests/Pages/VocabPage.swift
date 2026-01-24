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

    // MARK: - Assertions

    /// Assert Vocab page is displayed.
    func assertDisplayed() {
        assertExists(id: "vocab-view", message: "Vocab view should be displayed")
    }
}

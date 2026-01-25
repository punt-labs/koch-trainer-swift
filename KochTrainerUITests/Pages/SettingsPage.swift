import XCTest

/// Page object for the Settings screen.
/// Provides navigation to session history and other settings views.
final class SettingsPage: BasePage {

    // MARK: Lifecycle

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: Internal

    let app: XCUIApplication

    // MARK: - Element Accessors

    var view: XCUIElement {
        element(id: "settings-view")
    }

    var sessionHistoryLink: XCUIElement {
        // In Forms, look for static text "Session History" and its containing cell
        app.staticTexts["Session History"]
    }

    var whatsNewLink: XCUIElement {
        element(id: "settings-whats-new-link")
    }

    var acknowledgementsLink: XCUIElement {
        element(id: "settings-acknowledgements-link")
    }

    var resetProgressButton: XCUIElement {
        element(id: "settings-reset-progress-button")
    }

    // MARK: - Wait Helpers

    /// Wait for Settings page to load.
    @discardableResult
    func waitForPage(timeout: TimeInterval = 5) -> Self {
        _ = view.waitForExistence(timeout: timeout)
        return self
    }

    // MARK: - Navigation Actions

    /// Navigate to Session History.
    @discardableResult
    func goToSessionHistory() -> SessionHistoryPage {
        // Session History may be below the fold, scroll to find it
        let link = sessionHistoryLink
        if !link.exists {
            // Scroll down to find Session History by swiping on the main window
            for _ in 0 ..< 5 {
                if link.exists { break }
                app.swipeUp()
            }
        }
        XCTAssertTrue(link.waitForExistence(timeout: 5), "Session History link should exist")
        link.tap()
        return SessionHistoryPage(app: app)
    }

    /// Navigate to What's New.
    @discardableResult
    func goToWhatsNew() -> Self {
        let link = whatsNewLink
        XCTAssertTrue(link.waitForExistence(timeout: 5), "What's New link should exist")
        link.tap()
        return self
    }

    /// Navigate to Acknowledgements.
    @discardableResult
    func goToAcknowledgements() -> Self {
        let link = acknowledgementsLink
        XCTAssertTrue(link.waitForExistence(timeout: 5), "Acknowledgements link should exist")
        link.tap()
        return self
    }

    // MARK: - Assertions

    /// Assert Settings page is displayed.
    func assertDisplayed() {
        assertExists(id: "settings-view", message: "Settings view should be displayed")
    }
}

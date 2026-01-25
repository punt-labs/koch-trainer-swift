import XCTest

/// Page object for the Session History screen.
/// Displays session history with data maintenance options.
final class SessionHistoryPage: BasePage {

    // MARK: Lifecycle

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: Internal

    let app: XCUIApplication

    // MARK: - Element Accessors

    var view: XCUIElement {
        element(id: "session-history-view")
    }

    var emptyState: XCUIElement {
        element(id: "session-history-empty")
    }

    var nextPracticeSection: XCUIElement {
        element(id: "session-history-next-practice")
    }

    var maintenanceSection: XCUIElement {
        element(id: "session-history-maintenance")
    }

    var sessionsSection: XCUIElement {
        element(id: "session-history-sessions")
    }

    var deleteInvalidButton: XCUIElement {
        // May need scrolling in the list
        app.staticTexts["Delete Invalid Sessions"]
    }

    var recalculateButton: XCUIElement {
        // May need scrolling in the list
        app.staticTexts["Recalculate Schedule from History"]
    }

    var invalidSessionCount: XCUIElement {
        staticText(id: "session-history-invalid-count")
    }

    // MARK: - State Detection

    /// Check if the empty state is displayed.
    var isEmpty: Bool {
        emptyState.exists
    }

    /// Check if sessions list is displayed.
    var hasSessions: Bool {
        sessionsSection.exists
    }

    // MARK: - Wait Helpers

    /// Wait for Session History page to load.
    @discardableResult
    func waitForPage(timeout: TimeInterval = 5) -> Self {
        _ = view.waitForExistence(timeout: timeout)
        return self
    }

    /// Scroll to find an element if needed.
    private func scrollToElement(_ element: XCUIElement) {
        if !element.exists {
            for _ in 0 ..< 3 {
                if element.exists { break }
                app.swipeUp()
            }
        }
    }

    /// Tap Delete Invalid Sessions button.
    @discardableResult
    func tapDeleteInvalid() -> Self {
        scrollToElement(deleteInvalidButton)
        if deleteInvalidButton.waitForExistence(timeout: 3) {
            deleteInvalidButton.tap()
        }
        return self
    }

    /// Tap Recalculate Schedule button.
    @discardableResult
    func tapRecalculate() -> Self {
        scrollToElement(recalculateButton)
        if recalculateButton.waitForExistence(timeout: 3) {
            recalculateButton.tap()
        }
        return self
    }

    /// Dismiss alert by tapping OK.
    @discardableResult
    func dismissAlert() -> Self {
        let okButton = app.alerts.buttons["OK"]
        if okButton.waitForExistence(timeout: 3) {
            okButton.tap()
        }
        return self
    }

    /// Navigate back to Settings.
    @discardableResult
    func goBack() -> SettingsPage {
        app.navigationBars.buttons.firstMatch.tap()
        return SettingsPage(app: app)
    }

    // MARK: - Assertions

    /// Assert Session History page is displayed.
    func assertDisplayed() {
        assertExists(id: "session-history-view", message: "Session History view should be displayed")
    }

    /// Assert empty state is shown.
    func assertEmpty() {
        XCTAssertTrue(isEmpty, "Empty state should be displayed")
    }

    /// Assert sessions exist.
    func assertHasSessions() {
        XCTAssertTrue(hasSessions, "Sessions section should be displayed")
    }

    /// Assert maintenance section is visible.
    func assertMaintenanceSectionVisible() {
        XCTAssertTrue(
            maintenanceSection.waitForExistence(timeout: 3),
            "Maintenance section should be visible"
        )
    }
}

import XCTest

/// UI tests for the Session History screen.
/// Tests navigation, empty state, session list, and data maintenance actions.
final class SessionHistoryUITests: XCTestCase {

    // MARK: Internal

    override func setUpWithError() throws {
        continueAfterFailure = false
        let application = XCUIApplication()
        application.launchArguments = ["--uitesting"]
        application.launch()
        app = application
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigation Tests

    func testNavigateToSessionHistory() throws {
        let settingsPage = try getSettingsPage()
        let historyPage = settingsPage.goToSessionHistory()

        historyPage.waitForPage()
        historyPage.assertDisplayed()
    }

    func testCanNavigateBackFromSessionHistory() throws {
        let settingsPage = try getSettingsPage()
            .goToSessionHistory()
            .waitForPage()
            .goBack()
            .waitForPage()

        settingsPage.assertDisplayed()
    }

    // MARK: - Content Tests

    func testSessionHistoryShowsNextPracticeSection() throws {
        let historyPage = try getSettingsPage()
            .goToSessionHistory()
            .waitForPage()

        // Next Practice section should be visible (with or without sessions)
        XCTAssertTrue(
            historyPage.nextPracticeSection.waitForExistence(timeout: 5),
            "Next Practice section should be visible"
        )
    }

    func testSessionHistoryShowsMaintenanceSection() throws {
        let historyPage = try getSettingsPage()
            .goToSessionHistory()
            .waitForPage()

        historyPage.assertMaintenanceSectionVisible()
    }

    func testMaintenanceSectionHasDeleteInvalidButton() throws {
        let historyPage = try getSettingsPage()
            .goToSessionHistory()
            .waitForPage()

        // Scroll to find the button
        historyPage.tapDeleteInvalid()

        // After tapping, dismiss any alert that might appear
        historyPage.dismissAlert()

        // Verify we're still on the page
        historyPage.assertDisplayed()
    }

    func testMaintenanceSectionHasRecalculateButton() throws {
        let historyPage = try getSettingsPage()
            .goToSessionHistory()
            .waitForPage()

        // Scroll to find the button
        historyPage.tapRecalculate()

        // After tapping, dismiss any alert that might appear
        historyPage.dismissAlert()

        // Verify we're still on the page
        historyPage.assertDisplayed()
    }

    // MARK: - Maintenance Actions

    func testCanTapRecalculateButton() throws {
        let historyPage = try getSettingsPage()
            .goToSessionHistory()
            .waitForPage()

        // Scroll to and tap the button
        historyPage.tapRecalculate()

        // After the interaction, we should still be on the history page
        // (dismiss any alert that might appear)
        historyPage.dismissAlert()
        historyPage.assertDisplayed()
    }

    // MARK: Private

    private var app: XCUIApplication?

    private func getSettingsPage() throws -> SettingsPage {
        let application = try XCTUnwrap(app, "App should be initialized in setUp")

        // Navigate to Settings tab
        let settingsTab = application.tabBars.buttons["Settings"]
        _ = settingsTab.waitForExistence(timeout: 5)
        settingsTab.tap()

        return SettingsPage(app: application).waitForPage()
    }
}

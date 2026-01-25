import XCTest

/// UI tests for the QSO (Morse conversation) flow.
/// Tests navigation, style selection, session interaction, and completion.
final class QSOUITests: XCTestCase {

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

    func testNavigateToQSOFromVocab() throws {
        let vocabPage = try getVocabPage()
        let qsoPage = vocabPage.goToQSO()

        qsoPage.waitForPage()
        qsoPage.assertDisplayed()
    }

    func testQSOPageShowsCallsign() throws {
        let qsoPage = try getVocabPage().goToQSO().waitForPage()

        qsoPage.assertCallsignDisplayed()
    }

    func testQSOPageShowsStyleCards() throws {
        let qsoPage = try getVocabPage().goToQSO().waitForPage()

        // Check that at least the first contact style card exists
        XCTAssertTrue(
            qsoPage.styleCard("firstContact").waitForExistence(timeout: 3),
            "First Contact style card should be visible"
        )
    }

    // MARK: - Style Selection Tests

    func testCanSelectFirstContactStyle() throws {
        let qsoPage = try getVocabPage()
            .goToQSO()
            .waitForPage()
            .selectFirstContact()

        // Style should be selected (card should still exist)
        XCTAssertTrue(
            qsoPage.styleCard("firstContact").exists,
            "First Contact style card should exist after selection"
        )
    }

    func testCanSelectContestStyle() throws {
        let qsoPage = try getVocabPage()
            .goToQSO()
            .waitForPage()
            .selectContest()

        XCTAssertTrue(
            qsoPage.styleCard("contest").exists,
            "Contest style card should exist after selection"
        )
    }

    // MARK: - Session Start Tests

    func testCanStartQSOSession() throws {
        let morseQSOPage = try getVocabPage()
            .goToQSO()
            .waitForPage()
            .selectFirstContact()
            .startQSO()
            .waitForSession()

        morseQSOPage.assertSessionStarted()
    }

    func testQSOSessionShowsStatusBar() throws {
        let morseQSOPage = try getVocabPage()
            .goToQSO()
            .waitForPage()
            .selectFirstContact()
            .startQSO()
            .waitForSession()

        XCTAssertTrue(
            morseQSOPage.statusBar.exists,
            "Status bar should be visible during session"
        )
    }

    // MARK: - User Turn Tests

    func testQSOSessionShowsDitDahButtons() throws {
        let morseQSOPage = try getVocabPage()
            .goToQSO()
            .waitForPage()
            .selectFirstContact()
            .startQSO()
            .waitForSession()
            .waitForUserTurn(timeout: 30)

        morseQSOPage.assertInputButtonsVisible()
    }

    func testCanTapDitButton() throws {
        let morseQSOPage = try getVocabPage()
            .goToQSO()
            .waitForPage()
            .selectFirstContact()
            .startQSO()
            .waitForSession()
            .waitForUserTurn(timeout: 30)

        morseQSOPage.tapDit()

        // Should still be in session after tapping
        XCTAssertTrue(
            morseQSOPage.statusBar.exists || morseQSOPage.isCompleted,
            "Should remain in session or complete after dit"
        )
    }

    func testCanTapDahButton() throws {
        let morseQSOPage = try getVocabPage()
            .goToQSO()
            .waitForPage()
            .selectFirstContact()
            .startQSO()
            .waitForSession()
            .waitForUserTurn(timeout: 30)

        morseQSOPage.tapDah()

        XCTAssertTrue(
            morseQSOPage.statusBar.exists || morseQSOPage.isCompleted,
            "Should remain in session or complete after dah"
        )
    }

    // MARK: - End Session Tests

    func testCanEndSessionEarly() throws {
        let morseQSOPage = try getVocabPage()
            .goToQSO()
            .waitForPage()
            .selectFirstContact()
            .startQSO()
            .waitForSession()

        morseQSOPage.endSession()

        // After ending, should navigate away (back to QSO page or vocab)
        // The session should no longer be active
        XCTAssertFalse(
            morseQSOPage.statusBar.waitForExistence(timeout: 2),
            "Session should be ended"
        )
    }

    // MARK: Private

    private var app: XCUIApplication?

    private func getVocabPage() throws -> VocabPage {
        let application = try XCTUnwrap(app, "App should be initialized in setUp")

        // Navigate to Vocab tab
        let vocabTab = application.tabBars.buttons["Vocab"]
        _ = vocabTab.waitForExistence(timeout: 5)
        vocabTab.tap()

        return VocabPage(app: application).waitForPage()
    }
}

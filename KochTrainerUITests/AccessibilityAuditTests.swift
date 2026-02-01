import XCTest

/// Accessibility audit tests using iOS 17+ performAccessibilityAudit API.
/// These tests automatically verify accessibility compliance for key screens.
@available(iOS 17.0, *)
final class AccessibilityAuditTests: XCTestCase {

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

    // MARK: - Learn Tab Tests

    func testLearnViewAccessibilityAudit() throws {
        let application = try XCTUnwrap(app)
        // Learn view is visible by default on launch
        try application.performAccessibilityAudit()
    }

    // MARK: - Practice Tab Tests

    func testPracticeViewAccessibilityAudit() throws {
        let application = try XCTUnwrap(app)
        application.tabBars.buttons["Practice"].tap()
        _ = application.staticTexts["Custom Practice"].waitForExistence(timeout: 2)
        try application.performAccessibilityAudit()
    }

    // MARK: - Vocabulary Tab Tests

    func testVocabViewAccessibilityAudit() throws {
        let application = try XCTUnwrap(app)
        application.tabBars.buttons["Vocab"].tap()
        _ = application.staticTexts["Common Words"].waitForExistence(timeout: 2)
        try application.performAccessibilityAudit()
    }

    // MARK: - Settings Tab Tests

    func testSettingsViewAccessibilityAudit() throws {
        let application = try XCTUnwrap(app)
        application.tabBars.buttons["Settings"].tap()
        _ = application.staticTexts["Audio"].waitForExistence(timeout: 2)
        try application.performAccessibilityAudit()
    }

    // MARK: - Training View Tests

    func testReceiveTrainingIntroAccessibilityAudit() throws {
        let application = try XCTUnwrap(app)
        application.tabBars.buttons["Learn"].tap()
        application.buttons["learn-receive-training-start-button"].tap()
        _ = application.staticTexts["Character"].waitForExistence(timeout: 3)
        try application.performAccessibilityAudit()
    }

    func testSendTrainingIntroAccessibilityAudit() throws {
        let application = try XCTUnwrap(app)
        application.tabBars.buttons["Learn"].tap()
        application.buttons["learn-send-training-start-button"].tap()
        _ = application.staticTexts["Character"].waitForExistence(timeout: 3)
        try application.performAccessibilityAudit()
    }

    func testEarTrainingIntroAccessibilityAudit() throws {
        let application = try XCTUnwrap(app)
        application.tabBars.buttons["Learn"].tap()
        application.buttons["learn-ear-training-start-button"].tap()
        _ = application.staticTexts["Character"].waitForExistence(timeout: 3)
        try application.performAccessibilityAudit()
    }

    // MARK: Private

    private var app: XCUIApplication?

}

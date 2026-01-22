import XCTest

/// Integration tests for the Receive Training flow.
/// Tests the complete user journey from home screen through training completion.
final class ReceiveTrainingUITests: XCTestCase {

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

    /// Verify user can navigate to receive training from home screen.
    func testNavigateToReceiveTraining() throws {
        let application = try getApp()

        // Find and tap the receive training button
        let receiveButton = application.buttons["Start Receive Training"]
        XCTAssertTrue(receiveButton.waitForExistence(timeout: 5), "Receive training button should exist")

        receiveButton.tap()

        // Should show introduction view with character
        let introProgress = application.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Character'")
        ).firstMatch
        XCTAssertTrue(introProgress.waitForExistence(timeout: 5), "Should show character introduction")
    }

    /// Verify introduction phase shows character and pattern.
    func testIntroductionPhaseShowsCharacterAndPattern() throws {
        let application = try getApp()
        try navigateToReceiveTraining()

        // Should display the current character (K or M for level 1)
        // The character is displayed in a large font
        let characterLabel = application.staticTexts.matching(
            NSPredicate(format: "label == 'K' OR label == 'M'")
        ).firstMatch
        XCTAssertTrue(characterLabel.waitForExistence(timeout: 5), "Should show character K or M")

        // Should show the Morse pattern
        let patternLabel = application.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '-' OR label CONTAINS '.'")
        ).firstMatch
        XCTAssertTrue(patternLabel.exists, "Should show Morse pattern")

        // Should have Play Sound button
        let playButton = application.buttons["Play Sound"]
        XCTAssertTrue(playButton.exists, "Should have Play Sound button")

        // Should have Next Character button
        let nextButton = application.buttons["Next Character"]
        XCTAssertTrue(nextButton.exists, "Should have Next Character button")
    }

    /// Verify user can progress through introduction to training.
    func testProgressThroughIntroductionToTraining() throws {
        let application = try getApp()
        try navigateToReceiveTraining()

        // Progress through all intro characters
        // Level 1 has 2 characters (K, M)
        try skipThroughIntroduction()

        // After intro, should be in training phase
        // The navigation title changes to "Receive Training"
        let navTitle = application.navigationBars["Receive Training"]
        XCTAssertTrue(
            navTitle.waitForExistence(timeout: 5),
            "Should show Receive Training navigation title after intro"
        )
    }

    /// Verify training phase accepts keyboard input.
    func testTrainingPhaseAcceptsInput() throws {
        let application = try getApp()
        try navigateToReceiveTraining()
        try skipThroughIntroduction()

        // Wait for training to be ready
        let navTitle = application.navigationBars["Receive Training"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        // Type a character (K is always valid at level 1)
        // The app has a hidden text field that captures keyboard input
        application.typeText("K")

        // After input, feedback should appear (Correct or Incorrect)
        // We just verify the app doesn't crash and accepts input
        // The actual feedback depends on what character was played
        sleep(1) // Wait for audio and feedback

        // App should still be responsive
        XCTAssertTrue(navTitle.exists, "App should remain in training after input")
    }

    // MARK: Private

    private var app: XCUIApplication?

    /// Helper to safely access the app, fails test if not available.
    private func getApp() throws -> XCUIApplication {
        guard let application = app else {
            XCTFail("App not initialized")
            throw XCTestError(.failureWhileWaiting)
        }
        return application
    }

    /// Navigate from home screen to receive training.
    private func navigateToReceiveTraining() throws {
        let application = try getApp()
        let receiveButton = application.buttons["Start Receive Training"]
        XCTAssertTrue(receiveButton.waitForExistence(timeout: 5))
        receiveButton.tap()
    }

    /// Skip through all introduction characters by tapping Next.
    private func skipThroughIntroduction() throws {
        let application = try getApp()

        // Keep tapping "Next Character" or "Start Training" until we're out of intro
        for _ in 0 ..< 10 {
            // Check if we have "Start Training" button (last intro character)
            let startButton = application.buttons["Start Training"]
            if startButton.exists {
                startButton.tap()
                return
            }

            // Otherwise tap "Next Character"
            let nextButton = application.buttons["Next Character"]
            if nextButton.exists {
                nextButton.tap()
                // Small delay to let UI update
                usleep(100_000) // 100ms
            } else {
                // Neither button exists, we're probably in training already
                return
            }
        }
    }
}

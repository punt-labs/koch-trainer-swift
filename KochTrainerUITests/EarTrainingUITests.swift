import XCTest

/// UI tests for the Ear Training flow.
/// Tests navigation, introduction, pattern reproduction, and completion using page objects.
final class EarTrainingUITests: XCTestCase {

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

    func testNavigateToEarTraining() throws {
        let learnPage = try getLearnPage()
        let trainingPage = learnPage.goToEarTraining()

        trainingPage.waitForIntro()
        trainingPage.assertInIntroPhase()
    }

    // MARK: - Introduction Phase Tests

    func testIntroductionShowsCharacterAndPattern() throws {
        let trainingPage = try getLearnPage()
            .goToEarTraining()
            .waitForIntro()

        XCTAssertTrue(
            trainingPage.introCharacter.exists || trainingPage.nextCharacterButton.exists,
            "Should show intro character or navigation"
        )
    }

    func testSkipIntroductionToTraining() throws {
        let trainingPage = try getLearnPage()
            .goToEarTraining()
            .waitForIntro()
            .skipIntroduction()
            .waitForTraining()

        trainingPage.assertInTrainingPhase()
    }

    // MARK: - Training Phase Tests

    func testTrainingShowsDitDahButtons() throws {
        let trainingPage = try getLearnPage()
            .goToEarTraining()
            .waitForIntro()
            .skipIntroduction()
            .waitForTraining()

        XCTAssertTrue(
            trainingPage.ditButton.waitForExistence(timeout: 3),
            "Dit button should be visible"
        )
        XCTAssertTrue(
            trainingPage.dahButton.exists,
            "Dah button should be visible"
        )
    }

    func testCanTapDitButton() throws {
        let trainingPage = try getLearnPage()
            .goToEarTraining()
            .waitForIntro()
            .skipIntroduction()
            .waitForTraining()

        trainingPage.tapDit()

        XCTAssertTrue(
            trainingPage.isInTrainingPhase,
            "Should remain in training after dit input"
        )
    }

    func testCanTapDahButton() throws {
        let trainingPage = try getLearnPage()
            .goToEarTraining()
            .waitForIntro()
            .skipIntroduction()
            .waitForTraining()

        trainingPage.tapDah()

        XCTAssertTrue(
            trainingPage.isInTrainingPhase,
            "Should remain in training after dah input"
        )
    }

    func testCanReproducePattern() throws {
        let trainingPage = try getLearnPage()
            .goToEarTraining()
            .waitForIntro()
            .skipIntroduction()
            .waitForTraining()

        // Reproduce a pattern (K: -.-)
        trainingPage.reproducePattern("-.-")

        trainingPage.waitForFeedback()

        XCTAssertTrue(
            trainingPage.isInTrainingPhase || trainingPage.isCompleted,
            "Should remain in training or complete after pattern input"
        )
    }

    func testTrainingShowsScoreDisplay() throws {
        let trainingPage = try getLearnPage()
            .goToEarTraining()
            .waitForIntro()
            .skipIntroduction()
            .waitForTraining()

        XCTAssertTrue(
            trainingPage.scoreDisplay.waitForExistence(timeout: 3),
            "Score display should be visible during training"
        )
    }

    // MARK: - Pause/Resume Tests

    func testCanPauseAndResumeTraining() throws {
        let trainingPage = try getLearnPage()
            .goToEarTraining()
            .waitForIntro()
            .skipIntroduction()
            .waitForTraining()

        trainingPage.pause()
        XCTAssertTrue(
            trainingPage.resumeButton.waitForExistence(timeout: 3),
            "Resume button should appear when paused"
        )

        trainingPage.resume()
        trainingPage.waitForTraining()
        trainingPage.assertInTrainingPhase()
    }

    func testCanEndSessionFromPaused() throws {
        let trainingPage = try getLearnPage()
            .goToEarTraining()
            .waitForIntro()
            .skipIntroduction()
            .waitForTraining()

        trainingPage.pause()
        trainingPage.endSession()

        XCTAssertTrue(
            trainingPage.doneButton.waitForExistence(timeout: 5)
                || trainingPage.tryAgainButton.waitForExistence(timeout: 1),
            "Should show completion options after ending session"
        )
    }

    // MARK: - Completion Tests

    func testCanReturnHomeFromCompletion() throws {
        let trainingPage = try getLearnPage()
            .goToEarTraining()
            .waitForIntro()
            .skipIntroduction()
            .waitForTraining()

        trainingPage.pause()
        trainingPage.endSession()

        _ = trainingPage.doneButton.waitForExistence(timeout: 5)
        let returnedLearnPage = trainingPage.tapDone()

        returnedLearnPage.waitForPage()
        returnedLearnPage.assertDisplayed()
    }

    // MARK: Private

    private var app: XCUIApplication?

    private func getLearnPage() throws -> LearnPage {
        let application = try XCTUnwrap(app, "App should be initialized in setUp")
        return LearnPage(app: application).waitForPage()
    }
}

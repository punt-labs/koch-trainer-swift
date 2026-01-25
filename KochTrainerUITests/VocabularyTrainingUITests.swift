import XCTest

/// UI tests for the Vocabulary Training flow.
/// Tests navigation, receive mode, send mode, pause/resume, and completion.
final class VocabularyTrainingUITests: XCTestCase {

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

    func testNavigateToCommonWordsReceive() throws {
        let vocabPage = try getVocabPage()
        let trainingPage = vocabPage.goToCommonWordsReceive()

        trainingPage.waitForTraining()
        XCTAssertTrue(
            trainingPage.view.exists,
            "Vocabulary training view should be displayed"
        )
    }

    func testNavigateToCommonWordsSend() throws {
        let vocabPage = try getVocabPage()
        let trainingPage = vocabPage.goToCommonWordsSend()

        trainingPage.waitForTraining()
        XCTAssertTrue(
            trainingPage.view.exists,
            "Vocabulary training view should be displayed"
        )
    }

    func testNavigateToCallsignReceive() throws {
        let vocabPage = try getVocabPage()
        let trainingPage = vocabPage.goToCallsignReceive()

        trainingPage.waitForTraining()
        XCTAssertTrue(
            trainingPage.view.exists,
            "Vocabulary training view should be displayed"
        )
    }

    func testNavigateToCallsignSend() throws {
        let vocabPage = try getVocabPage()
        let trainingPage = vocabPage.goToCallsignSend()

        trainingPage.waitForTraining()
        XCTAssertTrue(
            trainingPage.view.exists,
            "Vocabulary training view should be displayed"
        )
    }

    // MARK: - Receive Mode Tests

    func testReceiveModeShowsReplayButton() throws {
        let trainingPage = try getVocabPage()
            .goToCommonWordsReceive()
            .waitForReceivePhase(timeout: 15)

        trainingPage.assertReceivePhase()
        trainingPage.assertReplayButtonVisible()
    }

    func testReceiveModeCanReplay() throws {
        let trainingPage = try getVocabPage()
            .goToCommonWordsReceive()
            .waitForReceivePhase(timeout: 15)

        // Tap replay and verify still in training
        trainingPage.tapReplay()

        XCTAssertTrue(
            trainingPage.receivePhaseView.exists || trainingPage.isCompleted,
            "Should remain in receive phase or complete after replay"
        )
    }

    func testReceiveModeCanPause() throws {
        let trainingPage = try getVocabPage()
            .goToCommonWordsReceive()
            .waitForReceivePhase(timeout: 15)

        trainingPage.pause()

        trainingPage.waitForPaused()
        trainingPage.assertPaused()
    }

    // MARK: - Send Mode Tests

    func testSendModeShowsDitDahButtons() throws {
        let trainingPage = try getVocabPage()
            .goToCommonWordsSend()
            .waitForSendPhase(timeout: 15)

        trainingPage.assertSendPhase()
        trainingPage.assertInputButtonsVisible()
    }

    func testSendModeCanTapDit() throws {
        let trainingPage = try getVocabPage()
            .goToCommonWordsSend()
            .waitForSendPhase(timeout: 15)

        trainingPage.tapDit()

        // Should still be in session after tapping
        XCTAssertTrue(
            trainingPage.sendPhaseView.exists || trainingPage.isCompleted,
            "Should remain in send phase or complete after dit"
        )
    }

    func testSendModeCanTapDah() throws {
        let trainingPage = try getVocabPage()
            .goToCommonWordsSend()
            .waitForSendPhase(timeout: 15)

        trainingPage.tapDah()

        XCTAssertTrue(
            trainingPage.sendPhaseView.exists || trainingPage.isCompleted,
            "Should remain in send phase or complete after dah"
        )
    }

    func testSendModeCanPause() throws {
        let trainingPage = try getVocabPage()
            .goToCommonWordsSend()
            .waitForSendPhase(timeout: 15)

        trainingPage.pause()

        trainingPage.waitForPaused()
        trainingPage.assertPaused()
    }

    // MARK: - Pause/Resume Tests

    func testPausedViewShowsResumeButton() throws {
        let trainingPage = try getVocabPage()
            .goToCommonWordsReceive()
            .waitForReceivePhase(timeout: 15)
            .pause()
            .waitForPaused()

        XCTAssertTrue(
            trainingPage.resumeButton.exists,
            "Resume button should be visible when paused"
        )
    }

    func testPausedViewShowsEndSessionButton() throws {
        let trainingPage = try getVocabPage()
            .goToCommonWordsReceive()
            .waitForReceivePhase(timeout: 15)
            .pause()
            .waitForPaused()

        XCTAssertTrue(
            trainingPage.endSessionButton.exists,
            "End Session button should be visible when paused"
        )
    }

    func testCanResumeFromPaused() throws {
        let trainingPage = try getVocabPage()
            .goToCommonWordsReceive()
            .waitForReceivePhase(timeout: 15)
            .pause()
            .waitForPaused()

        trainingPage.resume()

        // Wait for training to resume
        _ = trainingPage.receivePhaseView.waitForExistence(timeout: 5)

        XCTAssertTrue(
            trainingPage.isReceivePhase || trainingPage.isCompleted,
            "Should resume to receive phase or complete"
        )
    }

    func testCanEndSessionFromPaused() throws {
        let trainingPage = try getVocabPage()
            .goToCommonWordsSend()
            .waitForSendPhase(timeout: 15)
            .pause()
            .waitForPaused()

        trainingPage.endSession()

        trainingPage.waitForCompleted()
        trainingPage.assertCompleted()
    }

    // MARK: - Completed State Tests

    func testCompletedViewShowsDoneButton() throws {
        let trainingPage = try getVocabPage()
            .goToCommonWordsReceive()
            .waitForReceivePhase(timeout: 15)
            .pause()
            .waitForPaused()
            .endSession()
            .waitForCompleted()

        XCTAssertTrue(
            trainingPage.doneButton.exists,
            "Done button should be visible when completed"
        )
    }

    func testCompletedViewShowsStats() throws {
        let trainingPage = try getVocabPage()
            .goToCommonWordsSend()
            .waitForSendPhase(timeout: 15)
            .pause()
            .waitForPaused()
            .endSession()
            .waitForCompleted()

        XCTAssertTrue(
            trainingPage.completedStats.exists || trainingPage.scoreText.exists,
            "Stats should be visible when completed"
        )
    }

    func testCanReturnFromCompleted() throws {
        let vocabPage = try getVocabPage()
            .goToCommonWordsReceive()
            .waitForReceivePhase(timeout: 15)
            .pause()
            .waitForPaused()
            .endSession()
            .waitForCompleted()
            .tapDone()

        vocabPage.waitForPage()
        vocabPage.assertDisplayed()
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

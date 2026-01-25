import XCTest

/// Page object for the QSO mode selection screen.
/// Allows selecting QSO style and start mode before beginning a session.
final class QSOPage: BasePage {

    // MARK: Lifecycle

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: Internal

    let app: XCUIApplication

    // MARK: - Element Accessors

    var view: XCUIElement {
        element(id: "qso-view")
    }

    var startModePicker: XCUIElement {
        element(id: "qso-start-mode-picker")
    }

    var startButton: XCUIElement {
        button(id: "qso-start-button")
    }

    var callsignDisplay: XCUIElement {
        staticText(id: "qso-callsign-display")
    }

    /// Returns the style card element for a given style.
    func styleCard(_ style: String) -> XCUIElement {
        element(id: "qso-style-\(style)")
    }

    // MARK: - Wait Helpers

    /// Wait for QSO page to load.
    @discardableResult
    func waitForPage(timeout: TimeInterval = 5) -> Self {
        _ = view.waitForExistence(timeout: timeout)
        return self
    }

    // MARK: - Style Selection

    /// Select a QSO style.
    @discardableResult
    func selectStyle(_ style: String) -> Self {
        let card = styleCard(style)
        _ = card.waitForExistence(timeout: 3)
        card.tap()
        return self
    }

    /// Select First Contact style (beginner).
    @discardableResult
    func selectFirstContact() -> Self {
        selectStyle("firstContact")
    }

    /// Select Signal Report style (intermediate).
    @discardableResult
    func selectSignalReport() -> Self {
        selectStyle("signalReport")
    }

    /// Select Contest style (advanced).
    @discardableResult
    func selectContest() -> Self {
        selectStyle("contest")
    }

    /// Select Rag Chew style (expert).
    @discardableResult
    func selectRagChew() -> Self {
        selectStyle("ragChew")
    }

    // MARK: - Navigation Actions

    /// Start the QSO session.
    @discardableResult
    func startQSO() -> MorseQSOPage {
        _ = startButton.waitForExistence(timeout: 3)
        startButton.tap()
        return MorseQSOPage(app: app)
    }

    // MARK: - Assertions

    /// Assert QSO page is displayed.
    func assertDisplayed() {
        assertExists(id: "qso-view", message: "QSO view should be displayed")
    }

    /// Assert callsign is displayed.
    func assertCallsignDisplayed() {
        XCTAssertTrue(callsignDisplay.exists, "Callsign should be displayed")
    }
}

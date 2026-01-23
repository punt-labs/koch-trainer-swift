import XCTest

// MARK: - BasePage

/// Base protocol for all page objects in UI tests.
/// Provides common element accessors and wait helpers.
protocol BasePage {
    var app: XCUIApplication { get }
}

extension BasePage {

    // MARK: - Element Accessors

    /// Find element by accessibility identifier.
    func element(id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Find button by accessibility identifier.
    func button(id: String) -> XCUIElement {
        app.buttons[id]
    }

    /// Find static text by accessibility identifier.
    func staticText(id: String) -> XCUIElement {
        app.staticTexts[id]
    }

    /// Find navigation bar by title.
    func navigationBar(_ title: String) -> XCUIElement {
        app.navigationBars[title]
    }

    // MARK: - Wait Helpers

    /// Wait for element to exist with default timeout.
    @discardableResult
    func waitForElement(id: String, timeout: TimeInterval = 5) -> XCUIElement {
        let element = element(id: id)
        _ = element.waitForExistence(timeout: timeout)
        return element
    }

    /// Wait for button to exist with default timeout.
    @discardableResult
    func waitForButton(id: String, timeout: TimeInterval = 5) -> XCUIElement {
        let button = button(id: id)
        _ = button.waitForExistence(timeout: timeout)
        return button
    }

    /// Assert element exists.
    func assertExists(id: String, message: String? = nil, timeout: TimeInterval = 5) {
        let element = element(id: id)
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            message ?? "Element '\(id)' should exist"
        )
    }

    /// Assert element does not exist.
    func assertNotExists(id: String, message: String? = nil) {
        let element = element(id: id)
        XCTAssertFalse(element.exists, message ?? "Element '\(id)' should not exist")
    }

    // MARK: - Tap Helpers

    /// Tap element by accessibility identifier.
    func tap(id: String, timeout: TimeInterval = 5) {
        let element = waitForElement(id: id, timeout: timeout)
        XCTAssertTrue(element.exists, "Element '\(id)' should exist before tapping")
        element.tap()
    }

    /// Tap button by accessibility identifier.
    func tapButton(id: String, timeout: TimeInterval = 5) {
        let button = waitForButton(id: id, timeout: timeout)
        XCTAssertTrue(button.exists, "Button '\(id)' should exist before tapping")
        button.tap()
    }
}

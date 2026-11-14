import XCTest

/// Drives the Vitals tab the way a person would: grant Health access, log a
/// blood pressure reading, and confirm it appears and reached Apple Health.
final class VitalsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLogBloodPressureSavesToHealth() {
        let app = XCUIApplication()
        app.launch()

        allowHealthAccessIfAsked(app)

        app.buttons["Log Reading"].tap()

        let fields = app.textFields
        XCTAssertTrue(fields.element(boundBy: 0).waitForExistence(timeout: 5), "Log Reading form did not open")
        fields.element(boundBy: 0).tap()
        fields.element(boundBy: 0).typeText("131")
        fields.element(boundBy: 1).tap()
        fields.element(boundBy: 1).typeText("87")
        app.buttons["Save"].tap()

        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS '131/87'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Logged reading did not appear in the list")

        // The row's identifier flips once Health accepts the copy.
        let inHealth = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'reading.own.inHealth' AND label CONTAINS '131/87'")).firstMatch
        XCTAssertTrue(inHealth.waitForExistence(timeout: 10), "Reading was not saved to Apple Health")
    }

    /// The Health permission sheet only shows the first time; skip it when absent.
    @MainActor
    private func allowHealthAccessIfAsked(_ app: XCUIApplication) {
        let turnOnAll = app.staticTexts["Turn On All"]
        guard turnOnAll.waitForExistence(timeout: 8) else { return }
        turnOnAll.tap()
        app.navigationBars.buttons["Allow"].tap()
    }
}

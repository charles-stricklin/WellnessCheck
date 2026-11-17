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
        // Setup has its own flow; start this test on the Vitals list, not the auto-opened form.
        app.launchArguments += ["-onboarding.done", "YES", "-onboarding.healthSkipped", "NO",
                                "-prefs.openToLogReading", "NO"]
        app.launch()

        allowHealthAccessIfAsked(app)

        app.buttons["Log Reading"].tap()

        let fields = app.textFields
        XCTAssertTrue(fields.element(boundBy: 0).waitForExistence(timeout: 5), "Log Reading form did not open")
        type("131", into: fields.element(boundBy: 0))
        type("87", into: fields.element(boundBy: 1))
        app.buttons["Save"].tap()

        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS '131/87'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Logged reading did not appear in the list")

        // The row's identifier flips once Health accepts the copy.
        let inHealth = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'reading.own.inHealth' AND label CONTAINS '131/87'")).firstMatch
        XCTAssertTrue(inHealth.waitForExistence(timeout: 10), "Reading was not saved to Apple Health")

        // A family member's readings stay out of Health and off the owner's list.
        app.buttons["Me"].tap()
        app.buttons["Add Family Member"].tap()
        type("Pat", into: app.textFields["Name"])
        app.buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Pat"].waitForExistence(timeout: 5), "Did not switch to the new family member")
        XCTAssertFalse(app.staticTexts["131/87"].exists, "Owner's reading showed on a family member's list")

        app.buttons["Log Reading"].tap()
        XCTAssertTrue(fields.element(boundBy: 0).waitForExistence(timeout: 5))
        type("122", into: fields.element(boundBy: 0))
        type("79", into: fields.element(boundBy: 1))
        app.buttons["Save"].tap()

        let patReading = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'reading.own' AND label CONTAINS '122/79'")).firstMatch
        XCTAssertTrue(patReading.waitForExistence(timeout: 5), "Family member's reading did not appear")
        sleep(3)
        XCTAssertTrue(patReading.exists, "Family member's reading was sent to Apple Health")
    }

    /// A tap that lands while a sheet is still sliding up doesn't give the field the
    /// cursor, and typing then fails. Tap until the field has focus, then type.
    @MainActor
    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Text field never appeared")
        for _ in 0..<5 {
            field.tap()
            if (field.value(forKey: "hasKeyboardFocus") as? Bool) == true { break }
            usleep(300_000)
        }
        field.typeText(text)
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

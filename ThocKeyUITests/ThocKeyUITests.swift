import XCTest

final class ThocKeyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["THOCKEY_UI_TEST"] = "1"
        app.launchEnvironment["THOCKEY_UI_TEST_RESET_DEFAULTS"] = "1"
        app.launchEnvironment["THOCKEY_STORAGE_ROOT"] = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThocKeyUITests-\(UUID().uuidString)").path
        app.launch()
    }

    func testStudioLaunch_ShowsPrimaryPackControls() {
        XCTAssertTrue(app.staticTexts["Sounds & Packs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["sound-active-toggle"].exists)
        XCTAssertTrue(app.buttons["new-pack-button"].exists)
        XCTAssertTrue(app.textViews["typing-test-field"].exists)
    }

    func testSidebarNavigation_OpensLibraryAndSettings() {
        app.buttons["Sound Library"].click()
        XCTAssertTrue(app.staticTexts["Sound Library"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["import-audio-button"].exists)

        app.buttons["Settings"].click()
        XCTAssertTrue(app.staticTexts["Permissions, shortcuts, and privacy."].waitForExistence(timeout: 2))
    }

    func testSoundToggle_ChangesState() {
        let toggle = app.switches["sound-active-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let previous = toggle.value as? String
        toggle.click()
        XCTAssertNotEqual(toggle.value as? String, previous)
    }

    func testPackSelection_PreviewTypingAndVolume() {
        let packSelector = app.otherElements["active-pack-picker"]
        XCTAssertTrue(packSelector.waitForExistence(timeout: 5))
        packSelector.click()
        app.menuItems["Creamy"].click()
        XCTAssertTrue(app.staticTexts["Creamy"].waitForExistence(timeout: 2))

        XCTAssertTrue(app.buttons["preview-press-button"].exists)
        app.buttons["preview-press-button"].click()

        let typingTest = app.textViews["typing-test-field"]
        typingTest.click()
        typingTest.typeText("abc")
        XCTAssertEqual(typingTest.value as? String, "abc")

        let volume = app.sliders["master-volume-slider"]
        volume.adjust(toNormalizedSliderPosition: 0.35)
        XCTAssertLessThan(Double(volume.value as? String ?? "1") ?? 1, 0.6)
    }

    func testAccessibilityStatus_IsVisible() {
        XCTAssertTrue(app.staticTexts["Permissions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Accessibility active"].exists || app.staticTexts["Action required"].exists)
    }

    func testStudioReopening_RetainsSoundPreference() {
        let toggle = app.switches["sound-active-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.click()
        let changedValue = toggle.value as? String

        app.terminate()
        app.launchEnvironment["THOCKEY_UI_TEST_RESET_DEFAULTS"] = "0"
        app.launch()
        let relaunchedToggle = app.switches["sound-active-toggle"]
        XCTAssertTrue(relaunchedToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(relaunchedToggle.value as? String, changedValue)
    }
}

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
        XCTAssertFalse(app.staticTexts["ALL SOUND PACKS"].exists)
    }

    func testNewPack_UsesSingleDefaultSoundPicker() {
        let newPackButton = app.buttons["new-pack-button"]
        XCTAssertTrue(newPackButton.waitForExistence(timeout: 5))
        newPackButton.click()

        XCTAssertTrue(app.staticTexts["Default Sound"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Key Down"].exists)
        XCTAssertFalse(app.staticTexts["Key Up"].exists)
    }

    func testAppearancePicker_IsAvailableAndPersists() {
        app.buttons["Settings"].click()
        let picker = app.descendants(matching: .any)["appearance-picker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 2))

        let light = app.buttons["Light"].firstMatch
        XCTAssertTrue(light.exists)
        light.click()

        app.terminate()
        app.launchEnvironment["THOCKEY_UI_TEST_RESET_DEFAULTS"] = "0"
        app.launch()
        app.buttons["Settings"].click()
        XCTAssertTrue(app.buttons["Light"].firstMatch.isSelected)
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
        let previous = String(describing: toggle.value ?? "")
        toggle.click()
        let current = String(describing: toggle.value ?? "")
        XCTAssertNotEqual(current, previous)
    }

    func testPackSelection_PreviewTypingAndVolume() {
        let packSelector = app.descendants(matching: .any)["active-pack-picker"].firstMatch
        XCTAssertTrue(packSelector.waitForExistence(timeout: 5))
        packSelector.click()
        app.menuItems["Creamy"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["Creamy"].waitForExistence(timeout: 2))

        XCTAssertTrue(app.buttons["preview-press-button"].exists)
        app.buttons["preview-press-button"].click()

        let typingTest = app.textViews["typing-test-field"]
        XCTAssertTrue(typingTest.waitForExistence(timeout: 5))
        typingTest.click()
        typingTest.typeText("abc")
        XCTAssertEqual(typingTest.value as? String, "abc")

        let volume = app.sliders["master-volume-slider"]
        volume.adjust(toNormalizedSliderPosition: 0.35)
        let rawVal = volume.value
        let volumeNum: Double = {
            if let num = rawVal as? NSNumber { return num.doubleValue }
            if let str = rawVal as? String {
                let cleaned = str.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                if let parsed = Double(cleaned) { return parsed > 1.0 ? parsed / 100.0 : parsed }
            }
            return 1.0
        }()
        XCTAssertLessThan(volumeNum, 0.6)
    }

    func testAccessibilityStatus_IsVisible() {
        XCTAssertTrue(app.staticTexts["Permissions"].waitForExistence(timeout: 5))
        let hasActiveOrRequired = app.staticTexts["Accessibility active"].exists || 
                                  app.staticTexts["Action required"].exists ||
                                  app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'active' OR label CONTAINS[c] 'required'")).firstMatch.exists
        XCTAssertTrue(hasActiveOrRequired)
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

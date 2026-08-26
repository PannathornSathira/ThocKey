import XCTest

final class ThocKeyUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["THOCKEY_UI_TEST"] = "1"
        app.launchEnvironment["THOCKEY_UI_TEST_RESET_DEFAULTS"] = "1"
        app.launchEnvironment["THOCKEY_STORAGE_ROOT"] = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThocKeyUITests-Launch-\(UUID().uuidString)").path
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

import XCTest

class TopLevelMethodsThreadTests: XCTestCase {

    override func setUp() {
        begin()
        tap("Start - Main")
        XCTAssertTrue(XCUIApplication()
                        .navigationBars["Initialized"]
                        .waitForExistence(timeout: 5), "Failed to init Statsig")
    }

    func begin() {
        let key = ProcessInfo.processInfo.environment["STATSIG_CLIENT_KEY"]
        XCTAssertEqual(key?.starts(with: "client-"), true, "Invalid Client Key Provided")

        let app = XCUIApplication()
        app.launchEnvironment = ProcessInfo.processInfo.environment
        app.launch()
    }

    func tap(_ cell: String) {
        XCUIApplication().tables.staticTexts[cell].tap()
    }

    // MARK: - Tests

    func testGates() throws {
        tap("Gates - Main")
        tap("Gates - Background")
        tap("Gates - Custom")
    }

    func testLog() throws {
        tap("Log - Main")
        tap("Log - Background")
        tap("Log - Custom")
    }

    func testLogWithMetadataAndNoValue() {
        tap("Log - Main (w/ Meta w/o value)")
        tap("Log - Background (w/ Meta w/o value)")
        tap("Log - Custom (w/ Meta w/o value)")
    }

    func testLogWithMetadataAndStringValue() {
        tap("Log - Main (w/ Meta and String value)")
        tap("Log - Background (w/ Meta and String value)")
        tap("Log - Custom (w/ Meta and String value)")
    }

    func testLogWithMetadataAndNumberValue() {
        tap("Log - Main (w/ Meta and Number value)")
        tap("Log - Background (w/ Meta and Number value)")
        tap("Log - Custom (w/ Meta and Number value)")
    }

    func testConfigs() throws {
        tap("Configs - Main")
        tap("Configs - Background")
        tap("Configs - Custom")
    }

    func testExperiments() throws {
        tap("Experiments - Main")
        tap("Experiments - Background")
        tap("Experiments - Custom")
    }

    func testExperimentsWithDeviceValues() throws {
        tap("Experiments - Main (Keep Device Value)")
        tap("Experiments - Background (Keep Device Value)")
        tap("Experiments - Custom (Keep Device Value)")
    }

    func testGetStableID() throws {
        tap("Stable ID - Main")
        tap("Stable ID - Background")
        tap("Stable ID - Custom")
    }

    func testUpdateUser() throws {
        tap("Update User - Main (DLOOMB)")
        tap("Update User - Custom (JKW)")
        tap("Update User - Background (DLOOMB)")
        tap("Update User - Main (JKW)")
        tap("Update User - Background (TORE)")
        tap("Update User - Main (TORE)")
        tap("Update User - Custom (DLOOMB)")
        tap("Update User - Background (JKW)")
        tap("Update User - Custom (TORE)")
    }

    func testShutdown() throws {
        tap("Shutdown - Main")

        tap("Start - Main")
        tap("Shutdown - Background")

        tap("Start - Main")
        tap("Shutdown - Custom")
    }
}

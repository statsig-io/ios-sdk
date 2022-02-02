import XCTest


class StartingStatsigThreadsTests: XCTestCase {
    func begin() {
        let app = XCUIApplication()
        app.launchEnvironment = ProcessInfo.processInfo.environment
        app.launch()
    }

    func tap(_ cell: String) {
        XCUIApplication().tables.staticTexts[cell].tap()
    }

    func testStartOnMain() throws {
        begin()
        tap("Start - Main")
    }

    func testStartOnBackground() throws {
        begin()
        tap("Start - Background")
    }

    func testStartOnCustom() throws {
        begin()
        tap("Start - Custom")
    }

    func testStartOnMainWithUser() throws {
        begin()
        tap("Start - Main (w/ User)")
    }

    func testStartOnBackgroundWithUser() throws {
        begin()
        tap("Start - Background (w/ User)")
    }

    func testStartOnCustomWithUser() throws {
        begin()
        tap("Start - Custom (w/ User)")
    }
}

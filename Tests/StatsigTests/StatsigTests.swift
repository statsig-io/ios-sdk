import XCTest
@testable import Statsig

final class StatsigTests: XCTestCase {
    func testInvalidInput() {
        Statsig.start(sdkKey: "", user: StatsigUser(userID: "jkw", email: "jkw@statsig.com")) { errorMessage in
            XCTAssert(errorMessage != nil)
        }
        Statsig.start(sdkKey: "secret-1234", user: StatsigUser(userID: "jkw", email: "jkw@statsig.com")) { errorMessage in
            XCTAssert(errorMessage != nil)
        }
        Statsig.start(sdkKey: "secret-1234", user: StatsigUser(userID: "jkw", email: "jkw@statsig.com")) { errorMessage in
            XCTAssert(errorMessage != nil)
        }
    }

    func testCallAPIBeforeStart() {
        // Should all return default values because Statsig has not been started
        XCTAssertFalse(Statsig.checkGate("some_gate"))

        let config = Statsig.getConfig("some_config")
        XCTAssertEqual(config.getValue(forKey: "string", defaultValue: "default"), "default")
        XCTAssertEqual(config.getValue(forKey: "int", defaultValue: 3), 3)
        XCTAssertEqual(config.getValue(forKey: "Double", defaultValue: 3.23), 3.23)
        XCTAssertEqual(config.getValue(forKey: "Dict", defaultValue: ["key": 3]), ["key": 3])
        XCTAssertEqual(config.getValue(forKey: "Array", defaultValue: [1, 3]), [1, 3])
    }
}

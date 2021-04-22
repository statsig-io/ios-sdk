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
        XCTAssertNil(config)
    }
}

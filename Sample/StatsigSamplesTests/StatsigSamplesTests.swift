import XCTest

@testable import StatsigSamples

final class StatsigSamplesTests: XCTestCase {

    func testExampleViewControllersCompile() throws {
        let controllers: [UIViewController] = [
            BasicOnDeviceEvaluationsViewController(),
            SynchronousInitViewController(),
            BasicOnDeviceEvaluationsViewControllerObjC(),
            PerfOnDeviceEvaluationsViewControllerObjC()
        ]

        XCTAssertNotNil(controllers)
    }

}

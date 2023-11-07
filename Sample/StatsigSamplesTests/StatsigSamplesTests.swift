import XCTest

@testable import StatsigSamples

final class StatsigSamplesTests: XCTestCase {

    func testExampleViewControllersCompile() throws {
        let controllers: [UIViewController] = [
            BasicViewController(),
            BasicViewControllerObjC(),
            PerfViewControllerObjC(),
            ManyGatesSwiftUIViewController()
        ]

        XCTAssertNotNil(controllers)
    }

}

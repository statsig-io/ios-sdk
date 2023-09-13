import Foundation

import XCTest
import Nimble
import OHHTTPStubs
import Quick
@testable import Statsig

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

final class ApiOverrideSpec: BaseSpec {
    override func spec() {
        super.spec()

        var request: URLRequest?


        describe("When Overriden") {
            func start() {
                let opts = StatsigOptions(api: "http://api.override.com")
                request = TestUtils.startWithStatusAndWait(options: opts)
            }

            it("calls initialize on the overridden api") {
                start()
                expect(request?.url?.absoluteString).to(equal("http://api.override.com/v1/initialize"))
            }

            it("calls initialize on the overridden api") {
                start()
                var hitLog = false
                TestUtils.captureLogs(host: "api.override.com") { logs in
                    hitLog = true
                }

                Statsig.logEvent("test_event")
                Statsig.shutdown()
                expect(hitLog).toEventually(beTrue())
            }
        }

        describe("When Not Overriden") {
            func start() {
                request = TestUtils.startWithStatusAndWait()
            }

            it("calls initialize on the statsig api") {
                start()
                expect(request?.url?.absoluteString).to(equal("https://api.statsig.com/v1/initialize"))
            }

            it("calls initialize on the statsig api") {
                start()
                var hitLog = false
                TestUtils.captureLogs(host: "api.statsig.com") { logs in
                    hitLog = true
                }

                Statsig.logEvent("test_event")
                Statsig.shutdown()
                expect(hitLog).toEventually(beTrue())
            }
        }

    }
}

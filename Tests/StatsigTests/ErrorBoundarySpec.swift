import Foundation

import Nimble
import OHHTTPStubs
import Quick
import Statsig

#if !COCOAPODS

#if canImport(StatsigInternalObjC)
import StatsigInternalObjC
#endif

import OHHTTPStubsSwift
#endif


class ErrorBoundarySpec: BaseSpec {
    override func spec() {
        super.spec()
        
        describe("Error Boundary") {
            let defaults = UserDefaults(suiteName: "ErrorBoundarySpec")
            var requests: [[String: Any]] = []

            beforeEach {
                requests = []
                stub(condition: isPath("/v1/sdk_exception")) { req in
                    requests.append(req.statsig_body ?? [:])
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 202, headers: nil)
                }
            }

            afterEach {
                HTTPStubs.removeAllStubs()
            }

            it("logs to the endpoint") {
                let boundary = ErrorBoundary(key: "client-key", deviceEnvironment: ["sdkType": "ios"])
                boundary.capture("a-tag") {
                    defaults?.set(["crash": nil], forKey: "ShouldCrash")
                }

                expect(requests).toEventually(haveCount(1))
                expect(requests[0]["tag"] as? String).to(equal("a-tag"))
            }

            it("recovers") {
                let boundary = ErrorBoundary(key: "client-key", deviceEnvironment: ["sdkType": "ios"])
                var recovered = false
                boundary.capture("another-tag") {
                    defaults?.set(["crash": nil], forKey: "ShouldCrash")
                } withRecovery: {
                    recovered = true
                }

                expect(requests).toEventually(haveCount(1))
                expect(requests[0]["tag"] as? String).to(equal("another-tag"))
                expect(recovered).toEventually(beTrue())
            }
        }
    }
}

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

            it("logs to the endpoint") {
                var called = false
                stub(condition: isPath("/v1/sdk_exception")) { _ in
                    called = true
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 202, headers: nil)
                }

                let boundary = ErrorBoundary(key: "client-key", deviceEnvironment: ["sdkType": "ios"])
                boundary.capture {
                    defaults?.set(["crash": nil], forKey: "ShouldCrash")
                }

                expect(called).toEventually(beTrue())
            }

            it("recovers") {
                stub(condition: isPath("/v1/sdk_exception")) { _ in
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 202, headers: nil)
                }

                let boundary = ErrorBoundary(key: "client-key", deviceEnvironment: ["sdkType": "ios"])
                var recovered = false
                boundary.capture {
                    defaults?.set(["crash": nil], forKey: "ShouldCrash")
                } withRecovery: {
                    recovered = true
                }

                expect(recovered).toEventually(beTrue())
            }
        }
    }
}

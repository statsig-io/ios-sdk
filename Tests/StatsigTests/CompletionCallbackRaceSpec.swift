import Nimble
import OHHTTPStubs
import Quick

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

@testable import Statsig

class CompletionCallbackRaceSpec: BaseSpec {
    override func spec() {
        super.spec()

        let user = StatsigUser(userID: "jkw")
        let opts = StatsigOptions(initTimeout: 0.01)

        var client: StatsigClient?

        describe("CompletionCallbackRace") {
            beforeEach {
                stub(condition: isPath("/v1/initialize")) { request in
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil).responseTime(0.01)
                }
            }

            it("invalidates previous timers") {
                for _ in 0..<10 {
                    var message: String?
                    var calls = 0
                    waitUntil { done in
                        client = StatsigClient(sdkKey: "client-key", user: user, options: opts) { errorMessage in
                            message = errorMessage
                            calls += 1
                            done()
                        }
                    }

                    expect(client).toNot(beNil())
                    expect(message).to(equal("initTimeout Expired"))
                    expect(calls).toEventually(equal(1))
                }

            }
        }
    }
}

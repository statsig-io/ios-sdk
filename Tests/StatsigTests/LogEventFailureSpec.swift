import Foundation

import Nimble
import OHHTTPStubs
import Quick
@testable import Statsig

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

class MockNetwork: NetworkService {
    var responseError: String?
    var responseData: Data?
    var responseIsAsync = false
    var timesCalled: Int = 0

    init() {
        let opts = StatsigOptions()
        let store = InternalStore("", StatsigUser(), options: opts)
        super.init(sdkKey: "", options: opts, store: store)
    }

    override func sendEvents(
        forUser: StatsigUser,
        events: [Event],
        completion: @escaping ((String?, Data?) -> Void)) {
            let work = { [weak self] in
                guard let it = self else { return }
                completion(it.responseError, it.responseData)
                it.timesCalled += 1
            }

            responseIsAsync ? DispatchQueue.global().async(execute: work) : work()
    }
}

class LogEventFailureSpec: BaseSpec {
    override func spec() {
        super.spec()

        describe("LogEventFailure") {
            let user = StatsigUser(userID: "a-user")
            let defaults = MockDefaults()

            var network: MockNetwork!
            var logger: EventLogger!

            beforeEach {
                defaults.data.reset([:])

                network = MockNetwork()
                network.responseError = "Nah uh uh uh"
                network.responseData = "{}".data(using: .utf8)

                logger = EventLogger(user: user, networkService: network, userDefaults: defaults)
                logger.log(Event(user: user, name: "an_event", disableCurrentVCLogging: true))
            }

            it("handles errors that come back on the calling thread") {
                network.responseIsAsync = false
                logger.flush()
                expect(network.timesCalled).toEventually(equal(1))
                expect(logger.failedRequestQueue.count).toEventually(equal(1))
            }

            it("handles errors that come back on a bg thread") {
                network.responseIsAsync = true
                logger.flush()
                expect(network.timesCalled).toEventually(equal(1))
                expect(logger.failedRequestQueue.count).toEventually(equal(1))
            }
        }
    }
}

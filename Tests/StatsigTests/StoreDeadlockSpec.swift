import Foundation

import XCTest
import Nimble
import OHHTTPStubs
import Quick

@testable import Statsig

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

class StoreDeadlockSpec: BaseSpec {
    override func spec() {
        super.spec()

        describe("Store Deadlock Detection") {
            let iterations = 1000
            let numberOfTasks = 10

            var queues: [DispatchQueue] = []

            beforeEach {
                NotificationCenter.default
                        .addObserver(
                            forName: UserDefaults.didChangeNotification,
                            object: UserDefaults.standard, queue: .main) { _ in }

                stub(condition: isHost(ApiHost)) { req in
                    let delay = Double.random(in: 0.1 ..< 1.0)

                    return HTTPStubsResponse(jsonObject: [
                        "feature_gates": [
                            "a_gate".sha256(): [
                                "value": true,
                                "rule_id": "rule_id_1",
                                "secondary_exposures": []
                            ]
                        ],
                        "dynamic_configs": [:],
                        "layer_configs": [:],
                        "has_updates": true
                    ], statusCode: 200, headers: nil).responseTime(delay)
                }

                waitUntil { done in
                    Statsig.start(sdkKey: "client-key") { err in done() }
                }

                if (queues.isEmpty) {
                    for i in 0..<numberOfTasks {
                        queues.append(DispatchQueue(label: "com.statsig.task_\(i)"))
                    }
                }
            }

            afterEach {
                HTTPStubs.removeAllStubs()
            }

            it("can execute many different operations") {
                var i = 0

                for j in 0..<iterations {
                    let queue = queues[j % numberOfTasks]

                    queue.async { 
                        let user = StatsigUser(userID: "user_\(Int.random(in: 1...100))_\(j)")

                        Statsig.updateUser(user) { err in
                            i += 1
                        }
                        _ = Statsig.checkGate("a_gate")
                    }
                }

                expect(i).toEventually(equal(iterations), timeout: .seconds(5))
            }
        }
    }
}

import Foundation

import Nimble
import OHHTTPStubs
import Quick

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

@testable import Statsig
import SwiftUI

class SDKKeySpec: BaseSpec {
    static let mockUserValues: [String: Any] = [
        "feature_gates": [
            "gate_name_1".sha256(): [
                "value": false,
                "rule_id": "rule_id_1",
                "secondary_exposures": [
                    ["gate": "employee", "gateValue": "true", "ruleID": "rule_id_employee"]
                ]
            ],
            "gate_name_2".sha256(): ["value": true, "rule_id": "rule_id_2"]
        ],
        "dynamic_configs": [
            "config".sha256(): DynamicConfigSpec.TestMixedConfig
        ],
        "layer_configs": [
            "allocated_layer".sha256(): DynamicConfigSpec
                .TestMixedConfig
                .merging(["allocated_experiment_name":"config".sha256()]) { (_, new) in new },
            "unallocated_layer".sha256(): DynamicConfigSpec
                .TestMixedConfig
        ],
        "has_updates": true
    ]

    override func spec() {
        super.spec()
        
        describe("SDK Keys") {
            beforeEach {
                InternalStore.deleteAllLocalStorage()
                StatsigClient.autoValueUpdateTime = 10
            }

            afterEach {
                HTTPStubs.removeAllStubs()
                Statsig.shutdown()
                InternalStore.deleteAllLocalStorage()
            }

            it("works when provided invalid SDK key by returning default value") {
                stub(condition: isHost("api.statsig.com")) { _ in
                    let notConnectedError = NSError(domain: NSURLErrorDomain, code: 403)
                    return HTTPStubsResponse(error: notConnectedError)
                }

                var error: String?
                var gate: Bool?
                var config: DynamicConfig?
                waitUntil { done in
                    Statsig.start(sdkKey: "invalid_sdk_key", options: StatsigOptions()) { errorMessage in
                        error = errorMessage
                        gate = Statsig.checkGate("show_coupon")
                        config = Statsig.getConfig("my_config")
                        done()
                    }
                }

                expect(error).toEventually(contain("403"))
                expect(gate).toEventually(beFalse())
                expect(NSDictionary(dictionary: config!.value)).toEventually(equal(NSDictionary(dictionary: [:])))
                expect(config!.evaluationDetails.reason).toEventually(equal(.Uninitialized))
            }

            it("works when provided server secret by returning default value") {
                var error: String?
                var gate: Bool?
                var config: DynamicConfig?
                Statsig.start(sdkKey: "secret-key") { errorMessage in
                    error = errorMessage
                    gate = Statsig.checkGate("show_coupon")
                    config = Statsig.getConfig("my_config")
                }
                expect(error).toEventually(equal("Must use a valid client SDK key."))
                expect(gate).toEventually(beFalse())
                expect(NSDictionary(dictionary: config!.value)).toEventually(equal(NSDictionary(dictionary: [:])))
                expect(config!.evaluationDetails.reason).toEventually(equal(.Uninitialized))
            }
        }
    }
}

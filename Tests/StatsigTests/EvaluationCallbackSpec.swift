import Foundation

import XCTest
import Nimble
import OHHTTPStubs
import Quick
@testable import Statsig

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

final class EvaluationCallbackSpec: BaseSpec {
    override func spec() {
        super.spec()

        let baseResponse: [String: Any] = [
            "feature_gates": [
                "a_gate": [
                    "value": true
                ]
            ],
            "dynamic_configs": [],
            "hash_used": "none",
            "layer_configs": [],
            "time": 123,
            "has_updates": true
        ]

        describe("EvaluationCallback") {
            var defaults: MockDefaults?
            var requests: [URLRequest] = []
            var gateName: String? = nil
            var configName: String? = nil
            var experimentName: String? = nil
            var layerName: String? = nil

            beforeEach {
                // Setup Mock Caching
                TestUtils.clearStorage()
                defaults = MockDefaults()
                StatsigUserDefaults.defaults = defaults!

                // Setup Event Capture
                requests = []
                stub(condition: isPath("/v1/rgstr")) { request in
                    requests.append(request)
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
                }

                // Initialize Client Instance
                stub(condition: isPath("/v1/initialize")) { _ in
                    HTTPStubsResponse(jsonObject: baseResponse, statusCode: 200, headers: nil)
                }

                func callback(data: StatsigOptions.EvaluationCallbackData) {
                    switch data {
                    case .gate(let gate):
                        gateName = gate.name
                    case .config(let config):
                        configName = config.name
                    case .experiment(let exp):
                        experimentName = exp.name
                    case .layer(let layer):
                        layerName = layer.name
                    }
                }

                let opts = StatsigOptions(evaluationCallback: callback)
                Statsig.start(sdkKey: "client-api-key", options: opts)
            }

            afterEach {
                HTTPStubs.removeAllStubs()
                Statsig.shutdown()
                TestUtils.clearStorage()
            }

            it("gets different gate results") {
                Statsig.checkGate("a_gate")
                expect(gateName).to(equal("a_gate"))
                Statsig.checkGateWithExposureLoggingDisabled("b_gate")
                expect(gateName).to(equal("b_gate"))
            }

            it("works with configs") {
                Statsig.getConfig("a_config")
                expect(configName).to(equal("a_config"))
                Statsig.getConfigWithExposureLoggingDisabled("b_config")
                expect(configName).to(equal("b_config"))
            }

            it("works with experiments") {
                Statsig.getExperiment("a_exp")
                expect(experimentName).to(equal("a_exp"))
                Statsig.getExperimentWithExposureLoggingDisabled("b_exp")
                expect(experimentName).to(equal("b_exp"))
            }

            it("works with layers") {
                Statsig.getLayer("a_layer")
                expect(layerName).to(equal("a_layer"))
                Statsig.getLayerWithExposureLoggingDisabled("b_layer")
                expect(layerName).to(equal("b_layer"))
            }
        }
    }
}

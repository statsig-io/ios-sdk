import Foundation

import Nimble
import OHHTTPStubs
import Quick
@testable import Statsig

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

class CodableSpec: BaseSpec {
    override func spec() {
        super.spec()

        describe("Codable") {
            let opts = StatsigOptions()
            opts.overrideURL = URL(string: "http://CodableSpec")

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            beforeEach {
                _ = TestUtils.startWithResponseAndWait([
                    "feature_gates": [
                        "a_gate".sha256(): [
                            "value": true
                        ]
                    ],
                    "dynamic_configs": [
                        "a_config".sha256(): [
                            "value": ["a_bool": true],
                        ]
                    ],
                    "layer_configs": [
                        "a_layer".sha256(): [
                            "value": ["a_bool": true],
                        ]
                    ],
                    "time": 321,
                    "has_updates": true
                ], options: opts)
            }

            afterEach {
                Statsig.client?.shutdown()
                Statsig.client = nil
            }


            it("encodes/decodes FeatureGate") {
                let gate = Statsig.getFeatureGateWithExposureLoggingDisabled("a_gate")

                let encoded = try! encoder.encode(gate)
                let decoded = try! decoder.decode(FeatureGate.self, from: encoded)

                expect(gate.name).to(equal(decoded.name))
                expect(gate.ruleID).to(equal(decoded.ruleID))
                expect(gate.value).to(equal(decoded.value))
                expect(gate.secondaryExposures).to(equal(decoded.secondaryExposures))

                expect(gate.evaluationDetails.reason).to(equal(decoded.evaluationDetails.reason))
                expect(gate.evaluationDetails.time).to(equal(decoded.evaluationDetails.time))
            }

            it("encodes/decodes DynamicConfig") {
                let config = Statsig.getConfigWithExposureLoggingDisabled("a_config")

                let encoded = try! encoder.encode(config)
                let decoded = try! decoder.decode(DynamicConfig.self, from: encoded)

                expect(config.name).to(equal(decoded.name))
                expect(config.ruleID).to(equal(decoded.ruleID))
                expect(config.secondaryExposures).to(equal(decoded.secondaryExposures))
                expect(config.evaluationDetails.reason).to(equal(decoded.evaluationDetails.reason))
                expect(config.evaluationDetails.time).to(equal(decoded.evaluationDetails.time))
            }

            it("encodes/decodes Layer") {
                let config = Statsig.getLayerWithExposureLoggingDisabled("a_layer")

                let encoded = try! encoder.encode(config)
                let decoded = try! decoder.decode(Layer.self, from: encoded)

                expect(config.name).to(equal(decoded.name))
                expect(config.ruleID).to(equal(decoded.ruleID))
                expect(config.secondaryExposures).to(equal(decoded.secondaryExposures))
                expect(config.evaluationDetails.reason).to(equal(decoded.evaluationDetails.reason))
                expect(config.evaluationDetails.time).to(equal(decoded.evaluationDetails.time))
            }
        }
    }
}

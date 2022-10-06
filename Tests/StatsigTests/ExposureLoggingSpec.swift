import Foundation

import Nimble
import OHHTTPStubs
import Quick
@testable import Statsig

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

func skipFrame() {
    waitUntil { done in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            done()
        }
    }
}

class ExposureLoggingSpec: QuickSpec {
    override func spec() {
        describe("ExposureLogging") {
            var logs: [[String: Any]] = []
            beforeEach {
                TestUtils.startWithResponseAndWait([
                    "feature_gates": [
                        "a_gate".sha256(): [
                            "value": true
                        ]
                    ],
                    "dynamic_configs": [
                        "an_experiment".sha256(): [
                            "value": ["a_bool": true],
                        ],
                        "a_config".sha256(): [
                            "value": ["a_bool": true],
                        ]
                    ],
                    "layer_configs": [
                        "a_layer".sha256(): [
                            "value": ["a_bool": true],
                        ]
                    ]
                ])
                Statsig.client?.logger.flushBatchSize = 1

                logs = []
                TestUtils.captureLogs { captured in
                    if let events = captured["events"] as? [[String: Any]] {
                        logs = events
                    }
                }
            }

            afterEach {
                Statsig.client?.shutdown()
                Statsig.client = nil
            }

            describe("standard use") {
                it("logs gate exposures") {
                    _ = Statsig.checkGate("a_gate")
                    skipFrame()
                    expect(logs.count).to(be(1))
                    expect(logs[0][jsonDict: "metadata"]?["gate"] as? String).to(equal("a_gate"))
                    expect(logs[0]["eventName"]as? String).to(equal("statsig::gate_exposure"))
                }

                it("logs config exposures") {
                    _ = Statsig.getConfig("a_config")
                    skipFrame()
                    expect(logs.count).to(be(1))
                    expect(logs[0][jsonDict: "metadata"]?["config"] as? String).to(equal("a_config"))
                    expect(logs[0]["eventName"]as? String).to(equal("statsig::config_exposure"))
                }

                it("logs experiment exposures") {
                    _ = Statsig.getExperiment("an_experiment")
                    skipFrame()
                    expect(logs.count).to(be(1))
                    expect(logs[0][jsonDict: "metadata"]?["config"] as? String).to(equal("an_experiment"))
                    expect(logs[0]["eventName"]as? String).to(equal("statsig::config_exposure"))
                }

                it("logs layer exposures") {
                    let layer = Statsig.getLayer("a_layer")
                    _ = layer.getValue(forKey: "a_bool", defaultValue: false)
                    skipFrame()
                    expect(logs.count).to(be(1))
                    expect(logs[0][jsonDict: "metadata"]?["config"] as? String).to(equal("a_layer"))
                    expect(logs[0]["eventName"]as? String).to(equal("statsig::layer_exposure"))
                }
            }

            describe("exposure logging disabled") {
                it("does not log gate exposures") {
                    _ = Statsig.checkGateWithExposureLoggingDisabled("a_gate")
                    skipFrame()
                    expect(logs.count).to(be(0))
                }

                it("does not log config exposures") {
                    _ = Statsig.getConfigWithExposureLoggingDisabled("a_config")
                    skipFrame()
                    expect(logs.count).to(be(0))
                }

                it("does not log experiment exposures") {
                    _ = Statsig.getExperimentWithExposureLoggingDisabled("an_experiment")
                    skipFrame()
                    expect(logs.count).to(be(0))
                }

                it("does not log layer exposures") {
                    let layer = Statsig.getLayerWithExposureLoggingDisabled("a_layer")
                    _ = layer.getValue(forKey: "a_bool", defaultValue: false)
                    skipFrame()
                    expect(logs.count).to(be(0))
                }
            }

            describe("manual exposure logging") {
                it("logs a manual gate exposure") {
                    Statsig.manuallyLogGateExposure("a_gate")
                    skipFrame()
                    expect(logs.count).to(be(1))
                    expect(logs[0][jsonDict: "metadata"]?["gate"] as? String).to(equal("a_gate"))
                    expect(logs[0][jsonDict: "metadata"]?["isManualExposure"] as? String).to(equal("true"))
                    expect(logs[0]["eventName"]as? String).to(equal("statsig::gate_exposure"))
                }

                it("logs a manual config exposure") {
                    Statsig.manuallyLogConfigExposure("a_config")
                    skipFrame()
                    expect(logs.count).to(be(1))
                    expect(logs[0][jsonDict: "metadata"]?["config"] as? String).to(equal("a_config"))
                    expect(logs[0][jsonDict: "metadata"]?["isManualExposure"] as? String).to(equal("true"))
                    expect(logs[0]["eventName"]as? String).to(equal("statsig::config_exposure"))
                }

                it("logs a manual experiment exposure") {
                    Statsig.manuallyLogExperimentExposure("an_experiment")
                    skipFrame()
                    expect(logs.count).to(be(1))
                    expect(logs[0][jsonDict: "metadata"]?["config"] as? String).to(equal("an_experiment"))
                    expect(logs[0][jsonDict: "metadata"]?["isManualExposure"] as? String).to(equal("true"))
                    expect(logs[0]["eventName"]as? String).to(equal("statsig::config_exposure"))
                }

                it("logs a manual layer param exposure") {
                    Statsig.manuallyLogLayerParameterExposure("a_layer", "value")
                    skipFrame()
                    expect(logs.count).to(be(1))
                    expect(logs[0][jsonDict: "metadata"]?["config"] as? String).to(equal("a_layer"))
                    expect(logs[0][jsonDict: "metadata"]?["isManualExposure"] as? String).to(equal("true"))
                    expect(logs[0]["eventName"]as? String).to(equal("statsig::layer_exposure"))
                }
            }
        }
    }
}

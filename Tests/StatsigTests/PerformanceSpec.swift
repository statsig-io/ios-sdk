import Foundation

import XCTest
import Nimble
import OHHTTPStubs
import Quick
@testable import Statsig

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

final class PerformanceSpec: XCTestCase {

    override func setUpWithError() throws {
        let opts = StatsigOptions()
        opts.overrideURL = URL(string: "http://PerformanceSpec")

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

    override func tearDownWithError() throws {
        Statsig.client?.shutdown()
        Statsig.client = nil
    }

    func testCheckGatePerformance() throws {
        self.measure {
            for _ in 0...10 {
                let result = Statsig.checkGate("a_gate")
                expect(result).to(beTrue())
            }
        }
    }

    func testGetExperimentPerformance() throws {
        self.measure {
            for _ in 0...10 {
                let result = Statsig.getExperiment("a_config")
                expect(result.getValue(forKey: "a_bool", defaultValue: false)).to(beTrue())
            }
        }
    }

    func testGetLayerPerformance() throws {
        self.measure {
            for _ in 0...10 {
                let result = Statsig.getLayer("a_layer")
                expect(result.getValue(forKey: "a_bool", defaultValue: false)).to(beTrue())
            }
        }
    }

}

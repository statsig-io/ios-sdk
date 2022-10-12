import XCTest
@testable import Statsig

final class PerformanceTests: XCTestCase {
    var logs: [[String: Any]] = []
    var expectLogs: XCTestExpectation? = nil

    override func setUpWithError() throws {
        TestUtils.startWithResponseAndWait(self, [
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

        expectLogs = self.expectation(description: "Did Log")
        logs = []
        TestUtils.captureLogs(onLog: { [weak self] captured in
            if let events = captured["events"] as? [[String: Any]] {
                if self?.logs.count == 0 {
                    self?.expectLogs?.fulfill()
                }

                self?.logs = events
            }
        }, delay: 1)


        // Flush every call
        Statsig.client?.logger.flushBatchSize = 1
    }

    override func tearDownWithError() throws {
        Statsig.client?.shutdown()
        Statsig.client = nil
    }

    func testPerformanceOfOneGateCheck() throws {
        self.measure {
            _ = Statsig.checkGate("a_gate")
        }

        Statsig.shutdown()

        self.wait(for: [expectLogs!], timeout: 1)
        XCTAssertGreaterThan(self.logs.count, 0)
    }

    func testPerformanceOfManyGateChecks() throws {
        self.measure {
            for _ in 0...10000 {
                _ = Statsig.checkGate("a_gate")
            }
        }

        Statsig.shutdown()

        self.wait(for: [expectLogs!], timeout: 1)
        XCTAssertGreaterThan(self.logs.count, 0)
    }

    func testPerformanceOfOneDynamicConfigGet() throws {
        self.measure {
            _ = Statsig.getConfig("a_config")
        }

        Statsig.shutdown()

        self.wait(for: [expectLogs!], timeout: 1)
        XCTAssertGreaterThan(self.logs.count, 0)
    }

    func testPerformanceOfManyDynamicConfigGets() throws {
        self.measure {
            for _ in 0...10000 {
                _ = Statsig.getConfig("a_config")
            }
        }

        Statsig.shutdown()

        self.wait(for: [expectLogs!], timeout: 1)
        XCTAssertGreaterThan(self.logs.count, 0)
    }

    func testPerformanceOfOneExperimentGet() throws {
        self.measure {
            _ = Statsig.getExperiment("an_experiment")
        }

        Statsig.shutdown()

        self.wait(for: [expectLogs!], timeout: 1)
        XCTAssertGreaterThan(self.logs.count, 0)
    }

    func testPerformanceOfManyExperimentGets() throws {
        self.measure {
            for _ in 0...10000 {
                _ = Statsig.getExperiment("an_experiment")
            }
        }

        Statsig.shutdown()

        self.wait(for: [expectLogs!], timeout: 1)
        XCTAssertGreaterThan(self.logs.count, 0)
    }

    func testPerformanceOfOneLayerGet() throws {
        self.measure {
            let layer = Statsig.getLayer("a_layer")
            _ = layer.getValue(forKey: "a_bool", defaultValue: false)
        }

        Statsig.shutdown()

        self.wait(for: [expectLogs!], timeout: 1)
        XCTAssertGreaterThan(self.logs.count, 0)
    }

    func testPerformanceOfManyLayerGets() throws {
        self.measure {
            for _ in 0...10000 {
                let layer = Statsig.getLayer("a_layer")
                _ = layer.getValue(forKey: "a_bool", defaultValue: false)
            }
        }

        Statsig.shutdown()

        self.wait(for: [expectLogs!], timeout: 1)
        XCTAssertGreaterThan(self.logs.count, 0)
    }

}

import Nimble
import Quick
@testable import Statsig
import XCTest

class DynamicConfigSpec: QuickSpec {
    static let TestMixedConfig: [String: Any] =
        [
            "name": "config".sha256(),
            "rule_id": "default",
            "value":
                [
                    "str": "string",
                    "bool": true,
                    "double": 3.14,
                    "int": 3,
                    "strArray": ["1", "2"],
                    "mixedArray": [1, "2"],
                    "dict": ["key": "value"],
                    "mixedDict": ["keyStr": "string", "keyInt": 2, "keyArr": [1, 2], "keyDouble": 1.23, "keyDict": ["k": "v"]],
                ],
            "is_experiment_active": true,
            "is_user_in_experiment": true,
        ]
    override func spec() {
        describe("dummy config works as expected") {
            it("only returns the default values") {
                let dc = DynamicConfig(configName: "dummy")
                expect(dc.getValue(forKey: "str", defaultValue: "1")) == "1"
                expect(dc.getValue(forKey: "bool", defaultValue: true)) == true
                expect(dc.getValue(forKey: "double", defaultValue: 1.1)) == 1.1
                expect(dc.getValue(forKey: "int", defaultValue: 3)) == 3
                expect(dc.getValue(forKey: "strArray", defaultValue: ["1", "2"])) == ["1", "2"]
                expect(dc.getValue(forKey: "dict", defaultValue: ["key": "value"])) == ["key": "value"]
            }
        }

        describe("creating a dynamic config from dictionary") {
            let dc = DynamicConfig(
                configName: "testConfig",
                configObj: DynamicConfigSpec.TestMixedConfig)

            it("returns the correct value for key given the defaultValue with correct type") {
                expect(dc.getValue(forKey: "str", defaultValue: "1")) == "string"
                expect(dc.getValue(forKey: "bool", defaultValue: false)) == true
                expect(dc.getValue(forKey: "double", defaultValue: 1.0)) == 3.14
                expect(dc.getValue(forKey: "int", defaultValue: 1)) == 3
                expect(dc.getValue(forKey: "strArray", defaultValue: [])) == ["1", "2"]

                let mixedArray = dc.getValue(forKey: "mixedArray", defaultValue: [])
                expect(mixedArray.count) == 2
                expect(mixedArray[0] as? Int) == 1
                expect(mixedArray[1] as? String) == "2"

                let dict = dc.getValue(forKey: "dict", defaultValue: [String: String]())
                expect(dict.count) == 1
                expect(dict["key"]).to(equal("value"))

                let mixedDict = dc.getValue(forKey: "mixedDict", defaultValue: [:])
                expect(mixedDict.count) == 5
                expect(mixedDict["keyStr"] as? String) == "string"
                expect(mixedDict["keyInt"] as? Int) == 2
                expect(mixedDict["keyArr"] as? [Int]) == [1, 2]
                expect(mixedDict["keyDouble"] as? Double) == 1.23
                expect(mixedDict["keyDict"] as? [String: String]) == ["k": "v"]

                expect(dc.ruleID) == "default"
            }

            it("returns the default value for mismatched types") {
                expect(dc.getValue(forKey: "str", defaultValue: 1)) == 1
                expect(dc.getValue(forKey: "str", defaultValue: true)) == true

                expect(dc.getValue(forKey: "bool", defaultValue: "false")) == "false"
                expect(dc.getValue(forKey: "bool", defaultValue: 0)) == 0

                expect(dc.getValue(forKey: "double", defaultValue: 1)) == 1
                expect(dc.getValue(forKey: "double", defaultValue: "str")) == "str"

                expect(dc.getValue(forKey: "int", defaultValue: 1.0)) == 1.0
                expect(dc.getValue(forKey: "int", defaultValue: "1")) == "1"

                expect(dc.getValue(forKey: "strArray", defaultValue: [1, 2, 3])) == [1, 2, 3]

                expect(dc.getValue(forKey: "mixedArray", defaultValue: [1, 2, 3])) == [1, 2, 3]

                expect(dc.getValue(forKey: "dict", defaultValue: ["key": 3])) == ["key": 3]

                expect(dc.getValue(forKey: "mixedDict", defaultValue: ["key": "value"])) == ["key": "value"]
            }

            it("returns the default value for non-existent key") {
                expect(dc.getValue(forKey: "wrong_key", defaultValue: 1)) == 1
                expect(dc.getValue(forKey: "wrong_key", defaultValue: true)) == true
                expect(dc.getValue(forKey: "wrong_key", defaultValue: "false")) == "false"
                expect(dc.getValue(forKey: "wrong_key", defaultValue: 1.23)) == 1.23
                expect(dc.getValue(forKey: "wrong_key", defaultValue: [1, 2, 3])) == [1, 2, 3]
                expect(dc.getValue(forKey: "wrong_key", defaultValue: ["key": 3])) == ["key": 3]
                expect(dc.getValue(forKey: "wrong_key", defaultValue: ["key": "value"])) == ["key": "value"]
            }
        }
    }
}

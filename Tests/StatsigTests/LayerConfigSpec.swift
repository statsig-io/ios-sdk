import Foundation

import Nimble
import Quick
import OHHTTPStubs
#if !COCOAPODS
import OHHTTPStubsSwift
#endif
@testable import Statsig

fileprivate struct Data {
    static let GateKey = "gate"
    static let HashGateKey = GateKey.sha256()
    static let FeatureGates = [
        HashGateKey: ["value": true, "rule_id": "rule_id_2"]
    ]

    static let ConfigKey = "config"
    static let HashConfigKey = ConfigKey.sha256()

    static let AnotherConfigKey = "another_config"
    static let HashAnotherConfigKey = AnotherConfigKey.sha256()

    static let DeviceBasedConfigKey = "device_based_config"
    static let HashDeviceBasedConfigKey = DeviceBasedConfigKey.sha256()

    static let DynamicConfigs = [
        HashConfigKey: [
            "name": HashConfigKey,
            "rule_id": "default",
            "value": ["key": "value"],
            "is_user_in_experiment": true,
            "is_experiment_active": true,
        ],
        HashAnotherConfigKey: [
            "name": HashAnotherConfigKey,
            "rule_id": "default",
            "value": ["key": "another_value"],
            "is_user_in_experiment": true,
            "is_experiment_active": true,
        ],
        HashDeviceBasedConfigKey: [
            "name": HashDeviceBasedConfigKey,
            "rule_id": "default",
            "value": ["key": "device_based_value"],
            "is_user_in_experiment": true,
            "is_experiment_active": true,
            "is_device_based": true
        ],
    ]

    static let LayerConfigWithExperimentKey = "layer_with_exp"
    static let HashLayerConfigWithExperimentKey = LayerConfigWithExperimentKey.sha256()

    static let LayerConfigWithoutExperimentKey = "layer_without_exp"
    static let HashLayerConfigWithoutExperimentKey = LayerConfigWithoutExperimentKey.sha256()

    static let LayerConfigs: [String: Any] = [
        HashLayerConfigWithExperimentKey: [
            "name": HashLayerConfigWithExperimentKey,
            "rule_id": "default",
            "value": ["key": "value"],
            "is_user_in_experiment": true,
            "is_experiment_active": true,
            "allocated_experiment_name": HashConfigKey
        ],
        HashLayerConfigWithoutExperimentKey: [
            "name": HashLayerConfigWithExperimentKey,
            "rule_id": "default",
            "value": ["key": "another_value"],
            "is_user_in_experiment": true,
            "is_experiment_active": true,
        ]
    ]

    static let CacheValues: [String: Any] = [
        "dynamic_configs": DynamicConfigs,
        "feature_gates": FeatureGates,
        "layer_configs": LayerConfigs,
        "has_updates": true
    ]

    static let StickyValues = [
        HashConfigKey: [
            "rule_id": "sticky",
            "value": ["key": "value_sticky"],
        ],
    ]
}

class LayerConfigSpec: BaseSpec {

    override func spec() {
        super.spec()
        
        describe("using getLayerConfig") {
            let client = StatsigClient(sdkKey: "", user: nil, options: nil, completion: nil)
            var store: InternalStore!

            beforeEach {
                TestUtils.clearStorage()
                store = InternalStore(StatsigUser(userID: "dloomb"))

                let user = StatsigUser(userID: "dloomb")
                store.cache.saveValues(Data.CacheValues, user.getCacheKey(), user.getFullUserHash())
            }

            it("returns the experiment values") {
                let config = store.getLayer(client: client, forName: Data.LayerConfigWithExperimentKey, keepDeviceValue: false)
                expect(config.getValue(forKey: "key", defaultValue: "ERR")).to(equal("value"))

                let another = store.getLayer(client: client, forName: Data.LayerConfigWithoutExperimentKey, keepDeviceValue: false)
                expect(another.getValue(forKey: "key", defaultValue: "ERR")).to(equal("another_value"))
            }

            it("should return a sticky value") {
                var config = store.getLayer(client: client, forName: Data.LayerConfigWithExperimentKey, keepDeviceValue: true)
                expect(config.getValue(forKey: "key", defaultValue: "ERR")).to(equal("value"))

                var updatedValues: [String: Any] = Data.CacheValues
                updatedValues[jsonDict: "dynamic_configs"]?[jsonDict: Data.HashConfigKey]?["is_user_in_experiment"] = false

                let user = StatsigUser(userID: "dloomb")
                store = InternalStore(user) // reload the cache, and user is no longer in the experiment, but value should stick because experiment is active

                waitUntil { done in
                    store.saveValues(updatedValues, store.cache.userCacheKey, user.getFullUserHash()) {
                        done()
                    }
                }

                config = store.getLayer(client: client, forName: Data.LayerConfigWithExperimentKey, keepDeviceValue: true)
                expect(config.getValue(forKey: "key", defaultValue: "ERR")).to(equal("value"))

                updatedValues[jsonDict: "layer_configs"]?[jsonDict: Data.HashLayerConfigWithExperimentKey] = [
                    "name": Data.HashLayerConfigWithExperimentKey,
                    "rule_id": "default",
                    "value": ["key": "another_value"],
                    "is_user_in_experiment": true,
                    "is_experiment_active": true,
                    "allocated_experiment_name": "completely_different_exp"
                ]

                // reload the cache, and user is allocated to a different experiment,
                // but should still get same value because previous experiment is still active
                store = InternalStore(user)

                waitUntil { done in
                    store.saveValues(updatedValues, store.cache.userCacheKey, user.getFullUserHash()) {
                        done()
                    }
                }

                config = store.getLayer(client: client, forName: Data.LayerConfigWithExperimentKey, keepDeviceValue: true)
                expect(config.getValue(forKey: "key", defaultValue: "ERR")).to(equal("value"))

                updatedValues[jsonDict: "dynamic_configs"]?[jsonDict: Data.HashConfigKey]?["is_experiment_active"] = false
                // reload the cache, and previous experiment is no longer active, so should get new value
                store = InternalStore(StatsigUser(userID: "dloomb"))

                waitUntil { done in
                    store.saveValues(updatedValues, store.cache.userCacheKey, user.getFullUserHash()) {
                        done()
                    }
                }

                config = store.getLayer(client: client, forName: Data.LayerConfigWithExperimentKey, keepDeviceValue: true)
                expect(config.getValue(forKey: "key", defaultValue: "ERR")).to(equal("another_value"))
            }

            it("should wipe sticky value when keepDeviceValue is false") {
                var config = store.getLayer(client: client, forName: Data.LayerConfigWithExperimentKey, keepDeviceValue: true)
                expect(config.getValue(forKey: "key", defaultValue: "ERR")).to(equal("value"))

                var updatedValues: [String: Any] = Data.CacheValues
                updatedValues[jsonDict: "layer_configs"]?[jsonDict: Data.HashLayerConfigWithExperimentKey] = [
                    "name": Data.HashLayerConfigWithExperimentKey,
                    "rule_id": "default",
                    "value": ["key": "another_value"],
                    "is_user_in_experiment": true,
                    "is_experiment_active": true,
                    "allocated_experiment_name": Data.AnotherConfigKey
                ]

                let user = StatsigUser(userID: "dloomb")
                store = InternalStore(user)
                waitUntil { done in
                    store.saveValues(updatedValues, store.cache.userCacheKey, user.getFullUserHash()) {
                        done()
                    }
                }
                config = store.getLayer(client: client, forName: Data.LayerConfigWithExperimentKey, keepDeviceValue: false)
                expect(config.getValue(forKey: "key", defaultValue: "ERR")).to(equal("another_value"))
            }


            it("returns the default value for mismatched types") {
                let layer = Layer(client: client, name: "a_layer", value: [
                    "str": "string",
                    "bool": true,
                    "double": 3.14,
                    "int": 3,
                    "strArray": ["1", "2"],
                    "mixedArray": [1, "2"],
                    "dict": ["key": "value"],
                    "mixedDict": ["keyStr": "string", "keyInt": 2, "keyArr": [1, 2], "keyDouble": 1.23, "keyDict": ["k": "v"]],
                ], ruleID: "", evalDetails: EvaluationDetails(reason: .Cache))
                expect(layer.getValue(forKey: "str", defaultValue: 1)) == 1
                expect(layer.getValue(forKey: "str", defaultValue: true)) == true

                expect(layer.getValue(forKey: "bool", defaultValue: "false")) == "false"
                expect(layer.getValue(forKey: "bool", defaultValue: 0)) == 0

                expect(layer.getValue(forKey: "double", defaultValue: 1)) == 1
                expect(layer.getValue(forKey: "double", defaultValue: "str")) == "str"

                expect(layer.getValue(forKey: "int", defaultValue: 1.0)) == 1.0
                expect(layer.getValue(forKey: "int", defaultValue: "1")) == "1"

                expect(layer.getValue(forKey: "strArray", defaultValue: [1, 2, 3])) == [1, 2, 3]

                expect(layer.getValue(forKey: "mixedArray", defaultValue: [1, 2, 3])) == [1, 2, 3]

                expect(layer.getValue(forKey: "dict", defaultValue: ["key": 3])) == ["key": 3]

                expect(layer.getValue(forKey: "mixedDict", defaultValue: ["key": "value"])) == ["key": "value"]
            }

            it("returns the default value for non-existent key") {
                let layer = Layer(client: client, name: "a_layer", value: [:], ruleID: "", evalDetails: EvaluationDetails(reason: .Uninitialized))
                expect(layer.getValue(forKey: "wrong_key", defaultValue: 1)) == 1
                expect(layer.getValue(forKey: "wrong_key", defaultValue: true)) == true
                expect(layer.getValue(forKey: "wrong_key", defaultValue: "false")) == "false"
                expect(layer.getValue(forKey: "wrong_key", defaultValue: 1.23)) == 1.23
                expect(layer.getValue(forKey: "wrong_key", defaultValue: [1, 2, 3])) == [1, 2, 3]
                expect(layer.getValue(forKey: "wrong_key", defaultValue: ["key": 3])) == ["key": 3]
                expect(layer.getValue(forKey: "wrong_key", defaultValue: ["key": "value"])) == ["key": "value"]
            }
        }
    }
}

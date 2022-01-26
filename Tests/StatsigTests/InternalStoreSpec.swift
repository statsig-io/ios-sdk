import Nimble
import Quick
@testable import Statsig

class InternalStoreSpec: QuickSpec {
    override func spec() {
        describe("using internal store to save and retrieve values") {
            beforeEach {
                InternalStore.deleteAllLocalStorage()
            }

            it("is nil initially") {
                let store = InternalStore(userID: nil)
                expect(store.cache.count).to(equal(0))
            }

            it("sets value in UserDefaults correctly and persists between initialization") {
                let store = InternalStore(userID: nil)
                store.set(values: StatsigSpec.mockUserValues)

                let store2 = InternalStore(userID: nil)
                let cache = store2.cache
                expect(cache).toNot(beNil())
                expect((cache!["feature_gates"] as! [String: [String: Any]]).count).to(equal(2))
                expect((cache!["dynamic_configs"] as! [String: [String: Any]]).count).to(equal(1))

                let gate1 = store.checkGate(forName: "gate_name_1")
                expect(gate1?.value).to(beFalse())
                expect(gate1?.secondaryExposures[0]).to(equal(["gate": "employee", "gateValue": "true", "ruleID": "rule_id_employee"]))
                expect(store.checkGate(forName: "gate_name_2")?.value).to(beTrue())
                expect(store.getConfig(forName: "config")?.getValue(forKey: "str", defaultValue: "wrong")).to(equal("string"))

                InternalStore.deleteAllLocalStorage()
                expect(InternalStore(userID: nil).cache.count).to(equal(0))
            }

            it("sets sticky experiment values correctly") {
                let store = InternalStore(userID: nil)
                let configKey = "config"
                let hashConfigKey = configKey.sha256()

                let expKey = "exp"
                let hashedExpKey = expKey.sha256()

                let deviceExpKey = "device_exp"
                let hashedDeviceExpKey = deviceExpKey.sha256()

                let nonStickyExpKey = "exp_non_stick"
                let hashedNonStickyExpKey = nonStickyExpKey.sha256()

                var values: [String: [String: [String: Any]]] = [
                    "dynamic_configs": [
                        hashConfigKey: [
                            "rule_id": "default",
                            "value": ["key": "value"],
                        ],
                        hashedExpKey: [
                            "rule_id": "rule_id_1",
                            "value": ["label": "exp_v0"],
                            "is_device_based": false,
                            "is_user_in_experiment": true,
                            "is_experiment_active": true,
                        ],
                        hashedDeviceExpKey: [
                            "rule_id": "rule_id_1",
                            "value": ["label": "device_exp_v0"],
                            "is_device_based": true,
                            "is_user_in_experiment": true,
                            "is_experiment_active": true,
                        ],
                        hashedNonStickyExpKey: [
                            "rule_id": "rule_id_1",
                            "value": ["label": "non_stick_v0"],
                            "is_user_in_experiment": true,
                            "is_experiment_active": true,
                        ],
                    ],
                ]
                store.set(values: values)

                var exp = store.getExperiment(forName: expKey, keepDeviceValue: false)
                var deviceExp = store.getExperiment(forName: deviceExpKey, keepDeviceValue: false)
                var nonStickExp = store.getExperiment(forName: nonStickyExpKey, keepDeviceValue: false)
                expect(exp?.getValue(forKey: "label", defaultValue: "")).to(equal("exp_v0"))
                expect(deviceExp?.getValue(forKey: "label", defaultValue: "")).to(equal("device_exp_v0"))
                expect(nonStickExp?.getValue(forKey: "label", defaultValue: "")).to(equal("non_stick_v0"))

                // Change the values, now user should get updated values
                values["dynamic_configs"]![hashedExpKey]!["value"] = ["label": "exp_v1"]
                values["dynamic_configs"]![hashedDeviceExpKey]!["value"] = ["label": "device_exp_v1"]
                values["dynamic_configs"]![hashedNonStickyExpKey]!["value"] = ["label": "non_stick_v1"]
                store.set(values: values)

                exp = store.getExperiment(forName: expKey, keepDeviceValue: true)
                deviceExp = store.getExperiment(forName: deviceExpKey, keepDeviceValue: true)
                nonStickExp = store.getExperiment(forName: nonStickyExpKey, keepDeviceValue: false)
                expect(exp?.getValue(forKey: "label", defaultValue: "")).to(equal("exp_v1"))
                expect(deviceExp?.getValue(forKey: "label", defaultValue: "")).to(equal("device_exp_v1"))
                expect(nonStickExp?.getValue(forKey: "label", defaultValue: "")).to(equal("non_stick_v1"))

                // change the values again, but this time the value should be sticky from last time, except for the non sticky one
                values["dynamic_configs"]![hashedExpKey]!["value"] = ["label": "exp_v2"]
                values["dynamic_configs"]![hashedDeviceExpKey]!["value"] = ["label": "device_exp_v2"]
                values["dynamic_configs"]![hashedNonStickyExpKey]!["value"] = ["label": "non_stick_v2"]
                store.set(values: values)

                exp = store.getExperiment(forName: expKey, keepDeviceValue: true)
                deviceExp = store.getExperiment(forName: deviceExpKey, keepDeviceValue: true)
                nonStickExp = store.getExperiment(forName: nonStickyExpKey, keepDeviceValue: false)
                expect(exp?.getValue(forKey: "label", defaultValue: "")).to(equal("exp_v1"))
                expect(deviceExp?.getValue(forKey: "label", defaultValue: "")).to(equal("device_exp_v1"))
                expect(nonStickExp?.getValue(forKey: "label", defaultValue: "")).to(equal("non_stick_v2"))

                // Now we update the user to be no longer in the experiment, value should still be sticky
                values["dynamic_configs"]![hashedExpKey]!["value"] = ["label": "exp_v3"]
                values["dynamic_configs"]![hashedDeviceExpKey]!["value"] = ["label": "device_exp_v3"]
                values["dynamic_configs"]![hashedNonStickyExpKey]!["value"] = ["label": "non_stick_v3"]

                values["dynamic_configs"]![hashedExpKey]!["is_user_in_experiment"] = false
                values["dynamic_configs"]![hashedDeviceExpKey]!["is_user_in_experiment"] = false
                values["dynamic_configs"]![hashedNonStickyExpKey]!["is_user_in_experiment"] = false
                store.set(values: values)

                exp = store.getExperiment(forName: expKey, keepDeviceValue: true)
                deviceExp = store.getExperiment(forName: deviceExpKey, keepDeviceValue: true)
                nonStickExp = store.getExperiment(forName: nonStickyExpKey, keepDeviceValue: false)
                expect(exp?.getValue(forKey: "label", defaultValue: "")).to(equal("exp_v1"))
                expect(deviceExp?.getValue(forKey: "label", defaultValue: "")).to(equal("device_exp_v1"))
                expect(nonStickExp?.getValue(forKey: "label", defaultValue: "")).to(equal("non_stick_v3"))

                // Then we update the experiment to not be active, value should NOT be sticky
                values["dynamic_configs"]![hashedExpKey]!["value"] = ["label": "exp_v4"]
                values["dynamic_configs"]![hashedDeviceExpKey]!["value"] = ["label": "device_exp_v4"]
                values["dynamic_configs"]![hashedNonStickyExpKey]!["value"] = ["label": "non_stick_v4"]

                values["dynamic_configs"]![hashedExpKey]!["is_experiment_active"] = false
                values["dynamic_configs"]![hashedDeviceExpKey]!["is_experiment_active"] = false
                values["dynamic_configs"]![hashedNonStickyExpKey]!["is_experiment_active"] = false
                store.set(values: values)

                exp = store.getExperiment(forName: expKey, keepDeviceValue: true)
                deviceExp = store.getExperiment(forName: deviceExpKey, keepDeviceValue: true)
                nonStickExp = store.getExperiment(forName: nonStickyExpKey, keepDeviceValue: false)
                expect(exp?.getValue(forKey: "label", defaultValue: "")).to(equal("exp_v4"))
                expect(deviceExp?.getValue(forKey: "label", defaultValue: "")).to(equal("device_exp_v4"))
                expect(nonStickExp?.getValue(forKey: "label", defaultValue: "")).to(equal("non_stick_v4"))

                InternalStore.deleteAllLocalStorage()
            }

            it("it deletes user level sticky values but not device level sticky values when requested") {
                let store = InternalStore(userID: "jkw")
                let expKey = "exp"
                let hashedExpKey = expKey.sha256()

                let deviceExpKey = "device_exp"
                let hashedDeviceExpKey = deviceExpKey.sha256()

                var values: [String: [String: [String: Any]]] = [
                    "dynamic_configs": [
                        hashedExpKey: [
                            "rule_id": "rule_id_1",
                            "value": ["label": "exp_v0"],
                            "is_device_based": false,
                            "is_user_in_experiment": true,
                            "is_experiment_active": true,
                        ],
                        hashedDeviceExpKey: [
                            "rule_id": "rule_id_1",
                            "value": ["label": "device_exp_v0"],
                            "is_device_based": true,
                            "is_user_in_experiment": true,
                            "is_experiment_active": true,
                        ],
                    ],
                ]
                store.set(values: values)

                var exp = store.getExperiment(forName: expKey, keepDeviceValue: true)
                var deviceExp = store.getExperiment(forName: deviceExpKey, keepDeviceValue: true)
                expect(exp?.getValue(forKey: "label", defaultValue: "")).to(equal("exp_v0"))
                expect(deviceExp?.getValue(forKey: "label", defaultValue: "")).to(equal("device_exp_v0"))

                // Delete user sticky values (update user), change the latest values, now user should get updated values but device value stays the same
                store.loadAndResetStickyUserValuesIfNeeded(newUserID: "tore")
                values["dynamic_configs"]![hashedExpKey]!["value"] = ["label": "exp_v1"]
                values["dynamic_configs"]![hashedDeviceExpKey]!["value"] = ["label": "device_exp_v1"]
                store.set(values: values)

                exp = store.getExperiment(forName: expKey, keepDeviceValue: true)
                deviceExp = store.getExperiment(forName: deviceExpKey, keepDeviceValue: true)
                expect(exp?.getValue(forKey: "label", defaultValue: "")).to(equal("exp_v1"))
                expect(deviceExp?.getValue(forKey: "label", defaultValue: "")).to(equal("device_exp_v0"))

                // Try to get value with keepDeviceValue set to false. Should get updated values
                values["dynamic_configs"]![hashedExpKey]!["value"] = ["label": "exp_v2"]
                values["dynamic_configs"]![hashedDeviceExpKey]!["value"] = ["label": "device_exp_v2"]
                store.set(values: values)

                exp = store.getExperiment(forName: expKey, keepDeviceValue: false)
                deviceExp = store.getExperiment(forName: deviceExpKey, keepDeviceValue: false)
                expect(exp?.getValue(forKey: "label", defaultValue: "")).to(equal("exp_v2"))
                expect(deviceExp?.getValue(forKey: "label", defaultValue: "")).to(equal("device_exp_v2"))

                InternalStore.deleteAllLocalStorage()
            }

            it("changing userID in between sessions should invalidate sticky values") {
                var store = InternalStore(userID: "jkw")
                let expKey = "exp"
                let hashedExpKey = expKey.sha256()

                let deviceExpKey = "device_exp"
                let hashedDeviceExpKey = deviceExpKey.sha256()

                var values: [String: [String: [String: Any]]] = [
                    "dynamic_configs": [
                        hashedExpKey: [
                            "rule_id": "rule_id_1",
                            "value": ["label": "exp_v0"],
                            "is_device_based": false,
                            "is_user_in_experiment": true,
                            "is_experiment_active": true,
                        ],
                        hashedDeviceExpKey: [
                            "rule_id": "rule_id_1",
                            "value": ["label": "device_exp_v0"],
                            "is_device_based": true,
                            "is_user_in_experiment": true,
                            "is_experiment_active": true,
                        ],
                    ],
                ]
                store.set(values: values)

                var exp = store.getExperiment(forName: expKey, keepDeviceValue: true)
                var deviceExp = store.getExperiment(forName: deviceExpKey, keepDeviceValue: true)
                expect(exp?.getValue(forKey: "label", defaultValue: "")).to(equal("exp_v0"))
                expect(deviceExp?.getValue(forKey: "label", defaultValue: "")).to(equal("device_exp_v0"))

                // Re-initialize store with a different ID, change the latest values, now user should get updated values but device value stays the same
                store = InternalStore(userID: "tore")
                values["dynamic_configs"]![hashedExpKey]!["value"] = ["label": "exp_v1"]
                values["dynamic_configs"]![hashedDeviceExpKey]!["value"] = ["label": "device_exp_v1"]
                store.set(values: values)

                exp = store.getExperiment(forName: expKey, keepDeviceValue: true)
                deviceExp = store.getExperiment(forName: deviceExpKey, keepDeviceValue: true)
                expect(exp?.getValue(forKey: "label", defaultValue: "")).to(equal("exp_v1"))
                expect(deviceExp?.getValue(forKey: "label", defaultValue: "")).to(equal("device_exp_v0"))

                // Try to get value with keepDeviceValue set to false. Should get updated values
                values["dynamic_configs"]![hashedExpKey]!["value"] = ["label": "exp_v2"]
                values["dynamic_configs"]![hashedDeviceExpKey]!["value"] = ["label": "device_exp_v2"]
                store.set(values: values)

                exp = store.getExperiment(forName: expKey, keepDeviceValue: false)
                deviceExp = store.getExperiment(forName: deviceExpKey, keepDeviceValue: false)
                expect(exp?.getValue(forKey: "label", defaultValue: "")).to(equal("exp_v2"))
                expect(deviceExp?.getValue(forKey: "label", defaultValue: "")).to(equal("device_exp_v2"))

                InternalStore.deleteAllLocalStorage()
            }
        }
    }
}

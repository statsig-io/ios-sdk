import Quick
import Nimble
@testable import Statsig

class InternalStoreSpec: QuickSpec {
    override func spec() {
        describe("using internal store to save and retrieve values") {
            beforeEach {
                InternalStore.deleteLocalStorage()
            }

            it("is nil initially") {
                let store = InternalStore()
                expect(store.cache).to(beNil())
            }

            it("sets value in UserDefaults correctly and persists between initialization") {
                let store = InternalStore()
                store.set(values: UserValues(data: StatsigSpec.mockUserValues))

                let store2 = InternalStore()
                let cache = store2.cache!
                expect(cache).toNot(beNil())
                expect(cache.gates.count).to(equal(2))
                expect(cache.configs.count).to(equal(1))

                let gate1 = store.checkGate(gateName: "gate_name_1")
                expect(gate1?.value).to(beFalse())
                expect(gate1?.secondaryExposures[0]).to(equal(["gate": "employee", "gateValue": "true", "ruleID": "rule_id_employee"]))
                expect(store.checkGate(gateName: "gate_name_2")?.value).to(beTrue())
                expect(store.getConfig(configName: "config")?.getValue(forKey: "str", defaultValue: "wrong")).to(equal("string"))

                InternalStore.deleteLocalStorage()
                expect(InternalStore().cache).to(beNil())
            }
        }
    }
}

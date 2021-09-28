import Quick
import Nimble
@testable import Statsig

class InternalStoreSpec: QuickSpec {
    override func spec() {
        describe("using internal store to save and retrieve values") {
            beforeEach {
                InternalStore.deleteAllLocalStorage()
            }

            it("is nil initially") {
                let store = InternalStore()
                expect(store.cache.count).to(equal(0))
            }

            it("sets value in UserDefaults correctly and persists between initialization") {
                let store = InternalStore()
                store.set(values: StatsigSpec.mockUserValues)

                let store2 = InternalStore()
                let cache = store2.cache
                expect(cache).toNot(beNil())
                expect((cache["feature_gates"] as! [String: [String: Any]]).count).to(equal(2))
                expect((cache["dynamic_configs"] as! [String: [String: Any]]).count).to(equal(1))

                let gate1 = store.checkGate(forName: "gate_name_1")
                expect(gate1?.value).to(beFalse())
                expect(gate1?.secondaryExposures[0]).to(equal(["gate": "employee", "gateValue": "true", "ruleID": "rule_id_employee"]))
                expect(store.checkGate(forName: "gate_name_2")?.value).to(beTrue())
                expect(store.getConfig(forName: "config")?.getValue(forKey: "str", defaultValue: "wrong")).to(equal("string"))

                InternalStore.deleteAllLocalStorage()
                expect(InternalStore().cache.count).to(equal(0))
            }
        }
    }
}

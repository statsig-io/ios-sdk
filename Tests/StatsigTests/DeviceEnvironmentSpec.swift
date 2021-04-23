import Quick
import Nimble
@testable import Statsig

class DeviceEnvironmentSpec: QuickSpec {
    override func spec() {
        describe("getting the environment info about current device") {
            let env1 = DeviceEnvironment().get()
            let env2 = DeviceEnvironment().get()

            it("gets the same value across multiple times") {
                for (key, value) in env1 {
                    if key == "sessionID" {
                        expect(value) != env2[key]
                    } else {
                        expect(value) == env2[key]
                    }
                }
                expect(env1.count) == env2.count
            }

            it("has all the fields and non-nil values for required ones") {
                expect(env1.count) == 11
                expect(env1["sessionID"]).toNot(beNil())
                expect(env1["stableID"]).toNot(beNil())
                expect(env1["deviceOS"]).toNot(beNil())
                expect(env1["sdkVersion"]).toNot(beNil())
            }
        }
    }
}

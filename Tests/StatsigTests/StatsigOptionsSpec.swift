import Foundation

import Nimble
import Quick
import OHHTTPStubs
#if !COCOAPODS
import OHHTTPStubsSwift
#endif
@testable import Statsig

class StatsigOptionsSpec: BaseSpec {
    override func spec() {
        super.spec()

        describe("StatsigOptions") {
            it("can be constructed via the constructor") {
                let opts = StatsigOptions(
                    initTimeout: 1.23,
                    disableCurrentVCLogging:  true,
                    environment:  StatsigEnvironment(tier: "test"),
                    enableAutoValueUpdate:  true,
                    overrideStableID:  "an-override-id",
                    enableCacheByFile:  true,
                    initializeValues:  ["foo": 1],
                    disableDiagnostics:  true,
                    disableHashing:  true
                )


                expect(opts.initTimeout).to(equal(1.23))
                expect(opts.disableCurrentVCLogging).to(beTrue())
                expect(opts.environment).to(equal(["tier": "test"]))
                expect(opts.enableAutoValueUpdate).to(beTrue())
                expect(opts.overrideStableID).to(equal("an-override-id"))
                expect(opts.enableCacheByFile).to(beTrue())
                expect(opts.initializeValues as? [String: Int]).to(equal(["foo": 1]))
                expect(opts.disableDiagnostics).to(beTrue())
                expect(opts.disableHashing).to(beTrue())
            }

            it("can be constructed via assignment") {
                let opts = StatsigOptions()

                opts.initTimeout = 1.23
                opts.disableCurrentVCLogging = true
                opts.environment = ["tier": "test"]
                opts.enableAutoValueUpdate =  true
                opts.overrideStableID = "an-override-id"
                opts.enableCacheByFile =  true
                opts.initializeValues =  ["foo": 1]
                opts.disableDiagnostics =  true
                opts.disableHashing =  true


                expect(opts.initTimeout).to(equal(1.23))
                expect(opts.disableCurrentVCLogging).to(beTrue())
                expect(opts.environment).to(equal(["tier": "test"]))
                expect(opts.enableAutoValueUpdate).to(beTrue())
                expect(opts.overrideStableID).to(equal("an-override-id"))
                expect(opts.enableCacheByFile).to(beTrue())
                expect(opts.initializeValues as? [String: Int]).to(equal(["foo": 1]))
                expect(opts.disableDiagnostics).to(beTrue())
                expect(opts.disableHashing).to(beTrue())
            }
        }
    }
}

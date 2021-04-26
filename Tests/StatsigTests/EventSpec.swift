import Foundation

import Quick
import Nimble
@testable import Statsig

class EventSpec: QuickSpec {
    override func spec() {
        describe("creating custom events") {
            it("creates basic events as expected") {
                let event = Event(user: StatsigUser(), name: "purchase", disableCurrentVCLogging: false)
                expect(event.name) == "purchase"
                expect(event.user) == StatsigUser()
                expect(event.value).to(beNil())
                expect(event.metadata).to(beNil())
                expect(Int(event.time / 1000)) == Int(NSDate().timeIntervalSince1970)
            }

            it("creates events with value and metadata as expected") {
                let event = Event(user: StatsigUser(), name: "purchase", value:1.23,
                                  metadata: ["item_name": "no_ads"], disableCurrentVCLogging: false)
                expect(event.name) == "purchase"
                expect(event.user) == StatsigUser()
                expect(event.value as! Double).to(equal(1.23))
                expect(event.metadata) == ["item_name": "no_ads"]
                expect(Int(event.time / 1000)) == Int(NSDate().timeIntervalSince1970)
            }
            
            it("has helper functions that create gate exposure events correctly") {
                let gateExposure = Event.gateExposure(
                    user: StatsigUser(),
                    gateName: "show_coupon",
                    gateValue: true,
                    disableCurrentVCLogging: false)

                expect(gateExposure.name) == "statsig::gate_exposure"
                expect(gateExposure.user) == StatsigUser()
                expect(gateExposure.value).to(beNil())
                expect(gateExposure.metadata) == ["gate": "show_coupon", "gateValue": String(true)]
                expect(Int(gateExposure.time / 1000)) == Int(NSDate().timeIntervalSince1970)
            }

            it("has helper functions that create config exposure events correctly") {
                let configExposure = Event.configExposure(
                    user: StatsigUser(),
                    configName: "my_config",
                    configGroup: "default",
                    disableCurrentVCLogging: false)

                expect(configExposure.name) == "statsig::config_exposure"
                expect(configExposure.user) == StatsigUser()
                expect(configExposure.value).to(beNil())
                expect(configExposure.metadata) == ["config": "my_config", "configGroup": "default"]
                expect(Int(configExposure.time / 1000)) == Int(NSDate().timeIntervalSince1970)
            }

            it("has helper functions that create internal events correctly") {
                let internalEvent = Event.statsigInternalEvent(
                    user: StatsigUser(),
                    name: "network_failure",
                    value: 10,
                    metadata: nil,
                    disableCurrentVCLogging: false)

                expect(internalEvent.name) == "statsig::network_failure"
                expect(internalEvent.user) == StatsigUser()
                expect(internalEvent.value as! Int).to(equal(10))
                expect(internalEvent.metadata).to(beNil())
                expect(Int(internalEvent.time / 1000)) == Int(NSDate().timeIntervalSince1970)
            }
        }
    }
}

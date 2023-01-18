import Foundation

import Nimble
import Quick
import OHHTTPStubs
#if !COCOAPODS
import OHHTTPStubsSwift
#endif
@testable import Statsig


class BaseSpec: QuickSpec {
    override func spec() {
        beforeSuite {
            BaseSpec.resetUserDefaults()

            let stubs = HTTPStubs.allStubs()
            if !stubs.isEmpty {
                fatalError("Stubs not cleared")
            }

            if (StatsigClient.autoValueUpdateTime != 10.0) {
                fatalError("autoValueUpdate not reset")
            }
        }

        afterSuite {
            Statsig.client?.shutdown()
            Statsig.client = nil

            BaseSpec.resetUserDefaults()


        }
    }

    private static func resetUserDefaults() {
        let random = Int.random(in: 1..<100)
        let name = "Test User Defaults \(random)"
        let userDefaults = UserDefaults(suiteName: name)!
        userDefaults.removePersistentDomain(forName: name)
        StatsigUserDefaults.defaults = userDefaults

        BaseSpec.verifyStorage()
    }

    private static func verifyStorage() {
        let keys = StatsigUserDefaults.defaults.dictionaryRepresentation().keys
        for key in keys {
            if key.starts(with: "com.Statsig") {
                fatalError("User Defaults not cleared")
            }
        }
    }
    
}

import Foundation
import Nimble
import Statsig
import OHHTTPStubs

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

class TestUtils {
    static func startStatsigAndWait(key: String, _ user: StatsigUser? = nil) {
        waitUntil { done in
            Statsig.start(sdkKey: key, user: user) { _ in
                done()
            }
        }
    }

    static func startWithResponseAndWait(_ response: [String: Any], _ key: String = "client-api-key") {
        startWithResponseAndWait(response, key, nil)
    }

    static func startWithResponseAndWait(_ response: [String: Any], _ key: String = "client-api-key", _ user: StatsigUser? = nil) {
        stub(condition: isHost("api.statsig.com")) { _ in
            HTTPStubsResponse(jsonObject: response, statusCode: 200, headers: nil)
        }

        TestUtils.startStatsigAndWait(key: key, user)
    }
}

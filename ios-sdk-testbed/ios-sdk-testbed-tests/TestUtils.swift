import Foundation
import XCTest
import OHHTTPStubs

@testable import Statsig

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

class TestUtils {
    static func startStatsigAndWait(context: XCTestCase, key: String, _ user: StatsigUser? = nil) {
        let expect = context.expectation(description: "Initialized")
        Statsig.client = nil
        Statsig.start(sdkKey: key, user: user) { _ in
            expect.fulfill()
        }

        context.wait(for: [expect], timeout: 1)
    }

    static func startWithResponseAndWait(_ context: XCTestCase, _ response: [String: Any], _ key: String = "client-api-key") {
        startWithResponseAndWait(context, response, key, nil)
    }

    static func startWithResponseAndWait(_ context: XCTestCase, _ response: [String: Any], _ key: String = "client-api-key", _ user: StatsigUser? = nil) {
        stub(condition: isHost("api.statsig.com")) { _ in
            HTTPStubsResponse(jsonObject: response, statusCode: 200, headers: nil)
        }

        TestUtils.startStatsigAndWait(context: context, key: key, user)
    }

    static func captureLogs(onLog: @escaping ([String: Any]) -> Void, delay: TimeInterval? = nil) {
        stub(condition: isPath("/v1/rgstr")) { request in
            let data = try! JSONSerialization.jsonObject(with: request.ohhttpStubs_httpBody!, options: []) as! [String: Any]
            onLog(data)

            let response = HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
            if let delay = delay {
                return response.responseTime(delay)
            }

            return response
        }
    }
}

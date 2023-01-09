import Foundation
import Nimble
@testable import Statsig
import OHHTTPStubs

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

func skipFrame() {
    waitUntil { done in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            done()
        }
    }
}


class TestUtils {
    static func startStatsigAndWait(key: String, _ user: StatsigUser? = nil) {
        waitUntil { done in
            Statsig.client = nil
            Statsig.start(sdkKey: key, user: user) { _ in
                done()
            }
        }
    }

    static func startWithResponseAndWait(_ response: [String: Any], _ key: String = "client-api-key") -> URLRequest? {
        return startWithResponseAndWait(response, key, nil)
    }

    static func startWithResponseAndWait(_ response: [String: Any], _ key: String = "client-api-key", _ user: StatsigUser? = nil) -> URLRequest? {
        return startWithResponseAndWait(response, key, user, 200)
    }

    static func startWithResponseAndWait(_ response: [String: Any], _ key: String = "client-api-key", _ user: StatsigUser? = nil, _ statusCode: Int32 = 200) -> URLRequest? {
        var result: URLRequest? = nil
        stub(condition: isHost("api.statsig.com")) { req in
            result = req
            return HTTPStubsResponse(jsonObject: response, statusCode: statusCode, headers: nil)
        }

        TestUtils.startStatsigAndWait(key: key, user)

        return result
    }

    static func startWithStatusAndWait(_ statusCode: Int32 = 200, _ key: String = "client-api-key", _ user: StatsigUser? = nil) -> URLRequest? {
        var result: URLRequest? = nil
        stub(condition: isHost("api.statsig.com")) { req in
            result = req
            return HTTPStubsResponse(data: Data(), statusCode: statusCode, headers: nil)
        }

        TestUtils.startStatsigAndWait(key: key, user)

        return result
    }

    static func captureLogs(onLog: @escaping ([String: Any]) -> Void) {
        stub(condition: isPath("/v1/rgstr")) { request in
            let data = try! JSONSerialization.jsonObject(with: request.ohhttpStubs_httpBody!, options: []) as! [String: Any]
            onLog(data)
            return HTTPStubsResponse(jsonObject: StatsigSpec.mockUserValues, statusCode: 200, headers: nil)
        }
    }
}

extension URLRequest {
    public var statsig_body: [String: Any]? {
        guard let body = ohhttpStubs_httpBody else {
            return nil
        }

        return try? JSONSerialization.jsonObject(
            with: body,
            options: []) as? [String: Any]
    }
}

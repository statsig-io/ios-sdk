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
    static func clearStorage() {
        InternalStore.deleteAllLocalStorage()
    }

    static func startStatsigAndWait(key: String, _ user: StatsigUser? = nil, _ options: StatsigOptions? = nil) {
        var called = false
        waitUntil(timeout: .seconds(10)) { done in
            Statsig.client = nil
            Statsig.start(sdkKey: key, user: user, options: options) { _ in
                called = true
                done()
            }
        }

        if !called {
            let stubs = HTTPStubs.allStubs() as? [HTTPStubsDescriptor]
            fatalError("Failed to start Statsig. Stubs: \(String(describing: stubs))")
        }
    }

    static func startWithResponseAndWait(_ response: [String: Any], _ key: String = "client-api-key") -> URLRequest? {
        return startWithResponseAndWait(response, key, nil)
    }

    static func startWithResponseAndWait(_ response: [String: Any], _ key: String = "client-api-key", _ user: StatsigUser? = nil) -> URLRequest? {
        return startWithResponseAndWait(response, key, user, 200)
    }

    static func startWithResponseAndWait(_ response: [String: Any], _ key: String = "client-api-key", _ user: StatsigUser? = nil, _ statusCode: Int32 = 200) -> URLRequest? {
        return startWithResponseAndWait(response, key, user, 200, options: nil)
    }

    static func startWithResponseAndWait(_ response: [String: Any], _ key: String = "client-api-key", _ user: StatsigUser? = nil, _ statusCode: Int32 = 200, options: StatsigOptions? = nil) -> URLRequest? {
        var result: URLRequest? = nil
        let host = options?.overrideURL?.host ?? "api.statsig.com"
        let handle = stub(condition: isHost(host)) { req in
            result = req
            return HTTPStubsResponse(jsonObject: response, statusCode: statusCode, headers: nil)
        }

        let opts = options ?? StatsigOptions(disableDiagnostics: true)

        TestUtils.startStatsigAndWait(key: key, user, opts)

        HTTPStubs.removeStub(handle)

        return result
    }

    static func startWithStatusAndWait(_ statusCode: Int32 = 200, _ key: String = "client-api-key", _ user: StatsigUser? = nil, options: StatsigOptions? = nil) -> URLRequest? {
        var result: URLRequest? = nil
        stub(condition: isHost(options?.overrideURL?.host ?? "api.statsig.com")) { req in
            result = req
            return HTTPStubsResponse(data: Data(), statusCode: statusCode, headers: nil)
        }

        let opts = options ?? StatsigOptions(disableDiagnostics: true)
        TestUtils.startStatsigAndWait(key: key, user, opts)

        return result
    }

    static func captureLogs(host: String = "api.statsig.com", onLog: @escaping ([String: Any]) -> Void) {
        stub(condition: isHost(host) && isPath("/v1/rgstr")) { request in
            let data = try! JSONSerialization.jsonObject(with: request.ohhttpStubs_httpBody!, options: []) as! [String: Any]
            onLog(data)
            return HTTPStubsResponse(jsonObject: StatsigSpec.mockUserValues, statusCode: 200, headers: nil)
        }
    }

    static func getBody(fromRequest req: URLRequest) -> [String: Any] {
        return try! JSONSerialization.jsonObject(
            with: req.ohhttpStubs_httpBody!,
            options: []) as! [String: Any]
    }

    static func makeInitializeResponse(_ configValue: String) -> [String: Any] {
        return [
            "feature_gates": [:],
            "dynamic_configs": [
                "a_config".sha256(): [
                    "name": "a_config".sha256(),
                    "rule_id": "default",
                    "value": ["key": configValue],
                ]
            ],
            "layer_configs": [:],
            "time": 111,
            "has_updates": true
        ]
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


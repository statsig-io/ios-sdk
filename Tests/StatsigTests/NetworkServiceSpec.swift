import Foundation

import Nimble
import OHHTTPStubs
import Quick

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

@testable import Statsig

class NetworkServiceSpec: BaseSpec {
    override func spec() {
        super.spec()
        
        describe("using NetworkService to make network requests to Statsig API endpoints") {
            let sdkKey = "client-api-key"
            let opts = StatsigOptions()


            afterEach {
                HTTPStubs.removeAllStubs()
                TestUtils.clearStorage()
            }

            it("should send the correct request data when calling fetchInitialValues()") {
                var actualRequest: URLRequest?
                var actualRequestHttpBody: [String: Any]?
                stub(condition: isHost(ApiHost)) { request in
                    actualRequest = request
                    actualRequestHttpBody = try! JSONSerialization.jsonObject(
                        with: request.ohhttpStubs_httpBody!,
                        options: []) as! [String: Any]
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
                }

                let store = InternalStore(sdkKey, StatsigUser(userID: "jkw"), options: opts)
                let ns = NetworkService(sdkKey: sdkKey, options: opts, store: store)

                ns.fetchInitialValues(for:
                    StatsigUser(
                        userID: "jkw",
                        privateAttributes: ["email": "something@somethingelse.com"],
                        customIDs: ["randomID": "ABCDE"]), sinceTime: 0, previousDerivedFields: [:], fullChecksum: nil, completion: nil)
                let now = Date().timeIntervalSince1970

                expect(actualRequestHttpBody?.keys).toEventually(contain("user", "statsigMetadata"))
                // make sure when fetching values we still use private attributes
                expect((actualRequestHttpBody?["user"] as? [String: Any])!.keys).toEventually(contain("privateAttributes"))
                expect(NSDictionary(dictionary: (actualRequestHttpBody?["user"] as? [String: Any])!["customIDs"] as! [String: String])).toEventually(equal(NSDictionary(dictionary: ["randomID": "ABCDE"])))
                expect(actualRequest?.allHTTPHeaderFields!["STATSIG-API-KEY"]).toEventually(equal(sdkKey))
                expect(Double(actualRequest?.allHTTPHeaderFields?["STATSIG-CLIENT-TIME"] ?? "0")! / 1000)
                    .toEventually(beCloseTo(now, within: 1))
                expect(actualRequest?.httpMethod).toEventually(equal("POST"))
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://featureassets.org/v1/initialize"))
            }

            it("should send the correct request data when calling fetchUpdatedValues()") {
                var actualRequest: URLRequest?
                var actualRequestHttpBody: [String: Any]?
                stub(condition: isHost(ApiHost)) { request in
                    actualRequest = request
                    actualRequestHttpBody = try! JSONSerialization.jsonObject(
                        with: request.ohhttpStubs_httpBody!,
                        options: []) as! [String: Any]
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
                }


                let store = InternalStore(sdkKey, StatsigUser(userID: "jkw"), options: opts)
                let ns = NetworkService(sdkKey: sdkKey, options: opts, store: store)
                let now = Time.now()
                waitUntil { done in
                    ns.fetchUpdatedValues(
                        for: StatsigUser(userID: "jkw"),
                        lastSyncTimeForUser: now,
                        previousDerivedFields: [:],
                        fullChecksum: nil
                    ) { _ in
                        done()
                    }
                }

                expect(actualRequestHttpBody?.keys).to(contain("user", "statsigMetadata", "lastSyncTimeForUser"))
                expect(actualRequest?.allHTTPHeaderFields!["STATSIG-API-KEY"]).to(equal(sdkKey))
                expect(actualRequest?.httpMethod).to(equal("POST"))
                expect(actualRequest?.url?.absoluteString).to(equal("https://featureassets.org/v1/initialize"))
            }

            it("should send the correct request data when calling sendEvents(), and returns the request data back if request fails") {
                var actualRequest: URLRequest?
                var actualRequestHttpBody: [String: Any]?

                var actualRequestData: Data?
                var returnedRequestData: Data?

                stub(condition: isHost(LogEventHost)) { request in
                    actualRequest = request
                    actualRequestHttpBody = try! JSONSerialization.jsonObject(
                        with: request.ohhttpStubs_httpBody!,
                        options: []) as! [String: Any]
                    actualRequestData = request.ohhttpStubs_httpBody
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 403, headers: nil)
                }

                let store = InternalStore(sdkKey, StatsigUser(userID: "jkw"), options: opts)
                let ns = NetworkService(sdkKey: sdkKey, options: opts, store: store)
                let user = StatsigUser(userID: "jkw", privateAttributes: ["email": "something@somethingelse.com"])
                waitUntil { done in
                    ns.sendEvents(forUser: user, events: [Event(user: user, name: "test_event", value: 9.99, disableCurrentVCLogging: false)])
                        { _, jsonData in
                            returnedRequestData = jsonData
                            done()
                        }
                }

                expect(actualRequestHttpBody?.keys).toEventually(contain("user", "statsigMetadata", "events"))
                expect(actualRequest?.allHTTPHeaderFields!["STATSIG-API-KEY"]).toEventually(equal(sdkKey))
                expect(actualRequest?.httpMethod).toEventually(equal("POST"))
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://prodregistryv2.org/v1/rgstr"))
                expect(actualRequestData).toEventually(equal(returnedRequestData))

                // make sure when logging we drop private attributes
                expect((actualRequestHttpBody?["user"] as? [String: Any])!.keys).toEventuallyNot(contain("privateAttributes"))
                expect(((actualRequestHttpBody?["events"] as? [[String: Any]])![0]["user"] as? [String: Any])!.keys).toEventuallyNot(contain("privateAttributes"))
            }

            it("should send the correct request data when calling sendRequestsWithData(), and returns the request data back if request fails") {
                var actualRequest: URLRequest?
                var actualRequestHttpBody: [String: Any]?

                var actualRequestData: [Data] = []
                var returnedRequestData: [Data] = []

                stub(condition: isHost(LogEventHost)) { request in
                    actualRequest = request
                    actualRequestHttpBody = try! JSONSerialization.jsonObject(
                        with: request.ohhttpStubs_httpBody!,
                        options: []) as! [String: Any]
                    actualRequestData.append(request.ohhttpStubs_httpBody!)
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 403, headers: nil)
                }

                let user = StatsigUser(userID: "jkw")
                let store = InternalStore(sdkKey, user, options: opts)
                let ns = NetworkService(sdkKey: sdkKey, options: opts, store: store)

                var data = [Data]()
                for index in 1...10 {
                    let params: [String: Any] = [
                        "user": StatsigUser(userID: String(index)).toDictionary(forLogging: true),
                        "events": [Event(user: user, name: "test_event_\(index)", value: index, disableCurrentVCLogging: false).toDictionary()]
                    ]
                    let d = try! JSONSerialization.data(withJSONObject: params)
                    data.append(d)
                }

                waitUntil { done in
                    ns.sendRequestsWithData(data) { failedData in
                        returnedRequestData = failedData!
                        done()
                    }
                }

                expect(actualRequestHttpBody?.keys).toEventually(contain("user", "events"))
                expect(actualRequest?.allHTTPHeaderFields!["STATSIG-API-KEY"]).toEventually(equal(sdkKey))
                expect(actualRequest?.httpMethod).toEventually(equal("POST"))
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://prodregistryv2.org/v1/rgstr"))
                expect(actualRequestData.count).toEventually(equal(returnedRequestData.count))
            }


            it ("does not retry requests after timeout") {
                var calls = 0
                var timedout = false
                stub(condition: isHost(ApiHost)) { request in
                    calls += 1

                    while (timedout == false) {} // block until timeout

                    // 500 so retry logic would try again
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 500, headers: nil)
                }

                let user = StatsigUser()
                let opts = StatsigOptions(initTimeout: 0.01)
                let store = InternalStore("client-key", user, options: opts)
                let ns = NetworkService(sdkKey: "client-key", options: opts, store: store)

                var expected = -1
                waitUntil { done in
                    ns.fetchInitialValues(for: user, sinceTime: 0, previousDerivedFields: [:], fullChecksum: nil) { err in
                        expected = calls
                        expect(err?.code).to(equal(StatsigClientErrorCode.initTimeoutExpired))
                        timedout = true;
                        done()
                    }
                }


                waitUntil { done in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        expect(expected).notTo(equal(-1))
                        expect(calls).to(equal(expected))
                        done()
                    }
                }
            }
        }
    }
}

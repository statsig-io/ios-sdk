import Foundation

import Nimble
import OHHTTPStubs
import OHHTTPStubsSwift
import Quick

@testable import Statsig

class NetworkServiceSpec: QuickSpec {
    override func spec() {
        describe("using NetworkService to make network requests to Statsig API endpoints") {
            let sdkKey = "client-api-key"
            afterEach {
                HTTPStubs.removeAllStubs()
                InternalStore.deleteAllLocalStorage()
            }

            it("should send the correct request data when calling fetchInitialValues()") {
                var actualRequest: URLRequest?
                var actualRequestHttpBody: [String: Any]?
                stub(condition: isHost("api.statsig.com")) { request in
                    actualRequest = request
                    actualRequestHttpBody = try! JSONSerialization.jsonObject(
                        with: request.ohhttpStubs_httpBody!,
                        options: []) as! [String: Any]
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
                }

                let ns = NetworkService(sdkKey: "client-api-key", options: StatsigOptions(), store: InternalStore(userID: "jkw"))
                ns.fetchInitialValues(for:
                    StatsigUser(
                        userID: "jkw",
                        privateAttributes: ["email": "something@somethingelse.com"],
                        customIDs: ["randomID": "ABCDE"]), completion: nil)
                let now = NSDate().timeIntervalSince1970

                expect(actualRequestHttpBody?.keys).toEventually(contain("user", "statsigMetadata"))
                // make sure when fetching values we still use private attributes
                expect((actualRequestHttpBody?["user"] as? [String: Any])!.keys).toEventually(contain("privateAttributes"))
                expect(NSDictionary(dictionary: (actualRequestHttpBody?["user"] as? [String: Any])!["customIDs"] as! [String: String])).toEventually(equal(NSDictionary(dictionary: ["randomID": "ABCDE"])))
                expect(actualRequest?.allHTTPHeaderFields!["STATSIG-API-KEY"]).toEventually(equal(sdkKey))
                expect(Double(actualRequest?.allHTTPHeaderFields?["STATSIG-CLIENT-TIME"] ?? "0")! / 1000)
                    .toEventually(beCloseTo(now, within: 1))
                expect(actualRequest?.httpMethod).toEventually(equal("POST"))
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://api.statsig.com/v1/initialize"))
            }

            it("should send the correct request data when calling fetchUpdatedValues()") {
                var actualRequest: URLRequest?
                var actualRequestHttpBody: [String: Any]?
                stub(condition: isHost("api.statsig.com")) { request in
                    actualRequest = request
                    actualRequestHttpBody = try! JSONSerialization.jsonObject(
                        with: request.ohhttpStubs_httpBody!,
                        options: []) as! [String: Any]
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
                }

                let ns = NetworkService(sdkKey: "client-api-key", options: StatsigOptions(), store: InternalStore(userID: "jkw"))
                let now = NSDate().timeIntervalSince1970 * 1000
                waitUntil { done in
                    ns.fetchUpdatedValues(for: StatsigUser(userID: "jkw"), since: now) {
                        done()
                    }
                }

                expect(actualRequestHttpBody?.keys).to(contain("user", "statsigMetadata", "lastSyncTimeForUser"))
                expect(actualRequest?.allHTTPHeaderFields!["STATSIG-API-KEY"]).to(equal(sdkKey))
                expect(actualRequest?.httpMethod).to(equal("POST"))
                expect(actualRequest?.url?.absoluteString).to(equal("https://api.statsig.com/v1/initialize"))
            }

            it("should send the correct request data when calling sendEvents(), and returns the request data back if request fails") {
                var actualRequest: URLRequest?
                var actualRequestHttpBody: [String: Any]?

                var actualRequestData: Data?
                var returnedRequestData: Data?

                stub(condition: isHost("api.statsig.com")) { request in
                    actualRequest = request
                    actualRequestHttpBody = try! JSONSerialization.jsonObject(
                        with: request.ohhttpStubs_httpBody!,
                        options: []) as! [String: Any]
                    actualRequestData = request.ohhttpStubs_httpBody
                    return HTTPStubsResponse(error: NSError(domain: NSURLErrorDomain, code: 403))
                }

                let ns = NetworkService(sdkKey: "client-api-key", options: StatsigOptions(), store: InternalStore(userID: "jkw"))
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
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://api.statsig.com/v1/rgstr"))
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

                stub(condition: isHost("api.statsig.com")) { request in
                    actualRequest = request
                    actualRequestHttpBody = try! JSONSerialization.jsonObject(
                        with: request.ohhttpStubs_httpBody!,
                        options: []) as! [String: Any]
                    actualRequestData.append(request.ohhttpStubs_httpBody!)
                    return HTTPStubsResponse(error: NSError(domain: NSURLErrorDomain, code: 403))
                }

                let ns = NetworkService(sdkKey: "client-api-key", options: StatsigOptions(), store: InternalStore(userID: "jkw"))
                let user = StatsigUser(userID: "jkw")
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
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://api.statsig.com/v1/rgstr"))
                expect(actualRequestData).toEventually(equal(returnedRequestData))
            }
        }
    }
}

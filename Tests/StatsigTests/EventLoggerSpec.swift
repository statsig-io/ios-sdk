import Foundation

import Nimble
import OHHTTPStubs
import OHHTTPStubsSwift
import Quick

@testable import Statsig

class EventLoggerSpec: QuickSpec {
    override func spec() {
        describe("using EventLogger") {
            let sdkKey = "client-api-key"
            let ns = NetworkService(sdkKey: sdkKey, options: StatsigOptions(), store: InternalStore(userID: "jkw"))
            let user = StatsigUser(userID: "jkw")
            let event1 = Event(user: user, name: "test_event1", value: 1, disableCurrentVCLogging: false)
            let event2 = Event(user: user, name: "test_event2", value: 2, disableCurrentVCLogging: false)
            let event3 = Event(user: user, name: "test_event3", value: "3", disableCurrentVCLogging: false)

            afterEach {
                HTTPStubs.removeAllStubs()
                EventLogger.deleteLocalStorage()
            }

            it("should add events to internal queue and send once flush timer hits") {
                let logger = EventLogger(user: user, networkService: ns)
                logger.flushInterval = 1
                logger.log(event1)
                logger.log(event2)
                logger.log(event3)

                var actualRequest: URLRequest?
                var actualRequestHttpBody: [String: Any]?

                stub(condition: isHost("api.statsig.com")) { request in
                    actualRequest = request
                    actualRequestHttpBody = try! JSONSerialization.jsonObject(
                        with: request.ohhttpStubs_httpBody!,
                        options: []) as! [String: Any]
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
                }

                waitUntil(timeout: .seconds(2)) { done in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        done()
                    }
                }

                expect(actualRequestHttpBody?.keys).toEventually(contain("user", "events", "statsigMetadata"))
                expect((actualRequestHttpBody?["events"] as? [Any])?.count).toEventually(equal(3))
                expect(actualRequest?.allHTTPHeaderFields!["STATSIG-API-KEY"]).toEventually(equal(sdkKey))
                expect(actualRequest?.httpMethod).toEventually(equal("POST"))
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://api.statsig.com/v1/log_event"))
            }

            it("should add events to internal queue and send once it passes max batch size") {
                let logger = EventLogger(user: user, networkService: ns)
                logger.flushBatchSize = 3
                logger.log(event1)
                logger.log(event2)
                logger.log(event3)

                var actualRequest: URLRequest?
                var actualRequestHttpBody: [String: Any]?

                stub(condition: isHost("api.statsig.com")) { request in
                    actualRequest = request
                    actualRequestHttpBody = try! JSONSerialization.jsonObject(
                        with: request.ohhttpStubs_httpBody!,
                        options: []) as! [String: Any]
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
                }

                expect(actualRequestHttpBody?.keys).toEventually(contain("user", "events", "statsigMetadata"))
                expect((actualRequestHttpBody?["events"] as? [Any])?.count).toEventually(equal(3))
                expect(actualRequest?.allHTTPHeaderFields!["STATSIG-API-KEY"]).toEventually(equal(sdkKey))
                expect(actualRequest?.httpMethod).toEventually(equal("POST"))
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://api.statsig.com/v1/log_event"))
            }

            it("should send events with flush()") {
                let logger = EventLogger(user: user, networkService: ns)
                logger.log(event1)
                logger.log(event2)
                logger.log(event3)
                logger.flushInterval = 10
                logger.flushBatchSize = 10
                logger.flush()

                var actualRequest: URLRequest?
                var actualRequestHttpBody: [String: Any]?

                stub(condition: isHost("api.statsig.com")) { request in
                    actualRequest = request
                    actualRequestHttpBody = try! JSONSerialization.jsonObject(
                        with: request.ohhttpStubs_httpBody!,
                        options: []) as! [String: Any]
                    return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
                }

                expect(actualRequestHttpBody?.keys).toEventually(contain("user", "events", "statsigMetadata"))
                expect((actualRequestHttpBody?["events"] as? [Any])?.count).toEventually(equal(3))
                expect(actualRequest?.allHTTPHeaderFields!["STATSIG-API-KEY"]).toEventually(equal(sdkKey))
                expect(actualRequest?.httpMethod).toEventually(equal("POST"))
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://api.statsig.com/v1/log_event"))
            }

            it("should save failed to send requests locally during shutdown, and load and resend local requests during startup") {
                let logger = EventLogger(user: user, networkService: ns)
                logger.log(event1)
                logger.log(event2)
                logger.log(event3)
                logger.flushInterval = 10
                logger.flushBatchSize = 10
                logger.flush(shutdown: true)

                let savedData: [Data]?
                var resendData: [Data] = []

                waitUntil { done in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        done()
                    }
                }

                savedData = UserDefaults.standard.array(forKey: "com.Statsig.EventLogger.loggingRequestUserDefaultsKey") as? [Data]

                stub(condition: isHost("api.statsig.com")) { request in
                    resendData.append(request.ohhttpStubs_httpBody!)
                    return HTTPStubsResponse(error: NSError(domain: NSURLErrorDomain, code: 403))
                }

                EventLogger(user: user, networkService: ns)

                waitUntil { done in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        done()
                    }
                }

                expect(savedData).toEventuallyNot(beNil())
                expect(savedData).toEventually(equal(resendData))
            }
        }
    }
}

import Foundation

import Nimble
import OHHTTPStubs
import Quick

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

@testable import Statsig

class EventLoggerSpec: QuickSpec {
    class MockDefaults: UserDefaults {
        var data: [String: Any?] = [:]

        init() {
            super.init(suiteName: nil)!
        }

        override func setValue(_ value: Any?, forKey key: String) {
            data[key] = value
        }

        override func array(forKey defaultName: String) -> [Any]? {
            return data[defaultName] as? [Any]
        }

        func reset() {
            data = [:]
        }
    }

    override func spec() {
        describe("using EventLogger") {
            let sdkKey = "client-api-key"
            let ns = NetworkService(sdkKey: sdkKey, options: StatsigOptions(), store: InternalStore(StatsigUser(userID: "jkw")))
            let user = StatsigUser(userID: "jkw")
            let event1 = Event(user: user, name: "test_event1", value: 1, disableCurrentVCLogging: false)
            let event2 = Event(user: user, name: "test_event2", value: 2, disableCurrentVCLogging: false)
            let event3 = Event(user: user, name: "test_event3", value: "3", disableCurrentVCLogging: false)

            afterEach {
                HTTPStubs.removeAllStubs()
                EventLogger.deleteLocalStorage()
            }

            it("should add events to internal queue and send once flush timer hits") {
                let logger = EventLogger(user: user, networkService: ns, userDefaults: MockDefaults())
                logger.start(flushInterval: 1)
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
                    logger.logQueue.asyncAfter(deadline: .now() + 1) {
                        done()
                    }
                }

                expect(actualRequestHttpBody?.keys).toEventually(contain("user", "events", "statsigMetadata"))
                expect((actualRequestHttpBody?["events"] as? [Any])?.count).toEventually(equal(3))
                expect(actualRequest?.allHTTPHeaderFields!["STATSIG-API-KEY"]).toEventually(equal(sdkKey))
                expect(actualRequest?.httpMethod).toEventually(equal("POST"))
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://api.statsig.com/v1/rgstr"))
            }

            it("should add events to internal queue and send once it passes max batch size") {
                let logger = EventLogger(user: user, networkService: ns, userDefaults: MockDefaults())
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
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://api.statsig.com/v1/rgstr"))
            }

            it("should send events with flush()") {
                let logger = EventLogger(user: user, networkService: ns, userDefaults: MockDefaults())
                logger.start(flushInterval: 10)
                logger.log(event1)
                logger.log(event2)
                logger.log(event3)
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
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://api.statsig.com/v1/rgstr"))
            }

            it("should save failed to send requests locally during shutdown, and load and resend local requests during startup") {
                var isPendingRequest = true
                stub(condition: isHost("api.statsig.com")) { request in
                    isPendingRequest = false
                    return HTTPStubsResponse(error: NSError(domain: NSURLErrorDomain, code: 403))
                }

                let userDefaults = MockDefaults()
                let logger = EventLogger(user: user, networkService: ns, userDefaults: userDefaults)
                logger.start(flushInterval: 10)
                logger.log(event1)
                logger.log(event2)
                logger.log(event3)
                logger.flushBatchSize = 10
                logger.stop()

                expect(isPendingRequest).toEventually(beFalse())
                isPendingRequest = true

                let savedData = userDefaults.data[EventLogger.loggingRequestUserDefaultsKey] as? [Data]
                var resendData: [Data] = []

                stub(condition: isHost("api.statsig.com")) { request in
                    resendData.append(request.ohhttpStubs_httpBody!)
                    return HTTPStubsResponse(error: NSError(domain: NSURLErrorDomain, code: 403))
                }

                _ = EventLogger(user: user, networkService: ns, userDefaults: userDefaults)

                expect(resendData.isEmpty).toEventually(beFalse())
                expect(savedData).toEventuallyNot(beNil())
                expect(savedData).toEventually(equal(resendData))
            }

            it("should limit file size save to user defaults") {
                stub(condition: isHost("api.statsig.com")) { req in
                    return HTTPStubsResponse(error: NSError(domain: NSURLErrorDomain, code: 500))
                }

                let userDefaults = MockDefaults()

                var text = ""
                for _ in 0...100000 {
                    text += "test1234567"
                }

                var logger = EventLogger(user: user, networkService: ns, userDefaults: userDefaults)
                logger.start(flushInterval: 10)
                logger.log(Event(user: user, name: "a", value: 1, metadata: ["text": text], disableCurrentVCLogging: false))
                logger.stop()

                // Fail to save because event is too big
                expect(userDefaults.data[EventLogger.loggingRequestUserDefaultsKey] as? [Data]).toEventuallyNot(beNil())
                expect((userDefaults.data[EventLogger.loggingRequestUserDefaultsKey] as! [Data]).count).to(equal(0))

                userDefaults.reset()

                logger = EventLogger(user: user, networkService: ns, userDefaults: userDefaults)
                logger.start(flushInterval: 2)
                logger.log(Event(user: user, name: "b", value: 1, metadata: ["text": "small"], disableCurrentVCLogging: false))
                logger.stop()

                // Successfully save event
                expect(userDefaults.data[EventLogger.loggingRequestUserDefaultsKey] as? [Data]).toEventuallyNot(beNil())
                expect((userDefaults.data[EventLogger.loggingRequestUserDefaultsKey] as! [Data]).count).to(equal(1))
            }
        }
    }
}

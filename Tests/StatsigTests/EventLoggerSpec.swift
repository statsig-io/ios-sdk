import Foundation

import Nimble
import OHHTTPStubs
import Quick

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

@testable import Statsig

class EventLoggerSpec: BaseSpec {

    override func spec() {
        super.spec()
        
        describe("using EventLogger") {
            let sdkKey = "client-api-key"
            let opts = StatsigOptions()
            
            let store = InternalStore(sdkKey, StatsigUser(userID: "jkw"), options: opts)
            
            let ns = NetworkService(sdkKey: sdkKey, options: opts, store: store)
            let user = StatsigUser(userID: "jkw")
            let event1 = Event(user: user, name: "test_event1", value: 1, disableCurrentVCLogging: false)
            let event2 = Event(user: user, name: "test_event2", value: 2, disableCurrentVCLogging: false)
            let event3 = Event(user: user, name: "test_event3", value: "3", disableCurrentVCLogging: false)
            afterEach {
                HTTPStubs.removeAllStubs()
                EventLogger.deleteLocalStorage(sdkKey: "client-key")
            }

            it("should add events to internal queue and send once flush timer hits") {
                let logger = EventLogger(sdkKey: "client-key", user: user, networkService: ns, userDefaults: MockDefaults())
                logger.start(flushInterval: 1)
                logger.log(event1)
                logger.log(event2)
                logger.log(event3)

                var actualRequest: URLRequest?
                var actualRequestHttpBody: [String: Any]?
                stub(condition: isHost(LogEventHost)) { request in
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
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://prodregistryv2.org/v1/rgstr"))
            }

            it("should add events to internal queue and send once it passes max batch size") {
                let logger = EventLogger(sdkKey: "client-key", user: user, networkService: ns, userDefaults: MockDefaults())
                logger.maxEventQueueSize = 3
                logger.log(event1)
                logger.log(event2)
                logger.log(event3)

                var actualRequest: URLRequest?
                var actualRequestHttpBody: [String: Any]?

                stub(condition: isHost(LogEventHost)) { request in
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
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://prodregistryv2.org/v1/rgstr"))
            }

            it("should send events with flush()") {
                let logger = EventLogger(sdkKey: "client-key", user: user, networkService: ns, userDefaults: MockDefaults())
                logger.start(flushInterval: 10)
                logger.log(event1)
                logger.log(event2)
                logger.log(event3)
                logger.maxEventQueueSize = 10
                logger.flush()

                var actualRequest: URLRequest?
                var actualRequestHttpBody: [String: Any]?

                stub(condition: isHost(LogEventHost)) { request in
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
                expect(actualRequest?.url?.absoluteString).toEventually(equal("https://prodregistryv2.org/v1/rgstr"))
            }

            it("should save failed to send requests locally during shutdown, and load and resend local requests during startup") {
                var isPendingRequest = true
                stub(condition: isHost(LogEventHost)) { request in
                    isPendingRequest = false
                    return HTTPStubsResponse(error: NSError(domain: NSURLErrorDomain, code: 403))
                }

                let userDefaults = MockDefaults()
                let logger = EventLogger(sdkKey: "client-key", user: user, networkService: ns, userDefaults: userDefaults)
                logger.start(flushInterval: 10)
                logger.log(event1)
                logger.log(event2)
                logger.log(event3)
                logger.maxEventQueueSize = 10
                logger.stop()

                expect(isPendingRequest).toEventually(beFalse())
                isPendingRequest = true

                let savedData = userDefaults.data[getFailedEventStorageKey("client-key")] as? [Data]
                var resendData: [Data] = []

                stub(condition: isHost(LogEventHost)) { request in
                    resendData.append(request.ohhttpStubs_httpBody!)
                    return HTTPStubsResponse(error: NSError(domain: NSURLErrorDomain, code: 403))
                }

                _ = EventLogger(sdkKey: "client-key", user: user, networkService: ns, userDefaults: userDefaults)

                expect(resendData.isEmpty).toEventually(beFalse())
                expect(savedData).toEventuallyNot(beNil())
                expect(savedData).toEventually(equal(resendData))
            }

            it("should limit file size save to user defaults") {
                stub(condition: isHost(LogEventHost)) { req in
                    return HTTPStubsResponse(error: NSError(domain: NSURLErrorDomain, code: 500))
                }

                let userDefaults = MockDefaults()

                var text = ""
                for _ in 0...100000 {
                    text += "test1234567"
                }

                var logger = EventLogger(sdkKey: "client-key", user: user, networkService: ns, userDefaults: userDefaults)
                logger.start(flushInterval: 10)
                logger.log(Event(user: user, name: "a", value: 1, metadata: ["text": text], disableCurrentVCLogging: false))
                logger.stop()

                // Fail to save because event is too big
                expect(userDefaults.data[getFailedEventStorageKey("client-key")] as? [Data]).toEventuallyNot(beNil())
                expect((userDefaults.data[getFailedEventStorageKey("client-key")] as! [Data]).count).to(equal(0))

                userDefaults.reset()

                logger = EventLogger(sdkKey: "client-key", user: user, networkService: ns, userDefaults: userDefaults)
                logger.start(flushInterval: 2)
                logger.log(Event(user: user, name: "b", value: 1, metadata: ["text": "small"], disableCurrentVCLogging: false))
                logger.stop()

                // Successfully save event
                expect(userDefaults.data[getFailedEventStorageKey("client-key")] as? [Data]).toEventuallyNot(beNil())
                expect((userDefaults.data[getFailedEventStorageKey("client-key")] as! [Data]).count).to(equal(1))
            }
        }
    }
}

import Foundation

import Nimble
import Quick
import OHHTTPStubs
#if !COCOAPODS
import OHHTTPStubsSwift
#endif
@testable import Statsig

func goodStub() {
    stub(condition: isHost("api.statsig.com")) { req in
        return HTTPStubsResponse(jsonObject: [:], statusCode: 200, headers: nil)
    }
}

func badStub() {
    stub(condition: isHost("api.statsig.com")) { req in
        return HTTPStubsResponse(jsonObject: [:], statusCode: 500, headers: nil)
    }
}

class StatsigListeningSpec: QuickSpec {
    class TestListener: StatsigListening {
        var onInitializedCalled = false
        var onInitializedError: String?

        var onUserUpdatedCalled = false
        var onUserUpdatedError: String?

        func onInitialized(_ error: String?) {
            onInitializedCalled = true
            onInitializedError = error
        }

        func onUserUpdated(_ error: String?) {
            onUserUpdatedCalled = true
            onUserUpdatedError = error
        }
    }

    override func spec() {
        beforeEach {
            InternalStore.deleteAllLocalStorage()
        }

        afterEach {
            HTTPStubs.removeAllStubs()
            Statsig.shutdown()
            InternalStore.deleteAllLocalStorage()
        }

        describe("checking if initialized") {
            it("returns true when initialized") {
                goodStub()

                expect(Statsig.isInitialized()).to(beFalse())
                var called = false
                Statsig.start(sdkKey: "client-key") { _ in
                    called = true
                }
                expect(called).toEventually(beTrue())
                expect(Statsig.isInitialized()).to(beTrue())
            }
        }

        describe("listening to initialize callbacks") {
            it("responds with errors") {
                badStub()

                let listener = TestListener()

                Statsig.start(sdkKey: "client-key")
                Statsig.addListener(listener)

                expect(listener.onInitializedError).toEventually(contain("An error occurred during fetching values for the user. 500"))
            }

            it("responds without errors") {
                goodStub()

                let listener = TestListener()

                Statsig.start(sdkKey: "client-key")
                Statsig.addListener(listener)

                expect(listener.onInitializedCalled).toEventually(beTrue())
                expect(listener.onInitializedError).to(beNil())
            }

            it("notifies multiple users") {
                goodStub()

                let listener1 = TestListener()
                let listener2 = TestListener()

                Statsig.start(sdkKey: "client-key")
                Statsig.addListener(listener1)
                Statsig.addListener(listener2)

                expect(listener1.onInitializedCalled).toEventually(beTrue())
                expect(listener2.onInitializedCalled).toEventually(beTrue())
            }

            it("responds immediately if initialzing has previously completed") {
                goodStub()
                var initialized = false
                Statsig.start(sdkKey: "client-key") { _ in
                    initialized = true
                }

                expect(initialized).toEventually(beTrue())
                let listener = TestListener()
                Statsig.addListener(listener)
                expect(listener.onInitializedCalled).to(beTrue())
            }

            it("responds immediately with error if initialzing has previously completed") {
                badStub()
                var error: String?
                Statsig.start(sdkKey: "client-key") { err in
                    error = err
                }

                expect(error).toEventuallyNot(beNil())
                let listener = TestListener()
                Statsig.addListener(listener)
                expect(listener.onInitializedCalled).to(beTrue())
                expect(listener.onInitializedError).to(be(error))
            }
        }

        describe("listening to updateUser callbacks") {
            beforeEach {
                goodStub()

                var initialized = false
                Statsig.start(sdkKey: "client-key") { _ in
                    initialized = true
                }
                expect(initialized).toEventually(beTrue())
            }

            it("responds with errors") {
                badStub()

                let listener = TestListener()
                Statsig.addListener(listener)
                Statsig.updateUser(StatsigUser())

                expect(listener.onUserUpdatedError).toEventually(contain("An error occurred during fetching values for the user. 500"))
            }

            it("responds without errors") {
                goodStub()

                let listener = TestListener()
                Statsig.addListener(listener)
                Statsig.updateUser(StatsigUser())

                expect(listener.onUserUpdatedCalled).toEventually(beTrue())
                expect(listener.onUserUpdatedError).to(beNil())
            }
        }

    }
}

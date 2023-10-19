import Foundation

import Nimble
import OHHTTPStubs
import Quick

#if !COCOAPODS
import OHHTTPStubsSwift
#endif

@testable import Statsig

class UserCacheKeySpec: BaseSpec {

    override func spec() {
        super.spec()

        describe("UserCacheKey") {
            it("gets the same keys for identical users") {
                let firstUser = StatsigUser(userID: "a-user")
                let secondUser = StatsigUser(userID: "a-user")

                let firstKey = UserCacheKey.from(user: firstUser, sdkKey: "some-key")
                let secondKey = UserCacheKey.from(user: secondUser, sdkKey: "some-key")

                expect(firstKey.v1).to(equal(secondKey.v1))
                expect(firstKey.v2).to(equal(secondKey.v2))
            }

            it("gets different keys for different users") {
                let firstUser = StatsigUser(userID: "a-user")
                let secondUser = StatsigUser(userID: "b-user")

                let firstKey = UserCacheKey.from(user: firstUser, sdkKey: "some-key")
                let secondKey = UserCacheKey.from(user: secondUser, sdkKey: "some-key")

                expect(firstKey.v1).notTo(equal(secondKey.v1))
                expect(firstKey.v2).notTo(equal(secondKey.v2))
            }

            it("gets different v2 but same v1 for different sdk keys") {
                let firstUser = StatsigUser(userID: "a-user")
                let secondUser = StatsigUser(userID: "a-user")

                let firstKey = UserCacheKey
                    .from(user: firstUser, sdkKey: "some-key")
                let secondKey = UserCacheKey
                    .from(user: secondUser, sdkKey: "some-other-key")

                expect(firstKey.v1).to(equal(secondKey.v1))
                expect(firstKey.v2).notTo(equal(secondKey.v2))
            }

            it("gets the same values for null users") {
                let firstUser = StatsigUser()
                let secondUser = StatsigUser()

                let firstKey = UserCacheKey
                    .from(user: firstUser, sdkKey: "some-key")
                let secondKey = UserCacheKey
                    .from(user: secondUser, sdkKey: "some-key")


                expect(firstKey.v1).to(equal(secondKey.v1))
                expect(firstKey.v2).to(equal(secondKey.v2))
            }
        }
    }
}

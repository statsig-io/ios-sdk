import Quick
import Nimble
@testable import Statsig

class StatsigUserSpec: QuickSpec {
    override func spec() {
        let validJSONObject: [String:StatsigUserCustomTypeConvertible] =
            ["company": "Statsig", "YOE": 10.5, "alias" : ["abby", "bob", "charlie"]]
        let invalidJSONObject: [String:StatsigUserCustomTypeConvertible] =
            ["company": "Statsig", "invalid": String(bytes: [0xD8, 0x00] as [UInt8], encoding: String.Encoding.utf16BigEndian)!]

        describe("creating a new StatsigUser") {
            it("is a valid empty user") {
                let validEmptyUser = StatsigUser()
                expect(validEmptyUser).toNot(beNil())
                expect(validEmptyUser.userID).to(beNil())
                expect(validEmptyUser.email).to(beNil())
                expect(validEmptyUser.country).to(beNil())
                expect(validEmptyUser.ip).to(beNil())
                expect(validEmptyUser.custom).to(beNil())
                expect(validEmptyUser.environment).toNot(beNil())
            }

            it("is a valid user with ID provided") {
                let validUserWithID = StatsigUser(userID: "12345")
                expect(validUserWithID).toNot(beNil())
                expect(validUserWithID.userID) == "12345"
                expect(validUserWithID.toDictionary().count) == 1
            }

            it("is a valid user with custom attribute") {
                let validUserWithCustom = StatsigUser(userID: "12345",custom: validJSONObject)
                expect(validUserWithCustom).toNot(beNil())
                expect(validUserWithCustom.userID) == "12345"

                let customDict = validUserWithCustom.custom!
                expect(customDict.count) == 3
                expect(customDict["company"] as? String) == "Statsig"
                expect(customDict["YOE"] as? Double) == 10.5
                expect(customDict["alias"] as? [String]) == ["abby", "bob", "charlie"]
            }

            it("is a user with invalid custom attribute") {
                let validUserInvalidCustom = StatsigUser(userID: "12345",custom: invalidJSONObject)
                expect(validUserInvalidCustom).toNot(beNil())
                expect(validUserInvalidCustom.userID) == "12345"
                expect(validUserInvalidCustom.custom).to(beNil())
            }
        }

        describe("checking if 2 StatsigUser are equal") {
            expect(StatsigUser()) == StatsigUser()
            expect(StatsigUser(userID: "1")) == StatsigUser(userID: "1")
            expect(StatsigUser(userID: "1", custom: validJSONObject)) == StatsigUser(userID: "1", custom: validJSONObject)
            expect(StatsigUser(userID: "1")) == StatsigUser(userID: "1", custom: invalidJSONObject)

            expect(StatsigUser()) != StatsigUser(userID: "1")
            expect(StatsigUser(userID: "1")) != StatsigUser(userID: "2")
            expect(StatsigUser(userID: "1")) != StatsigUser(userID: "1", email:"1@gmail.com")
            expect(StatsigUser(userID: "1")) != StatsigUser(userID: "1", custom: validJSONObject)
        }
    }
}

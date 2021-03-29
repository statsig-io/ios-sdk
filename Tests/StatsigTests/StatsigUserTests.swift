import XCTest
@testable import Statsig

final class StatsigUserTests: XCTestCase {
    private let validJSONObject: [String:Codable] = ["company": "Statsig", "YOE": 10.5, "alias" : ["abby", "bob", "charlie"]]
    private let invalidJSONObject: [String:Codable] =
        ["company": "Statsig", "invalid": String(bytes: [0xD8, 0x00] as [UInt8], encoding: String.Encoding.utf16BigEndian)!]

    func testUserCreation() {
        let validEmptyUser = StatsigUser()
        XCTAssertNotNil(validEmptyUser)
        XCTAssert(validEmptyUser.userID == nil)
        XCTAssert(validEmptyUser.toDictionary().isEmpty)

        let validUserWithID = StatsigUser(userID: "12345")
        XCTAssertNotNil(validUserWithID)
        XCTAssert(validUserWithID.userID == "12345")
        XCTAssert(validUserWithID.toDictionary().count == 1)
        XCTAssertTrue(validUserWithID.toDictionary()["userID"] as? String == "12345")

        let validUserWithCustom = StatsigUser(userID: "12345",custom: validJSONObject)
        XCTAssertNotNil(validUserWithCustom)
        XCTAssert(validUserWithCustom.userID == "12345")
        XCTAssert(validUserWithCustom.custom?.count == 3)

        let userDict = validUserWithCustom.toDictionary();
        XCTAssertTrue(userDict["userID"] as? String == "12345")
        XCTAssertTrue(userDict.count == 2)

        // Test all properties in custom field are preserved in toDictionary() output
        let custom = userDict["custom"] as! [String:Codable]
        XCTAssertNotNil(custom.count == 3)
        XCTAssertEqual(custom["company"] as! String, "Statsig")
        XCTAssertEqual(custom["YOE"] as! Double, 10.5)
        XCTAssertEqual(custom["alias"] as! [String], ["abby", "bob", "charlie"])


        // custom saved as nil when it's not a valid JSON object
        let validUserInvalidCustom =
            StatsigUser(userID: "12345",custom: invalidJSONObject)
        XCTAssertNotNil(validUserInvalidCustom)
        XCTAssert(validUserInvalidCustom.userID == "12345")
        XCTAssert(validUserInvalidCustom.custom == nil)

        // invalid custom should NOT be present in toDictionary()
        XCTAssert(validUserInvalidCustom.toDictionary().count == 1)
        XCTAssert(validUserInvalidCustom.toDictionary()["userID"] as! String == "12345")
    }

    func testUserEquality() {
        let emptyUser = StatsigUser()
        let emptyUserClone = StatsigUser()
        let user1 = StatsigUser(userID: "1")
        let user1Clone = StatsigUser(userID: "1")
        let user1WithEmail = StatsigUser(userID: "1", email:"1@gmail.com")
        let user1WithCustom = StatsigUser(userID: "1", custom: validJSONObject)
        let user1WithCustomClone = StatsigUser(userID: "1", custom: validJSONObject)
        let user1WithInvalidCustom = StatsigUser(userID: "1", custom: invalidJSONObject)
        let user2 = StatsigUser(userID: "2")

        XCTAssertTrue(emptyUser == emptyUserClone)
        XCTAssertTrue(emptyUser != user1)
        XCTAssertTrue(user1 == user1Clone)
        XCTAssertTrue(user1 != user2)
        XCTAssertTrue(user1 != user1WithEmail)
        XCTAssertTrue(user1 != user1WithCustom)
        XCTAssertTrue(user1WithCustom == user1WithCustomClone)
        XCTAssertTrue(user1 == user1WithInvalidCustom)
    }
}

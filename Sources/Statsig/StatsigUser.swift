import Foundation

import UIKit

public struct StatsigUser: Codable, Equatable {
    public var userID: String?
    public var name: String?
    public var email: String?
    public var ip: String?
    public var country: String?
    public var custom: [String:String]?
    
    var environment: DeviceEnvironment = DeviceEnvironment()

    public init(userID:String? = nil,
         name: String? = nil,
         email: String? = nil,
         ip: String? = nil,
         country: String? = nil,
         custom: [String:String]? = nil) {
        self.userID = userID
        self.name = name
        self.email = email
        self.ip = ip
        self.country = country
        self.custom = custom
    }
    
    func toDictionary() -> [String:Any?] {
        var dict = [String:Any?]()
        dict["userID"] = self.userID
        dict["name"] = self.name
        dict["email"] = self.email
        dict["ip"] = self.ip
        dict["country"] = self.country
        dict["custom"] = self.custom
        dict["statsigEnvironment"] = self.environment.toDictionary()
        return dict
    }
    
    public static func == (lhs: StatsigUser, rhs: StatsigUser) -> Bool {
        return lhs.userID == rhs.userID
            && lhs.name == rhs.name
            && lhs.email == rhs.email
            && lhs.ip == rhs.ip
            && lhs.country == rhs.country
            && lhs.custom == rhs.custom
    }
}

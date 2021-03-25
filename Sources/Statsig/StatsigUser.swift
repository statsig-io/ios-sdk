import Foundation

public struct StatsigUser: Equatable {
    public var userID: String?
    public var email: String?
    public var ip: String?
    public var country: String?
    public var custom: [String:String]?
    
    var environment: [String:String?]

    public init(userID:String? = nil,
         email: String? = nil,
         ip: String? = nil,
         country: String? = nil,
         custom: [String:String]? = nil) {
        self.userID = userID
        self.email = email
        self.ip = ip
        self.country = country
        self.custom = custom
        self.environment = DeviceEnvironment().get()
    }

    func toDictionary() -> [String:Any?] {
        var dict = [String:Any?]()
        dict["userID"] = self.userID
        dict["email"] = self.email
        dict["ip"] = self.ip
        dict["country"] = self.country
        dict["custom"] = self.custom
        return dict
    }

    public static func == (lhs: StatsigUser, rhs: StatsigUser) -> Bool {
        return lhs.userID == rhs.userID
            && lhs.email == rhs.email
            && lhs.ip == rhs.ip
            && lhs.country == rhs.country
            && lhs.custom == rhs.custom
    }
}

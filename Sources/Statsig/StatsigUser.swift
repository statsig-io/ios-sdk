import Foundation

public struct StatsigUser: Equatable {
    public var userID: String?
    public var email: String?
    public var ip: String?
    public var country: String?
    public var custom: [String:Codable]?
    
    var environment: [String:String?]

    public init(userID:String? = nil,
         email: String? = nil,
         ip: String? = nil,
         country: String? = nil,
         custom: [String:Codable]? = nil) {
        self.userID = userID
        self.email = email
        self.ip = ip
        self.country = country
        if let custom = custom {
            if JSONSerialization.isValidJSONObject(custom) {
                self.custom = custom
            } else {
                print("[Statsig]: The provided custom value is not added to the user because it is not a valid JSON object.")
            }
        }
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
        let lhsJSONData = try? JSONSerialization.data(withJSONObject: lhs.custom ?? [])
        let rhsJSONData = try? JSONSerialization.data(withJSONObject: rhs.custom ?? [])
        return lhs.userID == rhs.userID
            && lhs.email == rhs.email
            && lhs.ip == rhs.ip
            && lhs.country == rhs.country
            && lhsJSONData == rhsJSONData
    }
}

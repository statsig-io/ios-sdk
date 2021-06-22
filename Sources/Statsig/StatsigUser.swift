import Foundation

public struct StatsigUser {
    public let userID: String?
    public let email: String?
    public let ip: String?
    public let country: String?
    public let locale: String?
    public let appVersion: String?
    public let custom: [String: StatsigUserCustomTypeConvertible]?

    var statsigEnvironment: [String: String] = [:]
    var deviceEnvironment: [String: String?]

    public init(userID: String? = nil,
         email: String? = nil,
         ip: String? = nil,
         country: String? = nil,
         locale: String? = nil,
         appVersion: String? = nil,
         custom: [String: StatsigUserCustomTypeConvertible]? = nil) {
        self.userID = userID
        self.email = email
        self.ip = ip
        self.country = country
        self.locale = locale
        self.appVersion = appVersion

        if let custom = custom, JSONSerialization.isValidJSONObject(custom) {
            self.custom = custom
        } else {
            if custom != nil {
                print("[Statsig]: The provided custom value is not added to the user because it is not a valid JSON object.")
            }
            self.custom = nil
        }
        self.deviceEnvironment = DeviceEnvironment().get()
    }

    func toDictionary() -> [String: Any?] {
        var dict = [String: Any?]()
        dict["userID"] = self.userID
        dict["email"] = self.email
        dict["ip"] = self.ip
        dict["country"] = self.country
        dict["locale"] = self.locale
        dict["appVersion"] = self.appVersion
        dict["custom"] = self.custom
        dict["statsigEnvironment"] = self.statsigEnvironment
        return dict
    }
}

import Foundation

public struct StatsigUser {
    public let userID: String?
    public let email: String?
    public let ip: String?
    public let country: String?
    public let locale: String?
    public let appVersion: String?
    public let custom: [String: StatsigUserCustomTypeConvertible]?
    public let privateAttributes: [String: StatsigUserCustomTypeConvertible]?
    public let customIDs: [String: String]?

    var statsigEnvironment: [String: String] = [:]
    var deviceEnvironment: [String: String?]

    public init(userID: String? = nil,
                email: String? = nil,
                ip: String? = nil,
                country: String? = nil,
                locale: String? = nil,
                appVersion: String? = nil,
                custom: [String: StatsigUserCustomTypeConvertible]? = nil,
                privateAttributes: [String: StatsigUserCustomTypeConvertible]? = nil,
                customIDs: [String: String]? = nil)
    {
        self.userID = userID
        self.email = email
        self.ip = ip
        self.country = country
        self.locale = locale
        self.appVersion = appVersion
        self.customIDs = customIDs

        if let custom = custom, JSONSerialization.isValidJSONObject(custom) {
            self.custom = custom
        } else {
            if custom != nil {
                print("[Statsig]: The provided custom value is not added to the user because it is not a valid JSON object.")
            }
            self.custom = nil
        }

        if let privateAttributes = privateAttributes, JSONSerialization.isValidJSONObject(privateAttributes) {
            self.privateAttributes = privateAttributes
        } else {
            if privateAttributes != nil {
                print("[Statsig]: The provided privateAttributes is not added to the user because it is not a valid JSON object.")
            }
            self.privateAttributes = nil
        }
        self.deviceEnvironment = DeviceEnvironment().get()
    }

    mutating func setStableID(_ overrideStableID: String) {
        self.deviceEnvironment = DeviceEnvironment().get(overrideStableID)
    }

    func toDictionary(forLogging: Bool) -> [String: Any?] {
        var dict = [String: Any?]()
        dict["userID"] = self.userID
        dict["email"] = self.email
        dict["ip"] = self.ip
        dict["country"] = self.country
        dict["locale"] = self.locale
        dict["appVersion"] = self.appVersion
        dict["custom"] = self.custom
        dict["statsigEnvironment"] = self.statsigEnvironment
        dict["customIDs"] = self.customIDs

        if !forLogging {
            dict["privateAttributes"] = self.privateAttributes
        }

        return dict
    }
}

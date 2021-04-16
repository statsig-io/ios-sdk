import Foundation

@objc(StatsigUser)
public final class ObjcStatsigUser : NSObject {
    var user : StatsigUser;

    @objc override public init() {
        self.user = StatsigUser();
    }

    @objc public init(userID: String) {
        self.user = StatsigUser(userID: userID);
    }

    @objc public init(userID: String? = nil,
                      email: String? = nil,
                      ip: String? = nil,
                      country: String? = nil,
                      custom: [String: Any]? = nil) {
        var filteredCustom = [String: StatsigUserCustomTypeConvertible]();
        if let custom = custom {
            custom.forEach({ (key, value) in
                if let v = convertToUserCustomType(value) {
                    filteredCustom[key] = v;
                } else {
                    print("[Statsig]: the entry for key \(key) is dropped because it is not of a supported type.")
                }
            })
        }

        self.user = StatsigUser(userID: userID, email: email, ip: ip, country: country,
                           custom: filteredCustom.isEmpty ? nil : filteredCustom);
    }
}

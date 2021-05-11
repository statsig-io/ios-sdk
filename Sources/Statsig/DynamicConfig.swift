import Foundation

public struct DynamicConfig {
    public var name: String
    public var value: [String: Any]
    var ruleID: String

    init(configName: String, configObj: [String: Any]) {
        self.name = configName;
        self.ruleID = configObj["rule_id"] as? String ?? "";
        self.value = configObj["value"] as? [String: Any] ?? [:];
    }

    public func getValue<T: StatsigDynamicConfigValue>(forKey: String, defaultValue: T) -> T {
        let serverValue = value[forKey] as? T
        if serverValue == nil {
            print("[Statsig]: \(forKey) does not exist in this Dynamic Config. Returning the defaultValue.")
        }
        return serverValue ?? defaultValue
    }
}

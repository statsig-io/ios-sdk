import Foundation

public struct DynamicConfig {
    public var name: String
    public var value: [String: Any]
    var group: String

    init(configName: String, config: [String: Any]) {
        self.name = configName;
        self.group = config["group"] as? String ?? "unknown";
        self.value = config["value"] as? [String: Any] ?? [:];
    }

    public func getValue<T: StatsigDynamicConfigValue>(forKey: String, defaultValue: T) -> T {
        let serverValue = value[forKey] as? T
        if serverValue == nil {
            print("[Statsig]: \(forKey) does not exist in this Dynamic Config. Returning the defaultValue.")
        }
        return serverValue ?? defaultValue
    }
}

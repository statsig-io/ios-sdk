import Foundation

public struct DynamicConfig {
    var name: String
    var group: String
    var value: [String:Any]

    init(configName: String, config: [String:Any]) {
        self.name = configName;
        self.group = config["group"] as? String ?? "unknown";
        self.value = config["value"] as? [String:Any] ?? [String:Any]();
    }

    static func createDummy() -> DynamicConfig {
        return DynamicConfig(configName: "com.Statsig.DynamicConfig.dummy", config: [String:Any]())
    }

    public func getValue<T: StatsigDynamicConfigValue>(forKey:String, defaultValue: T) -> T {
        let serverValue = value[forKey] as? T
        if serverValue == nil {
            print("[Statsig]: \(forKey) does not exist in this Dynamic Config. Returning the defaultValue.")
        }
        return serverValue ?? defaultValue
    }
}

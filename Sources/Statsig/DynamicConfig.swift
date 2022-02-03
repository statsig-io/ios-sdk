import Foundation

public struct DynamicConfig {
    public let name: String
    public let value: [String: Any]
    let ruleID: String
    let secondaryExposures: [[String: String]]
    var isDeviceBased: Bool = false
    var isUserInExperiment: Bool = false
    var isExperimentActive: Bool = false
    var rawValue: [String: Any] = [:]

    init(configName: String, configObj: [String: Any] = [:]) {
        self.name = configName
        self.ruleID = configObj["rule_id"] as? String ?? ""
        self.value = configObj["value"] as? [String: Any] ?? [:]
        self.secondaryExposures = configObj["secondary_exposures"] as? [[String: String]] ?? []

        self.isDeviceBased = configObj["is_device_based"] as? Bool ?? false
        self.isUserInExperiment = configObj["is_user_in_experiment"] as? Bool ?? false
        self.isExperimentActive = configObj["is_experiment_active"] as? Bool ?? false
        self.rawValue = configObj
    }

    init(configName: String, value: [String: Any], ruleID: String) {
        self.name = configName
        self.value = value
        self.ruleID = ruleID
        self.secondaryExposures = []
    }

    public func getValue<T: StatsigDynamicConfigValue>(forKey: String, defaultValue: T) -> T {
        let serverValue = value[forKey] as? T
        if serverValue == nil {
            print("[Statsig]: \(forKey) does not exist in this Dynamic Config. Returning the defaultValue.")
        }
        return serverValue ?? defaultValue
    }
}

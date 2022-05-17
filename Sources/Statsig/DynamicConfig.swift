import Foundation

public struct DynamicConfig: ConfigProtocol {
    public let name: String
    public let value: [String: Any]
    public let ruleID: String
    let secondaryExposures: [[String: String]]
    public let isUserInExperiment: Bool
    public let isExperimentActive: Bool
    public let hashedName: String
    public let evaluationDetails: EvaluationDetails

    var isDeviceBased: Bool = false
    var rawValue: [String: Any] = [:]

    init(name: String, configObj: [String: Any] = [:], evalDetails: EvaluationDetails) {
        self.init(configName: name, configObj: configObj, evalDetails: evalDetails)
    }

    init(configName: String, configObj: [String: Any] = [:], evalDetails: EvaluationDetails) {
        self.name = configName
        self.ruleID = configObj["rule_id"] as? String ?? ""
        self.value = configObj["value"] as? [String: Any] ?? [:]
        self.secondaryExposures = configObj["secondary_exposures"] as? [[String: String]] ?? []
        self.hashedName = configObj["name"] as? String ?? ""

        self.isDeviceBased = configObj["is_device_based"] as? Bool ?? false
        self.isUserInExperiment = configObj["is_user_in_experiment"] as? Bool ?? false
        self.isExperimentActive = configObj["is_experiment_active"] as? Bool ?? false
        self.rawValue = configObj

        self.evaluationDetails = evalDetails
    }

    init(configName: String, value: [String: Any], ruleID: String, evalDetails: EvaluationDetails) {
        self.name = configName
        self.value = value
        self.ruleID = ruleID
        self.secondaryExposures = []
        self.hashedName = ""

        self.isExperimentActive = false
        self.isUserInExperiment = false

        self.evaluationDetails = evalDetails
    }

    public func getValue<T: StatsigDynamicConfigValue>(forKey: String, defaultValue: T) -> T {
        let result = value[forKey]
        let typedResult = result as? T
        if typedResult == nil {
            if let result = result {
                print("[Statsig]: \(forKey) exists in this Dynamic Config, but requested type was incorrect (Requested = \(type(of: defaultValue)), Actual = \(type(of: result))). Returning the defaultValue.")
            } else {
                print("[Statsig]: \(forKey) does not exist in this Dynamic Config. Returning the defaultValue.")
            }
        }
        return typedResult ?? defaultValue
    }
}

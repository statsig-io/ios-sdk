import Foundation

/**
 Class that surfaces the current experiment/dynamic config/autotune values from Statsig.

 SeeAlso [Dynamic Config Documentation](https://docs.statsig.com/dynamic-config)

 SeeAlso [Experiments Documentation](https://docs.statsig.com/experiments-plus)
 */
public struct DynamicConfig: ConfigProtocol {
    /**
     The name used to retrieve this DynamicConfig
     */
    public let name: String

    /**
     The values stored
     */
    public let value: [String: Any]

    /**
     The ID of the rule that lead to the resulting dynamic config.
     */
    public let ruleID: String

    let secondaryExposures: [[String: String]]

    /**
     (Experiments Only) Is the current user allocated to this experiment
     */
    public let isUserInExperiment: Bool

    /**
     (Experiments Only) Is this experiment currently running
     */
    public let isExperimentActive: Bool

    /**
     The SHA256 hash of this configs name
     */
    public let hashedName: String

    /**
     (For debug purposes) Why did Statsig return this DynamicConfig
     */
    public let evaluationDetails: EvaluationDetails

    var isDeviceBased: Bool = false
    var rawValue: [String: Any] = [:]

    internal init(name: String, configObj: [String: Any] = [:], evalDetails: EvaluationDetails) {
        self.init(configName: name, configObj: configObj, evalDetails: evalDetails)
    }

    internal init(configName: String, configObj: [String: Any] = [:], evalDetails: EvaluationDetails) {
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

    internal init(configName: String, value: [String: Any], ruleID: String, evalDetails: EvaluationDetails) {
        self.name = configName
        self.value = value
        self.ruleID = ruleID
        self.secondaryExposures = []
        self.hashedName = ""

        self.isExperimentActive = false
        self.isUserInExperiment = false

        self.evaluationDetails = evalDetails
    }

    /**
     Get the value for the given key, falling back to the defaultValue if it cannot be found or is of a different type.

     Parameters:
     - forKey: The key of parameter being fetched
     - defaultValue: The fallback value if the key cannot be found
     */
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

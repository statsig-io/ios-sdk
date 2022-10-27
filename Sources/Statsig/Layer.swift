import Foundation

typealias StringRecord = [String: String]

/**
 Class that surfaces current layer values from Statsig. Will contain layer default values for all shared parameters in that layer.
 If a parameter is in an active experiment, and the current user is allocated to that experiment, those parameters will be updated to reflect the experiment values not the layer defaults.

 SeeAlso [Layers Documentation](https://docs.statsig.com/layers)
 */
public struct Layer: ConfigProtocol {
    /**
     The name used to retrieve this Layer.
     */
    public let name: String

    /**
     The ID of the rule that lead to the resulting layer.
     */
    public let ruleID: String

    /**
     (Experiments Only) Does this layer contain parameters being controlled by an experiment that the current user is allocated to.
     */
    public let isUserInExperiment: Bool

    /**
     (Experiments Only) Does this layer contain parameters being controlled by an experiment that is currently running.
     */
    public let isExperimentActive: Bool

    /**
     Hahsed name of the layer.
     */
    public let hashedName: String

    /**
     Hashed name of an experiment. Only set if the layer contains parameters being controlled by an experiment.
     */
    public let allocatedExperimentName: String

    /**
     (For debug purposes) Why did Statsig return this DynamicConfig
     */
    public let evaluationDetails: EvaluationDetails

    weak internal var client: StatsigClient?
    internal let secondaryExposures: [[String: String]]
    internal let undelegatedSecondaryExposures: [[String: String]]
    internal let explicitParameters: Set<String>
    internal var isDeviceBased: Bool = false
    internal var rawValue: [String: Any] = [:]

    private let value: [String: Any]

    internal init(client: StatsigClient?, name: String, configObj: [String: Any] = [:], evalDetails: EvaluationDetails) {
        self.client = client
        self.name = name
        self.ruleID = configObj["rule_id"] as? String ?? ""
        self.value = configObj["value"] as? [String: Any] ?? [:]
        self.secondaryExposures = configObj["secondary_exposures"] as? [[String: String]] ?? []
        self.undelegatedSecondaryExposures = configObj["undelegated_secondary_exposures"] as? [[String: String]] ?? []
        self.hashedName = configObj["name"] as? String ?? ""

        self.isDeviceBased = configObj["is_device_based"] as? Bool ?? false
        self.isUserInExperiment = configObj["is_user_in_experiment"] as? Bool ?? false
        self.isExperimentActive = configObj["is_experiment_active"] as? Bool ?? false
        self.allocatedExperimentName = configObj["allocated_experiment_name"] as? String ?? ""
        self.explicitParameters = Set(configObj["explicit_parameters"] as? [String] ?? [])
        self.rawValue = configObj

        self.evaluationDetails = evalDetails
    }

    internal init(client: StatsigClient?, name: String, value: [String: Any], ruleID: String, evalDetails: EvaluationDetails) {
        self.client = client
        self.name = name
        self.value = value
        self.ruleID = ruleID
        self.secondaryExposures = []
        self.undelegatedSecondaryExposures = []
        self.explicitParameters = Set()
        self.hashedName = ""

        self.isExperimentActive = false
        self.isUserInExperiment = false
        self.allocatedExperimentName = ""

        self.evaluationDetails = evalDetails
    }

    /**
     Get the value for the given key. If the value cannot be found, or is found to have a different type than the defaultValue, the defaultValue will be returned.
     If a valid value is found, a layer exposure event will be fired.

     Parameters:
     - forKey: The key of parameter being fetched
     - defaultValue: The fallback value if the key cannot be found
     */
    public func getValue<T: StatsigDynamicConfigValue>(forKey: String, defaultValue: T) -> T {
        let result = value[forKey]
        let typedResult = result as? T
        if typedResult == nil {
            if let result = result {
                print("[Statsig]: \(forKey) exists in this Layer, but requested type was incorrect (Requested = \(type(of: defaultValue)), Actual = \(type(of: result))). Returning the defaultValue.")
            } else {
                print("[Statsig]: \(forKey) does not exist in this Layer. Returning the defaultValue.")
            }
        } else {
            client?.logLayerParameterExposureForLayer(self, parameterName: forKey, isManualExposure: false)
        }
        return typedResult ?? defaultValue
    }
}

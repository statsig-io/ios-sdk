import Foundation

typealias ParamStoreConfiguration = [String: [String: Any]]

fileprivate struct RefType {
    static let staticValue = "static"
    static let gate = "gate"
    static let dynamicConfig = "dynamic_config"
    static let experiment = "experiment"
    static let layer = "layer"
}

fileprivate struct ParamKeys {
    static let paramType = "param_type"
    static let refType = "ref_type"
    
    // Gate
    static let gateName = "gate_name"
    static let passValue = "pass_value"
    static let failValue = "fail_value"
    
    // Static Value
    static let value = "value"
    
    // Dynamic Config / Experiment / Layer
    static let paramName = "param_name"
    static let configName = "config_name"
    static let experimentName = "experiment_name"
    static let layerName = "layer_name"
}

public struct ParameterStore: ConfigBase {
    /**
     The name used to retrieve this ParameterStore.
     */
    public let name: String
    
    /**
     (For debug purposes) Why did Statsig return this ParameterStore
     */
    public let evaluationDetails: EvaluationDetails
    
    internal let configuration: ParamStoreConfiguration
    weak internal var client: StatsigClient?
    internal var shouldExpose = true
    
    internal init(
        name: String,
        evaluationDetails: EvaluationDetails,
        client: StatsigClient? = nil,
        configuration: [String: Any] = [:]
    ) {
        self.name = name
        self.evaluationDetails = evaluationDetails
        self.client = client
        self.configuration = configuration as? ParamStoreConfiguration ?? ParamStoreConfiguration()
    }
    
    /**
     Get the value for the given key. If the value cannot be found, or is found to have a different type than the defaultValue, the defaultValue will be returned.
     If a valid value is found, a layer exposure event will be fired.
     
     Parameters:
     - forKey: The key of parameter being fetched
     - defaultValue: The fallback value if the key cannot be found
     */
    public func getValue<T: StatsigDynamicConfigValue>(
        forKey paramName: String,
        defaultValue: T
    ) -> T {
        if configuration.isEmpty {
            return defaultValue
        }
        
        guard
            let client = client,
            let param = configuration[paramName],
            let refType = param[ParamKeys.refType] as? String,
            let paramType = param[ParamKeys.paramType] as? String,
            getTypeOf(defaultValue) == paramType
        else {
            return defaultValue
        }
        
        switch refType {
        case RefType.staticValue:
            return getMappedStaticValue(param, defaultValue)
            
        case RefType.gate:
            return getMappedGateValue(client, param, defaultValue)
            
        case RefType.dynamicConfig:
            return getMappedDynamicConfigValue(client, param, defaultValue)
            
        case RefType.experiment:
            return getMappedExperimentValue(client, param, defaultValue)
            
        case RefType.layer:
            return getMappedLayerValue(client, param, defaultValue)
            
        default:
            return defaultValue
        }
    }
    
    fileprivate func getMappedStaticValue<T>(
        _ param: [String: Any],
        _ defaultValue: T
    ) -> T {
        return param[ParamKeys.value] as? T ?? defaultValue
    }
    
    
    fileprivate func getMappedGateValue<T: StatsigDynamicConfigValue>(
        _ client: StatsigClient,
        _ param: [String: Any],
        _ defaultValue: T
    ) -> T {
        guard
            let gateName = param[ParamKeys.gateName] as? String,
            let passValue = param[ParamKeys.passValue] as? T,
            let failValue = param[ParamKeys.failValue] as? T
        else {
            return defaultValue
        }
        
        let gate = shouldExpose
        ? client.getFeatureGate(gateName)
        : client.getFeatureGateWithExposureLoggingDisabled(gateName)
        return gate.value ? passValue : failValue
    }
    
    
    fileprivate func getMappedDynamicConfigValue<T: StatsigDynamicConfigValue>(
        _ client: StatsigClient,
        _ param: [String: Any],
        _ defaultValue: T
    ) -> T {
        guard
            let configName = param[ParamKeys.configName] as? String,
            let paramName = param[ParamKeys.paramName] as? String
        else {
            return defaultValue
        }
        
        let config = shouldExpose 
            ? client.getConfig(configName)
            : client.getConfigWithExposureLoggingDisabled(configName)
        return config.getValue(forKey: paramName, defaultValue: defaultValue)
    }
    
    
    fileprivate func getMappedExperimentValue<T: StatsigDynamicConfigValue>(
        _ client: StatsigClient,
        _ param: [String: Any],
        _ defaultValue: T
    ) -> T {
        guard
            let experimentName = param[ParamKeys.experimentName] as? String,
            let paramName = param[ParamKeys.paramName] as? String
        else {
            return defaultValue
        }
        
        let experiment = shouldExpose
            ? client.getExperiment(experimentName)
            : client.getExperimentWithExposureLoggingDisabled(experimentName)
        return experiment.getValue(forKey: paramName, defaultValue: defaultValue)
    }
    
    
    fileprivate func getMappedLayerValue<T: StatsigDynamicConfigValue>(
        _ client: StatsigClient,
        _ param: [String: Any],
        _ defaultValue: T
    ) -> T {
        guard
            let layerName = param[ParamKeys.layerName] as? String,
            let paramName = param[ParamKeys.paramName] as? String
        else {
            return defaultValue
        }

        let layer = shouldExpose
            ? client.getLayer(layerName)
            : client.getLayerWithExposureLoggingDisabled(layerName)
        return layer.getValue(forKey: paramName, defaultValue: defaultValue)
    }
    
}

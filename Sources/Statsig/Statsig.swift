import Foundation

#if !COCOAPODS && canImport(StatsigInternalObjC)
import StatsigInternalObjC
#endif

public typealias completionBlock = ((_ errorMessage: String?) -> Void)?

public class Statsig {
    internal static var client: StatsigClient?
    internal static var errorBoundary: ErrorBoundary = ErrorBoundary()
    internal static var pendingListeners: [StatsigListening] = []

    /**
     Initializes the Statsig SDK. Fetching latest values from Statsig.
     Default values will be returned until initialization is compelete.

     Parameters:
     - sdkKey: The client SDK key copied from console.statsig.com
     - user: The user to check values against
     - options: Configuration options for the Statsig SDK
     - completion: A callback function for when initialization completes. If an error occurred during initialization, a error message string will be passed to the callback.

     SeeAlso: [Initialization Documentation](https://docs.statsig.com/client/iosClientSDK#step-3---initialize-the-sdk)
     */
    public static func start(sdkKey: String, user: StatsigUser? = nil, options: StatsigOptions? = nil,
                             completion: completionBlock = nil)
    {
        if client != nil {
            completion?("Statsig has already started!")
            return
        }

        if sdkKey.isEmpty || sdkKey.starts(with: "secret-") {
            completion?("Must use a valid client SDK key.")
            return
        }

        func _initialize() {
            errorBoundary = ErrorBoundary(
                key: sdkKey, deviceEnvironment: DeviceEnvironment().explicitGet()
            )

            errorBoundary.capture("initialize") {
                client = StatsigClient(sdkKey: sdkKey, user: user, options: options, completion: completion)
                addPendingListeners()
            }
        }

        if options?.enableCacheByFile == true {
            DispatchQueue.main.async {
                StatsigUserDefaults.defaults = FileBasedUserDefaults()
                _initialize()
            }
        } else {
            _initialize()
        }
    }

    /**
     Whether Statsig initialization has been completed.

     SeeAlso [StatsigListening](https://docs.statsig.com/client/iosClientSDK#statsiglistening)
     */
    public static func isInitialized() -> Bool {
        guard let client = client else {
            print("[Statsig]: Statsig.start has not been called.")
            return false
        }

        return client.isInitialized()
    }

    /**
     Adds a delegate to be called during initializaiton and update user steps.

     Parameters:
     - listener: The class that implements the StatsigListening protocol

     SeeAlso [StatsigListening](https://docs.statsig.com/client/iosClientSDK#statsiglistening)
     */
    public static func addListener(_ listener: StatsigListening)
    {
        guard let client = client else {
            pendingListeners.append(listener)
            return
        }

        client.addListener(listener)
    }

    /**
     Gets the boolean result of a gate for the current user. An exposure event will automatically be logged for the given gate.

     Parameters:
     - gateName: The name of the feature gate setup on console.statsig.com

     SeeAlso [Gate Documentation](https://docs.statsig.com/feature-gates/working-with)
     */
    public static func checkGate(_ gateName: String) -> Bool {
        return checkGateImpl(gateName, withExposures: true, functionName: funcName()).value
    }

    /**
     Gets the boolean result of a gate for the current user. No exposure events will be logged.

     Parameters:
     - gateName: The name of the feature gate setup on console.statsig.com

     SeeAlso [Gate Documentation](https://docs.statsig.com/feature-gates/working-with)
     */
    public static func checkGateWithExposureLoggingDisabled(_ gateName: String) -> Bool {
        return checkGateImpl(gateName, withExposures: false, functionName: funcName()).value
    }

    /**
     Get the value for the given feature gate. No exposure event will be logged.

     Parameters:
     - gateName: The name of the feature gate setup on console.statsig.com

     SeeAlso [Gate Documentation](https://docs.statsig.com/feature-gates/working-with)
     */
    public static func getFeatureGateWithExposureLoggingDisabled(_ gateName: String) -> FeatureGate {
        return checkGateImpl(gateName, withExposures: false, functionName: funcName())
    }

    /**
     Logs an exposure event for the given gate. Only required if a related checkGateWithExposureLoggingDisabled call has been made.

     Parameters:
     - gateName: The name of the feature gate setup on console.statsig.com
     */
    public static func manuallyLogGateExposure(_ gateName: String) {
        errorBoundary.capture("manuallyLogGateExposure") {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling manuallyLogGateExposure.")
                return
            }

            client.logGateExposure(gateName)
        }
    }

    /**
     Get the values for the given experiment or autotune. An exposure event will automatically be logged for the given experiment.

     Parameters:
     - experimentName: The name of the experiment setup on console.statsig.com
     - keepDeviceValue: Locks experiment values to the first time they are received. If an experiment changes, but the user has already been exposed, the original values are returned. This is not common practice.

     SeeAlso [Experiments Documentation](https://docs.statsig.com/experiments-plus)
     */
    public static func getExperiment(_ experimentName: String, keepDeviceValue: Bool = false) -> DynamicConfig {
        return getExperimentImpl(experimentName, keepDeviceValue: keepDeviceValue, withExposures: true, functionName: funcName())
    }

    /**
     Get the values for the given experiment. No exposure events will be logged.

     Parameters:
     - experimentName: The name of the experiment setup on console.statsig.com
     - keepDeviceValue: Locks experiment values to the first time they are received. If an experiment changes, but the user has already been exposed, the original values are returned. This is not common practice.

     SeeAlso [Experiments Documentation](https://docs.statsig.com/experiments-plus)
     */
    public static func getExperimentWithExposureLoggingDisabled(_ experimentName: String, keepDeviceValue: Bool = false) -> DynamicConfig {
        return getExperimentImpl(experimentName, keepDeviceValue: keepDeviceValue, withExposures: false, functionName: funcName())
    }

    /**
     Logs an exposure event for the given experiment. Only required if a related getExperimentWithExposureLoggingDisabled has been made.

     Parameters:
     - experimentName: The name of the experiment setup on console.statsig.com
     */
    public static func manuallyLogExperimentExposure(_ experimentName: String, keepDeviceValue: Bool = false) {
        errorBoundary.capture("manuallyLogExperimentExposure") {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling manuallyLogExperimentExposure.")
                return
            }

            client.logExperimentExposure(experimentName, keepDeviceValue: keepDeviceValue)
        }
    }

    /**
     Get the values for the given dynamic config. An exposure event will automatically be logged for the given dynamic config.

     Parameters:
     - configName: The name of the dynamic config setup on console.statsig.com

     SeeAlso [Dynamic Config Documentation](https://docs.statsig.com/dynamic-config)
     */
    public static func getConfig(_ configName: String) -> DynamicConfig {
        return getConfigImpl(configName, withExposures: true, functionName: funcName())
    }

    /**
     Get the values for the given dynamic config. No exposure event will be logged.

     Parameters:
     - configName: The name of the dynamic config setup on console.statsig.com

     SeeAlso [Dynamic Config Documentation](https://docs.statsig.com/dynamic-config)
     */
    public static func getConfigWithExposureLoggingDisabled(_ configName: String) -> DynamicConfig {
        return getConfigImpl(configName, withExposures: false, functionName: funcName())
    }

    /**
     Logs an exposure event for the given dynamic config. Only required if a related getConfigWithExposureLoggingDisabled call has been made.

     Parameters:
     - experimentName: The name of the experiment setup on console.statsig.com
     */
    public static func manuallyLogConfigExposure(_ configName: String) {
        errorBoundary.capture("manuallyLogConfigExposure") {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling manuallyLogConfigExposure.")
                return
            }

            client.logConfigExposure(configName)
        }
    }

    /**
     Get the values for the given layer. Exposure events will be fired when getValue is called on the result Layer class.

     Parameters:
     - layerName: The name of the layer setup on console.statsig.com
     - keepDeviceValue: Locks layer values to the first time they are received. If an layer values change, but the user has already been exposed, the original values are returned. This is not common practice.

     SeeAlso [Layers Documentation](https://docs.statsig.com/layers)
     */
    public static func getLayer(_ layerName: String, keepDeviceValue: Bool = false) -> Layer {
        return getLayerImpl(layerName, keepDeviceValue: keepDeviceValue, withExposures: true, functionName: funcName())
    }

    /**
     Get the values for the given layer. No exposure events will be fired.

     Parameters:
     - layerName: The name of the layer setup on console.statsig.com
     - keepDeviceValue: Locks layer values to the first time they are received. If an layer values change, but the user has already been exposed, the original values are returned. This is not common practice.

     SeeAlso [Layers Documentation](https://docs.statsig.com/layers)
     */
    public static func getLayerWithExposureLoggingDisabled(_ layerName: String, keepDeviceValue: Bool = false) -> Layer {
        return getLayerImpl(layerName, keepDeviceValue: keepDeviceValue, withExposures: false, functionName: funcName())
    }

    /**
     Logs an exposure event for the given layer parameter. Only required if a related getLayerWithExposureLoggingDisabled call has been made.

     Parameters:
     - layerName: The name of the layer setup on console.statsig.com
     - parameterName: The name of the parameter that was checked.
     */
    public static func manuallyLogLayerParameterExposure(_ layerName: String, _ parameterName: String, keepDeviceValue: Bool = false) {
        errorBoundary.capture("manuallyLogLayerParameterExposure") {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling manuallyLogLayerParameterExposure.")
                return
            }

            client.logLayerParameterExposure(layerName, parameterName: parameterName, keepDeviceValue: keepDeviceValue)
        }
    }

    /**
     Logs an exposure event for the given feature gate. Only required if a related getFeatureGateWithExposureLoggingDisabled call has been made.

     Parameters:
     - gate: The the feature gate class of a feature gate setup on console.statsig.com
     */
    public static func manuallyLogExposure(_ gate: FeatureGate) {
        errorBoundary.capture("manuallyLogExposure:gate") {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling manuallyLogExposure.")
                return
            }

            client.logGateExposureForGate(gate.name, gate: gate, isManualExposure: true)
        }
    }

    /**
     Logs an exposure event for the given dynamic config. Only required if a related getConfigWithExposureLoggingDisabled or getExperimentWithExposureLoggingDisabled call has been made.

     Parameters:
     - config: The dynamic config class of an experiment, autotune, or dynamic config setup on console.statsig.com
     */
    public static func manuallyLogExposure(_ config: DynamicConfig) {
        errorBoundary.capture("manuallyLogExposure:config") {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling manuallyLogExposure.")
                return
            }

            client.logConfigExposureForConfig(config.name, config: config, isManualExposure: true)
        }
    }

    /**
     Logs an exposure event for the given layer. Only required if a related getLayerWithExposureLoggingDisabled call has been made.

     Parameters:
     - layer: The layer class of a layer setup on console.statsig.com
     - paramterName: The name of the layer parameter that was checked
     */
    public static func manuallyLogExposure(_ layer: Layer, parameterName: String) {
        errorBoundary.capture("manuallyLogExposure:layer") {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling manuallyLogExposure.")
                return
            }

            client.logLayerParameterExposureForLayer(layer, parameterName: parameterName, isManualExposure: true)
        }
    }

    /**
     Logs an event to Statsig with the provided values.

     Parameters:
     - withName: The name of the event
     - metadata: Any extra values to be logged with the event
     */
    public static func logEvent(_ withName: String, metadata: [String: String]? = nil) {
        logEventImpl(withName, value: nil, metadata: metadata)
    }

    /**
     Logs an event to Statsig with the provided values.

     Parameters:
     - withName: The name of the event
     - value: A top level value for the event
     - metadata: Any extra values to be logged with the event
     */
    public static func logEvent(_ withName: String, value: String, metadata: [String: String]? = nil) {
        logEventImpl(withName, value: value, metadata: metadata)
    }

    /**
     Logs an event to Statsig with the provided values.

     Parameters:
     - withName: The name of the event
     - value: A top level value for the event
     - metadata: Any extra key/value pairs to be logged with the event
     */
    public static func logEvent(_ withName: String, value: Double, metadata: [String: String]? = nil) {
        logEventImpl(withName, value: value, metadata: metadata)
    }

    /**
     Switches the user and pulls new values for that user from Statsig.
     Default values will be returned until the update is complete.

     Parameters:
     - user: The new user
     - completion: A callback block called when the new values have been received. May be called with an error message string if the fetch fails.
     */
    public static func updateUser(_ user: StatsigUser, completion: completionBlock = nil) {
        errorBoundary.capture("updateUser") {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling updateUser.")
                completion?("Must start Statsig first and wait for it to complete before calling updateUser.")
                return
            }

            client.updateUser(user, completion: completion)
        }
    }

    /**
     Stops all Statsig activity and flushes any pending events.
     */
    public static func shutdown() {
        errorBoundary.capture("shutdown") {
            client?.shutdown()
            client = nil
        }
    }

    /**
     The generated identifier that exists across users
     */
    public static func getStableID() -> String? {
        var result:String? = nil
        errorBoundary.capture("getStableID") {
            result = client?.getStableID()
        }
        return result
    }

    /**
     Sets a value to be returned for the given gate instead of the actual evaluated value.

     Parameters:
     - gateName: The name of the gate to be overridden
     - value: The value that will be returned
     */
    public static func overrideGate(_ gateName: String, value: Bool) {
        errorBoundary.capture("overrideGate") {
            client?.overrideGate(gateName, value: value)
        }
    }

    /**
     Sets a value to be returned for the given dynamic config/experiment instead of the actual evaluated value.

     Parameters:
     - configName: The name of the config or experiment to be overridden
     - value: The value that the resulting DynamicConfig will contain
     */
    public static func overrideConfig(_ configName: String, value: [String: Any]) {
        errorBoundary.capture("overrideConfig") {
            client?.overrideConfig(configName, value: value)
        }
    }

    /**
     Sets a value to be returned for the given layer instead of the actual evaluated value.

     Parameters:
     - layerName: The name of the layer to be overridden
     - value: The value that the resulting Layer will contain
     */
    public static func overrideLayer(_ layerName: String, value: [String: Any]) {
        errorBoundary.capture("overrideLayer") {
            client?.overrideLayer(layerName, value: value)
        }
    }

    /**
     Clears any overridden value for the given gate/dynamic config/experiment.

     Parameters:
     - name: The name of the gate/dynamic config/experiment to clear
     */
    public static func removeOverride(_ name: String) {
        errorBoundary.capture("removeOverride") {
            client?.removeOverride(name)
        }
    }

    /**
     Clears all overriden values.
     */
    public static func removeAllOverrides() {
        errorBoundary.capture("removeAllOverrides") {
            client?.removeAllOverrides()
        }
    }

    /**
     Returns all values that are currently overriden.
     */
    public static func getAllOverrides() -> StatsigOverrides? {
        var result: StatsigOverrides? = nil
        errorBoundary.capture("getAllOverrides") {
            result = client?.getAllOverrides()
        }
        return result
    }

    public static func openDebugView() {
        errorBoundary.capture("openDebugView") {
            client?.openDebugView()
        }
    }

    //
    // MARK: - Private
    //

    private static func checkGateImpl(_ gateName: String, withExposures: Bool, functionName: String) -> FeatureGate {
        var result: FeatureGate? = nil
        errorBoundary.capture(functionName) {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling \(functionName). Returning false as the default.")
                return
            }

            result = withExposures
            ? client.checkGate(gateName)
            : client.checkGateWithExposureLoggingDisabled(gateName)
        }
        return result ?? FeatureGate(name: gateName, value: false, ruleID: "", evalDetails: EvaluationDetails(reason: .Uninitialized))
    }

    private static func getExperimentImpl(_ experimentName: String, keepDeviceValue: Bool, withExposures: Bool, functionName: String) -> DynamicConfig {
        var result: DynamicConfig? = nil
        errorBoundary.capture(functionName) {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling \(functionName). Returning a dummy DynamicConfig that will only return default values.")
                return
            }

            result = withExposures
            ? client.getExperiment(experimentName, keepDeviceValue: keepDeviceValue)
            : client.getExperimentWithExposureLoggingDisabled(experimentName, keepDeviceValue: keepDeviceValue)
        }
        return result ?? getEmptyConfig(experimentName)
    }

    private static func getConfigImpl(_ configName: String, withExposures: Bool, functionName: String) -> DynamicConfig {
        var result: DynamicConfig? = nil
        errorBoundary.capture(functionName) {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling \(functionName). Returning a dummy DynamicConfig that will only return default values.")
                return
            }

            result = withExposures
            ? client.getConfig(configName)
            : client.getConfigWithExposureLoggingDisabled(configName)
        }
        return result ?? getEmptyConfig(configName)
    }

    private static func getLayerImpl(_ layerName: String, keepDeviceValue: Bool, withExposures: Bool, functionName: String) -> Layer {
        var result: Layer?
        errorBoundary.capture(functionName) {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling \(functionName). Returning an empty Layer object")
                return
            }

            result = withExposures
            ? client.getLayer(layerName, keepDeviceValue: keepDeviceValue)
            : client.getLayerWithExposureLoggingDisabled(layerName, keepDeviceValue: keepDeviceValue)
        }

        return result ?? Layer(client: nil, name: layerName, evalDetails: EvaluationDetails(reason: .Uninitialized))
    }

    private static func logEventImpl(_ withName: String, value: Any? = nil, metadata: [String: String]? = nil) {
        guard let client = client else {
            print("[Statsig]: Must start Statsig first and wait for it to complete before calling logEvent.")
            return
        }

        errorBoundary.capture("logEventImpl") {
            client.logEvent(withName, value: value, metadata: metadata)
        }
    }

    private static func getEmptyConfig(_ name: String) -> DynamicConfig {
        return DynamicConfig(configName: name, evalDetails: EvaluationDetails(reason: .Uninitialized))
    }

    private static func addPendingListeners() {
        for listener in pendingListeners {
            client?.addListener(listener)
        }
        pendingListeners.removeAll()
    }

    private static func funcName(_ name: String = #function) -> String {
        return name.components(separatedBy: "(").first ?? name
    }
}

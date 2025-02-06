import Foundation

public class StatsigClient {
    private static let exposureDedupeQueueLabel = "com.Statsig.exposureDedupeQueue"

    internal var logger: EventLogger
    internal var statsigOptions: StatsigOptions

    private var sdkKey: String
    private var currentUser: StatsigUser
    private var store: InternalStore
    private var networkService: NetworkService
    private var syncTimer: Timer?
    private var loggedExposures: [String: TimeInterval]
    // We use a list of functions to keep a weak reference to each listener. Using
    // NSHashTable.weakObjects isn't an option, as objects are only deallocated when
    // inside an autoreleasepool block. See https://github.com/GitHawkApp/FlatCache/issues/3
    private var listeners: [() -> StatsigListening?] = []
    private var hasInitialized: Bool = false
    private var lastInitializeError: StatsigClientError?
    private var completionWithResult: ResultCompletionBlock? = nil

    private let exposureDedupeQueue = DispatchQueue(label: exposureDedupeQueueLabel, qos: .userInitiated, attributes: .concurrent)

    let maxEventNameLength = 64

    /**
     Initializes the Statsig SDK. Fetching latest values from Statsig.
     Default values will be returned until initialization is compelete.

     Parameters:
     - sdkKey: The client SDK key copied from console.statsig.com
     - user: The user to check values against
     - options: Configuration options for the Statsig SDK
     - completionWithResult: A callback function for when initialization completes. If an error occurred during initialization, a `StatsigClientError` object will be passed to the callback.
     - completion (deprecated. use completionWithResult): A callback function for when initialization completes. If an error occurred during initialization, an error message string will be passed to the callback.

     SeeAlso: [Initialization Documentation](https://docs.statsig.com/client/iosClientSDK#step-3---initialize-the-sdk)
     */
    public init(
        sdkKey: String,
        user: StatsigUser? = nil,
        options: StatsigOptions? = nil,
        completionWithResult: ResultCompletionBlock? = nil,
        completion: ((_ error: String?) -> Void)? = nil
    ) {
        Diagnostics.boot(options)
        Diagnostics.mark?.overall.start();

        self.sdkKey = sdkKey
        self.currentUser = StatsigClient.normalizeUser(user, options: options)
        self.statsigOptions = options ?? StatsigOptions()
        self.store = InternalStore(sdkKey, self.currentUser, options: statsigOptions)
        self.networkService = NetworkService(sdkKey: sdkKey, options: statsigOptions, store: store)
        Diagnostics.mark?.initialize.loggerStart.start()
        self.logger = EventLogger(sdkKey: sdkKey, user: currentUser, networkService: networkService)
        self.logger.start()
        Diagnostics.mark?.initialize.loggerStart.end(success: true)
        self.loggedExposures = [String: TimeInterval]()

        subscribeToApplicationLifecycle()

        let capturedUser = self.currentUser
        let _onComplete: (StatsigClientError?) -> Void = { [weak self, completionWithResult, completion] error in
            guard let self = self else {
                return
            }

            if (self.statsigOptions.enableAutoValueUpdate) {
                self.scheduleRepeatingSync()
            }

            self.hasInitialized = true
            self.lastInitializeError = error

            self.logger.retryFailedRequests();

            Diagnostics.mark?.overall.end(
                success: error == nil,
                details: self.store.cache.getEvaluationDetails(),
                errorMessage: error?.message
            )
            Diagnostics.log(self.logger, user: capturedUser, context: .initialize)

            self.notifyOnInitializedListeners(error)
            completionWithResult?(error)
            completion?(error?.message)
        }

        if (options?.initializeValues != nil) {
            _onComplete(nil)
        } else {
            fetchValuesFromNetwork(completion: _onComplete)
        }
    }

    deinit {
        unsubscribeFromApplicationLifecycle()
    }

    /**
     Whether Statsig initialization has been completed.

     SeeAlso [StatsigListening](https://docs.statsig.com/client/iosClientSDK#statsiglistening)
     */
    public func isInitialized() -> Bool {
        return hasInitialized
    }

    /**
     Adds a delegate to be called during initializaiton and update user steps.

     Parameters:
     - listener: The class that implements the StatsigListening protocol

     SeeAlso [StatsigListening](https://docs.statsig.com/client/iosClientSDK#statsiglistening)
     */
    public func addListener(_ listener: StatsigListening) {
        if (hasInitialized) {
            listener.onInitializedWithResult?(lastInitializeError)
            (listener as StatsigListeningInternal).onInitialized?(lastInitializeError?.message)
        }
        listeners.append({ [weak listener] in return listener })
    }

    /**
     Switches the user and pulls new values for that user from Statsig.
     Default values will be returned until the update is complete.

     Parameters:
     - user: The new user
     - completion: A callback block called when the new values have been received. May be called with a `StatsigClientError` object if the fetch fails.
     */
    public func updateUserWithResult(_ user: StatsigUser, values: [String: Any]? = nil, completion: ResultCompletionBlock? = nil) {
        exposureDedupeQueue.async(flags: .barrier) { [weak self] in
            self?.loggedExposures.removeAll()
        }

        self.updateUserImpl(user, values: values, completion: completion)
    }
    
    /**
     Manually triggered the refreshing process for the current user

     Parameters:
     - completion: A callback block called when the new values/update operation have been received. May be called with a `StatsigClientError` object if the fetch fails.
     */
    public func refreshCacheWithResult(_ completion: ResultCompletionBlock? = nil) {
        self.updateUserWithResult(self.currentUser, completion: completion)
    }

    /**
     Stops all Statsig activity and flushes any pending events.
     */
    public func shutdown() {
        logger.stop()
        Diagnostics.shutdown()
        syncTimer?.invalidate()
    }

    /**
     Manually triggers a flush of any queued events.
     */
    public func flush() {
        logger.flush()
    }

    /**
     The generated identifier that exists across users
     */
    public func getStableID() -> String? {
        return currentUser.deviceEnvironment["stableID"] as? String
    }

    /**
     Presents a view of the current internal state of the SDK.
     */
    public func openDebugView(_ callback: DebuggerCallback? = nil) {
        let cache = store.cache
        let reason = cache.getEvaluationDetails().getDetailedReason()
        let state: [String: Any?] = [
            "user": self.currentUser.toDictionary(forLogging: false),
            "gates": cache.gates,
            "configs": cache.configs,
            "layers": cache.layers,
            "evalReason": reason
        ]

        DispatchQueue.main.async { [weak self] in
            if let self = self {
                DebugViewController.show(self.sdkKey, state, callback)
            }
        }
    }

    /**
     Returns the raw values that the SDK is using internally to provide gate/config/layer results
     */
    public func getInitializeResponseJson() -> ExternalInitializeResponse {
        var values: String? = nil
        let dict: [String: Any?] = [
            "feature_gates": self.store.cache.gates,
            "dynamic_configs": self.store.cache.configs,
            "layer_configs": self.store.cache.layers,
            "hash_used": self.store.cache.hashUsed,
            "time": self.store.cache.userCache["time"]
        ]

        if JSONSerialization.isValidJSONObject(dict),
           let data = try? JSONSerialization.data(withJSONObject: dict),
           let json = data.text {
            values = json
        }

        return ExternalInitializeResponse(
            values: values,
            evaluationDetails: store.cache.getEvaluationDetails()
        )
    }
}

// MARK: Feature Gates
extension StatsigClient {
    /**
     Gets the Bool value of a gate for the current user. An exposure event will automatically be logged for the given gate.

     Parameters:
     - gateName: The name of the feature gate setup on console.statsig.com

     SeeAlso [Gate Documentation](https://docs.statsig.com/feature-gates/working-with)
     */
    public func checkGate(_ gateName: String) -> Bool {
        return getFeatureGate(gateName).value
    }

    /**
     Gets the FeatureGate result of a gate for the current user. An exposure event will automatically be logged for the given gate.

     Parameters:
     - gateName: The name of the feature gate setup on console.statsig.com

     SeeAlso [Gate Documentation](https://docs.statsig.com/feature-gates/working-with)
     */
    public func getFeatureGate(_ gateName: String) -> FeatureGate {
        let gate = store.checkGate(forName: gateName)
        logGateExposureForGate(gateName, gate: gate, isManualExposure: false)
        if let cb = statsigOptions.evaluationCallback {
            cb(.gate(gate))
        }
        return gate
    }

    /**
     Gets the boolean result of a gate for the current user. No exposure events will be logged.

     Parameters:
     - gateName: The name of the feature gate setup on console.statsig.com

     SeeAlso [Gate Documentation](https://docs.statsig.com/feature-gates/working-with)
     */
    public func checkGateWithExposureLoggingDisabled(_ gateName: String) -> Bool {
        return getFeatureGateWithExposureLoggingDisabled(gateName).value
    }

    /**
     Gets the FeatureGate result of a gate for the current user. No exposure events will be logged.

     Parameters:
     - gateName: The name of the feature gate setup on console.statsig.com

     SeeAlso [Gate Documentation](https://docs.statsig.com/feature-gates/working-with)
     */
    public func getFeatureGateWithExposureLoggingDisabled(_ gateName: String) -> FeatureGate {
        logger.incrementNonExposedCheck(gateName)
        let gate = store.checkGate(forName: gateName)
        if let cb = statsigOptions.evaluationCallback {
            cb(.gate(gate))
        }
        return gate;
    }

    /**
     Logs an exposure event for the given gate. Only required if a related checkGateWithExposureLoggingDisabled call has been made.

     Parameters:
     - gateName: The name of the feature gate setup on console.statsig.com
     */
    public func manuallyLogGateExposure(_ gateName: String) {
        logGateExposure(gateName)
    }

    /**
     Logs an exposure event for the given feature gate. Only required if a related getFeatureGateWithExposureLoggingDisabled call has been made.

     Parameters:
     - gate: The the feature gate class of a feature gate setup on console.statsig.com
     */
    public func manuallyLogExposure(_ gate: FeatureGate) {
        logGateExposureForGate(gate.name, gate: gate, isManualExposure: true)
    }

    private func logGateExposure(_ gateName: String, gate: FeatureGate? = nil) {
        let isManualExposure = gate == nil
        let gate = gate ?? store.checkGate(forName: gateName)

        logGateExposureForGate(gateName, gate: gate, isManualExposure: isManualExposure)
    }

    private func logGateExposureForGate(_ gateName: String, gate: FeatureGate, isManualExposure: Bool) {
        let gateValue = gate.value
        let ruleID = gate.ruleID
        let dedupeKey = gateName + (gateValue ? "true" : "false") + ruleID + gate.evaluationDetails.getDetailedReason()

        if shouldLogExposure(key: dedupeKey) {
            logger.log(
                Event.gateExposure(
                    user: currentUser,
                    gateName: gateName,
                    gateValue: gateValue,
                    ruleID: ruleID,
                    secondaryExposures: gate.secondaryExposures,
                    evalDetails: gate.evaluationDetails,
                    bootstrapMetadata: store.getBootstrapMetadata(),
                    disableCurrentVCLogging: statsigOptions.disableCurrentVCLogging)
                .withManualExposureFlag(isManualExposure))
        }
    }
}


// MARK: Dynamic Configs
extension StatsigClient {
    /**
     Get the values for the given dynamic config. An exposure event will automatically be logged for the given dynamic config.

     Parameters:
     - configName: The name of the dynamic config setup on console.statsig.com

     SeeAlso [Dynamic Config Documentation](https://docs.statsig.com/dynamic-config)
     */
    public func getConfig(_ configName: String) -> DynamicConfig {
        let config = store.getConfig(forName: configName)
        logConfigExposureForConfig(configName, config: config, isManualExposure: false)
        if let cb = statsigOptions.evaluationCallback {
            cb(.config(config))
        }
        return config
    }

    /**
     Get the values for the given dynamic config. No exposure event will be logged.

     Parameters:
     - configName: The name of the dynamic config setup on console.statsig.com

     SeeAlso [Dynamic Config Documentation](https://docs.statsig.com/dynamic-config)
     */
    public func getConfigWithExposureLoggingDisabled(_ configName: String) -> DynamicConfig {
        logger.incrementNonExposedCheck(configName)
        let config = store.getConfig(forName: configName)
        if let cb = statsigOptions.evaluationCallback {
            cb(.config(config))
        }
        return config
    }

    /**
     Logs an exposure event for the given dynamic config. Only required if a related getConfigWithExposureLoggingDisabled call has been made.

     Parameters:
     - experimentName: The name of the experiment setup on console.statsig.com
     */
    public func manuallyLogConfigExposure(_ configName: String) {
        logConfigExposure(configName)
    }

    /**
     Logs an exposure event for the given dynamic config. Only required if a related getConfigWithExposureLoggingDisabled or getExperimentWithExposureLoggingDisabled call has been made.

     Parameters:
     - config: The dynamic config class of an experiment, autotune, or dynamic config setup on console.statsig.com
     */
    public func manuallyLogExposure(_ config: DynamicConfig) {
        logConfigExposureForConfig(config.name, config: config, isManualExposure: true)
    }

    private func logConfigExposure(_ configName: String, config: DynamicConfig? = nil) {
        let isManualExposure = config == nil
        let config = config ?? store.getConfig(forName: configName)
        logConfigExposureForConfig(configName, config: config, isManualExposure: isManualExposure)
    }

    private func logConfigExposureForConfig(_ configName: String, config: DynamicConfig, isManualExposure: Bool) {
        let ruleID = config.ruleID
        let dedupeKey = configName + ruleID + config.evaluationDetails.getDetailedReason()

        if shouldLogExposure(key: dedupeKey) {
            logger.log(
                Event.configExposure(
                    user: currentUser,
                    configName: configName,
                    config: config,
                    bootstrapMetadata: store.getBootstrapMetadata(),
                    disableCurrentVCLogging: statsigOptions.disableCurrentVCLogging)
                .withManualExposureFlag(isManualExposure))
        }
    }
}


// MARK: Experiments
extension StatsigClient {
    /**
     Get the values for the given experiment or autotune. An exposure event will automatically be logged for the given experiment.

     Parameters:
     - experimentName: The name of the experiment setup on console.statsig.com
     - keepDeviceValue: Locks experiment values to the first time they are received. If an experiment changes, but the user has already been exposed, the original values are returned. This is not common practice.

     SeeAlso [Experiments Documentation](https://docs.statsig.com/experiments-plus)
     */
    public func getExperiment(_ experimentName: String, keepDeviceValue: Bool = false) -> DynamicConfig {
        let experiment = store.getExperiment(forName: experimentName, keepDeviceValue: keepDeviceValue)
        logConfigExposureForConfig(experimentName, config: experiment, isManualExposure: false)
        if let cb = statsigOptions.evaluationCallback {
            cb(.experiment(experiment))
        }
        return experiment
    }

    /**
     Get the values for the given experiment. No exposure events will be logged.

     Parameters:
     - experimentName: The name of the experiment setup on console.statsig.com
     - keepDeviceValue: Locks experiment values to the first time they are received. If an experiment changes, but the user has already been exposed, the original values are returned. This is not common practice.

     SeeAlso [Experiments Documentation](https://docs.statsig.com/experiments-plus)
     */
    public func getExperimentWithExposureLoggingDisabled(_ experimentName: String, keepDeviceValue: Bool = false) -> DynamicConfig {
        logger.incrementNonExposedCheck(experimentName)
        let experiment = store.getExperiment(forName: experimentName, keepDeviceValue: keepDeviceValue)
        if let cb = statsigOptions.evaluationCallback {
            cb(.experiment(experiment))
        }
        return experiment
    }

    /**
     Logs an exposure event for the given experiment. Only required if a related getExperimentWithExposureLoggingDisabled has been made.

     Parameters:
     - experimentName: The name of the experiment setup on console.statsig.com
     */
    public func manuallyLogExperimentExposure(_ experimentName: String, keepDeviceValue: Bool = false) {
        logExperimentExposure(experimentName, keepDeviceValue: keepDeviceValue)
    }

    private func logExperimentExposure(_ experimentName: String, keepDeviceValue: Bool, experiment: DynamicConfig? = nil) {
        let isManualExposure = experiment == nil
        let experiment = experiment ?? store.getExperiment(forName: experimentName, keepDeviceValue: keepDeviceValue)
        logConfigExposureForConfig(experimentName, config: experiment, isManualExposure: isManualExposure)
    }
}


// MARK: Layers
extension StatsigClient {
    /**
     Get the values for the given layer. Exposure events will be fired when getValue is called on the result Layer class.

     Parameters:
     - layerName: The name of the layer setup on console.statsig.com
     - keepDeviceValue: Locks layer values to the first time they are received. If an layer values change, but the user has already been exposed, the original values are returned. This is not common practice.

     SeeAlso [Layers Documentation](https://docs.statsig.com/layers)
     */
    public func getLayer(_ layerName: String, keepDeviceValue: Bool = false) -> Layer {
        let layer = store.getLayer(client: self, forName: layerName, keepDeviceValue: keepDeviceValue)
        if let cb = statsigOptions.evaluationCallback {
            cb(.layer(layer))
        }
        return layer
    }

    /**
     Get the values for the given layer. No exposure events will be fired.

     Parameters:
     - layerName: The name of the layer setup on console.statsig.com
     - keepDeviceValue: Locks layer values to the first time they are received. If an layer values change, but the user has already been exposed, the original values are returned. This is not common practice.

     SeeAlso [Layers Documentation](https://docs.statsig.com/layers)
     */
    public func getLayerWithExposureLoggingDisabled(_ layerName: String, keepDeviceValue: Bool = false) -> Layer {
        logger.incrementNonExposedCheck(layerName)
        let layer = store.getLayer(client: nil, forName: layerName, keepDeviceValue: keepDeviceValue)
        if let cb = statsigOptions.evaluationCallback {
            cb(.layer(layer))
        }
        return layer
    }

    /**
     Logs an exposure event for the given layer parameter. Only required if a related getLayerWithExposureLoggingDisabled call has been made.

     Parameters:
     - layerName: The name of the layer setup on console.statsig.com
     - parameterName: The name of the parameter that was checked.
     */
    public func manuallyLogLayerParameterExposure(_ layerName: String, _ parameterName: String, keepDeviceValue: Bool = false) {
        let layer = getLayer(layerName, keepDeviceValue: keepDeviceValue)
        logLayerParameterExposureForLayer(layer, parameterName: parameterName, isManualExposure: true)
    }

    internal func logLayerParameterExposureForLayer(_ layer: Layer, parameterName: String, isManualExposure: Bool) {
        var exposures = layer.undelegatedSecondaryExposures
        var allocatedExperiment = ""
        let isExplicit = layer.explicitParameters.contains(parameterName)
        if isExplicit {
            exposures = layer.secondaryExposures
            allocatedExperiment = layer.allocatedExperimentName
        }

        let dedupeKey = [
            layer.name,
            layer.ruleID,
            allocatedExperiment,
            parameterName,
            "\(isExplicit)",
            layer.evaluationDetails.getDetailedReason()
        ].joined(separator: "|")

        if shouldLogExposure(key: dedupeKey) {
            logger.log(
                Event.layerExposure(
                    user: currentUser,
                    configName: layer.name,
                    ruleID: layer.ruleID,
                    secondaryExposures: exposures,
                    disableCurrentVCLogging: statsigOptions.disableCurrentVCLogging,
                    allocatedExperimentName: allocatedExperiment,
                    parameterName: parameterName,
                    isExplicitParameter: isExplicit,
                    evalDetails: layer.evaluationDetails,
                    bootstrapMetadata: store.getBootstrapMetadata()
                )
                .withManualExposureFlag(isManualExposure))
        }
    }
}

// MARK: Parameter Stores

extension StatsigClient {
    public func getParameterStore(_ storeName: String) -> ParameterStore {
        return getParameterStoreImpl(storeName, shouldExpose: true)
    }
    
    public func getParameterStoreWithExposureLoggingDisabled(_ storeName: String) -> ParameterStore {
        return getParameterStoreImpl(storeName, shouldExpose: false)
    }
    
    private func getParameterStoreImpl(_ storeName: String, shouldExpose: Bool) -> ParameterStore {
        logger.incrementNonExposedCheck(storeName)

        var store = store.getParamStore(client: self, forName: storeName)
        
        store.shouldExpose = shouldExpose
        
        if let cb = statsigOptions.evaluationCallback {
            cb(.parameterStore(store))
        }
        
        return store
    }
    
}


// MARK: Log Event
extension StatsigClient {
    /**
     Logs an event to Statsig with the provided values.

     Parameters:
     - withName: The name of the event
     - metadata: Any extra values to be logged with the event
     */
    public func logEvent(_ withName: String, metadata: [String: String]? = nil) {
        logEventImpl(withName, value: nil, metadata: metadata)
    }

    /**
     Logs an event to Statsig with the provided values.

     Parameters:
     - withName: The name of the event
     - value: A top level value for the event
     - metadata: Any extra values to be logged with the event
     */
    public func logEvent(_ withName: String, value: String, metadata: [String: String]? = nil) {
        logEventImpl(withName, value: value, metadata: metadata)
    }

    /**
     Logs an event to Statsig with the provided values.

     Parameters:
     - withName: The name of the event
     - value: A top level value for the event
     - metadata: Any extra key/value pairs to be logged with the event
     */
    public func logEvent(_ withName: String, value: Double, metadata: [String: String]? = nil) {
        logEventImpl(withName, value: value, metadata: metadata)
    }


    private func logEventImpl(_ withName: String, value: Any? = nil, metadata: [String: String]? = nil) {
        var eventName = withName

        if eventName.isEmpty {
            print("[Statsig]: Must log with a non-empty event name.")
            return
        }
        if eventName.count > maxEventNameLength {
            print("[Statsig]: Event name is too long. Trimming to \(maxEventNameLength).")
            eventName = String(eventName.prefix(maxEventNameLength))
        }
        if let metadata = metadata, !JSONSerialization.isValidJSONObject(metadata) {
            print("[Statsig]: metadata is not a valid JSON object. Event is logged without metadata.")
            logger.log(
                Event(
                    user: currentUser,
                    name: eventName,
                    value: value,
                    metadata: nil,
                    disableCurrentVCLogging: statsigOptions.disableCurrentVCLogging)
            )
            return
        }

        logger.log(
            Event(
                user: currentUser,
                name: eventName,
                value: value,
                metadata: metadata,
                disableCurrentVCLogging: statsigOptions.disableCurrentVCLogging)
        )
    }
}

// MARK: Local Overrides
extension StatsigClient {
    /**
     Sets a value to be returned for the given gate instead of the actual evaluated value.

     Parameters:
     - gateName: The name of the gate to be overridden
     - value: The value that will be returned
     */
    public func overrideGate(_ gateName: String, value: Bool) {
        store.overrideGate(gateName, value)
    }

    /**
     Sets a value to be returned for the given dynamic config/experiment instead of the actual evaluated value.

     Parameters:
     - configName: The name of the config or experiment to be overridden
     - value: The value that the resulting DynamicConfig will contain
     */
    public func overrideConfig(_ configName: String, value: [String: Any]) {
        store.overrideConfig(configName, value)
    }

    /**
     Sets a value to be returned for the given layer instead of the actual evaluated value.

     Parameters:
     - layerName: The name of the layer to be overridden
     - value: The value that the resulting Layer will contain
     */
    public func overrideLayer(_ layerName: String, value: [String: Any]) {
        store.overrideLayer(layerName, value)
    }

    /**
     Clears any overridden value for the given gate/dynamic config/experiment.

     Parameters:
     - name: The name of the gate/dynamic config/experiment to clear
     */
    public func removeOverride(_ name: String) {
        store.removeOverride(name)
    }

    /**
     Clears all overriden values.
     */
    public func removeAllOverrides() {
        store.removeAllOverrides()
    }

    /**
     Returns all values that are currently overriden.
     */
    public func getAllOverrides() -> StatsigOverrides {
        return store.getAllOverrides()
    }
}


// MARK: Misc Private
extension StatsigClient {
    private func fetchValuesFromNetwork(completion: ResultCompletionBlock?) {
        let currentUser = self.currentUser
        Diagnostics.mark?.initialize.storeRead.start()
        let sinceTime = self.store.getLastUpdateTime(user: currentUser)
        let previousDerivedFields = self.store.getPreviousDerivedFields(user: currentUser)
        let fullChecksum = self.store.getFullChecksum(user: currentUser)
        Diagnostics.mark?.initialize.storeRead.end(success: true)

        networkService.fetchInitialValues(for: currentUser, sinceTime: sinceTime, previousDerivedFields: previousDerivedFields, fullChecksum: fullChecksum) { [weak self] error in
            if let self = self {
                if let error = error {
                    self.logger.log(Event.statsigInternalEvent(
                        user: self.currentUser,
                        name: "fetch_values_failed",
                        value: nil,
                        metadata: ["error": error.message]))
                }
            }

            completion?(error)
        }
    }

    private func scheduleRepeatingSync() {
        syncTimer?.invalidate()

        let timer = Timer(
            timeInterval: self.statsigOptions.autoValueUpdateIntervalSec,
            repeats: true,
            block: { [weak self] _ in
            self?.syncValuesForCurrentUser()
        })
        syncTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    private func syncValuesForCurrentUser() {
        let sinceTime = self.store.getLastUpdateTime(user: currentUser)
        let previousDerivedFields = self.store.getPreviousDerivedFields(user: currentUser)
        let fullChecksum = self.store.getFullChecksum(user: currentUser)

        self.networkService.fetchUpdatedValues(
            for: currentUser,
            lastSyncTimeForUser: sinceTime,
            previousDerivedFields: previousDerivedFields,
            fullChecksum: fullChecksum) { [weak self] error in
                self?.notifyOnUserUpdatedListeners(error)
            }
    }

    private static func normalizeUser(_ user: StatsigUser?, options: StatsigOptions?) -> StatsigUser {
        var normalized = user ?? StatsigUser()
        if let validationCallback = options?.userValidationCallback {
            normalized = validationCallback(normalized)
        }
        normalized.statsigEnvironment = options?.environment ?? [:]
        if let stableID = options?.overrideStableID {
            normalized.setStableID(stableID)
        }
        return normalized
    }

    private func shouldLogExposure(key: String) -> Bool {
        return exposureDedupeQueue.sync { () -> Bool in
            let now = Date().timeIntervalSince1970
            if let lastTime = loggedExposures[key], lastTime >= now - 600 {
                // if the last time the exposure was logged was less than 10 mins ago, do not log exposure
                return false
            }

            exposureDedupeQueue.async(flags: .barrier) { [weak self] in
                self?.loggedExposures[key] = now
            }
            return true
        }
    }

    private func updateUserImpl(_ user: StatsigUser, values: [String: Any]? = nil, completion: ResultCompletionBlock? = nil) {
        currentUser = StatsigClient.normalizeUser(user, options: statsigOptions)
        store.updateUser(currentUser, values: values)
        logger.user = currentUser
        
        if values != nil {
            completion?(nil)
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.fetchValuesFromNetwork { [weak self, completion] error in
                guard let self = self else {
                    return
                }
                
                if self.statsigOptions.enableAutoValueUpdate {
                    self.scheduleRepeatingSync()
                }
                
                self.notifyOnUserUpdatedListeners(error)
                completion?(error)
            }
        }
    }

    private func notifyOnInitializedListeners(_ error: StatsigClientError?) {
        for getter in listeners {
            if let listener = getter() {
                listener.onInitializedWithResult?(error)
                // We use this cast to work around a deprecation warning we added on `onInitialized`
                (listener as StatsigListeningInternal).onInitialized?(error?.message)
            }
        }
    }

    private func notifyOnUserUpdatedListeners(_ error: StatsigClientError?) {
        for getter in listeners {
            if let listener = getter() {
                listener.onUserUpdatedWithResult?(error)
                // We use this cast to work around a deprecation warning we added on `onUserUpdated`
                (listener as StatsigListeningInternal).onUserUpdated?(error?.message)
            }
        }
    }
}

// MARK: Deprecated
extension StatsigClient {
    /**
     Switches the user and pulls new values for that user from Statsig.
     Default values will be returned until the update is complete.

     Parameters:
     - user: The new user
     - completion: A callback block called when the new values have been received. May be called with an error message string if the fetch fails.
     */
    @available(*, deprecated, message: "Use `StatsigClient.updateUserWithResult` instead")
    public func updateUser(_ user: StatsigUser, values: [String: Any]? = nil, completion: completionBlock = nil) {
        exposureDedupeQueue.async(flags: .barrier) { [weak self] in
            self?.loggedExposures.removeAll()
        }

        self.updateUserImpl(user, values: values) { error in 
            completion?(error?.message)
        }
    }
    
    /**
     Manually triggered the refreshing process for the current user

     Parameters:
     - completion: A callback block called when the new values/update operation have been received. May be called with an error message string if the fetch fails.
     */
    @available(*, deprecated, message: "Use `StatsigClient.refreshCacheWithResult` instead")
    public func refreshCache(_ completion: completionBlock = nil) {
        self.updateUser(self.currentUser, completion: completion)
    }
}

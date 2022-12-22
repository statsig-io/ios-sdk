import UIKit

internal class StatsigClient {
    private static let exposureDedupeQueueLabel = "com.Statsig.exposureDedupeQueue"

    internal static var autoValueUpdateTime = 10.0

    internal var logger: EventLogger
    private var sdkKey: String
    private var currentUser: StatsigUser
    private var statsigOptions: StatsigOptions
    private var store: InternalStore
    private var networkService: NetworkService
    private var syncTimer: Timer?
    private var loggedExposures: [String: TimeInterval]
    private var listeners: [() -> StatsigListening?] = []
    private var hasInitialized: Bool = false
    private var lastInitializeError: String?
    private var crashReporter: CrashReporter?

    private let exposureDedupeQueue = DispatchQueue(label: exposureDedupeQueueLabel, qos: .userInitiated, attributes: .concurrent)

    let maxEventNameLength = 64

    internal init(sdkKey: String, user: StatsigUser?, options: StatsigOptions?, completion: completionBlock) {
        self.sdkKey = sdkKey
        self.currentUser = StatsigClient.normalizeUser(user, options: options)
        self.statsigOptions = options ?? StatsigOptions()
        self.store = InternalStore(self.currentUser)
        self.networkService = NetworkService(sdkKey: sdkKey, options: statsigOptions, store: store)
        self.logger = EventLogger(user: currentUser, networkService: networkService)
        self.logger.start()
        self.loggedExposures = [String: TimeInterval]()
        self.crashReporter = CrashReporter()

        fetchAndScheduleSyncing { [weak self] errorMessage in
            self?.lastInitializeError = errorMessage
            self?.hasInitialized = true
            self?.notifyOnInitializedListeners(errorMessage)
            completion?(errorMessage)
        }

        subscribeToApplicationLifecycle()
    }

    internal func isInitialized() -> Bool {
        return hasInitialized
    }

    internal func addListener(_ listener: StatsigListening) {
        if (hasInitialized) {
            listener.onInitialized(lastInitializeError)
        }
        listeners.append({ [weak listener] in return listener })
    }

    internal func checkGate(_ gateName: String) -> Bool {
        let gate = store.checkGate(forName: gateName)

        logGateExposure(gateName, gate: gate)

        return gate.value
    }

    internal func logGateExposure(_ gateName: String, gate: FeatureGate? = nil) {
        let isManualExposure = gate == nil
        let gate = gate ?? store.checkGate(forName: gateName)
        let gateValue = gate.value
        let ruleID = gate.ruleID
        let dedupeKey = gateName + (gateValue ? "true" : "false") + ruleID + gate.evaluationDetails.reason.rawValue


        if shouldLogExposure(key: dedupeKey) {
            logger.log(
                Event.gateExposure(
                    user: currentUser,
                    gateName: gateName,
                    gateValue: gateValue,
                    ruleID: ruleID,
                    secondaryExposures: gate.secondaryExposures,
                    evalDetails: gate.evaluationDetails,
                    disableCurrentVCLogging: statsigOptions.disableCurrentVCLogging)
                .withManualExposureFlag(isManualExposure))
        }
    }

    internal func checkGateWithExposureLoggingDisabled(_ gateName: String) -> Bool {
        return store.checkGate(forName: gateName).value
    }

    internal func getExperiment(_ experimentName: String, keepDeviceValue: Bool = false) -> DynamicConfig {
        let experiment = store.getExperiment(forName: experimentName, keepDeviceValue: keepDeviceValue)

        logExperimentExposure(experimentName, keepDeviceValue: keepDeviceValue, experiment: experiment)

        return experiment
    }

    internal func getExperimentWithExposureLoggingDisabled(_ experimentName: String, keepDeviceValue: Bool = false) -> DynamicConfig {
        return store.getExperiment(forName: experimentName, keepDeviceValue: keepDeviceValue)
    }

    internal func logExperimentExposure(_ experimentName: String, keepDeviceValue: Bool, experiment: DynamicConfig? = nil) {
        let isManualExposure = experiment == nil
        let experiment = experiment ?? store.getExperiment(forName: experimentName, keepDeviceValue: keepDeviceValue)
       logConfigExposureForConfig(experimentName, config: experiment, isManualExposure: isManualExposure)
    }

    internal func getConfig(_ configName: String) -> DynamicConfig {
        let config = store.getConfig(forName: configName)

        logConfigExposure(configName, config: config)

        return config
    }

    internal func getConfigWithExposureLoggingDisabled(_ configName: String) -> DynamicConfig {
        return store.getConfig(forName: configName)
    }

    internal func logConfigExposure(_ configName: String, config: DynamicConfig? = nil) {
        let isManualExposure = config == nil
        let config = config ?? store.getConfig(forName: configName)
        logConfigExposureForConfig(configName, config: config, isManualExposure: isManualExposure)
    }

    internal func logConfigExposureForConfig(_ configName: String, config: DynamicConfig, isManualExposure: Bool) {
        let ruleID = config.ruleID
        let dedupeKey = configName + ruleID + config.evaluationDetails.reason.rawValue
        if shouldLogExposure(key: dedupeKey) {
            logger.log(
                Event.configExposure(
                    user: currentUser,
                    configName: configName,
                    ruleID: config.ruleID,
                    secondaryExposures: config.secondaryExposures,
                    evalDetails: config.evaluationDetails,
                    disableCurrentVCLogging: statsigOptions.disableCurrentVCLogging)
                .withManualExposureFlag(isManualExposure))
        }
    }

    internal func getLayer(_ layerName: String, keepDeviceValue: Bool = false) -> Layer {
        return store.getLayer(client: self, forName: layerName, keepDeviceValue: keepDeviceValue)
    }

    internal func getLayerWithExposureLoggingDisabled(_ layerName: String, keepDeviceValue: Bool = false) -> Layer {
        return store.getLayer(client: nil, forName: layerName, keepDeviceValue: keepDeviceValue)
    }


    internal func logLayerParameterExposure(_ layerName: String, parameterName: String, keepDeviceValue: Bool) {
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
            layer.evaluationDetails.reason.rawValue
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
                    evalDetails: layer.evaluationDetails
                )
                .withManualExposureFlag(isManualExposure))
        }
    }

    internal func updateUser(_ user: StatsigUser, completion: completionBlock = nil) {
        exposureDedupeQueue.async(flags: .barrier) { [weak self] in
            self?.loggedExposures.removeAll()
        }

        DispatchQueue.main.async { [weak self] in
            self?.updateUserImpl(user, completion: completion)
        }
    }

    internal func shutdown() {
        logger.stop()
        syncTimer?.invalidate()
    }

    internal func getStableID() -> String? {
        return currentUser.deviceEnvironment["stableID"] as? String
    }

    internal func overrideGate(_ gateName: String, value: Bool) {
        store.overrideGate(gateName, value)
    }

    internal func overrideConfig(_ configName: String, value: [String: Any]) {
        store.overrideConfig(configName, value)
    }

    internal func overrideLayer(_ layerName: String, value: [String: Any]) {
        store.overrideLayer(layerName, value)
    }

    internal func removeOverride(_ name: String) {
        store.removeOverride(name)
    }

    internal func removeAllOverrides() {
        store.removeAllOverrides()
    }

    internal func getAllOverrides() -> StatsigOverrides {
        return store.getAllOverrides()
    }

    internal func logEvent(_ withName: String, value: Any? = nil, metadata: [String: String]? = nil) {
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

    private func fetchAndScheduleSyncing(completion: completionBlock) {
        syncTimer?.invalidate()

        let currentUser = self.currentUser
        let shouldScheduleSync = statsigOptions.enableAutoValueUpdate
        networkService.fetchInitialValues(for: currentUser) { [weak self] errorMessage in
            if let self = self {
                if let errorMessage = errorMessage {
                    self.logger.log(Event.statsigInternalEvent(
                        user: self.currentUser,
                        name: "fetch_values_failed",
                        value: nil,
                        metadata: ["error": errorMessage]))
                }
                if shouldScheduleSync {
                    self.scheduleRepeatingSync()
                }
            }

            completion?(errorMessage)
        }
    }

    private func scheduleRepeatingSync() {
        let currentUser = self.currentUser
        syncTimer = Timer.scheduledTimer(withTimeInterval: StatsigClient.autoValueUpdateTime, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.networkService.fetchUpdatedValues(for: currentUser, since: self.store.updatedTime)
                { [weak self] in
                    self?.scheduleRepeatingSync()
                }
        }
    }

    private static func normalizeUser(_ user: StatsigUser?, options: StatsigOptions?) -> StatsigUser {
        var normalized = user ?? StatsigUser()
        normalized.statsigEnvironment = options?.environment ?? [:]
        if let stableID = options?.overrideStableID {
            normalized.setStableID(stableID)
        }
        return normalized
    }

    private func shouldLogExposure(key: String) -> Bool {
        return exposureDedupeQueue.sync { () -> Bool in
            let now = NSDate().timeIntervalSince1970
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

    private func updateUserImpl(_ user: StatsigUser, completion: completionBlock = nil) {
        currentUser = StatsigClient.normalizeUser(user, options: statsigOptions)
        store.updateUser(currentUser)
        logger.user = currentUser
        fetchAndScheduleSyncing { [weak self] errorMessage in
            self?.notifyOnUserUpdatedListeners(errorMessage)
            completion?(errorMessage)
        }
    }

    private func notifyOnInitializedListeners(_ error: String?) {
        for listener in listeners {
            listener()?.onInitialized(error)
        }
    }

    private func notifyOnUserUpdatedListeners(_ error: String?) {
        for listener in listeners {
            listener()?.onUserUpdated(error)
        }
    }

    deinit {
        unsubscribeFromApplicationLifecycle()
    }
}

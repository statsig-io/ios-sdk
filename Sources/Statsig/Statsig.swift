import Foundation

import UIKit

public typealias completionBlock = ((_ errorMessage: String?) -> Void)?

public class Statsig {
    private static var sharedInstance: Statsig?
    private var sdkKey: String
    private var currentUser: StatsigUser
    private var statsigOptions: StatsigOptions
    private var store: InternalStore
    private var networkService: NetworkService
    private var logger: EventLogger
    private var syncTimer: Timer?

    static let maxEventNameLength = 64;
    
    public static func start(sdkKey: String, user: StatsigUser? = nil, options: StatsigOptions? = nil,
                             completion: completionBlock = nil) {
        if sharedInstance != nil {
            completion?("Statsig has already started!")
            return
        }
        if sdkKey.isEmpty || sdkKey.starts(with: "secret-") {
            completion?("Must use a valid client SDK key.")
            return
        }
        sharedInstance = Statsig(sdkKey: sdkKey, user: user, options: options, completion: completion)
    }
    
    public static func checkGate(_ gateName: String) -> Bool {
        guard let sharedInstance = sharedInstance else {
            print("[Statsig]: Must start Statsig first and wait for it to complete before calling checkGate. Returning false as the default.")
            return false
        }
        var gate = sharedInstance.store.checkGate(forName: gateName)
        if gate == nil {
            print("[Statsig]: The feature gate with name \(gateName) does not exist. Returning false as the default.")
            gate = FeatureGate(name: gateName, value: false, ruleID: "")
        }
        sharedInstance.logger.log(
            Event.gateExposure(
                user: sharedInstance.currentUser,
                gateName: gateName,
                gateValue: gate?.value ?? false,
                ruleID: gate?.ruleID ?? "",
                secondaryExposures: gate?.secondaryExposures ?? [],
                disableCurrentVCLogging: sharedInstance.statsigOptions.disableCurrentVCLogging))
        return gate?.value ?? false
    }

    public static func getExperiment(_ experimentName: String, keepDeviceValue: Bool = false) -> DynamicConfig {
        guard let sharedInstance = sharedInstance else {
            print("[Statsig]: Must start Statsig first and wait for it to complete before calling getExperiment. Returning a dummy DynamicConfig that will only return default values.")
            return DynamicConfig(configName: experimentName)
        }
        var experiment = sharedInstance.store.getExperiment(forName: experimentName, keepDeviceValue: keepDeviceValue)
        if experiment == nil {
            print("[Statsig]: The experiment with name \(experimentName) does not exist. Returning a dummy DynamicConfig that will only return default values.")
            experiment = DynamicConfig(configName: experimentName)
        }

        sharedInstance.logger.log(
            Event.configExposure(
                user: sharedInstance.currentUser,
                configName: experimentName,
                ruleID: experiment?.ruleID ?? "",
                secondaryExposures: experiment?.secondaryExposures ?? [],
                disableCurrentVCLogging: sharedInstance.statsigOptions.disableCurrentVCLogging))
        return experiment!
    }
    
    public static func getConfig(_ configName: String) -> DynamicConfig {
        guard let sharedInstance = sharedInstance else {
            print("[Statsig]: Must start Statsig first and wait for it to complete before calling getConfig. Returning a dummy DynamicConfig that will only return default values.")
            return DynamicConfig(configName: configName)
        }
        var config = sharedInstance.store.getConfig(forName: configName)
        if config == nil {
            print("[Statsig]: The config with name \(configName) does not exist. Returning a dummy DynamicConfig that will only return default values.")
            config = DynamicConfig(configName: configName)
        }

        sharedInstance.logger.log(
            Event.configExposure(
                user: sharedInstance.currentUser,
                configName: configName,
                ruleID: config?.ruleID ?? "",
                secondaryExposures: config?.secondaryExposures ?? [],
                disableCurrentVCLogging: sharedInstance.statsigOptions.disableCurrentVCLogging))
        return config!
    }

    public static func logEvent(_ withName: String, metadata: [String: String]? = nil) {
        logEventInternal(withName, value: nil, metadata: metadata)
    }

    public static func logEvent(_ withName: String, value: String, metadata: [String: String]? = nil) {
        logEventInternal(withName, value: value, metadata: metadata)
    }

    public static func logEvent(_ withName: String, value: Double, metadata: [String: String]? = nil) {
        logEventInternal(withName, value: value, metadata: metadata)
    }

    public static func updateUser(_ user: StatsigUser, completion: completionBlock = nil) {
        guard let sharedInstance = sharedInstance else {
            print("[Statsig]: Must start Statsig first and wait for it to complete before calling updateUser.")
            completion?("Must start Statsig first and wait for it to complete before calling updateUser.")
            return
        }

        if sharedInstance.currentUser.userID != user.userID {
            InternalStore.deleteStickyUserValues()
        }
        sharedInstance.currentUser = normalizeUser(user, options: sharedInstance.statsigOptions)
        sharedInstance.logger.user = sharedInstance.currentUser
        sharedInstance.fetchAndScheduleSyncing(completion: completion)
    }
    
    public static func shutdown() {
        if sharedInstance == nil {
            return
        }
        sharedInstance?.logger.flush()
        sharedInstance?.syncTimer?.invalidate()
        sharedInstance = nil
    }

    private init(sdkKey: String, user: StatsigUser?, options: StatsigOptions?, completion: completionBlock) {
        self.sdkKey = sdkKey;
        self.currentUser = Statsig.normalizeUser(user, options: options)
        self.statsigOptions = options ?? StatsigOptions();
        self.store = InternalStore()
        self.networkService = NetworkService(sdkKey: sdkKey, options: self.statsigOptions, store: store)
        self.logger = EventLogger(user: currentUser, networkService: networkService)

        fetchAndScheduleSyncing(completion: completion)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil)
    }

    private func fetchAndScheduleSyncing(completion: completionBlock) {
        syncTimer?.invalidate()

        let currentUser = self.currentUser
        let shouldScheduleSync = self.statsigOptions.enableAutoValueUpdate
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
        self.syncTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] timer in
            guard let self = self else { return }
            self.networkService.fetchUpdatedValues(for: currentUser, since: self.store.updatedTime)
            { [weak self] in
                self?.scheduleRepeatingSync()
            }
        }
    }

    private static func logEventInternal(_ withName: String, value: Any? = nil, metadata: [String: String]? = nil) {
        guard let sharedInstance = sharedInstance else {
            print("[Statsig]: Must start Statsig first and wait for it to complete before calling logEvent.")
            return
        }
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
            sharedInstance.logger.log(
                Event(
                    user: sharedInstance.currentUser,
                    name: eventName,
                    value: value,
                    metadata: nil,
                    disableCurrentVCLogging: sharedInstance.statsigOptions.disableCurrentVCLogging
                )
            )
            return
        }

        sharedInstance.logger.log(
            Event(
                user: sharedInstance.currentUser,
                name: eventName,
                value: value,
                metadata: metadata,
                disableCurrentVCLogging: sharedInstance.statsigOptions.disableCurrentVCLogging
            )
        )
    }

    private static func normalizeUser(_ user: StatsigUser?, options: StatsigOptions?) -> StatsigUser {
        var normalized = user ?? StatsigUser()
        normalized.statsigEnvironment = options?.environment ?? [:]
        return normalized
    }

    @objc private func appWillBackground() {
        logger.flush(shutdown: true)
    }

    @objc private func appWillTerminate() {
        logger.flush(shutdown: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

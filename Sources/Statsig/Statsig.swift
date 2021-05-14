import Foundation

import UIKit

public typealias completionBlock = ((_ errorMessage: String?) -> Void)?

public class Statsig {
    private static var sharedInstance: Statsig?
    private var sdkKey: String
    private var currentUser: StatsigUser
    private var statsigOptions: StatsigOptions
    private var valueStore: InternalStore
    private var networkService: NetworkService
    private var logger: EventLogger

    static let maxEventNameLength = 64;
    static var loggedExposures = Set<String>()
    
    public static func start(sdkKey: String, user: StatsigUser? = nil, options: StatsigOptions? = nil, completion: completionBlock = nil) {
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
        guard let gate = sharedInstance.valueStore.checkGate(gateName: gateName) else {
            print("[Statsig]: The feature gate with name \(gateName) does not exist. Returning false as the default.")
            return false
        }
        let exposureDedupeKey = "gate::" + gateName;
        if !loggedExposures.contains(exposureDedupeKey) {
            sharedInstance.logger.log(
                Event.gateExposure(
                    user: sharedInstance.currentUser,
                    gateName: gateName,
                    gateValue: gate.value,
                    ruleID: gate.ruleID,
                    disableCurrentVCLogging: sharedInstance.statsigOptions.disableCurrentVCLogging))
            loggedExposures.insert(exposureDedupeKey);
        }
        return gate.value
    }
    
    public static func getConfig(_ configName: String) -> DynamicConfig {
        guard let sharedInstance = sharedInstance else {
            print("[Statsig]: Must start Statsig first and wait for it to complete before calling getConfig. Returning a dummy DynamicConfig that will only return default values.")
            return DynamicConfig(configName: configName)
        }
        guard let config = sharedInstance.valueStore.getConfig(configName: configName) else {
            print("[Statsig]: The config with name \(configName) does not exist. Returning a dummy DynamicConfig that will only return default values.")
            return DynamicConfig(configName: configName)
        }
        let exposureDedupeKey = "config::" + configName;
        if (!loggedExposures.contains(exposureDedupeKey)) {
            sharedInstance.logger.log(
                Event.configExposure(
                    user: sharedInstance.currentUser,
                    configName: configName,
                    ruleID: config.ruleID,
                    disableCurrentVCLogging: sharedInstance.statsigOptions.disableCurrentVCLogging))
            loggedExposures.insert(exposureDedupeKey);
        }
        return config
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
        if sharedInstance.currentUser == user {
            completion?(nil)
            return
        }

        loggedExposures.removeAll()
        sharedInstance.currentUser = user
        sharedInstance.logger.user = user
        sharedInstance.networkService.fetchInitialValues(forUser: user) { errorMessage in
            if let errorMessage = errorMessage {
                sharedInstance.logger.log(Event.statsigInternalEvent(
                                    user: user,
                                    name: "fetch_values_failed",
                                    value: nil,
                                    metadata: ["error": errorMessage]))
            }
            completion?(errorMessage)
        }
    }
    
    public static func shutdown() {
        if sharedInstance == nil {
            return
        }
        sharedInstance?.logger.flush()
        sharedInstance = nil
    }

    private init(sdkKey: String, user: StatsigUser?, options: StatsigOptions?, completion: completionBlock) {
        self.sdkKey = sdkKey;
        self.currentUser = user ?? StatsigUser();
        self.statsigOptions = options ?? StatsigOptions();
        self.valueStore = InternalStore()
        self.networkService = NetworkService(sdkKey: sdkKey, options: self.statsigOptions, store: valueStore)
        self.logger = EventLogger(user: currentUser, networkService: networkService)
        networkService.fetchInitialValues(forUser: currentUser) { [weak self] errorMessage in
            if let errorMessage = errorMessage, let self = self {
                self.logger.log(Event.statsigInternalEvent(
                                    user: self.currentUser,
                                    name: "fetch_values_failed",
                                    value: nil,
                                    metadata: ["error": errorMessage]))
            }
            completion?(errorMessage)
        }

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

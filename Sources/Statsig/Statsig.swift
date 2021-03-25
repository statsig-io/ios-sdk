import Foundation

import UIKit

public typealias completionBlock = ((_ errorMessage: String?) -> Void)?

public class Statsig {
    private static var sharedInstance: Statsig?
    private var sdkKey: String
    private var user: StatsigUser
    private var valueStore: InternalStore
    private var networkService: StatsigNetworkService
    private var logger: EventLogger

    static let maxEventNameLength = 64;
    
    public static func start(user: StatsigUser, sdkKey: String, completion: completionBlock) {
        if sharedInstance != nil {
            completion?("Statsig has already started!")
            return
        }
        if sdkKey.isEmpty || sdkKey.starts(with: "secret-") {
            completion?("Must use a valid client SDK key.")
            return
        }
        sharedInstance = Statsig(user: user, sdkKey: sdkKey, completion: completion)
    }
    
    public static func checkGate(_ gateName: String) -> Bool {
        guard let sharedInstance = sharedInstance else {
            print("[Statsig]: Must start Statsig first before calling checkGate. Returning false as the default.")
            return false
        }
        let gateValue = sharedInstance.valueStore.checkGate(sharedInstance.user, gateName: gateName)
        sharedInstance.logger.log(
            Event.gateExposure(user: sharedInstance.user, gateName: gateName, gateValue: gateValue))
        return gateValue
    }
    
    public static func getConfig(_ configName: String) -> DynamicConfig {
        guard let sharedInstance = sharedInstance else {
            print("[Statsig]: Must start Statsig first before calling getConfig. The returning config will only return default values")
            return DynamicConfig.createDummy()
        }
        let config = sharedInstance.valueStore.getConfig(sharedInstance.user, configName: configName)
        sharedInstance.logger.log(
            Event.configExposure(user: sharedInstance.user, configName: configName, configGroup: config.group))
        return config
    }
    
    public static func logEvent(withName:String, value:Double? = nil, metadata:[String:Codable]? = nil) {
        guard let sharedInstance = sharedInstance else {
            print("[Statsig]: Must start Statsig first before calling logEvent.")
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
        if let metadata = metadata {
            if JSONSerialization.isValidJSONObject(metadata) {
                sharedInstance.logger.log(
                    Event(user: sharedInstance.user, name: eventName, value: value, metadata: metadata))
            } else {
                print("[Statsig]: metadata is not a valid JSON object. Event is logged without metadata.")
            }
        }
        sharedInstance.logger.log(
            Event(user: sharedInstance.user, name: eventName, value: value, metadata: nil))
    }
    
    public static func updateUser(_ user:StatsigUser, completion: completionBlock) {
        guard let sharedInstance = sharedInstance else {
            print("[Statsig]: Must start Statsig first before calling updateUser.")
            completion?("Must start Statsig first before calling updateUser.")
            return
        }
        if sharedInstance.user == user {
            completion?(nil)
            return
        }

        sharedInstance.user = user
        sharedInstance.logger.user = user
        sharedInstance.networkService.fetchValues(forUser: user) { errorMessage in
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
        guard let sharedInstance = sharedInstance else {
            return
        }
        sharedInstance.logger.flush()
    }

    private init(user: StatsigUser, sdkKey: String, completion: completionBlock) {
        self.sdkKey = sdkKey;
        self.user = user;
        self.valueStore = InternalStore()
        self.networkService = StatsigNetworkService(sdkKey: sdkKey, store: valueStore)
        self.logger = EventLogger(user: user, networkService: networkService)
        networkService.fetchValues(forUser: user) { [weak self] errorMessage in
            if let errorMessage = errorMessage, let self = self {
                self.logger.log(Event.statsigInternalEvent(
                                    user: self.user,
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

    @objc private func appWillBackground() {
        logger.flush()
    }

    @objc private func appWillTerminate() {
        logger.flush()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

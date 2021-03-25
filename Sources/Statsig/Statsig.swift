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
    
    public static func start(user: StatsigUser, sdkKey: String, completion: completionBlock) {
        if sharedInstance != nil {
            print("Statsig has already started!")
            return
        }
        sharedInstance = Statsig(user: user, sdkKey: sdkKey, completion: completion)
    }
    
    public static func checkGate(forName: String) -> Bool {
        guard let sharedInstance = sharedInstance else {
            print("Must start Statsig first before calling checkGate. Returning false as the default.")
            return false
        }
        let gateValue = sharedInstance.valueStore.checkGate(sharedInstance.user, gateName: forName)
        sharedInstance.logger.log(
            event: Event.gateExposure(user: sharedInstance.user, gateName: forName, gateValue: gateValue))
        return gateValue
    }
    
    public static func getConfig(forName: String) -> DynamicConfig {
        guard let sharedInstance = sharedInstance else {
            print("Must start Statsig first before calling getConfig. The returning config will only return default values")
            return DynamicConfig.createDummy()
        }
        let config = sharedInstance.valueStore.getConfig(sharedInstance.user, configName: forName)
        sharedInstance.logger.log(
            event: Event.configExposure(user: sharedInstance.user, configName: forName, configGroup: config.group))
        return config
    }
    
    public static func logEvent(withName:String, value:Double? = nil, metadata:[String:Codable]? = nil) {
        guard let sharedInstance = sharedInstance else {
            print("Must start Statsig first before calling logEvent.")
            return
        }
        if let metadata = metadata {
            if JSONSerialization.isValidJSONObject(metadata) {
                sharedInstance.logger.log(
                    event: Event(user: sharedInstance.user, name: withName, value: value, metadata: metadata))
            } else {
                print("metadata is not a valid JSON object. Event is logged without metadata.")
            }
        }
        sharedInstance.logger.log(
            event: Event(user: sharedInstance.user, name: withName, value: value, metadata: nil))
    }
    
    public static func updateUser(_ user:StatsigUser, completion: completionBlock) {
        guard let sharedInstance = sharedInstance else {
            print("Must start Statsig first before calling updateUser.")
            completion?("Must start Statsig first before calling updateUser.")
            return
        }
        if sharedInstance.user == user {
            print("Calling updateUser with the same user, no-op.")
            completion?(nil)
            return
        }

        sharedInstance.user = user
        sharedInstance.networkService.user = user
        sharedInstance.networkService.fetchValues(completion: completion)
        sharedInstance.networkService.fetchValues { errorMessage in
            if let errorMessage = errorMessage {
                sharedInstance.logger.log(event: Event.statsigInternalEvent(
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
        self.networkService = StatsigNetworkService(sdkKey: sdkKey, user: user, store: valueStore)
        self.logger = EventLogger(networkService: networkService)
        networkService.fetchValues { [weak self] errorMessage in
            if let errorMessage = errorMessage, let self = self {
                self.logger.log(event: Event.statsigInternalEvent(
                                    user: user,
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
        NotificationCenter.default.removeObserver(self)
    }
}

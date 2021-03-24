import Foundation

import UIKit

// TODOs:
// switch/update user
// add logevent API
// add init timeout
// add value synchronizer

public typealias completionBlock = ((_ errorMessage: String?
) -> Void)?

public class Statsig {
    private static var sharedInstance: Statsig?
    private var sdkKey: String
    private var user: StatsigUser
    private var valueStore: InternalStore
    private var networkService: StatsigNetworkService
    private var logger: EventLogger
    
    public static func start(user: StatsigUser, sdkKey: String, completion: completionBlock) {
        if sharedInstance != nil {
            NSLog("Statsig has already started!")
            return
        }
        sharedInstance = Statsig(user: user, sdkKey: sdkKey, completion: completion)
    }
    
    public static func get() -> Statsig? {
        return sharedInstance
    }
    
    public static func checkGate(forName: String) -> Bool {
        guard let sharedInstance = sharedInstance else {
            NSLog("Must start Statsig first before calling checkGate.")
            return false
        }
        return sharedInstance.valueStore.checkGate(sharedInstance.user, gateName: forName)
    }
    
    public static func getConfig(forName: String) -> DynamicConfig? {
        guard let sharedInstance = sharedInstance else {
            NSLog("Must start Statsig first before calling getConfig.")
            return nil
        }
        return sharedInstance.valueStore.getConfig(sharedInstance.user, configName: forName)
    }
    
    public static func logEvent(withName:String, value:Double? = nil, metadata:[String:Codable]? = nil) {
        guard let sharedInstance = sharedInstance else {
            NSLog("Must start Statsig first before calling logEvent.")
            return
        }
        sharedInstance.logger.log(event: Event(name: withName, value: value, metadata: metadata))
    }
    
    public static func updateUser(_ user:StatsigUser) {
        guard let sharedInstance = sharedInstance else {
            NSLog("Must start Statsig first before calling updateUser.")
            return
        }
        if sharedInstance.user == user {
            NSLog("Calling updateUser with the same user, no-op.")
            return
        }
        if sharedInstance.user.userID == user.userID {
            // TODO: update different fields
        } else {
            // TODO: update the whole user and refetch values
        }
    }
    
    public static func shutdown() {
        // TODO: anything else?
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
        networkService.fetchValues(completion: completion)
        
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
        NSLog("app will background")
        logger.flush()
    }
    
    @objc private func appWillTerminate() {
        NSLog("app will terminate")
        logger.flush()
        NotificationCenter.default.removeObserver(self)
    }
}

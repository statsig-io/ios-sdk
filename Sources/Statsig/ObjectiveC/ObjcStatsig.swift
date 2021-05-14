import Foundation

@objc(Statsig)
public final class ObjcStatsig : NSObject {
    @objc public static func start(withSDKKey: String) {
        Statsig.start(sdkKey: withSDKKey)
    }

    @objc public static func start(withSDKKey: String, user: ObjcStatsigUser) {
        Statsig.start(sdkKey: withSDKKey, user: user.user)
    }

    @objc public static func start(withSDKKey: String, options: StatsigOptions) {
        Statsig.start(sdkKey: withSDKKey, options: options)
    }

    @objc public static func start(withSDKKey: String, completion: completionBlock) {
        Statsig.start(sdkKey: withSDKKey, completion: completion)
    }

    @objc public static func start(withSDKKey: String, user: ObjcStatsigUser, completion: completionBlock) {
        Statsig.start(sdkKey: withSDKKey, user: user.user, completion: completion)
    }

    @objc public static func start(withSDKKey: String, user: ObjcStatsigUser, options: StatsigOptions) {
        Statsig.start(sdkKey: withSDKKey, user: user.user, options: options)
    }

    @objc public static func start(withSDKKey: String, options: StatsigOptions, completion: completionBlock) {
        Statsig.start(sdkKey: withSDKKey, options: options, completion: completion)
    }

    @objc public static func start(withSDKKey: String, user: ObjcStatsigUser, options: StatsigOptions,
                                   completion: completionBlock) {
        Statsig.start(sdkKey: withSDKKey, user: user.user, options: options, completion: completion)
    }

    @objc public static func checkGate(forName: String) -> Bool {
        return Statsig.checkGate(forName)
    }

    @objc public static func getConfig(forName: String) -> ObjcStatsigDynamicConfig {
        return ObjcStatsigDynamicConfig(withConfig: Statsig.getConfig(forName))
    }

    @objc public static func logEvent(_ withName: String) {
        Statsig.logEvent(withName)
    }

    @objc public static func logEvent(_ withName: String, stringValue: String) {
        Statsig.logEvent(withName, value: stringValue)
    }

    @objc public static func logEvent(_ withName: String, doubleValue: Double) {
        Statsig.logEvent(withName, value: doubleValue)
    }

    @objc public static func logEvent(_ withName: String, metadata: [String: String]) {
        Statsig.logEvent(withName, metadata: metadata)
    }

    @objc public static func logEvent(_ withName: String, stringValue: String, metadata: [String: String]) {
        Statsig.logEvent(withName, value: stringValue, metadata: metadata)
    }

    @objc public static func logEvent(_ withName: String, doubleValue: Double, metadata: [String: String]) {
        Statsig.logEvent(withName, value: doubleValue, metadata: metadata)
    }

    @objc public static func updateUser(newUser: ObjcStatsigUser) {
        Statsig.updateUser(newUser.user, completion: nil)
    }

    @objc public static func updateUser(newUser: ObjcStatsigUser, completion: completionBlock) {
        Statsig.updateUser(newUser.user, completion: completion)
    }

    @objc public static func shutdown() {
        Statsig.shutdown()
    }
}

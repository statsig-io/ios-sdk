import Foundation

@objc(Statsig)
public final class ObjcStatsig : NSObject {
    @objc public static func start(sdkKey: String, user: ObjcStatsigUser? = nil, completion: completionBlock = nil) {
        Statsig.start(sdkKey: sdkKey, user: user?.user, completion: completion)
    }

    @objc public static func checkGate(forName: String) -> Bool {
        return Statsig.checkGate(forName)
    }

    @objc public static func getConfig(forName: String) -> ObjcStatsigDynamicConfig {
        let dc = Statsig.getConfig(forName)
        return ObjcStatsigDynamicConfig(withConfig: dc)
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

    @objc public static func updateUser(newUser: ObjcStatsigUser, completion: completionBlock) {
        Statsig.updateUser(newUser.user, completion: completion)
    }

    @objc public static func shutdown() {
        Statsig.shutdown()
    }
}

import Foundation


struct DeviceEnvironment {
    private let stableIDKey = "com.Statsig.InternalStore.stableIDKey"

    var deviceOS: String = "iOS"
    var sdkType: String = "ios-client"
    var sdkVersion: String = "1.23.0"
    var sessionID: String? { UUID().uuidString }
    var systemVersion: String { PlatformCompatibility.deviceInfo.systemVersion }
    var systemName: String { PlatformCompatibility.deviceInfo.systemName }
    var language: String { Locale.preferredLanguages[0] }
    var locale: String { Locale.current.identifier }
    var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    var appIdentifier = Bundle.main.bundleIdentifier

    var deviceModel: String {
        if let simulatorModelIdentifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModelIdentifier
        }
        var sysinfo = utsname()
        uname(&sysinfo)
        if let deviceModel = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii) {
            return deviceModel.trimmingCharacters(in: .controlCharacters)
        } else {
            return PlatformCompatibility.deviceInfo.model
        }
    }

    func getStableID(_ overrideStableID: String? = nil) -> String {
        let stableID = overrideStableID ?? StatsigUserDefaults.defaults.string(forKey: stableIDKey) ?? UUID().uuidString
        StatsigUserDefaults.defaults.setValue(stableID, forKey: stableIDKey)
        return stableID
    }

    func get(_ overrideStableID: String? = nil) -> [String: String?] {
        return [
            "appIdentifier": appIdentifier,
            "appVersion": appVersion,
            "deviceModel": deviceModel,
            "deviceOS": deviceOS,
            "language": language,
            "locale": locale,
            "sdkType": sdkType,
            "sdkVersion": sdkVersion,
            "sessionID": sessionID,
            "stableID": getStableID(overrideStableID),
            "systemVersion": systemVersion,
            "systemName": systemName
        ]
    }

    func explicitGet(_ overrideStableID: String? = nil) -> [String: String] {
        return get(overrideStableID).mapValues { val in
            return val ?? ""
        }
    }
}

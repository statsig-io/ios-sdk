import Foundation


struct DeviceEnvironment {
    private let stableIDKey = "com.Statsig.InternalStore.stableIDKey"

    var deviceOS: String = "iOS"
    var sdkType: String = "ios-client"
    var sdkVersion: String = "1.13.2"
    var sessionID: String? { UUID().uuidString }
    var systemVersion: String = SystemInfo.version
    var systemName: String = SystemInfo.name
    var language: String { Locale.preferredLanguages[0] }
    var locale: String { Locale.current.identifier }
    var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    var appIdentifier = Bundle.main.bundleIdentifier
    var deviceModel = SystemInfo.model

    func getStableID(_ overrideStableID: String? = nil) -> String {
        let stableID = overrideStableID ?? UserDefaults.standard.string(forKey: stableIDKey) ?? UUID().uuidString
        UserDefaults.standard.setValue(stableID, forKey: stableIDKey)
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

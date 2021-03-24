import Foundation

import UIKit

struct DeviceEnvironment: Codable {
    var deviceOS: String = "iOS"
    var sdkVersion: String = "1.0.0"
    var deviceID: String? { UIDevice.current.identifierForVendor?.uuidString }
    var sessionID: String? { UUID().uuidString }
    var systemVersion: String { UIDevice.current.systemVersion }
    var systemName: String { UIDevice.current.systemName }
    var language: String { Locale.preferredLanguages[0] }
    var locale: String { Locale.current.identifier }
    var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

    var deviceModel: String {
        if let simulatorModelIdentifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModelIdentifier
        }
        var sysinfo = utsname()
        uname(&sysinfo)
        if let deviceModel = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii) {
            return deviceModel.trimmingCharacters(in: .controlCharacters)
        } else {
            return UIDevice.current.model
        }
    }
    
    func toDictionary() -> [String:String?] {
        return [
            "appVersion": appVersion,
            "deviceID": deviceID,
            "deviceMode": deviceModel,
            "deviceOS": deviceOS,
            "language": language,
            "locale": locale,
            "sdkVersion": sdkVersion,
            "sessionID": sessionID,
            "systemVersion": systemVersion,
            "systemName": systemName
        ]
    }
}

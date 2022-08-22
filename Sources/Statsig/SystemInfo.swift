#if os(macOS)
import Foundation
import AppKit

class SystemInfo {
    static let version = ProcessInfo.processInfo.operatingSystemVersionString
    static let name = "macOS"
    static var model: String {
        let service = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                  IOServiceMatching("IOPlatformExpertDevice"))
        var modelIdentifier: String?
        if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
            modelIdentifier = String(data: modelData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
        }

        IOObjectRelease(service)
        return modelIdentifier ?? "UKNOWN"
    }

    static func getCurrentViewController() -> NSViewController? {
        return NSApplication.shared.keyWindow?.contentViewController
    }
}

#else

import UIKit

class SystemInfo {
    static let version = UIDevice.current.systemVersion
    static let name = UIDevice.current.systemName
    static var model: String {
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

    static func getCurrentViewController() -> UIViewController? {
        return UIApplication.shared.keyWindow?.rootViewController
    }
}

#endif

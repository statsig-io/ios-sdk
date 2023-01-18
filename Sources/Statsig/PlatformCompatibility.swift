import Foundation

#if canImport(UIKit)
import UIKit

struct DeviceInfo {
    let systemVersion = UIDevice.current.systemVersion
    let systemName = UIDevice.current.systemName
    let model = UIDevice.current.model
}

class PlatformCompatibility
{
    static let willResignActiveNotification = UIApplication.willResignActiveNotification
    static let willTerminateNotification = UIApplication.willTerminateNotification
    static let willEnterForegroundNotification = UIApplication.willEnterForegroundNotification

    static let deviceInfo = DeviceInfo()

    static func getRootViewControllerClassName(_ callback: @escaping (_ name: String?) -> Void) {
        DispatchQueue.main.async { [callback] in
            if let klass = UIApplication.shared.keyWindow?.rootViewController?.classForCoder {
                callback("\(klass)")
            } else {
                callback(nil)
            }
        }
    }
}

#else
import AppKit
import IOKit

struct DeviceInfo {
    let systemVersion: String
    let systemName = "macOS"
    let model: String

    init() {
        let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        if let data = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
            model = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) ?? "Unknown"
        } else {
            model = "Unknown"
        }

        IOObjectRelease(service)

        let version = ProcessInfo.processInfo.operatingSystemVersion
        systemVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}

class PlatformCompatibility
{
    static let willResignActiveNotification = NSApplication.willResignActiveNotification
    static let willTerminateNotification = NSApplication.willTerminateNotification
    static let willEnterForegroundNotification = NSApplication.willBecomeActiveNotification

    static let deviceInfo = DeviceInfo()

    static func getRootViewControllerClassName(_ callback: @escaping (_ name: String?) -> Void) {
        DispatchQueue.main.async { [callback] in
            if let klass = NSApplication.shared.keyWindow?.contentViewController?.classForCoder {
                callback("\(klass)")
            } else {
                callback(nil)
            }
        }
    }
}

#endif



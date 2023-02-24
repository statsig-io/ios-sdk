import Foundation


#if TEST

struct DeviceInfo {
    let systemVersion = "test.system.version"
    let systemName = "test_system"
    let model = "test_model"
}

class PlatformCompatibility
{
    static let willResignActiveNotification = NSNotification.Name(rawValue: "test.willResignActiveNotification")
    static let willTerminateNotification = NSNotification.Name(rawValue:"test.willTerminateNotification")
    static let willEnterForegroundNotification = NSNotification.Name(rawValue:"test.willEnterForegroundNotification")

    static let deviceInfo = DeviceInfo()

    static func getRootViewControllerClassName(_ callback: @escaping (_ name: String?) -> Void) {
        callback(nil)
    }
}

#elseif canImport(UIKit)

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

#elseif canImport(AppKit)
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

#else

// No PlatformCompatibility (Won't Compile)

#endif



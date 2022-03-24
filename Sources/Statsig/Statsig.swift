import Foundation

import UIKit

public typealias completionBlock = ((_ errorMessage: String?) -> Void)?

public class Statsig {
    private static var client: StatsigClient?

    public static func start(sdkKey: String, user: StatsigUser? = nil, options: StatsigOptions? = nil,
                             completion: completionBlock = nil)
    {
        if client != nil {
            completion?("Statsig has already started!")
            return
        }
        if sdkKey.isEmpty || sdkKey.starts(with: "secret-") {
            completion?("Must use a valid client SDK key.")
            return
        }
        client = StatsigClient(sdkKey: sdkKey, user: user, options: options, completion: completion)
    }

    public static func checkGate(_ gateName: String) -> Bool {
        guard let client = client else {
            print("[Statsig]: Must start Statsig first and wait for it to complete before calling checkGate. Returning false as the default.")
            return false
        }

        return client.checkGate(gateName)
    }

    public static func getExperiment(_ experimentName: String, keepDeviceValue: Bool = false) -> DynamicConfig {
        guard let client = client else {
            return getDummyConfig(experimentName, #function)
        }

        return client.getExperiment(experimentName, keepDeviceValue: keepDeviceValue)
    }

    public static func getConfig(_ configName: String) -> DynamicConfig {
        guard let client = client else {
            return getDummyConfig(configName, #function)
        }

        return client.getConfig(configName)
    }

    public static func getLayer(_ layerName: String, keepDeviceValue: Bool = false) -> Layer {
        guard let client = client else {
            print("[Statsig]: Must start Statsig first and wait for it to complete before calling getLayer. Returning an empty Layer object")
            return Layer(name: layerName)
        }

        return client.getLayer(layerName, keepDeviceValue: keepDeviceValue)
    }


    public static func logEvent(_ withName: String, metadata: [String: String]? = nil) {
        logEventImpl(withName, value: nil, metadata: metadata)
    }

    public static func logEvent(_ withName: String, value: String, metadata: [String: String]? = nil) {
        logEventImpl(withName, value: value, metadata: metadata)
    }

    public static func logEvent(_ withName: String, value: Double, metadata: [String: String]? = nil) {
        logEventImpl(withName, value: value, metadata: metadata)
    }

    public static func updateUser(_ user: StatsigUser, completion: completionBlock = nil) {
        guard let client = client else {
            print("[Statsig]: Must start Statsig first and wait for it to complete before calling updateUser.")
            completion?("Must start Statsig first and wait for it to complete before calling updateUser.")
            return
        }

        client.updateUser(user, completion: completion)
    }

    public static func shutdown() {
        client?.shutdown()
        client = nil
    }

    public static func getStableID() -> String? {
        return client?.getStableID()
    }

    public static func overrideGate(_ gateName: String, value: Bool) {
        client?.overrideGate(gateName, value: value)
    }

    public static func overrideConfig(_ configName: String, value: [String: Any]) {
        client?.overrideConfig(configName, value: value)
    }

    public static func removeOverride(_ name: String) {
        client?.removeOverride(name)
    }

    public static func removeAllOverrides() {
        client?.removeAllOverrides()
    }

    public static func getAllOverrides() -> StatsigOverrides? {
        return client?.getAllOverrides()
    }

    private static func logEventImpl(_ withName: String, value: Any? = nil, metadata: [String: String]? = nil) {
        guard let client = client else {
            print("[Statsig]: Must start Statsig first and wait for it to complete before calling logEvent.")
            return
        }

        client.logEvent(withName, value: value, metadata: metadata)
    }

    private static func getDummyConfig(_ name: String, _ caller: String) -> DynamicConfig {
        print("[Statsig]: Must start Statsig first and wait for it to complete before calling \(caller). Returning a dummy DynamicConfig that will only return default values.")
        return DynamicConfig(configName: name)
    }
}


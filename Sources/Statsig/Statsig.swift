import Foundation

import UIKit
import StatsigInternalObjC

public typealias completionBlock = ((_ errorMessage: String?) -> Void)?

public class Statsig {
    internal static var client: StatsigClient?
    internal static var errorBoundary: ErrorBoundary = ErrorBoundary()

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

        errorBoundary = ErrorBoundary(
            key: sdkKey, deviceEnvironment: DeviceEnvironment().explicitGet()
        )

        errorBoundary.capture {
            client = StatsigClient(sdkKey: sdkKey, user: user, options: options, completion: completion)
        }
    }

    public static func isInitialized() -> Bool {
        guard let client = client else {
            print("[Statsig]: Statsig.start has not been called.")
            return false
        }

        return client.isInitialized()
    }

    public static func addListener(_ listener: StatsigListening)
    {
        client?.addListener(listener)
    }

    public static func checkGate(_ gateName: String) -> Bool {
        guard let client = client else {
            print("[Statsig]: Must start Statsig first and wait for it to complete before calling checkGate. Returning false as the default.")
            return false
        }

        var result = false
        errorBoundary.capture {
            result = client.checkGate(gateName)
        }
        return result
    }

    public static func getExperiment(_ experimentName: String, keepDeviceValue: Bool = false) -> DynamicConfig {
        var result: DynamicConfig? = nil
        errorBoundary.capture {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling getExperiment. Returning a dummy DynamicConfig that will only return default values.")
                return
            }

            result = client.getExperiment(experimentName, keepDeviceValue: keepDeviceValue)
        }
        return result ?? getEmptyConfig(experimentName)
    }

    public static func getConfig(_ configName: String) -> DynamicConfig {
        var result: DynamicConfig? = nil
        errorBoundary.capture {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling getConfig. Returning a dummy DynamicConfig that will only return default values.")
                return
            }

            result = client.getConfig(configName)
        }
        return result ?? getEmptyConfig(configName)
    }

    public static func getLayer(_ layerName: String, keepDeviceValue: Bool = false) -> Layer {
        var result: Layer?
        errorBoundary.capture {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling getLayer. Returning an empty Layer object")
                return
            }

            result = client.getLayer(layerName, keepDeviceValue: keepDeviceValue)
        } 

        return result ?? Layer(client: nil, name: layerName, evalDetails: EvaluationDetails(reason: .Uninitialized))
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
        errorBoundary.capture {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling updateUser.")
                completion?("Must start Statsig first and wait for it to complete before calling updateUser.")
                return
            }

            client.updateUser(user, completion: completion)
        }
    }

    public static func shutdown() {
        errorBoundary.capture {
            client?.shutdown()
            client = nil
        }
    }

    public static func getStableID() -> String? {
        var result:String? = nil
        errorBoundary.capture {
            result = client?.getStableID()
        }
        return result
    }

    public static func overrideGate(_ gateName: String, value: Bool) {
        errorBoundary.capture {
            client?.overrideGate(gateName, value: value)
        }
    }

    public static func overrideConfig(_ configName: String, value: [String: Any]) {
        errorBoundary.capture {
            client?.overrideConfig(configName, value: value)
        }
    }

    public static func removeOverride(_ name: String) {
        errorBoundary.capture {
            client?.removeOverride(name)
        }
    }

    public static func removeAllOverrides() {
        errorBoundary.capture {
            client?.removeAllOverrides()
        }
    }

    public static func getAllOverrides() -> StatsigOverrides? {
        var result: StatsigOverrides? = nil
        errorBoundary.capture {
            result = client?.getAllOverrides()
        }
        return result
    }

    private static func logEventImpl(_ withName: String, value: Any? = nil, metadata: [String: String]? = nil) {
        guard let client = client else {
            print("[Statsig]: Must start Statsig first and wait for it to complete before calling logEvent.")
            return
        }

        errorBoundary.capture {
            client.logEvent(withName, value: value, metadata: metadata)
        }
    }

    private static func getEmptyConfig(_ name: String) -> DynamicConfig {
        return DynamicConfig(configName: name, evalDetails: EvaluationDetails(reason: .Uninitialized))
    }
}


import Foundation

import UIKit
import StatsigInternalObjC

public typealias completionBlock = ((_ errorMessage: String?) -> Void)?

public class Statsig {
    internal static var client: StatsigClient?
    internal static var errorBoundary: ErrorBoundary = ErrorBoundary()
    internal static var pendingListeners: [StatsigListening] = []

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
            addPendingListeners()
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
        guard let client = client else {
            pendingListeners.append(listener)
            return
        }

        client.addListener(listener)
    }

    public static func checkGate(_ gateName: String) -> Bool {
        return checkGateImpl(gateName, withExposures: true, functionName: #function)
    }

    public static func checkGateWithExposureLoggingDisabled(_ gateName: String) -> Bool {
        return checkGateImpl(gateName, withExposures: false, functionName: #function)
    }

    public static func manuallyLogGateExposure(_ gateName: String) {
        errorBoundary.capture {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling manuallyLogGateExposure.")
                return
            }

            client.logGateExposure(gateName)
        }
    }

    public static func getExperiment(_ experimentName: String, keepDeviceValue: Bool = false) -> DynamicConfig {
        return getExperimentImpl(experimentName, keepDeviceValue: keepDeviceValue, withExposures: true, functionName: #function)
    }

    public static func getExperimentWithExposureLoggingDisabled(_ experimentName: String, keepDeviceValue: Bool = false) -> DynamicConfig {
        return getExperimentImpl(experimentName, keepDeviceValue: keepDeviceValue, withExposures: false, functionName: #function)
    }

    public static func manuallyLogExperimentExposure(_ experimentName: String, keepDeviceValue: Bool = false) {
        errorBoundary.capture {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling manuallyLogExperimentExposure.")
                return
            }

            client.logExperimentExposure(experimentName, keepDeviceValue: keepDeviceValue)
        }
    }

    public static func getConfig(_ configName: String) -> DynamicConfig {
        return getConfigImpl(configName, withExposures: true, functionName: #function)
    }

    public static func getConfigWithExposureLoggingDisabled(_ configName: String) -> DynamicConfig {
        return getConfigImpl(configName, withExposures: false, functionName: #function)
    }

    public static func manuallyLogConfigExposure(_ configName: String) {
        errorBoundary.capture {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling manuallyLogConfigExposure.")
                return
            }

            client.logConfigExposure(configName)
        }
    }

    public static func getLayer(_ layerName: String, keepDeviceValue: Bool = false) -> Layer {
        return getLayerImpl(layerName, keepDeviceValue: keepDeviceValue, withExposures: true, functionName: #function)
    }

    public static func getLayerWithExposureLoggingDisabled(_ layerName: String, keepDeviceValue: Bool = false) -> Layer {
        return getLayerImpl(layerName, keepDeviceValue: keepDeviceValue, withExposures: false, functionName: #function)
    }

    public static func manuallyLogLayerParameterExposure(_ layerName: String, _ parameterName: String, keepDeviceValue: Bool = false) {
        errorBoundary.capture {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling manuallyLogLayerParameterExposure.")
                return
            }

            client.logLayerParameterExposure(layerName, parameterName: parameterName, keepDeviceValue: keepDeviceValue)
        }
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

    private static func checkGateImpl(_ gateName: String, withExposures: Bool, functionName: String) -> Bool {
        var result = false
        errorBoundary.capture {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling \(functionName). Returning false as the default.")
                return
            }

            result = withExposures
            ? client.checkGate(gateName)
            : client.checkGateWithExposureLoggingDisabled(gateName)
        }
        return result
    }

    private static func getExperimentImpl(_ experimentName: String, keepDeviceValue: Bool, withExposures: Bool, functionName: String) -> DynamicConfig {
        var result: DynamicConfig? = nil
        errorBoundary.capture {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling \(functionName). Returning a dummy DynamicConfig that will only return default values.")
                return
            }

            result = withExposures
            ? client.getExperiment(experimentName, keepDeviceValue: keepDeviceValue)
            : client.getExperimentWithExposureLoggingDisabled(experimentName, keepDeviceValue: keepDeviceValue)
        }
        return result ?? getEmptyConfig(experimentName)
    }

    private static func getConfigImpl(_ configName: String, withExposures: Bool, functionName: String) -> DynamicConfig {
        var result: DynamicConfig? = nil
        errorBoundary.capture {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling \(functionName). Returning a dummy DynamicConfig that will only return default values.")
                return
            }

            result = withExposures
            ? client.getConfig(configName)
            : client.getConfigWithExposureLoggingDisabled(configName)
        }
        return result ?? getEmptyConfig(configName)
    }

    private static func getLayerImpl(_ layerName: String, keepDeviceValue: Bool, withExposures: Bool, functionName: String) -> Layer {
        var result: Layer?
        errorBoundary.capture {
            guard let client = client else {
                print("[Statsig]: Must start Statsig first and wait for it to complete before calling \(functionName). Returning an empty Layer object")
                return
            }

            result = withExposures
            ? client.getLayer(layerName, keepDeviceValue: keepDeviceValue)
            : client.getLayerWithExposureLoggingDisabled(layerName, keepDeviceValue: keepDeviceValue)
        }

        return result ?? Layer(client: nil, name: layerName, evalDetails: EvaluationDetails(reason: .Uninitialized))
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

    private static func addPendingListeners() {
        for listener in pendingListeners {
            client?.addListener(listener)
        }
        pendingListeners.removeAll()
    }
}


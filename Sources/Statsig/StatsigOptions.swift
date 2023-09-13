import Foundation

internal let ApiHost = "api.statsig.com"

/**
 Configuration options for the StatsigSDK.
 */
public class StatsigOptions {
    /**
     Used to decide how long the Statsig client waits for the initial network request to respond before calling the completion block. The Statsig client will return either cached values (if any) or default values if checkGate/getConfig/getExperiment is called before the initial network request completes
     */
    public var initTimeout = 3.0

    /**
     By default, any custom event your application logs with Statsig.logEvent() includes the current root View Controller. This is so we can generate user journey funnels for your users. You can set this parameter to true to disable this behavior.
     */
    public var disableCurrentVCLogging = false


    /**
     By default, feature values for a user are fetched once during Statsig.start and don't change throughout the session. Setting this value to true will make Statsig periodically fetch updated values for the current user.
     */
    public var enableAutoValueUpdate = false

    /**
     Overrides the auto generated StableID that is set for the device.
     */
    public var overrideStableID: String?

    /**
     Use file caching instead of UserDefaults. Useful if you are running into size limits with UserDefaults (ie tvOS)
     */
    public var enableCacheByFile = false

    /**
     Provide a Dictionary representing the "initiailize response" required  to synchronously initialize the SDK.
     This value can be obtained from a Statsig server SDK.
     */
    public var initializeValues: [String: Any]? = nil

    /**
     Prevent the SDK from sending useful debug information to Statsig
     */
    public var disableDiagnostics = false;

    /**
     When disabled, the SDK will not hash gate/config/experiment names, instead they will be readable as plain text.
     Note: This requires special authorization from Statsig. Reach out to us if you are interested in this feature.
     */
    public var disableHashing = false;

    /**
     The SDK automatically shuts down when an app is put into the background.
     If you need to use the SDK while your app is backgrounded, set this to false.
     */
    public var shutdownOnBackground = true;

    /**
     The endpoint to use for all SDK network requests. You should not need to override this (unless you have another API that implements the Statsig API endpoints)
     */
    public var api = "https://\(ApiHost)";

    internal var overrideURL: URL?
    var environment: [String: String] = [:]

    public init(initTimeout: Double? = 3.0,
                disableCurrentVCLogging: Bool? = false,
                environment: StatsigEnvironment? = nil,
                enableAutoValueUpdate: Bool? = false,
                overrideStableID: String? = nil,
                enableCacheByFile: Bool? = false,
                initializeValues: [String: Any]? = nil,
                disableDiagnostics: Bool? = false,
                disableHashing: Bool? = false,
                shutdownOnBackground: Bool? = true,
                api: String? = nil
    )
    {
        if let initTimeout = initTimeout, initTimeout >= 0 {
            self.initTimeout = initTimeout
        }

        if let disableCurrentVCLogging = disableCurrentVCLogging {
            self.disableCurrentVCLogging = disableCurrentVCLogging
        }

        if let environment = environment {
            self.environment = environment.params
        }

        if let enableAutoValueUpdate = enableAutoValueUpdate {
            self.enableAutoValueUpdate = enableAutoValueUpdate
        }

        if let enableCacheByFile = enableCacheByFile {
            self.enableCacheByFile = enableCacheByFile
        }

        if let initializeValues = initializeValues {
            self.initializeValues = initializeValues
        }

        if let disableDiagnostics = disableDiagnostics {
            self.disableDiagnostics = disableDiagnostics
        }

        if let disableHashing = disableHashing {
            self.disableHashing = disableHashing
        }

        if let shutdownOnBackground = shutdownOnBackground {
            self.shutdownOnBackground = shutdownOnBackground
        }

        if let api = api, let url = URL(string: api) {
            self.overrideURL = url
        } else {
            self.overrideURL = nil
        }

        self.overrideStableID = overrideStableID
    }
}

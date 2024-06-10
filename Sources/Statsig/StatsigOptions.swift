import Foundation

internal let ApiHost = "api.statsig.com"

/**
 Configuration options for the StatsigSDK.
 */
public class StatsigOptions {
    public enum EvaluationCallbackData {
        case gate (FeatureGate)
        case config (DynamicConfig)
        case experiment (DynamicConfig)
        case layer (Layer)
    }
    
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
     Only applies if StatsigOptions.enableAutoValueUpdate is true. Controls how fequently calls to refresh the current users values are made. Time is in Secibds and defaults to 60 seconds.
     */
    public var autoValueUpdateIntervalSec = 60.0
    
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
     The API to use for all SDK network requests. You should not need to override this (unless you have another API that implements the Statsig API endpoints)
     */
    public var api = "https://\(ApiHost)" {
        didSet {
            mainApiUrl = URL(string: api) ?? mainApiUrl
        }
    }
    
    /**
     The API to use for log_event network requests. You should not need to override this (unless you have another API that implements the Statsig /v1/log_event endpoint)
     */
    public var eventLoggingApi = "https://\(ApiHost)" {
        didSet {
            logEventApiUrl = URL(string: eventLoggingApi) ?? logEventApiUrl
        }
    }
    
    /**
     A callback to validate the user on initialization/updateUser.
     */
    public var userValidationCallback: ((StatsigUser) -> StatsigUser)?
    
    /**
     A callback for when an evaluation is made against one of your configurations (gate, dynamic config, experiment or layer).
     */
    public var evaluationCallback: ((EvaluationCallbackData) -> Void)?
    
    /**
     Overrides the default cache key generation. Given the SDKKey and current StatsigUser, return a key to be used for storing values related to that user.
     Default key is a hash of the sdkKey, user.userID, and  user.customIDs.
     */
    public var customCacheKey: ((String, StatsigUser) -> String)?
    
    /**
     The URLSession to be used for network requests. By default, it is set to URLSession.shared.
     This property can be customized to utilize URLSession instances with specific configurations, including certificate pinning, for enhanced security when communicating with servers.
     */
    public var urlSession: URLSession = .shared
    
    internal var mainApiUrl: URL?
    internal var logEventApiUrl: URL?
    var environment: [String: String] = [:]
    
    public init(initTimeout: Double? = 3.0,
                disableCurrentVCLogging: Bool? = false,
                environment: StatsigEnvironment? = nil,
                enableAutoValueUpdate: Bool? = false,
                autoValueUpdateIntervalSec: Double? = nil,
                overrideStableID: String? = nil,
                enableCacheByFile: Bool? = false,
                initializeValues: [String: Any]? = nil,
                disableDiagnostics: Bool? = false,
                disableHashing: Bool? = false,
                shutdownOnBackground: Bool? = true,
                api: String? = nil,
                eventLoggingApi: String? = nil,
                evaluationCallback: ((EvaluationCallbackData) -> Void)? = nil,
                userValidationCallback: ((StatsigUser) -> StatsigUser)? = nil,
                customCacheKey: ((String, StatsigUser) -> String)? = nil,
                urlSession: URLSession? = nil
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
        
        if let internval = autoValueUpdateIntervalSec {
            self.autoValueUpdateIntervalSec = internval
        }
        
        
        if let api = api {
            self.api = api
            self.mainApiUrl = URL(string: api)
        }
        
        if let eventLoggingApi = eventLoggingApi {
            self.eventLoggingApi = eventLoggingApi
            self.logEventApiUrl = URL(string: eventLoggingApi)
        }
        
        if let customCacheKey = customCacheKey {
            self.customCacheKey = customCacheKey
        }
        
        if let urlSession = urlSession {
            self.urlSession = urlSession
        }

        self.overrideStableID = overrideStableID
        
        self.evaluationCallback = evaluationCallback
        
        self.userValidationCallback = userValidationCallback
    }
}

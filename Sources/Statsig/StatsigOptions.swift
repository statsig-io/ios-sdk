import Foundation

public class StatsigOptions {
    public var initTimeout = 3.0
    public var disableCurrentVCLogging = false
    public var enableAutoValueUpdate = false
    public var overrideStableID: String?

    internal var overrideURL: URL?
    var environment: [String: String] = [:]

    public init(initTimeout: Double? = 3.0,
                disableCurrentVCLogging: Bool? = false,
                environment: StatsigEnvironment? = nil,
                enableAutoValueUpdate: Bool? = false,
                overrideStableID: String? = nil)
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
        self.overrideStableID = overrideStableID
        self.overrideURL = nil
    }
}

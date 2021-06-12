import Foundation

@objc public class StatsigOptions: NSObject {
    public var initTimeout = 3.0;
    public var disableCurrentVCLogging = false;
    var environment: [String: String] = [:];

    public init(initTimeout: Double = 3.0, disableCurrentVCLogging: Bool = false, environment: StatsigEnvironment? = nil) {
        if initTimeout >= 0 {
            self.initTimeout = initTimeout
        }
        if disableCurrentVCLogging {
            self.disableCurrentVCLogging = disableCurrentVCLogging
        }
        if let environment = environment {
            self.environment = environment.params
        }
    }
}

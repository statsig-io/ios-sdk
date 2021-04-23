import Foundation

@objc public class StatsigOptions: NSObject {
    public var initTimeout = 3.0;
    public var disableCurrentVCLogging = false;

    public init(initTimeout: Double = 3.0, disableCurrentVCLogging: Bool = false) {
        if initTimeout >= 0 {
            self.initTimeout = initTimeout
        }
        if disableCurrentVCLogging {
            self.disableCurrentVCLogging = disableCurrentVCLogging
        }
    }
}

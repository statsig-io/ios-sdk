import Foundation

@objc public class StatsigOptions: NSObject {
    public var initTimeout = 3.0;

    public init(initTimeout: Double? = nil) {
        if let initTimeout = initTimeout, initTimeout >= 0 {
            self.initTimeout = initTimeout
        }
    }
}

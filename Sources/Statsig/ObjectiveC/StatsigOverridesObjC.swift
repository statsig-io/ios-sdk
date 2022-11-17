import Foundation

@objc(StatsigOverrides)
public final class StatsigOverridesObjC: NSObject {
    private var overrides: StatsigOverrides?

    init(_ overrides: StatsigOverrides?) {
        self.overrides = overrides
    }
}

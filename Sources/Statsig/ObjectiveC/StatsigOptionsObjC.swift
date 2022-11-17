import Foundation

@objc(StatsigOptions)
public final class StatsigOptionsObjC: NSObject {
    var optionsInternal: StatsigOptions

    @objc override public init() {
        self.optionsInternal = StatsigOptions()
    }

    @objc public init(initTimeout: Double) {
        self.optionsInternal = StatsigOptions(initTimeout: initTimeout)
    }

    @objc public init(disableCurrentVCLogging: Bool) {
        self.optionsInternal = StatsigOptions(disableCurrentVCLogging: disableCurrentVCLogging)
    }

    @objc public init(environment: StatsigEnvironment) {
        self.optionsInternal = StatsigOptions(environment: environment)
    }

    @objc public init(enableAutoValueUpdate: Bool) {
        self.optionsInternal = StatsigOptions(enableAutoValueUpdate: enableAutoValueUpdate)
    }

    @objc public init(initTimeout: Double,
                      disableCurrentVCLogging: Bool,
                      environment: StatsigEnvironment,
                      enableAutoValueUpdate: Bool)
    {
        self.optionsInternal = StatsigOptions(initTimeout: initTimeout,
                                              disableCurrentVCLogging: disableCurrentVCLogging,
                                              environment: environment,
                                              enableAutoValueUpdate: enableAutoValueUpdate)
    }
}

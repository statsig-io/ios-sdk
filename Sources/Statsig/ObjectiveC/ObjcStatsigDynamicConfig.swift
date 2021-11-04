import Foundation

@objc(DynamicConfig)
public final class ObjcStatsigDynamicConfig: NSObject {
    private var config: DynamicConfig

    @objc public var value: [String: Any] {
        config.value
    }

    init(withConfig: DynamicConfig) {
        config = withConfig
    }

    @objc public func getArray(forKey: String, defaultValue: [Any]) -> [Any] {
        return config.getValue(forKey: forKey, defaultValue: defaultValue)
    }

    @objc public func getBool(forKey: String, defaultValue: Bool) -> Bool {
        return config.getValue(forKey: forKey, defaultValue: defaultValue)
    }

    @objc public func getDictionary(forKey: String, defaultValue: [String: Any]) -> [String: Any] {
        return config.getValue(forKey: forKey, defaultValue: defaultValue)
    }

    @objc public func getDouble(forKey: String, defaultValue: Double) -> Double {
        return config.getValue(forKey: forKey, defaultValue: defaultValue)
    }

    @objc public func getInt(forKey: String, defaultValue: Int) -> Int {
        return config.getValue(forKey: forKey, defaultValue: defaultValue)
    }

    @objc public func getString(forKey: String, defaultValue: String) -> String {
        return config.getValue(forKey: forKey, defaultValue: defaultValue)
    }
}

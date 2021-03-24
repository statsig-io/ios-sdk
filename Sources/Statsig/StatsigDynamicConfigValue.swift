import Foundation

public protocol StatsigDynamicConfigValue {}

extension Array: StatsigDynamicConfigValue {}

extension Array where Element: StatsigDynamicConfigValue {}

extension Bool: StatsigDynamicConfigValue {}

extension Dictionary: StatsigDynamicConfigValue {}

extension Double: StatsigDynamicConfigValue {}

extension Int: StatsigDynamicConfigValue {}

extension String: StatsigDynamicConfigValue {}

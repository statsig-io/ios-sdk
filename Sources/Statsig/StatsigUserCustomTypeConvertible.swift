import Foundation

public protocol StatsigUserCustomTypeConvertible {}

extension Bool : StatsigUserCustomTypeConvertible {}

extension Double : StatsigUserCustomTypeConvertible {}

extension String : StatsigUserCustomTypeConvertible {}

extension Array : StatsigUserCustomTypeConvertible where Element == String {}

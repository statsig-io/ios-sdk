import Foundation

public protocol StatsigDynamicConfigValue {}

extension Array: StatsigDynamicConfigValue {}

extension Array where Element: StatsigDynamicConfigValue {}

extension Bool: StatsigDynamicConfigValue {}

extension Dictionary: StatsigDynamicConfigValue {}

extension Double: StatsigDynamicConfigValue {}

extension Int: StatsigDynamicConfigValue {}

extension String: StatsigDynamicConfigValue {}

extension String?: StatsigDynamicConfigValue {}


fileprivate struct TypeString {
    static let boolean = "boolean"
    static let number = "number"
    static let string = "string"
    static let array = "array"
    static let object = "object"
}

func getTypeOf<T: StatsigDynamicConfigValue>(_ value: T) -> String? {
    switch value {
     case is Bool:
         return TypeString.boolean
     case is Int, is Double:
         return TypeString.number
     case is String, is Optional<String>:
         return TypeString.string
     case is Array<StatsigDynamicConfigValue>:
         return TypeString.array
     case is Dictionary<String, StatsigDynamicConfigValue>:
         return TypeString.object
     default:
         return nil
     }
}



import Foundation

public class Time {
    public static func now() -> UInt {
        UInt(Date().timeIntervalSince1970 * 1000)
    }

    public static func parse(_ value: Any?) -> UInt {
        if let time = value as? UInt {
            return time
        }

        if let time = value as? Double {
            return UInt(time)
        }

        if let str = value as? String {
            if let time = UInt(str) {
                return time
            }

            if let time = Double(str) {
                return UInt(time)
            }
        }

        return 0
    }
}

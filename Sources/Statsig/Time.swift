import Foundation

public class Time {
    public static func now() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1000)
    }

    public static func parse(_ value: Any?) -> UInt64 {
        if let time = value as? UInt64 {
            return time
        }

        if let time = value as? Double {
            return UInt64(time)
        }

        if let str = value as? String {
            if let time = UInt64(str) {
                return time
            }

            if let time = Double(str) {
                return UInt64(time)
            }
        }

        return 0
    }
}

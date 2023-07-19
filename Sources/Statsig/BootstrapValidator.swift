import Foundation

class BootstrapValidator {
    static func isValid(_ user: StatsigUser, _ values: [String: Any]) -> Bool {
        guard let evaluatedKeys = values["evaluated_keys"] else {
            return true
        }

        guard let evaluatedKeys = self.copyObject(evaluatedKeys as? [String: Any]) else {
            return true
        }

        let userDict = self.copyObject(user.toDictionary(forLogging: false))

        return BootstrapValidator.validate(evaluatedKeys, userDict) &&
        BootstrapValidator.validate(userDict, evaluatedKeys)
    }

    private static func validate(_ one: [String: Any]?, _ two: [String: Any]?) -> Bool {
        guard let one = one, let two = two else {
            return one == nil && two == nil
        }

        for (key, value) in one {
            if key == "stableID" {
                continue
            }

            guard let value2 = two[key] else {
                return false
            }

            if value as? AnyHashable == value2 as? AnyHashable {
                return true
            }

            if let objectValue = value as? [String: Any], let objectValue2 = value2 as? [String: Any] {
                return self.validate(objectValue, objectValue2)
            }

            // unexpected
            return false
        }

        return true
    }

    private static func copyObject(_ obj: [String: Any?]?) -> [String: Any]? {
        guard let obj = obj else {
            return nil
        }

        var copy = [String: Any]()
        if let userID = obj["userID"] {
            copy["userID"] = userID
        }

        if let customIDs = obj["customIDs"] as? [String: Any] {
            var customIDsCopy = customIDs
            customIDsCopy.removeValue(forKey: "stableID")
            if !customIDsCopy.isEmpty {
                copy["customIDs"] = customIDsCopy
            }
        }

        return copy
    }
}

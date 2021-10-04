import Foundation

import CommonCrypto

class InternalStore {
    private static let localStorageKey = "com.Statsig.InternalStore.localStorageKey"
    private static let stickyUserIDKey = "com.Statsig.InternalStore.stickyUserIDKey"
    private static let stickyUserExperimentsKey = "com.Statsig.InternalStore.stickyUserExperimentsKey"
    private static let stickyDeviceExperimentsKey = "com.Statsig.InternalStore.stickyDeviceExperimentsKey"
    var stickyUserID: String?
    var cache: [String: Any]!
    var stickyUserExperiments: [String: Any]!
    var stickyDeviceExperiments: [String: Any]!
    var updatedTime: Double = 0 // in milliseconds - retrieved from and sent to server in milliseconds

    init(userID: String?) {
        cache = UserDefaults.standard.dictionary(forKey: InternalStore.localStorageKey) ?? [String: Any]()
        stickyDeviceExperiments =
            UserDefaults.standard.dictionary(forKey: InternalStore.stickyDeviceExperimentsKey) ?? [String: Any]()
        loadAndResetStickyUserValuesIfNeeded(newUserID: userID)
    }

    func checkGate(forName: String) -> FeatureGate? {
        if let nameHash = forName.sha256() {
            if let gates = cache["feature_gates"] as? [String: [String: Any]], let gateObj = gates[nameHash] {
                return FeatureGate(name: forName, gateObj: gateObj)
            }
        }
        return nil
    }

    func getConfig(forName: String) -> DynamicConfig? {
        if let nameHash = forName.sha256() {
            if let configs = cache["dynamic_configs"] as? [String: [String: Any]], let configObj = configs[nameHash] {
                return DynamicConfig(configName: forName, configObj: configObj)
            }
        }
        return nil
    }

    func getExperiment(forName: String, keepDeviceValue: Bool) -> DynamicConfig? {
        if let nameHash = forName.sha256() {
            let stickyValue = (stickyUserExperiments[nameHash] ?? stickyDeviceExperiments[nameHash]) as? [String: Any]
            let latestValue = getConfig(forName: forName)

            // If flag is false, or experiment is NOT active, simply remove the sticky experiment value, and return the latest value
            if !keepDeviceValue || latestValue?.isExperimentActive == false {
                removeStickyValue(forKey: nameHash)
                return latestValue
            }

            // If sticky value is already in cache, use it
            if let stickyValue = stickyValue {
                return DynamicConfig(configName: forName, configObj: stickyValue)
            }

            // The user has NOT been exposed before. If is IN this ACTIVE experiment, then we save the value as sticky
            if let latestValue = latestValue, latestValue.isExperimentActive, latestValue.isUserInExperiment {
                if latestValue.isDeviceBased {
                    stickyDeviceExperiments[nameHash] = latestValue.rawValue
                } else {
                    stickyUserExperiments[nameHash] = latestValue.rawValue
                }
                saveStickyValues()
            }
            return latestValue
        }
        return nil
    }

    func set(values: [String: Any], time: Double? = nil) {
        cache = values
        updatedTime = time ?? updatedTime
        UserDefaults.standard.setValue(cache, forKey: InternalStore.localStorageKey)
    }

    func removeStickyValue(forKey: String) {
        stickyUserExperiments.removeValue(forKey: forKey)
        stickyDeviceExperiments.removeValue(forKey: forKey)
        saveStickyValues()
    }

    func loadAndResetStickyUserValuesIfNeeded(newUserID: String?) {
        stickyUserID = UserDefaults.standard.string(forKey: InternalStore.stickyUserIDKey)
        if stickyUserID == newUserID {
            // If user ID is unchanged, just grab the sticky values
            stickyUserExperiments = UserDefaults.standard.dictionary(forKey: InternalStore.stickyUserExperimentsKey) ?? [String: Any]()
        } else {
            // Otherwise, update the ID in memory, and in cache
            stickyUserID = newUserID
            UserDefaults.standard.set(newUserID, forKey: InternalStore.stickyUserIDKey)
            // Also resets sticky user values in memory and cache
            stickyUserExperiments = [String: Any]()
            UserDefaults.standard.removeObject(forKey: InternalStore.stickyUserExperimentsKey)
        }
    }

    static func deleteAllLocalStorage() {
        UserDefaults.standard.removeObject(forKey: InternalStore.localStorageKey)
        UserDefaults.standard.removeObject(forKey: InternalStore.stickyUserExperimentsKey)
        UserDefaults.standard.removeObject(forKey: InternalStore.stickyDeviceExperimentsKey)
    }

    private func saveStickyValues() {
        UserDefaults.standard.setValue(stickyUserExperiments, forKey: InternalStore.stickyUserExperimentsKey)
        UserDefaults.standard.setValue(stickyDeviceExperiments, forKey: InternalStore.stickyDeviceExperimentsKey)
    }
}

extension String {
    func sha256() -> String? {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest).base64EncodedString()
    }
}

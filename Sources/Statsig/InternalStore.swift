import Foundation

import CommonCrypto

class InternalStore {
    private static let localStorageKey = "com.Statsig.InternalStore.localStorageKey"
    private static let stickyUserIDKey = "com.Statsig.InternalStore.stickyUserIDKey"
    private static let stickyUserExperimentsKey = "com.Statsig.InternalStore.stickyUserExperimentsKey"
    private static let stickyDeviceExperimentsKey = "com.Statsig.InternalStore.stickyDeviceExperimentsKey"
    private static let storeQueueLabel = "com.Statsig.storeQueue"

    var stickyUserID: String?
    var cache: [String: Any]!
    var stickyUserExperiments: [String: Any]!
    var stickyDeviceExperiments: [String: Any]!
    var updatedTime: Double = 0 // in milliseconds - retrieved from and sent to server in milliseconds

    let storeQueue = DispatchQueue(label: storeQueueLabel, qos: .userInitiated, attributes: .concurrent)

    init(userID: String?) {
        cache = UserDefaults.standard.dictionary(forKey: InternalStore.localStorageKey) ?? [String: Any]()
        stickyDeviceExperiments =
            UserDefaults.standard.dictionary(forKey: InternalStore.stickyDeviceExperimentsKey) ?? [String: Any]()
        loadAndResetStickyUserValuesIfNeeded(newUserID: userID)

    }

    func checkGate(forName: String) -> FeatureGate? {
        storeQueue.sync {
            let hashedKey = forName.sha256()
            if let gates = cache["feature_gates"] as? [String: [String: Any]], let gateObj = gates[hashedKey] {
                return FeatureGate(name: forName, gateObj: gateObj)
            }
            return nil
        }
    }

    func getConfig(forName: String) -> DynamicConfig? {
        storeQueue.sync {
            let hashedKey = forName.sha256()
            if let configs = cache["dynamic_configs"] as? [String: [String: Any]], let configObj = configs[hashedKey] {
                return DynamicConfig(configName: forName, configObj: configObj)
            }
            return nil
        }
    }

    func getExperiment(forName: String, keepDeviceValue: Bool) -> DynamicConfig? {
        let latestValue = getConfig(forName: forName)

        return storeQueue.sync {
            let hashedKey = forName.sha256()
            let stickyValue = (stickyUserExperiments[hashedKey] ?? stickyDeviceExperiments[hashedKey]) as? [String: Any]

            // If flag is false, or experiment is NOT active, simply remove the sticky experiment value, and return the latest value
            if !keepDeviceValue || latestValue?.isExperimentActive == false {
                stickyUserExperiments.removeValue(forKey: hashedKey)
                stickyDeviceExperiments.removeValue(forKey: hashedKey)
                saveStickyValues()
                return latestValue
            }

            // If sticky value is already in cache, use it
            if let stickyValue = stickyValue {
                return DynamicConfig(configName: forName, configObj: stickyValue)
            }

            // The user has NOT been exposed before. If is IN this ACTIVE experiment, then we save the value as sticky
            if let latestValue = latestValue, latestValue.isExperimentActive, latestValue.isUserInExperiment {
                if latestValue.isDeviceBased {
                    stickyDeviceExperiments[hashedKey] = latestValue.rawValue
                } else {
                    stickyUserExperiments[hashedKey] = latestValue.rawValue
                }
                saveStickyValues()
            }
            return latestValue
        }
    }

    func set(values: [String: Any], time: Double? = nil, completion: (() -> Void)? = nil) {
        storeQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.cache = values
            self.updatedTime = time ?? self.updatedTime
            UserDefaults.standard.setValue(self.cache, forKey: InternalStore.localStorageKey)
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    func loadAndResetStickyUserValuesIfNeeded(newUserID: String?) {
        storeQueue.sync(flags: .barrier) {
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
    func sha256() -> String {
        let data = Data(utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest).base64EncodedString()
    }
}

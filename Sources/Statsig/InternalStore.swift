import Foundation

import CommonCrypto

class InternalStore {
    private static let localStorageKey = "com.Statsig.InternalStore.localStorageKey"
    private static let stickyUserExperimentsKey = "com.Statsig.InternalStore.stickyUserExperimentsKey"
    private static let stickyDeviceExperimentsKey = "com.Statsig.InternalStore.stickyDeviceExperimentsKey"
    var cache: [String: Any]
    var stickyUserExperiments: [String: Any]
    var stickyDeviceExperiments: [String: Any]
    var updatedTime: Double = 0 // in milliseconds - retrieved from and sent to server in milliseconds

    init() {
        if let localCache = UserDefaults.standard.dictionary(forKey: InternalStore.localStorageKey) {
            cache = localCache
        } else {
            cache = [String: Any]()
        }

        if let userExpCache = UserDefaults.standard.dictionary(forKey: InternalStore.stickyUserExperimentsKey) {
            stickyUserExperiments = userExpCache
        } else {
            stickyUserExperiments = [String: Any]()
        }

        if let deviceExpCache = UserDefaults.standard.dictionary(forKey: InternalStore.stickyDeviceExperimentsKey) {
            stickyDeviceExperiments = deviceExpCache
        } else {
            stickyDeviceExperiments = [String: Any]()
        }
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
            if keepDeviceValue, let stickyValue =
                (stickyUserExperiments[nameHash] ?? stickyDeviceExperiments[nameHash]) as? [String: Any] {
                // If experiment is no longer active, we invalidate the sticky value that was used previously for the user
                if let latestValue = getConfig(forName: forName), !latestValue.isExperimentActive {
                    removeStickyValue(forKey: nameHash)
                    return latestValue
                } else {
                    return DynamicConfig(configName: forName, configObj: stickyValue)
                }
            }
            if !keepDeviceValue {
                removeStickyValue(forKey: nameHash)
            }
            if let latestValue = getConfig(forName: forName) {
                // When all of the 3 conditions are true, we save the value on device for the user for the duration of the experiment:
                // 1. getExperiment caller asks to "keepDeviceValue", i.e. keepDeviceValue == true,
                // 2. the experiment is still active,
                // 3. the current user is in the experiment.
                if keepDeviceValue && latestValue.isExperimentActive && latestValue.isUserInExperiment {
                    if latestValue.isDeviceBased {
                        stickyDeviceExperiments[nameHash] = latestValue.rawValue
                    } else {
                        stickyUserExperiments[nameHash] = latestValue.rawValue
                    }
                    saveStickyValues()
                }
                return latestValue
            }
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

    func deleteStickyUserValues() {
        stickyUserExperiments = [String: Any]()
        UserDefaults.standard.removeObject(forKey: InternalStore.stickyUserExperimentsKey)
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

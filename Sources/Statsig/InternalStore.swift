import Foundation

import CommonCrypto

public struct StatsigOverrides {
    public var gates: [String: Bool]
    public var configs: [String: [String: Any]]

    init(_ overrides: [String: Any]) {
        gates = overrides[InternalStore.gatesKey] as? [String: Bool] ?? [:]
        configs = overrides[InternalStore.configsKey] as? [String: [String: Any]] ?? [:]
    }
}

extension UserDefaults {
    func setDictionarySafe(_ dict: [String: Any], forKey key: String) {
        do {
            let json = try JSONSerialization.data(withJSONObject: dict)
            UserDefaults.standard.set(json, forKey: key)
        } catch {
            print("[Statsig]: Failed to save to cache")
        }
    }

    func dictionarySafe(forKey key: String) -> [String: Any]? {
        do {
            guard let data = UserDefaults.standard.data(forKey: key) else {
                return nil
            }

            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            return dict
        } catch {
            return nil
        }
    }
}

struct StatsigValuesCache {
    var cacheByID: [String: [String: Any]]
    var userCacheKey: String
    var userCache: [String: Any]
    var stickyDeviceExperiments: [String: [String: Any]]

    init(_ user: StatsigUser) {
        self.cacheByID = StatsigValuesCache.loadDictMigratingIfRequired(forKey: InternalStore.localStorageKey)
        self.stickyDeviceExperiments = StatsigValuesCache.loadDictMigratingIfRequired(forKey: InternalStore.stickyDeviceExperimentsKey)

        self.userCache = [:]
        self.userCacheKey = "null"

        self.setUserCacheKey(user)
        self.migrateLegacyStickyExperimentValues(user)
    }

    func getGate(_ gateName: String) -> FeatureGate? {
        let gateNameHash = gateName.sha256()
        if let gates = userCache[InternalStore.gatesKey] as? [String: [String: Any]], let gateObj = gates[gateNameHash] {
            return FeatureGate(name: gateName, gateObj: gateObj)
        }
        if let gates = userCache[InternalStore.gatesKey] as? [String: [String: Any]], let gateObj = gates[gateName] {
            return FeatureGate(name: gateName, gateObj: gateObj)
        }
        return nil
    }

    func getConfig(_ configName: String) -> DynamicConfig? {
        let configNameHash = configName.sha256()
        if let configObj = getConfigData(configNameHash, topLevelKey: InternalStore.configsKey) {
            return DynamicConfig(configName: configName, configObj: configObj)
        }
        if let configObj = getConfigData(configName, topLevelKey: InternalStore.configsKey) {
            return DynamicConfig(configName: configName, configObj: configObj)
        }
        return nil
    }

    func getLayer(_ layerName: String) -> Layer? {
        let layerNameHash = layerName.sha256()
        if let configObj = getConfigData(layerNameHash, topLevelKey: InternalStore.layerConfigsKey) {
            return Layer(name: layerName, configObj: configObj)
        }
        if let configObj = getConfigData(layerName, topLevelKey: InternalStore.layerConfigsKey) {
            return Layer(name: layerName, configObj: configObj)
        }
        return nil
    }

    func getStickyExperiment(_ expName: String) -> [String: Any]? {
        let expNameHash = expName.sha256()
        if let stickyExps = userCache[InternalStore.stickyExpKey] as? [String: [String: Any]],
           let expObj = stickyExps[expNameHash] {
            return expObj
        } else if let expObj = stickyDeviceExperiments[expNameHash] {
            return expObj
        }
        return nil
    }

    func getConfigData(_ configNameHash: String, topLevelKey: String) -> [String: Any]? {
        if let configs = userCache[topLevelKey] as? [String: [String: Any]],
           let configObj = configs[configNameHash] {
            return configObj
        }
        return nil
    }

    func getLastUpdatedTime() -> Double {
        return userCache["time"] as? Double ?? 0
    }

    mutating func updateUser(_ newUser: StatsigUser) {
        setUserCacheKey(newUser)
    }

    mutating func saveValuesForCurrentUser(_ values: [String: Any]) {
        userCache[InternalStore.gatesKey] = values[InternalStore.gatesKey]
        userCache[InternalStore.configsKey] = values[InternalStore.configsKey]
        userCache[InternalStore.layerConfigsKey] = values[InternalStore.layerConfigsKey]
        userCache["time"] = values["time"] as? Double ?? userCache["time"]
        cacheByID[userCacheKey] = userCache
        UserDefaults.standard.setDictionarySafe(cacheByID, forKey: InternalStore.localStorageKey)
    }

    mutating func saveStickyExperimentIfNeeded(_ expName: String, _ latestValue: ConfigProtocol) {
        let expNameHash = expName.sha256()
        // If is IN this ACTIVE experiment, then we save the value as sticky
        if latestValue.isExperimentActive, latestValue.isUserInExperiment {
            if latestValue.isDeviceBased {
                stickyDeviceExperiments[expNameHash] = latestValue.rawValue
            } else {
                userCache[jsonDict: InternalStore.stickyExpKey]?[expNameHash] = latestValue.rawValue
            }
            saveToUserDefaults()
        }
    }

    mutating func removeStickyExperiment(_ expName: String) {
        let expNameHash = expName.sha256()
        stickyDeviceExperiments.removeValue(forKey: expNameHash)
        userCache[jsonDict: InternalStore.stickyExpKey]?.removeValue(forKey: expNameHash)
        saveToUserDefaults()
    }

    private mutating func saveToUserDefaults() {
        cacheByID[userCacheKey] = userCache
        UserDefaults.standard.setDictionarySafe(cacheByID, forKey: InternalStore.localStorageKey)
        UserDefaults.standard.setDictionarySafe(stickyDeviceExperiments, forKey: InternalStore.stickyDeviceExperimentsKey)
    }

    private mutating func setUserCacheKey(_ user: StatsigUser) {
        var key = user.userID ?? "null"
        if let customIDs = user.customIDs {
            for (idType, idValue) in customIDs {
                key += "\(idType)\(idValue)"
            }
        }
        userCacheKey = key

        if cacheByID[userCacheKey] == nil {
            cacheByID[userCacheKey] =
                [
                    InternalStore.gatesKey: [:],
                    InternalStore.configsKey: [:],
                    InternalStore.stickyExpKey: [:],
                    "time": 0,
                ]
        }
        userCache = cacheByID[userCacheKey]!
    }

    private static func loadDictMigratingIfRequired(forKey key: String) -> [String: [String: Any]] {
        if let dict = UserDefaults.standard.dictionarySafe(forKey: key) as? [String: [String: Any]] {
            return dict
        }

        // Load and Migrate Legacy
        if let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: [String: Any]] {
            UserDefaults.standard.setDictionarySafe(dict, forKey: key)
            return dict
        }

        return [:]
    }

    private mutating func migrateLegacyStickyExperimentValues(_ currentUser: StatsigUser) {
        let previousUserID = UserDefaults.standard.string(forKey: InternalStore.DEPRECATED_stickyUserIDKey) ?? ""
        let previousUserStickyExperiments = UserDefaults.standard.dictionary(forKey: InternalStore.DEPRECATED_stickyUserExperimentsKey)
        if previousUserID == currentUser.userID, let oldStickyExps = previousUserStickyExperiments {
            userCache[InternalStore.stickyExpKey] = oldStickyExps
        }

        let previousCache = UserDefaults.standard.dictionary(forKey: InternalStore.DEPRECATED_localStorageKey)
        if let previousCache = previousCache {
            if let gates = userCache[InternalStore.gatesKey] as? [String: Bool], gates.count == 0 {
                userCache[InternalStore.gatesKey] = previousCache[InternalStore.gatesKey]
            }
            if let configs = userCache[InternalStore.configsKey] as? [String: Any], configs.count == 0 {
                userCache[InternalStore.configsKey] = previousCache[InternalStore.configsKey]
            }
        }

        UserDefaults.standard.removeObject(forKey: InternalStore.DEPRECATED_localStorageKey)
        UserDefaults.standard.removeObject(forKey: InternalStore.DEPRECATED_stickyUserExperimentsKey)
        UserDefaults.standard.removeObject(forKey: InternalStore.DEPRECATED_stickyUserIDKey)
    }
}

class InternalStore {
    static let localOverridesKey = "com.Statsig.InternalStore.localOverridesKey"
    static let localStorageKey = "com.Statsig.InternalStore.localStorageKeyV2"
    static let stickyDeviceExperimentsKey = "com.Statsig.InternalStore.stickyDeviceExperimentsKey"

    static let DEPRECATED_localStorageKey = "com.Statsig.InternalStore.localStorageKey"
    static let DEPRECATED_stickyUserExperimentsKey = "com.Statsig.InternalStore.stickyUserExperimentsKey"
    static let DEPRECATED_stickyUserIDKey = "com.Statsig.InternalStore.stickyUserIDKey"

    static let storeQueueLabel = "com.Statsig.storeQueue"

    static let gatesKey = "feature_gates"
    static let configsKey = "dynamic_configs"
    static let stickyExpKey = "sticky_experiments"
    static let layerConfigsKey = "layer_configs"

    var cache: StatsigValuesCache
    var localOverrides: [String: Any]!
    var updatedTime: Double { cache.getLastUpdatedTime() }
    let storeQueue = DispatchQueue(label: storeQueueLabel, qos: .userInitiated, attributes: .concurrent)

    init(_ user: StatsigUser) {
        cache = StatsigValuesCache(user)
        localOverrides = UserDefaults.standard.dictionarySafe(forKey: InternalStore.localOverridesKey)
            ?? getEmptyOverrides()
    }

    func checkGate(forName: String) -> FeatureGate? {
        storeQueue.sync {
            if let override = (localOverrides[InternalStore.gatesKey] as? [String: Bool])?[forName] {
                return FeatureGate(name: forName, value: override, ruleID: "override")
            }
            return cache.getGate(forName)
        }
    }

    func getConfig(forName: String) -> DynamicConfig? {
        storeQueue.sync {
            if let override = (localOverrides[InternalStore.configsKey] as? [String: [String: Any]])?[forName] {
                return DynamicConfig(configName: forName, value: override, ruleID: "override")
            }
            return cache.getConfig(forName)
        }
    }

    func getExperiment(forName experimentName: String, keepDeviceValue: Bool) -> DynamicConfig? {
        let latestValue = getConfig(forName: experimentName)
        return getPossiblyStickyValue(experimentName,
                                      latestValue: latestValue,
                                      keepDeviceValue: keepDeviceValue)
    }

    func getLayer(forName layerName: String, keepDeviceValue: Bool = false) -> Layer? {
        let latestValue = cache.getLayer(layerName)
        return getPossiblyStickyValue(layerName,
                                      latestValue: latestValue,
                                      keepDeviceValue: keepDeviceValue,
                                      isLayer: true)
    }

    func set(values: [String: Any], completion: (() -> Void)? = nil) {
        storeQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.cache.saveValuesForCurrentUser(values)
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    func updateUser(_ newUser: StatsigUser) {
        storeQueue.async(flags: .barrier) { [weak self] in
            self?.cache.updateUser(newUser)
        }
    }

    static func deleteAllLocalStorage() {
        UserDefaults.standard.removeObject(forKey: InternalStore.DEPRECATED_localStorageKey)
        UserDefaults.standard.removeObject(forKey: InternalStore.localStorageKey)
        UserDefaults.standard.removeObject(forKey: InternalStore.DEPRECATED_stickyUserExperimentsKey)
        UserDefaults.standard.removeObject(forKey: InternalStore.stickyDeviceExperimentsKey)
        UserDefaults.standard.removeObject(forKey: InternalStore.DEPRECATED_stickyUserIDKey)
        UserDefaults.standard.removeObject(forKey: InternalStore.localOverridesKey)
    }

    // Local overrides functions
    func overrideGate(_ gateName: String, _ value: Bool) {
        storeQueue.async(flags: .barrier) { [weak self] in
            self?.localOverrides[jsonDict: InternalStore.gatesKey]?[gateName] = value
            self?.saveOverrides()
        }
    }

    func overrideConfig(_ configName: String, _ value: [String: Any]) {
        storeQueue.async(flags: .barrier) { [weak self] in
            self?.localOverrides[jsonDict: InternalStore.configsKey]?[configName] = value
            self?.saveOverrides()
        }
    }

    func removeOverride(_ name: String) {
        storeQueue.async(flags: .barrier) { [weak self] in
            self?.localOverrides[jsonDict: InternalStore.gatesKey]?.removeValue(forKey: name)
            self?.localOverrides[jsonDict: InternalStore.configsKey]?.removeValue(forKey: name)
        }
    }

    func removeAllOverrides() {
        storeQueue.async(flags: .barrier) { [weak self] in
            self?.localOverrides = self?.getEmptyOverrides()
            self?.saveOverrides()
        }
    }

    func getAllOverrides() -> StatsigOverrides {
        storeQueue.sync {
            StatsigOverrides(localOverrides)
        }
    }

    private func saveOverrides() {
        UserDefaults.standard.setDictionarySafe(localOverrides, forKey: InternalStore.localOverridesKey)
    }

    private func getEmptyOverrides() -> [String: Any] {
        return [InternalStore.gatesKey: [:], InternalStore.configsKey: [:]]
    }

    private func getPossiblyStickyValue<T: ConfigProtocol>(_ name: String, latestValue: T?, keepDeviceValue: Bool,
                                                           isLayer: Bool = false) -> T? {
        return storeQueue.sync {
            var stickyExperimentIsActive = latestValue?.isExperimentActive
            if isLayer {
                // a user can have a different allocated experiment in a layer, but should still be sticky
                // to the previous experiment if it's still active, so we need to look it up
                let stickyLayerExp = cache.getStickyExperiment(name)
                if stickyLayerExp != nil {
                    if let stickyExpNameHash = stickyLayerExp?["allocated_experiment_name"] as? String,
                       let currentExp = cache.getConfig(stickyExpNameHash) {
                        stickyExperimentIsActive = currentExp.isExperimentActive
                    }
                }
            }

            // If flag is false, or experiment is NOT active, simply remove the sticky experiment value, and return the latest value
            if !keepDeviceValue || stickyExperimentIsActive == false {
               storeQueue.async(flags: .barrier) { [weak self] in
                   self?.cache.removeStickyExperiment(name)
               }
                return latestValue
            }

            // If sticky value is already in cache, use it
            if let stickyValue = cache.getStickyExperiment(name) {
                return T(name: name, configObj: stickyValue)
            }

            // The user has NOT been exposed before. If is IN this ACTIVE experiment, then we save the value as sticky
            if let latestValue = latestValue {
                storeQueue.async(flags: .barrier) { [weak self] in
                    self?.cache.saveStickyExperimentIfNeeded(name, latestValue)
                }
            }
            return latestValue
        }

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

// https://stackoverflow.com/a/41543070
extension Dictionary {
    subscript(jsonDict key: Key) -> [String: Any]? {
        get {
            return self[key] as? [String: Any]
        }
        set {
            self[key] = newValue as? Value
        }
    }
}

import Foundation
import CommonCrypto

struct StatsigValuesCache {
    var cacheByID: [String: [String: Any]]
    var userCacheKey: String
    var userLastUpdateTime: Double
    var stickyDeviceExperiments: [String: [String: Any]]
    var reason: EvaluationReason = .Uninitialized

    var gates: [String: [String: Any]]? = nil
    var configs: [String: [String: Any]]? = nil
    var layers: [String: [String: Any]]? = nil

    var userCache: [String: Any] {
        didSet {
            gates = userCache[StorageKeys.gatesKey] as? [String: [String: Any]]
            configs = userCache[StorageKeys.configsKey] as? [String: [String: Any]]
            layers = userCache[StorageKeys.layerConfigsKey] as? [String: [String: Any]]
        }
    }

    init(_ user: StatsigUser) {
        self.cacheByID = StatsigValuesCache.loadDictMigratingIfRequired(forKey: StorageKeys.localStorageKey)
        self.stickyDeviceExperiments = StatsigValuesCache.loadDictMigratingIfRequired(forKey: StorageKeys.stickyDeviceExperimentsKey)

        self.userCache = [:]
        self.userCacheKey = "null"
        self.userLastUpdateTime = 0

        self.setUserCacheKeyAndValues(user)
        self.migrateLegacyStickyExperimentValues(user)
    }

    func getGate(_ gateName: String) -> FeatureGate {
        guard let gates = gates else {
            print("[Statsig]: Failed to get feature gate with name \(gateName). Returning false as the default.")
            return FeatureGate(name: gateName, value: false, ruleID: "", evalDetails: getEvaluationDetails(valueExists: false))
        }

        if let gateObj = (gates[gateName.sha256()] ?? gates[gateName]) {
            return FeatureGate(name: gateName, gateObj: gateObj, evalDetails: getEvaluationDetails(valueExists: true))
        }

        print("[Statsig]: The feature gate with name \(gateName) does not exist. Returning false as the default.")
        return FeatureGate(name: gateName, value: false, ruleID: "", evalDetails: getEvaluationDetails(valueExists: false))
    }

    func getConfig(_ configName: String) -> DynamicConfig {
        guard let configs = configs else {
            print("[Statsig]: Failed to get config with name \(configName). Returning a dummy DynamicConfig that will only return default values.")
            return DynamicConfig(configName: configName, evalDetails: getEvaluationDetails(valueExists: false))
        }

        if let configObj = (configs[configName.sha256()] ?? configs[configName]) {
            return DynamicConfig(configName: configName, configObj: configObj, evalDetails: getEvaluationDetails(valueExists: true))
        }

        print("[Statsig]: \(configName) does not exist. Returning a dummy DynamicConfig that will only return default values.")
        return DynamicConfig(configName: configName, evalDetails: getEvaluationDetails(valueExists: false))
    }

    func getLayer(_ client: StatsigClient?, _ layerName: String) -> Layer {
        guard let layers = layers else {
            print("[Statsig]: Failed to get layer with name \(layerName). Returning an empty Layer.")
            return Layer(client: client, name: layerName, evalDetails: getEvaluationDetails(valueExists: false))
        }

        if let configObj = layers[layerName.sha256()] ?? layers[layerName] {
            return Layer(client: client, name: layerName, configObj: configObj, evalDetails: getEvaluationDetails(valueExists: true))
        }

        print("[Statsig]: The layer with name \(layerName) does not exist. Returning an empty Layer.")
        return Layer(client: client, name: layerName, evalDetails: getEvaluationDetails(valueExists: false))
    }

    func getStickyExperiment(_ expName: String) -> [String: Any]? {
        let expNameHash = expName.sha256()
        if let stickyExps = userCache[StorageKeys.stickyExpKey] as? [String: [String: Any]],
           let expObj = stickyExps[expNameHash] {
            return expObj
        } else if let expObj = stickyDeviceExperiments[expNameHash] {
            return expObj
        }
        return nil
    }

    func getEvaluationDetails(valueExists: Bool) -> EvaluationDetails {
        if valueExists {
            return EvaluationDetails(
                reason: reason,
                time: userCache[StorageKeys.evalTimeKey] as? Double ?? NSDate().epochTimeInMs()
            )
        } else {
            return EvaluationDetails(
                reason: reason == .Uninitialized ? .Uninitialized : .Unrecognized,
                time: NSDate().epochTimeInMs()
            )
        }
    }

    func getLastUpdatedTime(user: StatsigUser) -> Double {
        if (userCache[StorageKeys.userHashKey] as? String == user.getFullUserHash()) {
            return userCache["time"] as? Double ?? 0
        }

        return 0
    }

    mutating func updateUser(_ newUser: StatsigUser) {
        // when updateUser is called, state will be uninitialized until updated values are fetched or local cache is retrieved
        reason = .Uninitialized
        setUserCacheKeyAndValues(newUser)
    }

    mutating func saveValues(_ values: [String: Any], _ cacheKey: String, _ userHash: String?) {
        var cache = cacheKey == userCacheKey ? userCache : getCacheValues(forCacheKey: cacheKey)

        let hasUpdates = values["has_updates"] as? Bool
        if hasUpdates == true {
            cache[StorageKeys.gatesKey] = values[StorageKeys.gatesKey]
            cache[StorageKeys.configsKey] = values[StorageKeys.configsKey]
            cache[StorageKeys.layerConfigsKey] = values[StorageKeys.layerConfigsKey]
            cache["time"] = values["time"] as? Double ?? 0
            cache[StorageKeys.evalTimeKey] = NSDate().epochTimeInMs()
            cache[StorageKeys.userHashKey] = userHash
        }

        if (userCacheKey == cacheKey) {
            // Now the values we serve came from network request
            reason = hasUpdates == true ? .Network : .NetworkNotModified
            userCache = cache
        }

        cacheByID[cacheKey] = cache
        StatsigUserDefaults.defaults.setDictionarySafe(cacheByID, forKey: StorageKeys.localStorageKey)
    }

    mutating func saveStickyExperimentIfNeeded(_ expName: String, _ latestValue: ConfigProtocol) {
        let expNameHash = expName.sha256()
        // If is IN this ACTIVE experiment, then we save the value as sticky
        if latestValue.isExperimentActive, latestValue.isUserInExperiment {
            if latestValue.isDeviceBased {
                stickyDeviceExperiments[expNameHash] = latestValue.rawValue
            } else {
                userCache[jsonDict: StorageKeys.stickyExpKey]?[expNameHash] = latestValue.rawValue
            }
            saveToUserDefaults()
        }
    }

    mutating func removeStickyExperiment(_ expName: String) {
        let expNameHash = expName.sha256()
        stickyDeviceExperiments.removeValue(forKey: expNameHash)
        userCache[jsonDict: StorageKeys.stickyExpKey]?.removeValue(forKey: expNameHash)
        saveToUserDefaults()
    }

    private func getCacheValues(forCacheKey key: String) -> [String: Any] {
        return cacheByID[key] ?? [
            StorageKeys.gatesKey: [:],
            StorageKeys.configsKey: [:],
            StorageKeys.stickyExpKey: [:],
            "time": 0,
        ]

    }

    private mutating func saveToUserDefaults() {
        cacheByID[userCacheKey] = userCache
        StatsigUserDefaults.defaults.setDictionarySafe(cacheByID, forKey: StorageKeys.localStorageKey)
        StatsigUserDefaults.defaults.setDictionarySafe(stickyDeviceExperiments, forKey: StorageKeys.stickyDeviceExperimentsKey)
    }

    private mutating func setUserCacheKeyAndValues(_ user: StatsigUser) {
        userCacheKey = user.getCacheKey()

        let cachedValues = getCacheValues(forCacheKey: userCacheKey)

        if cacheByID[userCacheKey] == nil {
            cacheByID[userCacheKey] = cachedValues
        } else {
            // The values we serve now is from the local cache
            reason = .Cache
        }

        userCache = cachedValues
    }

    private static func loadDictMigratingIfRequired(forKey key: String) -> [String: [String: Any]] {
        if let dict = StatsigUserDefaults.defaults.dictionarySafe(forKey: key) as? [String: [String: Any]] {
            return dict
        }

        // Load and Migrate Legacy
        if let dict = StatsigUserDefaults.defaults.dictionary(forKey: key) as? [String: [String: Any]] {
            StatsigUserDefaults.defaults.setDictionarySafe(dict, forKey: key)
            return dict
        }

        return [:]
    }

    private mutating func migrateLegacyStickyExperimentValues(_ currentUser: StatsigUser) {
        let previousUserID = StatsigUserDefaults.defaults.string(forKey: StorageKeys.DEPRECATED_stickyUserIDKey) ?? ""
        let previousUserStickyExperiments = StatsigUserDefaults.defaults.dictionary(forKey: StorageKeys.DEPRECATED_stickyUserExperimentsKey)
        if previousUserID == currentUser.userID, let oldStickyExps = previousUserStickyExperiments {
            userCache[StorageKeys.stickyExpKey] = oldStickyExps
        }

        let previousCache = StatsigUserDefaults.defaults.dictionary(forKey: StorageKeys.DEPRECATED_localStorageKey)
        if let previousCache = previousCache {
            if let gates = userCache[StorageKeys.gatesKey] as? [String: Bool], gates.count == 0 {
                userCache[StorageKeys.gatesKey] = previousCache[StorageKeys.gatesKey]
            }
            if let configs = userCache[StorageKeys.configsKey] as? [String: Any], configs.count == 0 {
                userCache[StorageKeys.configsKey] = previousCache[StorageKeys.configsKey]
            }
        }

        StatsigUserDefaults.defaults.removeObject(forKey: StorageKeys.DEPRECATED_localStorageKey)
        StatsigUserDefaults.defaults.removeObject(forKey: StorageKeys.DEPRECATED_stickyUserExperimentsKey)
        StatsigUserDefaults.defaults.removeObject(forKey: StorageKeys.DEPRECATED_stickyUserIDKey)
    }
}

class InternalStore {
    static let storeQueueLabel = "com.Statsig.storeQueue"

    var cache: StatsigValuesCache
    var localOverrides = LocalOverrides.empty()
    let storeQueue = DispatchQueue(label: storeQueueLabel, qos: .userInitiated, attributes: .concurrent)

    init(_ user: StatsigUser) {
        cache = StatsigValuesCache(user)
        localOverrides = LocalOverrides.loadedOrEmpty()
    }

    func getLastUpdateTime(user: StatsigUser) -> Double {
        storeQueue.sync {
            return cache.getLastUpdatedTime(user: user)
        }
    }

    func checkGate(forName: String) -> FeatureGate {
        storeQueue.sync {
            if let override = localOverrides.gates[forName] {
                return FeatureGate(
                    name: forName,
                    value: override,
                    ruleID: "override",
                    evalDetails: EvaluationDetails(reason: .LocalOverride)
                )
            }
            return cache.getGate(forName)
        }
    }

    func getConfig(forName: String) -> DynamicConfig {
        storeQueue.sync {
            if let override = localOverrides.configs[forName] {
                return DynamicConfig(
                    configName: forName,
                    value: override,
                    ruleID: "override",
                    evalDetails: EvaluationDetails(reason: .LocalOverride)
                )
            }
            return cache.getConfig(forName)
        }
    }

    func getExperiment(forName experimentName: String, keepDeviceValue: Bool) -> DynamicConfig {
        let latestValue = getConfig(forName: experimentName)
        return getPossiblyStickyValue(
            experimentName,
            latestValue: latestValue,
            keepDeviceValue: keepDeviceValue,
            isLayer: false,
            factory: { name, data in
                return DynamicConfig(name: name, configObj: data, evalDetails: EvaluationDetails(reason: .Sticky))
            })
    }

    func getLayer(client: StatsigClient?, forName layerName: String, keepDeviceValue: Bool = false) -> Layer {
        let latestValue: Layer = storeQueue.sync {
            if let override = localOverrides.layers[layerName] {
                return Layer(
                    client: nil,
                    name: layerName,
                    value: override,
                    ruleID: "override",
                    evalDetails: EvaluationDetails(reason: .LocalOverride)
                )
            }
            return cache.getLayer(client, layerName)
        }
        return getPossiblyStickyValue(
            layerName,
            latestValue: latestValue,
            keepDeviceValue: keepDeviceValue,
            isLayer: true,
            factory: { name, data in
                return Layer(client: client, name: name, configObj: data, evalDetails: EvaluationDetails(reason: .Sticky))
            })
    }

    func saveValues(_ values: [String: Any], _ cacheKey: String, _ userHash: String?, _ completion: (() -> Void)? = nil) {
        storeQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.cache.saveValues(values, cacheKey, userHash)
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
        StatsigUserDefaults.defaults.removeObject(forKey: StorageKeys.DEPRECATED_localStorageKey)
        StatsigUserDefaults.defaults.removeObject(forKey: StorageKeys.localStorageKey)
        StatsigUserDefaults.defaults.removeObject(forKey: StorageKeys.DEPRECATED_stickyUserExperimentsKey)
        StatsigUserDefaults.defaults.removeObject(forKey: StorageKeys.stickyDeviceExperimentsKey)
        StatsigUserDefaults.defaults.removeObject(forKey: StorageKeys.DEPRECATED_stickyUserIDKey)
        StatsigUserDefaults.defaults.removeObject(forKey: StorageKeys.localOverridesKey)
        _ = StatsigUserDefaults.defaults.synchronize()
    }

    // Local overrides functions
    func overrideGate(_ gateName: String, _ value: Bool) {
        storeQueue.async(flags: .barrier) { [weak self] in
            self?.localOverrides.gates[gateName] = value
            self?.localOverrides.save()
        }
    }

    func overrideConfig(_ configName: String, _ value: [String: Any]) {
        storeQueue.async(flags: .barrier) { [weak self] in
            self?.localOverrides.configs[configName] = value
            self?.localOverrides.save()
        }
    }

    func overrideLayer(_ layerName: String, _ value: [String: Any]) {
        storeQueue.async(flags: .barrier) { [weak self] in
            self?.localOverrides.layers[layerName] = value
            self?.localOverrides.save()
        }
    }

    func removeOverride(_ name: String) {
        storeQueue.async(flags: .barrier) { [weak self] in
            self?.localOverrides.removeOverride(name)
        }
    }

    func removeAllOverrides() {
        storeQueue.async(flags: .barrier) { [weak self] in
            guard let this = self else { return }
            this.localOverrides = LocalOverrides.empty()
            self?.localOverrides.save()
        }
    }

    func getAllOverrides() -> StatsigOverrides {
        storeQueue.sync {
            StatsigOverrides(localOverrides)
        }
    }

    // Sticky Logic: https://gist.github.com/daniel-statsig/3d8dfc9bdee531cffc96901c1a06a402
    private func getPossiblyStickyValue<T: ConfigProtocol>(
        _ name: String,
        latestValue: T,
        keepDeviceValue: Bool,
        isLayer: Bool,
        factory: (_ name: String, _ data: [String: Any]) -> T) -> T {
        return storeQueue.sync {
            // We don't want sticky behavior. Clear any sticky values and return latest.
            if (!keepDeviceValue) {
                removeStickyExperimentThreaded(name)
                return latestValue
            }

            // If there is no sticky value, save latest as sticky and return latest.
            guard let stickyValue = cache.getStickyExperiment(name) else {
                saveStickyExperimentIfNeededThreaded(name, latestValue)
                return latestValue
            }

            // Get the latest config value. Layers require a lookup by allocated_experiment_name.
            var latestExperimentValue: ConfigProtocol? = nil
            if isLayer {
                latestExperimentValue = cache.getConfig(stickyValue["allocated_experiment_name"] as? String ?? "")
            } else {
                latestExperimentValue = latestValue
            }

            
            if (latestExperimentValue?.isExperimentActive == true) {
                return factory(name, stickyValue)
            }

            if (latestValue.isExperimentActive == true) {
                saveStickyExperimentIfNeededThreaded(name, latestValue)
            } else {
                removeStickyExperimentThreaded(name)
            }

            return latestValue
        }
    }

    private func removeStickyExperimentThreaded(_ name: String) {
        storeQueue.async(flags: .barrier) { [weak self] in
            self?.cache.removeStickyExperiment(name)
        }
    }

    private func saveStickyExperimentIfNeededThreaded(_ name: String, _ config: ConfigProtocol?) {
        guard let config = config else {
            return
        }

        storeQueue.async(flags: .barrier) { [weak self] in
            self?.cache.saveStickyExperimentIfNeeded(name, config)
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

extension NSDate {
    func epochTimeInMs() -> Double {
        return NSDate().timeIntervalSince1970 * 1000
    }
}

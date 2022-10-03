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
    var reason: EvaluationReason = .Uninitialized

    init(_ user: StatsigUser) {
        self.cacheByID = StatsigValuesCache.loadDictMigratingIfRequired(forKey: InternalStore.localStorageKey)
        self.stickyDeviceExperiments = StatsigValuesCache.loadDictMigratingIfRequired(forKey: InternalStore.stickyDeviceExperimentsKey)

        self.userCache = [:]
        self.userCacheKey = "null"

        self.setUserCacheKeyAndValues(user)
        self.migrateLegacyStickyExperimentValues(user)
    }

    func getGate(_ gateName: String) -> FeatureGate {
        let gateNameHash = gateName.sha256()
        if let gates = userCache[InternalStore.gatesKey] as? [String: [String: Any]], let gateObj = gates[gateNameHash] {
            return FeatureGate(name: gateName, gateObj: gateObj, evalDetails: getEvaluationDetails(valueExists: true))
        }
        if let gates = userCache[InternalStore.gatesKey] as? [String: [String: Any]], let gateObj = gates[gateName] {
            return FeatureGate(name: gateName, gateObj: gateObj, evalDetails: getEvaluationDetails(valueExists: true))
        }
        print("[Statsig]: The feature gate with name \(gateName) does not exist. Returning false as the default.")
        return FeatureGate(name: gateName, value: false, ruleID: "", evalDetails: getEvaluationDetails(valueExists: false))
    }

    func getConfig(_ configName: String) -> DynamicConfig {
        let configNameHash = configName.sha256()
        if let configObj = getConfigData(configNameHash, topLevelKey: InternalStore.configsKey) {
            return DynamicConfig(configName: configName, configObj: configObj, evalDetails: getEvaluationDetails(valueExists: true))
        }
        if let configObj = getConfigData(configName, topLevelKey: InternalStore.configsKey) {
            return DynamicConfig(configName: configName, configObj: configObj, evalDetails: getEvaluationDetails(valueExists: true))
        }
        print("[Statsig]: \(configName) does not exist. Returning a dummy DynamicConfig that will only return default values.")
        return DynamicConfig(configName: configName, evalDetails: getEvaluationDetails(valueExists: false))
    }

    func getLayer(_ client: StatsigClient?, _ layerName: String) -> Layer {
        let layerNameHash = layerName.sha256()
        if let configObj = getConfigData(layerNameHash, topLevelKey: InternalStore.layerConfigsKey) {
            return Layer(client: client, name: layerName, configObj: configObj, evalDetails: getEvaluationDetails(valueExists: true))
        }
        if let configObj = getConfigData(layerName, topLevelKey: InternalStore.layerConfigsKey) {
            return Layer(client: client, name: layerName, configObj: configObj, evalDetails: getEvaluationDetails(valueExists: true))
        }
        print("[Statsig]: The layer with name \(layerName) does not exist. Returning an empty Layer.")
        return Layer(client: client, name: layerName, evalDetails: getEvaluationDetails(valueExists: false))
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

    func getEvaluationDetails(valueExists: Bool) -> EvaluationDetails {
        if valueExists {
            return EvaluationDetails(
                reason: reason,
                time: userCache[InternalStore.evalTimeKey] as? Double ?? NSDate().epochTimeInMs()
            )
        } else {
            return EvaluationDetails(
                reason: reason == .Uninitialized ? .Uninitialized : .Unrecognized,
                time: NSDate().epochTimeInMs()
            )
        }
    }

    func getLastUpdatedTime() -> Double {
        return userCache["time"] as? Double ?? 0
    }

    mutating func updateUser(_ newUser: StatsigUser) {
        // when updateUser is called, state will be uninitialized until updated values are fetched or local cache is retrieved
        reason = .Uninitialized
        setUserCacheKeyAndValues(newUser)
    }

    mutating func saveValues(_ values: [String: Any], forCacheKey cacheKey: String) {
        var cache = cacheKey == userCacheKey ? userCache : getCacheValues(forCacheKey: cacheKey)

        cache[InternalStore.gatesKey] = values[InternalStore.gatesKey]
        cache[InternalStore.configsKey] = values[InternalStore.configsKey]
        cache[InternalStore.layerConfigsKey] = values[InternalStore.layerConfigsKey]
        cache["time"] = values["time"] as? Double ?? userCache["time"]
        cache[InternalStore.evalTimeKey] = NSDate().epochTimeInMs()

        if (userCacheKey == cacheKey) {
            // Now the values we serve came from network request
            reason = .Network
            userCache = cache
        }


        cacheByID[cacheKey] = cache
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

    private func getCacheValues(forCacheKey key: String) -> [String: Any] {
        return cacheByID[key] ?? [
            InternalStore.gatesKey: [:],
            InternalStore.configsKey: [:],
            InternalStore.stickyExpKey: [:],
            "time": 0,
        ]

    }

    private mutating func saveToUserDefaults() {
        cacheByID[userCacheKey] = userCache
        UserDefaults.standard.setDictionarySafe(cacheByID, forKey: InternalStore.localStorageKey)
        UserDefaults.standard.setDictionarySafe(stickyDeviceExperiments, forKey: InternalStore.stickyDeviceExperimentsKey)
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
    static let evalTimeKey = "evaluation_time"

    var cache: StatsigValuesCache
    var localOverrides: [String: Any] = InternalStore.getEmptyOverrides()
    var updatedTime: Double { cache.getLastUpdatedTime() }
    let storeQueue = DispatchQueue(label: storeQueueLabel, qos: .userInitiated, attributes: .concurrent)

    init(_ user: StatsigUser) {
        cache = StatsigValuesCache(user)
        localOverrides = UserDefaults.standard.dictionarySafe(forKey: InternalStore.localOverridesKey)
        ?? InternalStore.getEmptyOverrides()
    }

    func checkGate(forName: String) -> FeatureGate {
        storeQueue.sync {
            if let override = (localOverrides[InternalStore.gatesKey] as? [String: Bool])?[forName] {
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
            if let override = (localOverrides[InternalStore.configsKey] as? [String: [String: Any]])?[forName] {
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
        let latestValue = storeQueue.sync {
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

    func set(values: [String: Any], withCacheKey cacheKey: String, completion: (() -> Void)? = nil) {
        storeQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.cache.saveValues(values, forCacheKey: cacheKey)
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
        UserDefaults.standard.synchronize()
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
            guard let this = self else { return }
            this.localOverrides = InternalStore.getEmptyOverrides()
            this.saveOverrides()
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

    private static func getEmptyOverrides() -> [String: Any] {
        return [InternalStore.gatesKey: [:], InternalStore.configsKey: [:]]
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

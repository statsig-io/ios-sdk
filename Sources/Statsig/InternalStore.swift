import Foundation

import CommonCrypto

class InternalStore {
    private let localStorageKey = "com.Statsig.InternalStore.localStorageKey"
    private let loggedOutUserID = "com.Statsig.InternalStore.loggedOutUserID"
    private let maxUserCacheCount = 5
    private var cache: [String: UserValues]

    init() {
        cache = [String: UserValues]()
        if let localCache = UserDefaults.standard.dictionary(forKey: localStorageKey) {
            for (userID, rawData) in localCache {
                if let rawData = rawData as? [String:Any] {
                    cache[userID] = UserValues(data:rawData)
                }
            }
        }
    }

    func checkGate(_ forUser:StatsigUser, gateName:String) -> Bool {
        let userValues = get(forUser: forUser)
        return userValues?.checkGate(forName: gateName) ?? false
    }

    func getConfig(_ forUser:StatsigUser, configName:String) -> DynamicConfig {
        let userValues = get(forUser: forUser)
        return userValues?.getConfig(forName: configName) ?? DynamicConfig.createDummy()
    }

    func set(forUser: StatsigUser, values: UserValues) {
        cache[forUser.userID ?? loggedOutUserID] = values
        while cache.count > maxUserCacheCount {
            removeOldest()
        }
        
        saveToLocalCache()
    }
    
    func get(forUser: StatsigUser) -> UserValues? {
        if let userID = forUser.userID {
            return cache[userID] ?? nil
        }
        return cache[loggedOutUserID]
    }
    
    private func removeOldest() {
        var oldestTime: Double = -1;
        var oldestUserKey: String?;
        for (key, values) in cache {
            if oldestTime < 0 || oldestTime > values.creationTime {
                oldestTime = values.creationTime
                oldestUserKey = key
            }
        }
        if oldestUserKey != nil {
            cache.removeValue(forKey: oldestUserKey ?? "")
        }
    }
    
    private func saveToLocalCache() {
        var rawCache = [String:[String:Any]]()
        for (userID, values) in cache {
            rawCache[userID] = values.rawData
        }
        UserDefaults.standard.setValue(rawCache, forKey: localStorageKey)
    }
}

struct UserValues {
    var rawData: [String:Any] // raw data fetched directly from Statsig server
    var gates: [String:Bool]
    var configs: [String:DynamicConfig]
    var creationTime: Double
    
    init(data: [String:Any]) {
        self.rawData = data
        self.creationTime = NSDate().timeIntervalSince1970

        var gates = [String:Bool]()
        var configs = [String:DynamicConfig]()
        if let gatesJSON = data["gates"] as? [String:Bool] {
            for (name, value) in gatesJSON {
                gates[name] = value
            }
        }
        self.gates = gates;
        
        if let configsJSON = data["configs"] as? [String:[String:Any]] {
            for (name, config) in configsJSON {
                configs[name] = DynamicConfig(configName: name, config: config)
            }
        }
        self.configs = configs;
    }
    
    func checkGate(forName:String) -> Bool {
        if let nameHash = forName.sha256() {
            return gates[nameHash] ?? false
        }
        return false
    }
    
    func getConfig(forName:String) -> DynamicConfig? {
        if let nameHash = forName.sha256() {
            return configs[nameHash] ?? DynamicConfig.createDummy()
        }
        return DynamicConfig.createDummy()
    }
}

extension String {
    func sha256() -> String? {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest).base64EncodedString()
    }
}

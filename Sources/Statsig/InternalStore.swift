import Foundation
import CommonCrypto

// TODOs:
// rename file/class

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

    public func checkGate(_ forUser:StatsigUser, gateName:String) -> Bool {
        let userValues = get(forUser: forUser)
        return userValues?.checkGate(forName: gateName) ?? false
    }

    public func getConfig(_ forUser:StatsigUser, configName:String) -> DynamicConfig? {
        let userValues = get(forUser: forUser)
        return userValues?.getConfig(forName: configName) ?? DynamicConfig.createDummy()
    }

    func set(forUser: StatsigUser, values: UserValues) {
        cache[forUser.userID ?? loggedOutUserID] = values

        // logged out user should get cached values of the most recent logged in session
        cache[loggedOutUserID] = values
        while cache.count > maxUserCacheCount {
            removeOldest()
        }
        
        saveToLocalCache()
    }
    
    func get(forUser: StatsigUser) -> UserValues? {
        if let userID = forUser.userID {
            return cache[userID] ?? cache[loggedOutUserID]
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
    var rawData: [String:Any] // data fetched directly from Statsig server
    var gates: [String:Bool]
    var configs: [String:DynamicConfig]
    var sdkParams: [String:Any]
    var creationTime: Double
    
    init(data: [String:Any]) {
        self.rawData = data

        var gates = [String:Bool]()
        var configs = [String:DynamicConfig]()
        var sdkParams = [String:Any]()
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
        
        if let sdkParamsJSON = data["sdkParams"] as? [String:Any] {
            for (param, value) in sdkParamsJSON {
                sdkParams[param] = value
            }
        }
        self.sdkParams = sdkParams;
        
        creationTime = NSDate().timeIntervalSince1970
    }
    
    public func checkGate(forName:String) -> Bool {
        if let nameHash = hash(value: forName) {
            // TODO: return dummy config?
            return gates[nameHash] ?? false
        }
        return false
    }
    
    public func getConfig(forName:String) -> DynamicConfig? {
        if let nameHash = hash(value: forName) {
            // TODO: return dummy config?
            return configs[nameHash] ?? nil
        }
        return nil
    }
    
    private func hash(value: String) -> String? {
        guard let nameData = value.data(using: String.Encoding.utf8) else {
            return nil
        }
        var hashNameData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        _ = hashNameData.withUnsafeMutableBytes {digestBytes in
            nameData.withUnsafeBytes {messageBytes in
                CC_SHA256(messageBytes, CC_LONG(nameData.count), digestBytes)
            }
        }
        return hashNameData.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
    }
}

public struct DynamicConfig {
    var name: String
    var group: String
    var value: [String:Any]
    
    init(configName: String, config: [String:Any]) {
        self.name = configName;
        self.group = config["group"] as? String ?? "unknown";
        self.value = config["value"] as? [String:Any] ?? [String:Any]();
    }
    
    static func createDummy() -> DynamicConfig {
        return DynamicConfig(configName: "com.Statsig.DynamicConfig.dummy", config: [String:Any]())
    }
    
    public func getValue<T: StatsigDynamicConfigValue>(forKey:String, defaultValue: T) -> T {
        let serverValue = value[forKey] as? T
        if serverValue == nil {
            NSLog("\(forKey) does not exist in this Dynamic Config. Returning the defaultValue.")
        }
        return serverValue ?? defaultValue
    }
}

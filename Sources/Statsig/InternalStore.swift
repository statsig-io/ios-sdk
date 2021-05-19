import Foundation

import CommonCrypto

class InternalStore {
    private static let localStorageKey = "com.Statsig.InternalStore.localStorageKey"
    var cache: UserValues?
    var updatedTime: Double = 0// in milliseconds - retrieved from and sent to server in milliseconds

    init() {
        if let localCache = UserDefaults.standard.dictionary(forKey: InternalStore.localStorageKey) {
            cache = UserValues(data: localCache)
        }
    }

    func checkGate(gateName: String) -> FeatureGate? {
        return cache?.checkGate(forName: gateName)
    }

    func getConfig(configName: String) -> DynamicConfig? {
        return cache?.getConfig(forName: configName)
    }

    func set(values: UserValues, time: Double? = nil) {
        cache = values
        updatedTime = time ?? updatedTime
        saveToLocalCache()
    }

    static func deleteLocalStorage() {
        UserDefaults.standard.removeObject(forKey: InternalStore.localStorageKey)
    }

    private func saveToLocalCache() {
        if let rawData = cache?.rawData {
            UserDefaults.standard.setValue(rawData, forKey: InternalStore.localStorageKey)
        }
    }
}

struct UserValues {
    var rawData: [String: Any] // raw data fetched directly from Statsig server
    var gates: [String: FeatureGate]
    var configs: [String: DynamicConfig]
    var creationTime: Double
    
    init(data: [String: Any]) {
        self.rawData = data
        self.creationTime = NSDate().timeIntervalSince1970

        var gates = [String: FeatureGate]()
        var configs = [String: DynamicConfig]()
        if let gatesJSON = data["feature_gates"] as? [String: [String: Any]] {
            for (name, gateObj) in gatesJSON {
                gates[name] = FeatureGate(name: name, gateObj: gateObj)
            }
        }
        self.gates = gates;
        
        if let configsJSON = data["dynamic_configs"] as? [String: [String: Any]] {
            for (name, configObj) in configsJSON {
                configs[name] = DynamicConfig(configName: name, configObj: configObj)
            }
        }
        self.configs = configs;
    }
    
    func checkGate(forName: String) -> FeatureGate? {
        if let nameHash = forName.sha256() {
            return gates[nameHash] ?? gates[forName] ?? nil
        }
        return nil
    }
    
    func getConfig(forName: String) -> DynamicConfig? {
        if let nameHash = forName.sha256() {
            return configs[nameHash] ?? configs[forName]
        }
        return nil
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

import Foundation

@testable import Statsig

class MockDefaults {
    var data: [String: Any] = [:]
    var dict: NSDictionary { get {data as NSDictionary} }
    
    func reset() {
        data = [:]
    }
    
    init(data: [String : Any] = [:]) {
        self.data = data
    }
}

extension MockDefaults: DefaultsLike {
    func array(forKey defaultName: String) -> [Any]? {
        getValue(forKey: defaultName) as? [Any]
    }
    
    func string(forKey defaultName: String) -> String? {
        getValue(forKey: defaultName) as? String
    }
    
    func dictionary(forKey defaultName: String) -> [String : Any]? {
        getValue(forKey: defaultName) as? [String : Any]
    }
    
    func data(forKey defaultName: String) -> Data? {
        getValue(forKey: defaultName) as? Data
    }
    
    func removeObject(forKey defaultName: String) {
        data[defaultName] = nil
    }
    
    func setValue(_ value: Any?, forKey: String) {
        set(value, forKey: forKey)
    }
    
    func set(_ value: Any?, forKey: String) {
        data[forKey] = value
    }
    
    func synchronize() -> Bool {
        return true
    }
    
    func keys() -> [String] {
        return Array(data.keys)
    }
    
    func setDictionarySafe(_ dict: [String: Any], forKey key: String) {
        set(dict, forKey: key)
    }
    
    func dictionarySafe(forKey key: String) -> [String: Any]? {
        return dictionary(forKey: key)
    }
    
    private func getValue(forKey key: String) -> Any? {
        return data[key]
    }
}

extension MockDefaults {
    func getUserCaches() -> NSDictionary {
        if let data = dict[InternalStore.localStorageKey] as? NSDictionary {
            return data
        }
        
        return [:]
    }
}

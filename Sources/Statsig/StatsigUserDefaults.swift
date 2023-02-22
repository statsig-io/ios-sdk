import Foundation

protocol DefaultsLike {
    func array(forKey defaultName: String) -> [Any]?
    func string(forKey defaultName: String) -> String?
    func dictionary(forKey defaultName: String) -> [String : Any]?
    func data(forKey defaultName: String) -> Data?
    func removeObject(forKey defaultName: String)
    func setValue(_ value: Any?, forKey: String)
    func set(_ value: Any?, forKey: String)
    func synchronize() -> Bool
    func dictionaryRepresentation() -> [String : Any]

    func setDictionarySafe(_ dict: [String: Any], forKey key: String)
    func dictionarySafe(forKey key: String) -> [String: Any]?
}

extension UserDefaults: DefaultsLike {
    func setDictionarySafe(_ dict: [String: Any], forKey key: String) {
        do {
            let json = try JSONSerialization.data(withJSONObject: dict)
            self.set(json, forKey: key)
        } catch {
            print("[Statsig]: Failed to save to cache")
        }
    }

    func dictionarySafe(forKey key: String) -> [String: Any]? {
        do {
            guard let data = self.data(forKey: key) else {
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

class FileBasedUserDefaults: DefaultsLike {
    private let cacheUrl = FileManager
        .default.urls(for: .cachesDirectory, in: .userDomainMask)
        .first?.appendingPathComponent("statsig-cache.json")

    private let queue = DispatchQueue(
        label: "com.Statsig.FileBasedUserDefaults",
        qos: .userInitiated,
        attributes: .concurrent)

    private var data: [String: Any?] = [:]

    init() {
        readFromDisk()
    }

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
        queue.sync {
            guard self.data.index(forKey: defaultName) != nil else {
                return
            }

            self.data.removeValue(forKey: defaultName)
            _ = synchronize()
        }
    }

    func setValue(_ value: Any?, forKey: String) {
        set(value, forKey: forKey)
    }

    func set(_ value: Any?, forKey: String) {
        queue.sync {
            data[forKey] = value
            _ = synchronize()
        }
    }

    func synchronize() -> Bool {
        return writeToDisk()
    }

    func dictionaryRepresentation() -> [String : Any] {
        return data as [String: Any]
    }

    func setDictionarySafe(_ dict: [String: Any], forKey key: String) {
        // File storage doesn't actaully need this Safe func call, just call the standard .set
        set(dict, forKey: key)
    }

    func dictionarySafe(forKey key: String) -> [String: Any]? {
        // File storage doesn't actaully need this Safe func call, just call the standard .dictionary
        return dictionary(forKey: key)
    }

    private func getValue(forKey key: String) -> Any? {
        queue.sync {
            return data[key] as? Any
        }
    }

    private func writeToDisk() -> Bool {
        guard let url = cacheUrl else {
            return false
        }

        do {
            let json = try JSONSerialization.data(withJSONObject: data)
            try json.write(to: url)
        } catch {
            return false
        }

        return true
    }

    private func readFromDisk() {
        guard let url = cacheUrl else {
            return
        }

        do {
            let json = try Data(contentsOf: url)
            let dict = try JSONSerialization.jsonObject(with: json)
            data = dict as? [String: Any] ?? [:]
        } catch {
            return
        }
    }
}

class StatsigUserDefaults {
    static var defaults: DefaultsLike = UserDefaults.standard
}

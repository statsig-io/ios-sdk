import Foundation

class AtomicDictionary<T>
{
    private var internalDictionary:Dictionary<String, T>
    private let queue: DispatchQueue

    init(_ initialValues: [String: T] = [:], label: String = "com.Statsig.AtomicDictionary") {
        queue = DispatchQueue(label: label, attributes: .concurrent)
        internalDictionary = initialValues
    }

    subscript(key: String) -> T? {
        get {
            var value : T?
            self.queue.sync {
                value = self.internalDictionary[key]
            }

            return value
        }

        set {
            setValue(value: newValue, forKey: key)
        }
    }

    func setValue(value: T?, forKey key: String) {
        self.queue.async(flags: .barrier) {
            self.internalDictionary[key] = value
        }
    }

    func keys() -> [String] {
        var keys: [String] = []
        self.queue.sync {
            keys = self.internalDictionary.keys.sorted()
        }
        return keys
    }

    func toJsonData() -> Data? {
        var data: Data?
        self.queue.sync {
            do {
                data = try JSONSerialization.data(withJSONObject: self.internalDictionary)
            } catch {

            }
        }
        return data
    }
}

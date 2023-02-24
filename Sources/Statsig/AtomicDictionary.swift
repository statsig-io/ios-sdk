import Foundation

struct AtomicDictionary<T>
{
    private var internalDictionary:Dictionary<String, T>
    private let queue: DispatchQueue

    init(_ initialValues: [String: T] = [:], label: String = "com.Statsig.AtomicDictionary") {
        queue = DispatchQueue(label: label, qos: .userInitiated, attributes: .concurrent)
        internalDictionary = initialValues
    }

    subscript(key: String) -> T? {
        get {
            var value : T?
            self.queue.sync(flags: DispatchWorkItemFlags.barrier) {
                value = self.internalDictionary[key]
            }

            return value
        }

        set {
            setValue(value: newValue, forKey: key)
        }
    }

    mutating func setValue(value: T?, forKey key: String) {
        self.queue.sync(flags: DispatchWorkItemFlags.barrier) {
            self.internalDictionary[key] = value
        }
    }

    func keys() -> [String] {
        var keys: [String] = []
        self.queue.sync(flags: DispatchWorkItemFlags.barrier) {
            keys = self.internalDictionary.keys.sorted()
        }
        return keys
    }

    func toJsonData() -> Data? {
        var data: Data?
        self.queue.sync(flags: DispatchWorkItemFlags.barrier) {
            do {
                data = try JSONSerialization.data(withJSONObject: self.internalDictionary)
            } catch {

            }
        }
        return data
    }
}

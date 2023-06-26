import Foundation

class AtomicDictionary<T>
{
    private var internalDictionary:Dictionary<String, T>
    private let queue: DispatchQueue

    static func fromData(_ data: Data, label: String) -> AtomicDictionary<T> {
        let dict = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: T]
        return AtomicDictionary(dict ?? [:], label: label)
    }

    convenience init(label: String = "com.Statsig.AtomicDictionary") {
        self.init([:], label: label)
    }

    private init(_ initialValues: [String: T] = [:], label: String) {
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

    func toData() -> Data? {
        self.queue.sync {
            let dict = self.internalDictionary
            if #available(iOS 11.0, tvOS 11.0, *) {
                guard let data = try? NSKeyedArchiver.archivedData(withRootObject: dict, requiringSecureCoding: false) else {
                    print("[Statsig]: Failed create Data from AtomicDictionary")
                    return nil
                }
                return data
            } else {
                let data = NSKeyedArchiver.archivedData(withRootObject: dict)
                return data
            }
        }
    }
}

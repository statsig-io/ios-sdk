import Foundation

@objc(Layer)
public final class LayerObjC: NSObject {
    private var layer: Layer

    init(_ layer: Layer) {
        self.layer = layer
    }

    @objc public func getArray(forKey: String, defaultValue: [Any]) -> [Any] {
        return layer.getValue(forKey: forKey, defaultValue: defaultValue)
    }

    @objc public func getBool(forKey: String, defaultValue: Bool) -> Bool {
        return layer.getValue(forKey: forKey, defaultValue: defaultValue)
    }

    @objc public func getDictionary(forKey: String, defaultValue: [String: Any]) -> [String: Any] {
        return layer.getValue(forKey: forKey, defaultValue: defaultValue)
    }

    @objc public func getDouble(forKey: String, defaultValue: Double) -> Double {
        return layer.getValue(forKey: forKey, defaultValue: defaultValue)
    }

    @objc public func getInt(forKey: String, defaultValue: Int) -> Int {
        return layer.getValue(forKey: forKey, defaultValue: defaultValue)
    }

    @objc public func getString(forKey: String, defaultValue: String) -> String {
        return layer.getValue(forKey: forKey, defaultValue: defaultValue)
    }
}

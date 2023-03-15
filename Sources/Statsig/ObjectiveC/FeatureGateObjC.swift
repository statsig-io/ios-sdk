import Foundation

@objc(FeatureGate)
public final class FeatureGateObjC: NSObject {
    internal var gate: FeatureGate

    @objc public var name: String {
        gate.name
    }

    @objc public var ruleID: String {
        gate.ruleID
    }

    @objc public var value: Bool {
        gate.value
    }

    @objc public var secondaryExposures: [[String: String]] {
        gate.secondaryExposures
    }

    init(withGate: FeatureGate) {
        gate = withGate
    }

    @objc public func toData() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(gate)
    }

    @objc public static func fromData(_ data: Data) -> FeatureGateObjC? {
        let decoder = JSONDecoder()
        let swiftGate = try? decoder.decode(FeatureGate.self, from: data)
        guard let swiftGate = swiftGate else {
            return nil
        }

        return FeatureGateObjC(withGate: swiftGate)
    }
}

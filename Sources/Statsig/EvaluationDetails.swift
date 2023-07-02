import Foundation

public struct EvaluationDetails: Codable {
    let time: Double;
    let reason: EvaluationReason;

    init(reason: EvaluationReason, time: Double? = nil) {
        self.reason = reason
        self.time = time ?? NSDate().epochTimeInMs()
    }

    func toDictionary() -> [String: Any] {
        return [
            "time": time,
            "reason": reason.rawValue,
        ]
    }
}

public enum EvaluationReason: String, Codable {
    case Network;
    case NetworkNotModified;
    case Cache;
    case Sticky;
    case LocalOverride;
    case Unrecognized;
    case Uninitialized;
    case Bootstrap;
    case InvalidBootstrap;
}

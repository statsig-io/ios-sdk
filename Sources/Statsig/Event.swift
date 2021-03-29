import Foundation

struct Event {
    let name: String
    let value: Double?
    let metadata: [String:Codable]?
    let time: TimeInterval
    let user: StatsigUser

    static let statsigPrefix = "statsig::"
    static let configExposureEventName = "config_exposure"
    static let gateExposureEventName = "gate_exposure"

    init(user: StatsigUser, name: String, value: Double? = nil, metadata: [String:Codable]? = nil) {
        self.time = NSDate().timeIntervalSince1970 * 1000
        self.user = user
        self.name = name
        self.value = value
        self.metadata = metadata
    }

    static func statsigInternalEvent(
        user: StatsigUser,
        name: String,
        value: Double? = nil,
        metadata: [String:Codable]? = nil
    ) -> Event {
        return Event(user: user, name: self.statsigPrefix + name, value: value, metadata: metadata)
    }

    static func gateExposure(user: StatsigUser, gateName: String, gateValue: Bool) -> Event {
        return statsigInternalEvent(
            user: user,
            name: gateExposureEventName,
            value:nil,
            metadata: ["gate": gateName, "gateValue": gateValue])
    }

    static func configExposure(user: StatsigUser, configName: String, configGroup: String) -> Event {
        return statsigInternalEvent(
            user: user,
            name: configExposureEventName,
            value:nil,
            metadata: ["config": configName, "configGroup": configGroup])
    }

    func toDictionary() -> [String:Any] {
        var dict = [String:Any]()
        dict["eventName"] = name
        dict["user"] = user.toDictionary()
        dict["time"] = time
        if let value = value {
            dict["value"] = value
        }
        if let metadata = metadata {
            dict["metadata"] = metadata
        }

        return dict
    }
}

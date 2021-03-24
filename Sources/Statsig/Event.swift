import Foundation

struct Event {
    let name: String
    let value: Double?
    let metadata: [String:Any]?
    let time: TimeInterval
    
    static let statsigPrefix = "statsig::"
    static let configExposureEventName = "config_exposure"
    static let gateExposureEventName = "gate_exposure"

    init(name: String, value: Double? = nil, metadata: [String:Any]? = nil) {
        self.time = NSDate().timeIntervalSince1970
        self.name = name
        self.value = value
        self.metadata = metadata
    }

    static func statsigInternalEvent(
        name: String,
        value: Double? = nil,
        metadata: [String:Codable]? = nil
    ) -> Event {
        return Event(name: self.statsigPrefix + name, value: value, metadata: metadata)
    }

    static func gateExposure(gateName: String, gateValue: Bool) -> Event {
        return statsigInternalEvent(
            name: gateExposureEventName,
            value:nil,
            metadata: ["gate": gateName, "gateValue": gateValue])
    }

    static func configExposure(configName: String, configGroup: String) -> Event {
        return statsigInternalEvent(
            name: configExposureEventName,
            value:nil,
            metadata: ["config": configName, "configGroup": configGroup])
    }

    func toDictionary() -> [String:Any] {
        var dict = [String:Any]()
        dict["eventName"] = name
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

import Foundation

import UIKit

struct Event {
    let name: String
    let value: Any?
    let metadata: [String: String]?
    let time: TimeInterval
    let user: StatsigUser
    var statsigMetadata: [String: String]?

    static let statsigPrefix = "statsig::"
    static let configExposureEventName = "config_exposure"
    static let gateExposureEventName = "gate_exposure"
    static let currentVCKey = "currentPage"

    init(user: StatsigUser, name: String, value: Any? = nil, metadata: [String: String]? = nil,
         disableCurrentVCLogging: Bool) {
        self.time = NSDate().timeIntervalSince1970 * 1000
        self.user = user
        self.name = name
        self.value = value
        self.metadata = metadata
        if !disableCurrentVCLogging,
           let vc = UIApplication.shared.keyWindow?.rootViewController {
            self.statsigMetadata = [Event.currentVCKey: "\(vc.classForCoder)"]
        }
    }

    static func statsigInternalEvent(
        user: StatsigUser,
        name: String,
        value: Any? = nil,
        metadata: [String: String]? = nil,
        disableCurrentVCLogging: Bool = true // for internal events, default to not log the VC, other than for exposures
    ) -> Event {
        return Event(
            user: user,
            name: self.statsigPrefix + name,
            value: value,
            metadata: metadata,
            disableCurrentVCLogging: disableCurrentVCLogging)
    }

    static func gateExposure(
        user: StatsigUser,
        gateName: String,
        gateValue: Bool,
        disableCurrentVCLogging: Bool
    ) -> Event {
        return statsigInternalEvent(
            user: user,
            name: gateExposureEventName,
            value: nil,
            metadata: ["gate": gateName, "gateValue": String(gateValue)],
            disableCurrentVCLogging: disableCurrentVCLogging)
    }

    static func configExposure(
        user: StatsigUser,
        configName: String,
        configGroup: String,
        disableCurrentVCLogging: Bool
    ) -> Event {
        return statsigInternalEvent(
            user: user,
            name: configExposureEventName,
            value: nil,
            metadata: ["config": configName, "configGroup": configGroup],
            disableCurrentVCLogging: disableCurrentVCLogging)
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
        if let statsigMetadata = statsigMetadata {
            dict["statsigMetadata"] = statsigMetadata
        }

        return dict
    }
}

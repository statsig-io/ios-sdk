import Foundation


class Event {
    let name: String
    let value: Any?
    let metadata: [String: String]?
    let time: TimeInterval
    let user: [String: Any?]
    let secondaryExposures: [[String: String]]?
    var statsigMetadata: [String: String]?
    var allocatedExperimentHash: String?
    var isManualExposure: Bool = false

    static let statsigPrefix = "statsig::"
    static let configExposureEventName = "config_exposure"
    static let layerExposureEventName = "layer_exposure"
    static let gateExposureEventName = "gate_exposure"
    static let currentVCKey = "currentPage"

    init(
        user: StatsigUser,
        name: String,
        value: Any? = nil,
        metadata: [String: String]? = nil,
        secondaryExposures: [[String: String]]? = nil,
        disableCurrentVCLogging: Bool
    ) {
        self.time = Date().epochTimeInMs()
        self.user = user.toDictionary(forLogging: true)
        self.name = name
        self.value = value
        self.metadata = metadata
        self.secondaryExposures = secondaryExposures

        if !disableCurrentVCLogging {
            PlatformCompatibility.getRootViewControllerClassName { name in
                if let name = name {
                    self.statsigMetadata = [Event.currentVCKey: "\(name)"]
                }
            }
        }
    }

    func withManualExposureFlag(_ isManualExposure: Bool) -> Event {
        self.isManualExposure = isManualExposure
        return self
    }

    static func statsigInternalEvent(
        user: StatsigUser,
        name: String,
        value: Any? = nil,
        metadata: [String: String]? = nil,
        secondaryExposures: [[String: String]]? = nil,
        disableCurrentVCLogging: Bool = true // for internal events, default to not log the VC, other than for exposures
    ) -> Event {
        return Event(
            user: user,
            name: statsigPrefix + name,
            value: value,
            metadata: metadata,
            secondaryExposures: secondaryExposures,
            disableCurrentVCLogging: disableCurrentVCLogging
        )
    }

    static func gateExposure(
        user: StatsigUser,
        gateName: String,
        gateValue: Bool,
        ruleID: String,
        secondaryExposures: [[String: String]],
        evalDetails: EvaluationDetails,
        disableCurrentVCLogging: Bool
    ) -> Event {
        return statsigInternalEvent(
            user: user,
            name: gateExposureEventName,
            value: nil,
            metadata: [
                "gate": gateName,
                "gateValue": String(gateValue),
                "ruleID": ruleID,
                "reason": evalDetails.reason.rawValue,
                "time": String(evalDetails.time)
            ],
            secondaryExposures: secondaryExposures,
            disableCurrentVCLogging: disableCurrentVCLogging
        )
    }

    static func configExposure(
        user: StatsigUser,
        configName: String,
        ruleID: String,
        secondaryExposures: [[String: String]],
        evalDetails: EvaluationDetails,
        disableCurrentVCLogging: Bool
    ) -> Event {
        return statsigInternalEvent(
            user: user,
            name: configExposureEventName,
            value: nil,
            metadata: [
                "config": configName,
                "ruleID": ruleID,
                "reason": evalDetails.reason.rawValue,
                "time": String(evalDetails.time)
            ],
            secondaryExposures: secondaryExposures,
            disableCurrentVCLogging: disableCurrentVCLogging
        )
    }

    static func layerExposure(
        user: StatsigUser,
        configName: String,
        ruleID: String,
        secondaryExposures: [[String: String]],
        disableCurrentVCLogging: Bool,
        allocatedExperimentName: String,
        parameterName: String,
        isExplicitParameter: Bool,
        evalDetails: EvaluationDetails
    ) -> Event {
        return statsigInternalEvent(
            user: user,
            name: layerExposureEventName,
            value: nil,
            metadata: [
                "config": configName,
                "ruleID": ruleID,
                "allocatedExperiment": allocatedExperimentName,
                "parameterName": parameterName,
                "isExplicitParameter": "\(isExplicitParameter)",
                "reason": evalDetails.reason.rawValue,
                "time": String(evalDetails.time)
            ],
            secondaryExposures: secondaryExposures,
            disableCurrentVCLogging: disableCurrentVCLogging
        )
    }

    func toDictionary() -> [String: Any] {
        var metadataForLogging = metadata
        if isManualExposure {
            metadataForLogging = metadataForLogging ?? [:]
            metadataForLogging?["isManualExposure"] = "true"
        }

        return [
            "eventName": name,
            "user": user,
            "time": time,
            "value": value,
            "metadata": metadataForLogging,
            "statsigMetadata": statsigMetadata,
            "secondaryExposures": secondaryExposures,
            "allocatedExperimentHash": allocatedExperimentHash,
        ].compactMapValues { $0 }
    }
}

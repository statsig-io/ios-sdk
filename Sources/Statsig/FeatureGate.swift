struct FeatureGate: Codable {
    let name: String
    let ruleID: String
    let value: Bool
    let secondaryExposures: [[String: String]]
    let evaluationDetails: EvaluationDetails

    init(name: String, gateObj: [String: Any], evalDetails: EvaluationDetails) {
        self.name = name
        self.value = gateObj["value"] as? Bool ?? false
        self.ruleID = gateObj["rule_id"] as? String ?? ""
        self.secondaryExposures = gateObj["secondary_exposures"] as? [[String: String]] ?? []
        self.evaluationDetails = evalDetails
    }

    init(name: String, value: Bool, ruleID: String, evalDetails: EvaluationDetails) {
        self.name = name
        self.value = value
        self.ruleID = ruleID
        self.secondaryExposures = []
        self.evaluationDetails = evalDetails
    }
}

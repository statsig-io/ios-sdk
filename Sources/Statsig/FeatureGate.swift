struct FeatureGate: Codable {
    let name: String
    let ruleID: String
    let value: Bool

    init(name: String, gateObj: [String: Any]) {
        self.name = name
        self.value = gateObj["value"] as? Bool ?? false
        self.ruleID = gateObj["rule_id"] as? String ?? ""
    }

    init(name: String, value: Bool, ruleID: String) {
        self.name = name
        self.value = value
        self.ruleID = ruleID ?? ""
    }
}

import Foundation

public protocol ConfigBase {
    var name: String { get }
    var ruleID: String { get }
    var evaluationDetails: EvaluationDetails { get }
}

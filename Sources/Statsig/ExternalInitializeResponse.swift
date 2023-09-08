public struct ExternalInitializeResponse {
    public let values: String?
    public let evaluationDetails: EvaluationDetails

    public static func uninitialized() -> ExternalInitializeResponse {
        return ExternalInitializeResponse(
            values: nil,
            evaluationDetails: EvaluationDetails.init(reason: .Uninitialized)
        )
    }

}

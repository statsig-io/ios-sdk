class OverallMarker: MarkerBase {
    convenience init(_ recorder: MarkerAtomicDict) {
        self.init(recorder, context: .initialize, markerKey: "overall")
    }

    func start() {
        super.start([:])
    }

    func end(success: Bool, details: EvaluationDetails, errorMessage: String?) {
        var args: [String: Any] = [
            "success": success,
            "evaluationDetails": details.toDictionary()
        ]

        if let message = errorMessage {
            args["error"] = [
                "name": "Error",
                "message": message
            ]
        }

        super.end(args)
    }
}

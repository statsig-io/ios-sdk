class NetworkMarker: MarkerBase {
    let step = "network_request"

    convenience init(_ recorder: MarkerAtomicDict, key: String) {
        self.init(recorder, context: .initialize, markerKey: key)
    }

    func start(attempt: Int) {
        super.start([
            "step": step,
            "attempt": attempt
        ])
    }

    func end(success: Bool, attempt: Int, status: Int?, region: String?) {
        var args: [String: Any] = [
            "step": step,
            "success": success,
            "attempt": attempt,
        ]

        if let status = status {
            args["statusCode"] = status
        }

        if let region = region {
            args["sdkRegion"] = region
        }

        super.end(args)
    }
}

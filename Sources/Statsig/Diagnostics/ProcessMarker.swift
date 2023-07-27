class ProcessMarker: MarkerBase {
    let step = "process"

    convenience init(_ recorder: MarkerAtomicDict, key: String) {
        self.init(recorder, context: .initialize, markerKey: key)
    }

    func start() {
        super.start([
            "step": step,
        ])
    }

    func end(success: Bool) {
        super.end([
            "step": step,
            "success": success,
        ])
    }
}

class OverallMarker: MarkerBase {
    convenience init(_ recorder: MarkerAtomicDict) {
        self.init(recorder, context: .initialize, markerKey: "overall")
    }

    func start() {
        super.start([:])
    }

    func end(success: Bool) {
        super.end([
            "success": success
        ])
    }
}

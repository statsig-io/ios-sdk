class InitializeMarkers {
    let key = "initialize"
    let network: NetworkMarker
    let process: ProcessMarker

    init(_ recorder: MarkerAtomicDict) {
        self.network = NetworkMarker(recorder, key: key)
        self.process = ProcessMarker(recorder, key: key)
    }
}

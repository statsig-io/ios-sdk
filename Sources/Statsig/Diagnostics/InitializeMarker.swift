class InitializeMarkers {
    let key = "initialize"
    let network: NetworkMarker
    let process: ProcessMarker
    let readCache: ReadCacheMarker

    init(_ recorder: MarkerAtomicDict) {
        self.network = NetworkMarker(recorder, key: key)
        self.process = ProcessMarker(recorder, key: key)
        self.readCache = ReadCacheMarker(recorder, key: key)
    }
}

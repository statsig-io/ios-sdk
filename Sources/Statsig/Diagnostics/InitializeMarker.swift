class InitializeMarkers {
    let key = "initialize"
    let network: NetworkMarker
    let createCache: CreateCacheMarker
    let readCache: InitializeStepMarker
    let loggerStart: InitializeStepMarker
    let storeRead: InitializeStepMarker
    let netThreadJump: InitializeStepMarker
    let process: InitializeStepMarker

    init(_ recorder: MarkerAtomicDict) {
        self.network = NetworkMarker(recorder, key: key)
        self.createCache = CreateCacheMarker(recorder, key: key)
        self.readCache = InitializeStepMarker(recorder, key: key, step: "load_cache")
        self.loggerStart = InitializeStepMarker(recorder, key: key, step: "logger_start")
        self.storeRead = InitializeStepMarker(recorder, key: key, step: "store_read")
        self.netThreadJump = InitializeStepMarker(recorder, key: key, step: "net_thread_jump")
        self.process = InitializeStepMarker(recorder, key: key, step: "process")
    }
}

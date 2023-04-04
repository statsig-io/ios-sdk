import Foundation

class StorageKeys {
    static let localOverridesKey = "com.Statsig.InternalStore.localOverridesKey"
    static let localStorageKey = "com.Statsig.StorageKeys.localStorageKeyV2"
    static let stickyDeviceExperimentsKey = "com.Statsig.StorageKeys.stickyDeviceExperimentsKey"

    static let DEPRECATED_localStorageKey = "com.Statsig.StorageKeys.localStorageKey"
    static let DEPRECATED_stickyUserExperimentsKey = "com.Statsig.InternalStore.stickyUserExperimentsKey"
    static let DEPRECATED_stickyUserIDKey = "com.Statsig.InternalStore.stickyUserIDKey"

    static let gatesKey = "feature_gates"
    static let configsKey = "dynamic_configs"
    static let stickyExpKey = "sticky_experiments"
    static let layerConfigsKey = "layer_configs"
    static let evalTimeKey = "evaluation_time"
    static let userHashKey = "user_hash"
}

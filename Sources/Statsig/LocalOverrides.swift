import Foundation

public struct StatsigOverrides {
    public let gates: [String: Bool]
    public let configs: [String: [String: Any]]
    public let layers: [String: [String: Any]]

    internal init(_ localOverrides: LocalOverrides) {
        gates = localOverrides.gates
        configs = localOverrides.configs
        layers = localOverrides.layers
    }
}

internal class LocalOverrides {
    public var gates: [String: Bool]
    public var configs: [String: [String: Any]]
    public var layers: [String: [String: Any]]

    public static func empty() -> LocalOverrides {
        return LocalOverrides(gates: [:], configs: [:], layers: [:])
    }

    public static func loadedOrEmpty() -> LocalOverrides {
        guard let dict = StatsigUserDefaults.defaults.dictionarySafe(forKey: StorageKeys.localOverridesKey) else {
            return LocalOverrides.empty()
        }

        let gates = dict[StorageKeys.gatesKey] as? [String: Bool] ?? [:]
        let configs = dict[StorageKeys.configsKey] as? [String: [String: Any]] ?? [:]
        let layers = dict[StorageKeys.layerConfigsKey] as? [String: [String: Any]] ?? [:]

        return LocalOverrides(gates: gates, configs: configs, layers: layers)
    }

    public func removeOverride(_ name: String) {
        self.gates.removeValue(forKey: name)
        self.configs.removeValue(forKey: name)
        self.layers.removeValue(forKey: name)
    }

    public func save() {
        StatsigUserDefaults.defaults.setDictionarySafe([
            StorageKeys.gatesKey: gates,
            StorageKeys.configsKey: configs,
            StorageKeys.layerConfigsKey: layers,
        ], forKey: StorageKeys.localOverridesKey)
    }

    private init(gates: [String : Bool], configs: [String : [String : Any]], layers: [String : [String : Any]]) {
        self.gates = gates
        self.configs = configs
        self.layers = layers
    }
}

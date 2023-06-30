@testable import Statsig

extension InternalStore {
    convenience init(_ user: StatsigUser) {
        self.init(user, options: StatsigOptions())
    }
}

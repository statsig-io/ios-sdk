
public protocol StatsigListening: AnyObject {
    func onInitialized(_ error: String?)
    func onUserUpdated(_ error: String?)
}

public extension StatsigListening {
    func onInitialized(_ error: String?) {

    }

    func onUserUpdated(_ error: String?) {

    }
}

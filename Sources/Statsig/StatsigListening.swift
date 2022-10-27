/**
 A delegate protocol that you can implement in your own class to be alerted when Statsig performs Initialize and Update operations. The implementor of this protocol should be handed to `Statsig.addListener`.

 The `StatsigListening` protocol has two optional methods that can be implemented:

 `onInitialized` - Will be called when the initialize request is returned in `Statsig.start()`. An error string may be passed to this function if something went wrong with the network request.

 `onUserUpdated` - Will be called when the network request for `Statsig.updateUser()` is returned. An error string may be passed to this function if something went wrong with the network request.

 */
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

import Foundation


/**
 A protocol used to suppress deprecation warnings internally
 */
@objc public protocol StatsigListeningInternal {
    func onInitialized(_ error: String?)
    func onUserUpdated(_ error: String?)
}

/**
 A delegate protocol that you can implement in your own class to be alerted when Statsig performs Initialize and Update operations. The implementor of this protocol should be handed to `Statsig.addListener`.

 The `StatsigListening` protocol has four optional methods that can be implemented:

 `onInitializedWithResult` - Will be called when the initialize request is returned in `Statsig.initialize()`. A `StatsigClientError` object may be passed to this function if something went wrong with the network request.

 `onUserUpdatedWithResult` - Will be called when the network request for `Statsig.updateUserWithResult()` is returned. A `StatsigClientError` object may be passed to this function if something went wrong with the network request.
 
 `onInitialized` (deprecated) - Will be called when the initialize request is returned in `Statsig.initialize()`. An error string may be passed to this function if something went wrong with the network request.
 
 `onUserUpdated` (deprecated) - Will be called when the network request for `Statsig.updateUserWithResult()` is returned. An error string may be passed to this function if something went wrong with the network request.

 */
@objc public protocol StatsigListening: AnyObject, StatsigListeningInternal {
    func onInitializedWithResult(_ error: StatsigClientError?)
    func onUserUpdatedWithResult(_ error: StatsigClientError?)

    @available(*, deprecated, message: "Implement `onInitializedWithResult` instead")
    func onInitialized(_ error: String?)
    @available(*, deprecated, message: "Implement `onUserUpdatedWithResult` instead")
    func onUserUpdated(_ error: String?)
}

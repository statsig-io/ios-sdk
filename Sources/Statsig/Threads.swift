import Foundation

/**
 Runs the block on the main thread. If called from the main thread,
 it's executed synchronously. Otherwise, an async execution is queued.
 */
internal func ensureMainThread(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.async(execute: block)
    }
}

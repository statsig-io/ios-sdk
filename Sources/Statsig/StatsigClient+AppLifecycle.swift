import Foundation

extension StatsigClient {
    internal func subscribeToApplicationLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillBackground),
            name: PlatformCompatibility.willResignActiveNotification,
            object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: PlatformCompatibility.willTerminateNotification,
            object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillForeground),
            name: PlatformCompatibility.willEnterForegroundNotification,
            object: nil)
    }

    internal func unsubscribeFromApplicationLifecycle() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appWillForeground() {
        logger.start()
    }

    @objc private func appWillBackground() {
        DispatchQueue.global().async { [weak self] in
            self?.logger.stop()
        }
    }

    @objc private func appWillTerminate() {
        logger.stop()
    }
}

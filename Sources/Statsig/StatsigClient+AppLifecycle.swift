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
            guard let self = self else {
                return
            }

            if (self.statsigOptions.shutdownOnBackground) {
                self.logger.stop()
            } else {
                self.logger.flush()
            }
        }
    }

    @objc private func appWillTerminate() {
        logger.stop()
    }
}

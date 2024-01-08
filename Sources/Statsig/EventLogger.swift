import Foundation

class EventLogger {
    internal static let failedLogsKey = "com.Statsig.EventLogger.loggingRequestUserDefaultsKey"
    private static let eventQueueLabel = "com.Statsig.eventQueue"

    let networkService: NetworkService
    let userDefaults: DefaultsLike

    let logQueue = DispatchQueue(label: eventQueueLabel, qos: .userInitiated)
    let failedRequestLock = NSLock()

    var maxEventQueueSize: Int = 50
    var events: [Event]
    var failedRequestQueue: [Data]
    var loggedErrorMessage: Set<String>
    var flushTimer: Timer?
    var user: StatsigUser

    #if os(tvOS)
        let MAX_SAVED_LOG_REQUEST_SIZE = 100_000 //100 KB
    #else
        let MAX_SAVED_LOG_REQUEST_SIZE = 1_000_000 //1 MB
    #endif

    init(user: StatsigUser, networkService: NetworkService, userDefaults: DefaultsLike = StatsigUserDefaults.defaults) {
        self.events = [Event]()
        self.failedRequestQueue = [Data]()
        self.user = user
        self.networkService = networkService
        self.loggedErrorMessage = Set<String>()
        self.userDefaults = userDefaults

        if let localCache = userDefaults.array(forKey: EventLogger.failedLogsKey) as? [Data] {
            self.failedRequestQueue = localCache
        }

        userDefaults.removeObject(forKey: EventLogger.failedLogsKey)

        networkService.sendRequestsWithData(failedRequestQueue) { [weak self] failedRequestsData in
            guard let failedRequestsData = failedRequestsData else { return }
            DispatchQueue.main.async { [weak self] in
                self?.addFailedLogRequest(failedRequestsData)
            }
        }
    }

    func log(_ event: Event) {
        logQueue.async { [weak self] in
            guard let self = self else { return }

            self.events.append(event)

            if (self.events.count >= self.maxEventQueueSize) {
                self.flush()
            }
        }
    }

    func start(flushInterval: Double = 60) {
        DispatchQueue.main.async { [weak self] in
            self?.flushTimer?.invalidate()
            self?.flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
                self?.flush()
            }
        }
    }

    func stop() {
        flushTimer?.invalidate()
        logQueue.sync {
            self.flushInternal(isShuttingDown: true)
        }
    }

    func flush() {
        logQueue.async { [weak self] in
            self?.flushInternal()
        }
    }

    private func flushInternal(isShuttingDown: Bool = false) {
        if events.isEmpty {
            return
        }

        let oldEvents = events
        events = []

        let capturedSelf = isShuttingDown ? self : nil
        networkService.sendEvents(forUser: user, events: oldEvents) {
            [weak self, capturedSelf] errorMessage, requestData in
            guard let self = self ?? capturedSelf else { return }

            if errorMessage == nil {
                return
            }

            self.addSingleFailedLogRequest(requestData)
            self.saveFailedLogRequestsToDisk()

            if let errorMessage = errorMessage, !self.loggedErrorMessage.contains(errorMessage) {
                self.loggedErrorMessage.insert(errorMessage)
                self.log(Event.statsigInternalEvent(user: self.user, name: "log_event_failed", value: nil,
                                                    metadata: ["error": errorMessage]))
            }
        }
    }

    private func addSingleFailedLogRequest(_ requestData: Data?) {
        guard let data = requestData else { return }

        addFailedLogRequest([data])
    }

    private func addFailedLogRequest(_ requestData: [Data]) {
        failedRequestLock.lock()
        defer { failedRequestLock.unlock() }

        failedRequestQueue += requestData

        while (failedRequestQueue.count > 0
               && failedRequestQueue.reduce(0,{ $0 + $1.count }) > MAX_SAVED_LOG_REQUEST_SIZE) {
            failedRequestQueue.removeFirst()
        }
    }

    private func saveFailedLogRequestsToDisk() {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync { saveFailedLogRequestsToDisk() }
            return
        }

        userDefaults.setValue(
            failedRequestQueue,
            forKey: EventLogger.failedLogsKey
        )
    }

    static func deleteLocalStorage() {
        StatsigUserDefaults.defaults.removeObject(forKey: EventLogger.failedLogsKey)
    }
}

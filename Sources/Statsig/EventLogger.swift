import Foundation

class EventLogger {
    internal static let loggingRequestUserDefaultsKey = "com.Statsig.EventLogger.loggingRequestUserDefaultsKey"
    private static let eventQueueLabel = "com.Statsig.eventQueue"
    var flushBatchSize: Int = 50
    let maxEventQueueSize: Int = 1000

    var events: [Event]
    var failedRequestQueue: [Data]
    var loggedErrorMessage: Set<String>
    var flushTimer: Timer?
    var user: StatsigUser
    let networkService: NetworkService
    let userDefaults: UserDefaults

    let logQueue = DispatchQueue(label: eventQueueLabel, qos: .userInitiated)

    let MAX_SAVED_LOG_REQUEST_SIZE = 1_000_000 //1MB

    init(user: StatsigUser, networkService: NetworkService, userDefaults: UserDefaults = UserDefaults.standard) {
        self.events = [Event]()
        self.failedRequestQueue = [Data]()
        self.user = user
        self.networkService = networkService
        self.loggedErrorMessage = Set<String>()
        self.userDefaults = userDefaults

        if let localCache = userDefaults.array(forKey: EventLogger.loggingRequestUserDefaultsKey) as? [Data] {
            self.failedRequestQueue = localCache
        }
        userDefaults.removeObject(forKey: EventLogger.loggingRequestUserDefaultsKey)

        networkService.sendRequestsWithData(failedRequestQueue) { [weak self] failedRequestsData in
            guard let failedRequestsData = failedRequestsData, let self = self else { return }
            DispatchQueue.main.async {
                self.addFailedLogRequest(failedRequestsData)
            }
        }
    }

    func log(_ event: Event) {
        logQueue.sync { [weak self] in
            guard let self = self else { return }
            if (self.events.count > self.maxEventQueueSize) {
                self.events = Array(self.events.prefix(self.maxEventQueueSize))
            } else {
                self.events.append(event)
            }

            if (self.events.count >= self.flushBatchSize) {
                self.flush()
            }
        }
    }

    func start(flushInterval: Double = 60) {
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.flush()
        }
    }

    func stop() {
        flushTimer?.invalidate()
        logQueue.sync {
            self.flushInternal(shutdown: true)
        }
    }

    func flush() {
        logQueue.async {
            self.flushInternal(shutdown: false)
        }
    }

    private func flushInternal(shutdown: Bool = false) {
        if events.isEmpty {
            return
        }

        let oldEvents = events
        events = [Event]()
        networkService.sendEvents(forUser: user, events: oldEvents) { [weak self] errorMessage, requestData in
            guard let self = self else { return }

            if errorMessage == nil {
                return
            }

            // when shutting down, save request data locally to be sent next time instead of adding it back to event queue
            if shutdown {
                DispatchQueue.main.sync { [self] in
                    self.addFailedLogRequest(requestData)
                    self.userDefaults.setValue(self.failedRequestQueue, forKey: EventLogger.loggingRequestUserDefaultsKey)
                }
                return
            }

            self.logQueue.sync {
                self.events = oldEvents + self.events // add old events back to the queue if request fails
                self.flushBatchSize = min(self.events.count * 2, self.maxEventQueueSize)
            }

            if let errorMessage = errorMessage, !self.loggedErrorMessage.contains(errorMessage) {
                self.loggedErrorMessage.insert(errorMessage)
                self.log(Event.statsigInternalEvent(user: self.user, name: "log_event_failed", value: nil,
                                                    metadata: ["error": errorMessage]))
            }
        }
    }

    private func addFailedLogRequest(_ requestData: Data?) {
        guard let data = requestData else { return }

        addFailedLogRequest([data])
    }

    private func addFailedLogRequest(_ requestData: [Data]) {
        self.failedRequestQueue += requestData

        while (self.failedRequestQueue.count > 0
               && self.failedRequestQueue.reduce(0,{ $0 + $1.count }) > MAX_SAVED_LOG_REQUEST_SIZE) {
            self.failedRequestQueue.removeFirst()
        }
    }

    static func deleteLocalStorage() {
        UserDefaults.standard.removeObject(forKey: EventLogger.loggingRequestUserDefaultsKey)
    }
}

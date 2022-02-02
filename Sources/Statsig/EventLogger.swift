import Foundation

class EventLogger {
    private static let loggingRequestUserDefaultsKey = "com.Statsig.EventLogger.loggingRequestUserDefaultsKey"
    private static let eventQueueLabel = "com.Statsig.eventQueue"
    var flushBatchSize: Int = 50
    let maxEventQueueSize: Int = 1000

    var events: [Event]
    var requestQueue: [Data]
    var loggedErrorMessage: Set<String>
    var flushTimer: Timer?
    var user: StatsigUser
    let networkService: NetworkService

    let logQueue = DispatchQueue(label: eventQueueLabel, qos: .userInitiated)

    init(user: StatsigUser, networkService: NetworkService) {
        self.events = [Event]()
        self.requestQueue = [Data]()
        self.user = user
        self.networkService = networkService
        self.loggedErrorMessage = Set<String>()
        if let localCache = UserDefaults.standard.array(forKey: EventLogger.loggingRequestUserDefaultsKey) as? [Data] {
            self.requestQueue = localCache
        }
        UserDefaults.standard.removeObject(forKey: EventLogger.loggingRequestUserDefaultsKey)

        networkService.sendRequestsWithData(requestQueue) { [weak self] failedRequestsData in
            guard let failedRequestsData = failedRequestsData, let self = self else { return }
            DispatchQueue.main.async {
                self.requestQueue += failedRequestsData
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
                DispatchQueue.main.sync {
                    if let requestData = requestData {
                        self.requestQueue.append(requestData)
                    }
                    UserDefaults.standard.setValue(self.requestQueue, forKey: EventLogger.loggingRequestUserDefaultsKey)
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

    static func deleteLocalStorage() {
        UserDefaults.standard.removeObject(forKey: EventLogger.loggingRequestUserDefaultsKey)
    }
}

import Foundation

class EventLogger {
    private static let loggingRequestUserDefaultsKey = "com.Statsig.EventLogger.loggingRequestUserDefaultsKey"
    var flushBatchSize: Int = 10
    var flushInterval: Double = 60
    let maxEventQueueSize: Int = 1000

    var eventQueue: [Event]
    var requestQueue: [Data]
    var loggedErrorMessage: Set<String>
    var flushTimer: Timer?
    var user: StatsigUser
    let networkService: NetworkService

    init(user: StatsigUser, networkService: NetworkService) {
        self.eventQueue = [Event]()
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
            self.requestQueue += failedRequestsData
        }
    }
    
    func log(_ event: Event) {
        eventQueue.append(event)

        while eventQueue.count > maxEventQueueSize {
            eventQueue.removeFirst()
        }

        if eventQueue.count >= self.flushBatchSize {
            flush()
        } else {
            flushTimer?.invalidate()
            flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: false) { [weak self] timer in
                guard let self = self else { return }
                self.flush()
            }
        }
    }

    func flush(shutdown: Bool = false) {
        flushTimer?.invalidate()
        if eventQueue.isEmpty {
            return
        }

        let oldQueue = eventQueue
        eventQueue = [Event]()
        networkService.sendEvents(forUser: user, events: oldQueue) { [weak self] errorMessage, requestData in
            guard let self = self else { return }
            if errorMessage == nil {
                return
            }

            // when shutting down, save request data locally to be sent next time instead of adding it back to event queue
            if shutdown {
                if let requestData = requestData {
                    self.requestQueue.append(requestData)
                }
                UserDefaults.standard.setValue(self.requestQueue, forKey: EventLogger.loggingRequestUserDefaultsKey)
                return
            }

            self.eventQueue = oldQueue + self.eventQueue // add old events back to the queue if request fails
            self.flushBatchSize = min(self.eventQueue.count * 2, self.maxEventQueueSize)
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

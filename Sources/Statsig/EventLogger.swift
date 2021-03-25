import Foundation

class EventLogger {
    var flushBatchSize: Int = 10
    let flushInterval: Double = 60
    let maxEventQueueSize: Int = 1000

    var eventQueue: [Event]
    var flushTimer: Timer?
    var user: StatsigUser
    let networkService: StatsigNetworkService
    
    init(user: StatsigUser, networkService: StatsigNetworkService) {
        self.eventQueue = [Event]()
        self.user = user
        self.networkService = networkService
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

    func flush() {
        flushTimer?.invalidate()
        if eventQueue.isEmpty {
            return
        }

        let oldQueue = eventQueue
        networkService.sendEvents(forUser: user, events: oldQueue) { [weak self] errorMessage in
            guard let self = self else { return }
            if errorMessage == nil {
                return
            }
            self.log(Event.statsigInternalEvent(user: self.user, name: "log_event_failed"))
            self.eventQueue = oldQueue + self.eventQueue // add old events back to the queue if request fails
            self.flushBatchSize = min(self.eventQueue.count + 1, self.maxEventQueueSize)
        }
    }
}

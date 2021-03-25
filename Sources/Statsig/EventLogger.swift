import Foundation

class EventLogger {
    var eventQueue: [Event]
    var flushTimer: Timer?
    var flushBatchSize: Int = 10
    var flushInterval: Double = 60
    var maxEventQueueSize: Int = 1000
    
    private let networkService: StatsigNetworkService
    
    init(networkService: StatsigNetworkService) {
        self.eventQueue = [Event]()
        self.networkService = networkService
    }
    
    func log(event: Event) {
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
        networkService.sendEvents(oldQueue) { [weak self] errorMessage in
            guard let self = self else { return }
            if errorMessage == nil {
                return
            }
            //log(event: Event.statsigInternalEvent(user: <#T##StatsigUser#>, name: <#T##String#>))
            self.eventQueue = oldQueue + self.eventQueue // add old events back to the queue if request fails
            self.flushBatchSize = min(self.eventQueue.count + 1, self.maxEventQueueSize)
        }
    }
}

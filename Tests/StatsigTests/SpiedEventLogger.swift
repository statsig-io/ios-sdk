import Foundation
@testable import Statsig

class SpiedEventLogger: EventLogger {
    var timerInstances: [Timer] = []
    var timesFlushCalled = 0
    var timesShutdownCalled = 0

    override func start(flushInterval: Double = 60) {
        super.start(flushInterval: flushInterval)

        DispatchQueue.main.async {
            self.timerInstances.append(self.flushTimer!)
        }
    }

    override func flush() {
        super.flush()
        timesFlushCalled += 1
    }

    override func stop() {
        super.stop()
        timesShutdownCalled += 1
    }
}

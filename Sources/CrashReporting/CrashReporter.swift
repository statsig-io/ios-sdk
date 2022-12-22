internal class CrashReporter: CrashReportable {
    // Flush once on start, but give the app time to boot up
    let waitSecondsUntilFlush = 5.0
    let network: NetworkService

    init(_ network: NetworkService) {
        let instance = KSCrash.sharedInstance()
        instance?.install()

        self.network = network

        DispatchQueue
            .global(qos: .background)
            .asyncAfter(deadline: .now() + waitSecondsUntilFlush) { [weak self] in
                self?.flush()
            }
    }

    func updateUser(_ user: StatsigUser) {
        let instance = KSCrash.sharedInstance()
        instance?.userInfo = [
            "userID": user.userID ?? "",
            "customIDs": user.customIDs ?? [:],
            "deviceEnvironment": user.deviceEnvironment,
            "statsigEnvironment": user.statsigEnvironment
        ]
    }

    func getCrashReports() -> [String : Any] {
        let instance = KSCrash.sharedInstance()
        guard let reportIDs = instance?.reportIDs() as? [NSNumber] else {
            return [:]
        }

        var reports: [String: Any] = [:]
        reportIDs.forEach() { id in
            guard let report = instance?.report(withID: id) as? [String: Any] else {
                reports["\(id)"] = ["message": "Failed to load report"]
                return
            }

            reports["\(id)"] = report
        }

        return reports
    }

    private func flush() {
        let instance = KSCrash.sharedInstance()
        guard let instance = instance, let reportIDs = instance.reportIDs() as? [NSNumber] else {
            return
        }

        for reportID in reportIDs {
            let report = instance.report(withID: reportID) as? [String: Any]
            ?? ["message": "Failed to load report"]
            
            let user = StatsigUser.fromCrashReport(report)
            let events = [Event.fromCrashReport(report, user: user)]
            self.network
                .sendEvents(forUser: user, events: events) { err, data in
                    if err != nil {
                        // Well get it next time
                        return
                    }

                    instance.deleteReport(withID: reportID)
                }
        }
    }
}

fileprivate extension StatsigUser {
    static func fromCrashReport(_ report: [String: Any]) -> StatsigUser {
        var user = StatsigUser()

        if let userData = report["user"] as? [String: Any] {
            user = StatsigUser(
                userID: userData["userID"] as? String,
                customIDs: userData["customIDs"] as? [String: String]
            )

            let device = userData["deviceEnvironment"] as? [String: String?]
            user.deviceEnvironment = device ?? [:]

            let env = userData["statsigEnvironment"] as? [String: String]
            user.statsigEnvironment = env ?? [:]
        } else {
            user.deviceEnvironment = [:]
            user.statsigEnvironment = [:]
        }

        return user
    }
}

fileprivate extension Event {
    static func fromCrashReport(_ report: [String: Any], user: StatsigUser) -> Event {
        return Event.statsigInternalEvent(
            user: user,
            name: Event.statsigPrefix + "crash_report",
            value: nil,
            metadata: ["report": report],
            secondaryExposures: nil,
            disableCurrentVCLogging: true
        )
    }
}

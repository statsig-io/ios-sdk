import Foundation

protocol CrashReportable {
    func updateUser(_ user: StatsigUser)
}

internal class CrashReporterProvider {
    static func attachCrashReporter(_ network: NetworkService, user: StatsigUser) -> CrashReportable? {
#if STATSIG_CRASH_REPORTING || canImport(KSCrash_Installations)
        let reporter = CrashReporter(network)
        reporter.updateUser(user)
        return reporter
#else
        return nil
#endif
    }
}

#if STATSIG_CRASH_REPORTING || canImport(KSCrash_Installations)

#if canImport(KSCrash_Installations)
import KSCrash_Installations
#endif

internal class CrashReporter: CrashReportable {
    // Flush once on start, but wait X seconds giving the app time to boot up
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

    private func flush() {
        let instance = KSCrash.sharedInstance()
        guard let instance = instance, let reportIDs = instance.reportIDs() as? [NSNumber] else {
            return
        }

        for reportID in reportIDs {
            let report = instance.report(withID: reportID) as? [String: Any]
            ?? ["message": "Failed to load report"]

            let user = StatsigUser.fromCrashReport(report)
            let event = Event.fromCrashReport(report, user: user)
            self.network.sendCrashReportEvent(event) { success in
                if success != true {
                    // We'll get it next time
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
            name: "crash_report",
            value: nil,
            metadata: report,
            secondaryExposures: nil,
            disableCurrentVCLogging: true
        )
    }
}

#endif

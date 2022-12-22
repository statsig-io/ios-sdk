import Foundation

protocol CrashReportable {
    func updateUser(_ user: StatsigUser)
    func getCrashReports() -> [String: Any]
}

internal class CrashReporterProvider {
    static func attachCrashReporter(_ network: NetworkService, user: StatsigUser) -> CrashReportable? {
#if STATSIG_CRASH_REPORTING
        let reporter = CrashReporter(network)
        reporter.updateUser(user)
        return reporter
#else
        return nil
#endif
    }
}

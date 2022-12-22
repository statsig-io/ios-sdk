import Foundation

protocol CrashReportable {}

internal class CrashReporterProvider {
    static func getCrashReporter() -> CrashReportable? {
#if STATSIG_CRASH_REPORTING
        return CrashReporter()
#else
        return nil
#endif

    }
}

internal class CrashReporter: CrashReportable {
    init() {
        UserDefaults.standard.removeObject(forKey: "com.dloomb.crash")

        let instance = KSCrash.sharedInstance()
        instance?.install()
        instance?.userInfo = ["SessionID": "A-Session"]

        guard let reportIDs = instance?.reportIDs() as? [NSNumber] else {
            return
        }

        for reportID in reportIDs {
            let report = instance?.report(withID: reportID)
            UserDefaults.standard.setValue("\(report)", forKey: "com.dloomb.crash")
        }

        instance?.deleteAllReports()
    }
}

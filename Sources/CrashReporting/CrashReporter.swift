import KSCrash

internal class CrashReporter {
//    var installation: KSCrashInstallationStatsig?
    var kscrash: KSCrash?

    init() {
        UserDefaults.standard.removeObject(forKey: "com.dloomb.crash")

        let path = Bundle.main.bundlePath

        let instance = KSCrash.sharedInstance()!
//        kscrash = instance
        instance.install()
        instance.userInfo = ["SessionID": "A-Session"]

        guard let reportIDs = instance.reportIDs() as? [NSNumber] else {
            return
        }

//        let formatter = KSCrashReportFilterAppleFmt(reportStyle: KSAppleReportStyleSymbolicated)



        for reportID in reportIDs {
            let report = instance.report(withID: reportID)
            UserDefaults.standard.setValue("\(report)", forKey: "com.dloomb.crash")
//            formatter?.filterReports([report]) { a, b, c in
//                UserDefaults.standard.setValue("\((a as! [String])[0])", forKey: "com.dloomb.crash")
//            }

        }

//        instance?.sendAllReports() {  reports, completed, error in
//            //            UserDefaults.standard.setValue(reports, forKey: "com.dloomb.crash")
//        }

//        installation = KSCrashInstallationStatsig()
//        installation?.install()
//        installation?.sendAllReports() { reports, completed, error in
//            UserDefaults.standard.setValue(reports, forKey: "com.dloomb.crash")
////            print("\(String(describing: reports))")
//        }
    }
}

//internal class KSCrashInstallationStatsig: KSCrashInstallation {
//    override init() {
//        super.init(requiredProperties:[])
//    }
//
//    override func sink() -> KSCrashReportFilter {
//        return KSCrashReportFilterAppleFmt(reportStyle: KSAppleReportStyleSymbolicated)
//    }
//}

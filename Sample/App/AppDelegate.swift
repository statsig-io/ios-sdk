import UIKit

enum DemoType {
    case swiftBasic
//    case swiftSyncInit

    case objcBasic
    case objcPerf
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        window = UIWindow()
        window?.rootViewController = getViewController(.objcPerf)
        window?.makeKeyAndVisible()

        return true
    }

    private func getViewController(_ type: DemoType) -> UIViewController {
        switch type {
        case .swiftBasic:
            return BasicOnDeviceEvaluationsViewController()

//        case .swiftSyncInit:
//            return SynchronousInitViewController()

        case .objcBasic:
            return BasicOnDeviceEvaluationsViewControllerObjC()

        case .objcPerf:
            return PerfOnDeviceEvaluationsViewControllerObjC()
        }

    }
}


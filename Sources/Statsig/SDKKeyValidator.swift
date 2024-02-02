import Foundation

class SDKKeyValidator {
    static func validate(
        _ sdkKey: String?,
        _ values: [String: Any]
    ) -> Bool {
        guard let sdkKey = sdkKey,
              let keyUsedHash = values["hashed_sdk_key_used"] as? String else {
            return true
        }

        if keyUsedHash == sdkKey.djb2() {
            return true
        }

        let exception = NSException(
            name: NSExceptionName("StatsigSDKKeyMismatchError"),
            reason: "The SDK key provided does not match the one used to generate values.", userInfo: nil
        )

        Statsig.errorBoundary.logException(
            "SDKKeyValidator",
            exception: exception
        )

        return false
    }
}

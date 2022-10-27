import Foundation

/**
 StatsigEnvironment is a class for you to set environment variables that apply to all of your users in the same session and will be used for targeting purposes.
 */
@objc public class StatsigEnvironment: NSObject {
    @objc public enum EnvironmentTier: Int {
        case Production
        case Staging
        case Development
    }

    var params: [String: String] = [:]

    public init(tier: EnvironmentTier? = nil, additionalParams: [String: String]? = nil) {
        if let additionalParams = additionalParams {
            self.params = additionalParams
        }

        if let tier = tier {
            switch tier {
            case .Production:
                self.params["tier"] = "production"
            case .Development:
                self.params["tier"] = "development"
            case .Staging:
                self.params["tier"] = "staging"
            }
        }
    }
}

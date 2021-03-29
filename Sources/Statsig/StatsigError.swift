import Foundation

enum StatsigError : Error {
    case invalidJSONParam(String)
    case tooManyRequests(String)
}

extension StatsigError : LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidJSONParam(let paramName):
            return NSLocalizedString("The param \(paramName) is not a valid JSON object.", comment: "")
        case .tooManyRequests(let requestURL):
            return NSLocalizedString("Too many requests made to \(requestURL).", comment: "")
        }
    }
}

import Foundation

enum requestType: String {
    case initialize = "initialize"
    case logEvent = "logEvent"
}

class StatsigNetworkService {
    var sdkKey: String
    var valueStore: InternalStore
    var rateLimiter: [String:Int]
    
    final private let apiHost = "api.statsig.com"
    final private let initializeAPIPath = "/v1/initialize"
    final private let logEventAPIPath = "/v1/log_event"

    init(sdkKey: String, store:InternalStore) {
        self.sdkKey = sdkKey
        self.valueStore = store
        self.rateLimiter = [String:Int]()
    }

    private func sendRequest(
        forType: requestType,
        requestBody: [String: Any],
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = apiHost
        switch forType {
        case .initialize:
            urlComponents.path = initializeAPIPath
        case .logEvent:
            urlComponents.path = logEventAPIPath
        }

        guard let requestURL = urlComponents.url else {
            completion(nil, nil, StatsigError.invalidRequestURL(forType.rawValue))
            return
        }
        let urlString = requestURL.absoluteString
        
        var request = URLRequest(url: requestURL)
        guard JSONSerialization.isValidJSONObject(requestBody),
              let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(nil, nil, StatsigError.invalidJSONParam("requestBody"))
            return
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sdkKey, forHTTPHeaderField: "STATSIG-API-KEY")
        request.httpBody = jsonData
        request.httpMethod = "POST"

        if let pendingRequestCount = rateLimiter[urlString] {
            // limit to at most 10 pending requests for the same URL at a time
            if pendingRequestCount >= 10 {
                completion(nil, nil, StatsigError.tooManyRequests(urlString))
                return
            }
            rateLimiter[urlString] = pendingRequestCount + 1
        } else {
            rateLimiter[urlString] = 1
        }

        let task = URLSession.shared.dataTask(with: request) { [weak self] responseData, response, error in
            self?.rateLimiter[urlString] = max((self?.rateLimiter[urlString] ?? 0) - 1, 0)
            DispatchQueue.main.async {
                completion(responseData, response, error)
            }
        }

        task.resume()
    }
    
    func fetchValues(forUser: StatsigUser, completion: completionBlock) {
        var completionClone = completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            completionClone?(nil)
            completionClone = nil
        }

        let params: [String: Any] = [
            "user": forUser.toDictionary(),
            "statsigMetadata": forUser.environment
        ]
        sendRequest(forType: .initialize, requestBody: params) { [weak self] responseData, response, error in
            var errorMessage: String?
            if let error = error {
                errorMessage = error.localizedDescription
            } else if let statusCode = (response as? HTTPURLResponse)?.statusCode, !(200...299).contains(statusCode) {
                errorMessage = "An error occurred during fetching values for the user. "
                    + "\(String(describing: statusCode))"
            }

            if let responseData = responseData {
                if let json = try? JSONSerialization.jsonObject(with: responseData, options: []) {
                    if let json = json as? [String:Any], let self = self {
                        self.valueStore.set(forUser: forUser, values: UserValues(data: json))
                    }
                }
            }

            DispatchQueue.main.async {
                completionClone?(errorMessage)
                completionClone = nil
            }
        }
    }
    
    func sendEvents(forUser: StatsigUser, events: [Event], completion: completionBlock) {
        let params: [String: Any] = [
            "events": events.map { $0.toDictionary() },
            "user": forUser.toDictionary(),
            "statsigMetadata": forUser.environment
        ]
        sendRequest(forType: .logEvent, requestBody: params ) { responseData, response, error in
            if let error = error {
                completion?(error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion?("An error occurred during sending events to server. "
                            + "\(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                return
            }
        }
    }
}

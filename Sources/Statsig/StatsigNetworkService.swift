import Foundation

enum requestType: String {
    case initialize = "/initialize"
    case logEvent = "/log_event"
}

class StatsigNetworkService {
    var sdkKey: String
    var valueStore: InternalStore
    var rateLimiter: [String:Int]
    
    final private let apiURL = "https://api.statsig.com/v1"

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
        let requestURL = apiURL + forType.rawValue
        var request = URLRequest(url: URL(string: requestURL)!)
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(nil, nil, nil)
            return
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.httpMethod = "POST"

        if let pendingRequestCount = rateLimiter[requestURL] {
            // limit to at most 10 pending requests for the same URL at a time
            if pendingRequestCount >= 10 {
                completion(nil, nil, nil)
                return
            }
            rateLimiter[requestURL] = pendingRequestCount + 1
        } else {
            rateLimiter[requestURL] = 1
        }

        let task = URLSession.shared.dataTask(with: request) { [weak self] responseData, response, error in
            self?.rateLimiter[requestURL] = max((self?.rateLimiter[requestURL] ?? 0) - 1, 0)
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
            "sdkKey": sdkKey,
            "user": forUser.toDictionary(),
            "statsigMetadata": forUser.environment
        ]
        sendRequest(forType: .initialize, requestBody: params) { responseData, response, error in
            var errorMessage: String?
            if let error = error {
                errorMessage = error.localizedDescription
            } else if let statusCode = (response as? HTTPURLResponse)?.statusCode, !(200...299).contains(statusCode) {
                errorMessage = "An error occurred during fetching values for the user. "
                    + "\(String(describing: statusCode))"
            }

            if let responseData = responseData {
                if let json = try? JSONSerialization.jsonObject(with: responseData, options: []) {
                    if let json = json as? [String:Any] {
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
            "sdkKey": sdkKey,
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

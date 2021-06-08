import Foundation

enum requestType: String {
    case initialize = "initialize"
    case logEvent = "logEvent"
}

class NetworkService {
    let sdkKey: String
    let statsigOptions: StatsigOptions
    var store: InternalStore
    var rateLimiter: [String:Int]
    
    final private let apiHost = "api.statsig.com"
    final private let initializeAPIPath = "/v1/initialize"
    final private let logEventAPIPath = "/v1/log_event"
    final private let networkRetryErrorCodes = [408, 500, 502, 503, 504, 522, 524, 599]

    init(sdkKey: String, options: StatsigOptions, store: InternalStore) {
        self.sdkKey = sdkKey
        self.statsigOptions = options
        self.store = store
        self.rateLimiter = [String:Int]()
    }

    private func sendRequest(
        forType: requestType,
        requestBody: [String: Any],
        retry: Int = 0,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        guard JSONSerialization.isValidJSONObject(requestBody),
              let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(nil, nil, StatsigError.invalidJSONParam("requestBody"))
            return
        }
        sendRequest(forType: forType, requestData: jsonData, retry: retry, completion: completion)
    }

    private func sendRequest(
        forType: requestType,
        requestData: Data,
        retry: Int = 0,
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sdkKey, forHTTPHeaderField: "STATSIG-API-KEY")
        request.httpBody = requestData
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

        send(request: request, retry: retry) { [weak self] responseData, response, error in
            if let self = self {
                self.rateLimiter[urlString] = max((self.rateLimiter[urlString] ?? 0) - 1, 0)
            }
            DispatchQueue.main.async {
                completion(responseData, response, error)
            }
        }
    }

    func send(request: URLRequest, retry: Int = 0, backoff: Double = 0.5, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: request) { [weak self] responseData, response, error in
            if retry > 0,
               let self = self,
               let statusCode = (response as? HTTPURLResponse)?.statusCode,
               self.networkRetryErrorCodes.contains(statusCode) {
                DispatchQueue.main.asyncAfter(deadline: .now() + backoff) {
                    self.send(request: request, retry: retry - 1, backoff: backoff * 2, completion: completion)
                }
            } else {
                completion(responseData, response, error)
            }
        }
        task.resume()
    }

    func fetchUpdatedValues(for user: StatsigUser, since: Double, completion: (() -> Void)?) {
        let params: [String: Any] = [
            "user": user.toDictionary(),
            "statsigMetadata": user.environment,
            "lastSyncTimeForUser": since,
        ]
        sendRequest(forType: .initialize, requestBody: params) { [weak self] responseData, _, _ in
            if let self = self,
               let responseData = responseData,
               let json = try? JSONSerialization.jsonObject(with: responseData, options: []),
               let responseDict = json as? [String: Any],
               let hasUpdates = responseDict["has_updates"] as? Bool,
               hasUpdates {
                self.store.set(values: UserValues(data: responseDict), time: responseDict["time"] as? Double)
            }

            completion?()
        }
    }
    
    func fetchInitialValues(for user: StatsigUser, completion: completionBlock) {
        var completionClone = completion
        if self.statsigOptions.initTimeout > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + self.statsigOptions.initTimeout) {
                completionClone?(nil)
                completionClone = nil
            }
        }

        let params: [String: Any] = [
            "user": user.toDictionary(),
            "statsigMetadata": user.environment
        ]
        sendRequest(forType: .initialize, requestBody: params, retry: 5) { [weak self] responseData, response, error in
            var errorMessage: String?
            if let error = error {
                errorMessage = error.localizedDescription
            } else if let statusCode = (response as? HTTPURLResponse)?.statusCode, !(200...299).contains(statusCode) {
                errorMessage = "An error occurred during fetching values for the user. "
                    + "\(String(describing: statusCode))"
            }

            if let self = self,
               let responseData = responseData,
               let json = try? JSONSerialization.jsonObject(with: responseData, options: []),
               let responseDict = json as? [String: Any] {
                self.store.set(values: UserValues(data: responseDict), time: responseDict["time"] as? Double)
            }

            DispatchQueue.main.async {
                completionClone?(errorMessage)
                completionClone = nil
            }
        }
    }
    
    func sendEvents(forUser: StatsigUser, events: [Event],
                    completion: @escaping ((_ errorMessage: String?, _ data: Data?) -> Void)) {
        let params: [String: Any] = [
            "events": events.map { $0.toDictionary() },
            "user": forUser.toDictionary(),
            "statsigMetadata": forUser.environment
        ]
        guard JSONSerialization.isValidJSONObject(params),
              let jsonData = try? JSONSerialization.data(withJSONObject: params) else {
            completion(StatsigError.invalidJSONParam("requestBody").localizedDescription, nil)
            return
        }

        sendRequest(forType: .logEvent, requestData: jsonData ) { responseData, response, error in
            if let error = error {
                completion(error.localizedDescription, jsonData)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion("An error occurred during sending events to server. "
                            + "\(String(describing: (response as? HTTPURLResponse)?.statusCode))", jsonData)
                return
            }
        }
    }

    func sendRequestsWithData(_ dataArray: [Data], completion: @escaping ((_ failedRequestsData: [Data]?) -> Void)) {
        var failedRequests: [Data] = []
        let dispatchGroup = DispatchGroup()
        for data in dataArray {
            dispatchGroup.enter()
            sendRequest(forType: .logEvent, requestData: data) { responseData, response, error in
                let httpResponse = response as? HTTPURLResponse
                if error != nil ||
                    (httpResponse != nil && !(200...299).contains(httpResponse!.statusCode)) {
                    failedRequests.append(data)
                }
                dispatchGroup.leave()
            }
        }
        dispatchGroup.notify(queue: .main) {
            completion(failedRequests)
        }
    }
}

import Foundation

enum requestType: String {
    case initialize
    case logEvent
}

class NetworkService {
    let sdkKey: String
    let statsigOptions: StatsigOptions
    var store: InternalStore

    private final let apiHost = "api.statsig.com"
    private final let initializeAPIPath = "/v1/initialize"
    private final let logEventAPIPath = "/v1/rgstr"
    private final let networkRetryErrorCodes = [408, 500, 502, 503, 504, 522, 524, 599]

    init(sdkKey: String, options: StatsigOptions, store: InternalStore) {
        self.sdkKey = sdkKey
        self.statsigOptions = options
        self.store = store
    }

    private func sendRequest(forType: requestType,
                             requestBody: [String: Any],
                             retry: Int = 0,
                             completion: @escaping (Data?, URLResponse?, Error?) -> Void)
    {
        guard JSONSerialization.isValidJSONObject(requestBody),
              let jsonData = try? JSONSerialization.data(withJSONObject: requestBody)
        else {
            completion(nil, nil, StatsigError.invalidJSONParam("requestBody"))
            return
        }
        sendRequest(forType: forType, requestData: jsonData, retry: retry, completion: completion)
    }

    private func sendRequest(forType: requestType,
                             requestData: Data,
                             retry: Int = 0,
                             completion: @escaping (Data?, URLResponse?, Error?) -> Void)
    {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = apiHost

        if let override = self.statsigOptions.overrideURL {
            urlComponents.scheme = override.scheme
            urlComponents.host = override.host
            urlComponents.port = override.port
        }

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

        var request = URLRequest(url: requestURL)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sdkKey, forHTTPHeaderField: "STATSIG-API-KEY")
        request.setValue("\(NSDate().timeIntervalSince1970 * 1000)", forHTTPHeaderField: "STATSIG-CLIENT-TIME")
        request.httpBody = requestData
        request.httpMethod = "POST"

        send(request: request, retry: retry) { responseData, response, error in
            completion(responseData, response, error)
        }
    }

    func send(request: URLRequest, retry: Int = 0, backoff: Double = 1, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        DispatchQueue.main.async {
            let task = URLSession.shared.dataTask(with: request) { [weak self] responseData, response, error in
                if retry > 0,
                   let self = self,
                   let statusCode = (response as? HTTPURLResponse)?.statusCode,
                   self.networkRetryErrorCodes.contains(statusCode)
                {
                    self.send(request: request, retry: retry - 1, backoff: backoff * 2, completion: completion)
                } else {
                    completion(responseData, response, error)
                }
            }
            task.resume()
        }
    }

    func fetchUpdatedValues(for user: StatsigUser, since: Double, completion: (() -> Void)?) {
        let params: [String: Any] = [
            "user": user.toDictionary(forLogging: false),
            "statsigMetadata": user.deviceEnvironment,
            "lastSyncTimeForUser": since
        ]
        sendRequest(forType: .initialize, requestBody: params) { [weak self] responseData, _, _ in
            if let self = self,
               let responseData = responseData,
               let json = try? JSONSerialization.jsonObject(with: responseData, options: []),
               let responseDict = json as? [String: Any],
               let hasUpdates = responseDict["has_updates"] as? Bool,
               hasUpdates
            {
                self.store.set(values: responseDict, completion: completion)
            } else {
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }
    }

    func fetchInitialValues(for user: StatsigUser, completion: completionBlock) {
        var completionClone = completion
        if statsigOptions.initTimeout > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + statsigOptions.initTimeout) {
                completionClone?(nil)
                completionClone = nil
            }
        }

        let params: [String: Any] = [
            "user": user.toDictionary(forLogging: false),
            "statsigMetadata": user.deviceEnvironment
        ]
        sendRequest(forType: .initialize, requestBody: params, retry: 3) { [weak self] responseData, response, error in
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
               let responseDict = json as? [String: Any]
            {
                self.store.set(values: responseDict) {
                    completionClone?(errorMessage)
                    completionClone = nil
                }
            } else {
                DispatchQueue.main.async {
                    completionClone?(errorMessage)
                    completionClone = nil
                }
            }
        }
    }

    func sendEvents(forUser: StatsigUser, events: [Event],
                    completion: @escaping ((_ errorMessage: String?, _ data: Data?) -> Void))
    {
        let params: [String: Any] = [
            "events": events.map { $0.toDictionary() },
            "user": forUser.toDictionary(forLogging: true),
            "statsigMetadata": forUser.deviceEnvironment
        ]
        guard JSONSerialization.isValidJSONObject(params),
              let jsonData = try? JSONSerialization.data(withJSONObject: params)
        else {
            completion(StatsigError.invalidJSONParam("requestBody").localizedDescription, nil)
            return
        }

        sendRequest(forType: .logEvent, requestData: jsonData) { _, response, error in
            if let error = error {
                completion(error.localizedDescription, jsonData)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode)
            else {
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
            sendRequest(forType: .logEvent, requestData: data) { _, response, error in
                let httpResponse = response as? HTTPURLResponse
                if error != nil ||
                    (httpResponse != nil && !(200...299).contains(httpResponse!.statusCode))
                {
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

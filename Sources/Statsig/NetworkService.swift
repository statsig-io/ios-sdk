import Foundation

fileprivate enum Endpoint: String {
    case initialize = "/v1/initialize"
    case logEvent = "/v1/rgstr"
}

fileprivate let RetryLimits: [Endpoint: Int] = [
    .initialize: 3,
    .logEvent: 3
]

fileprivate typealias NetworkCompletionHandler = (Data?, URLResponse?, Error?) -> Void
fileprivate typealias TaskCaptureHandler = ((URLSessionDataTask) -> Void)?

class NetworkService {
    let sdkKey: String
    let statsigOptions: StatsigOptions
    var store: InternalStore
    var inflightRequests = AtomicDictionary<URLSessionTask>(label: "com.Statsig.InFlightRequests")

    private final let networkRetryErrorCodes = [408, 500, 502, 503, 504, 522, 524, 599]

    init(sdkKey: String, options: StatsigOptions, store: InternalStore) {
        self.sdkKey = sdkKey
        self.statsigOptions = options
        self.store = store
    }

    func fetchUpdatedValues(
        for user: StatsigUser,
        lastSyncTimeForUser: UInt64,
        previousDerivedFields: [String: String],
        completion: completionBlock
    ) {
        let (body, parseErr) = makeReqBody([
            "user": user.toDictionary(forLogging: false),
            "statsigMetadata": user.deviceEnvironment,
            "lastSyncTimeForUser": lastSyncTimeForUser,
            "previousDerivedFields": previousDerivedFields,
        ])

        guard let body = body else {
            self.store.finalizeValues()
            completion?(parseErr?.localizedDescription ?? "Failed to serialize request body ")
            return
        }

        let cacheKey = UserCacheKey.from(self.statsigOptions, user, self.sdkKey)
        let fullUserHash = user.getFullUserHash()

        makeAndSendRequest(.initialize, body: body) { [weak self] data, response, error in
            if let error {
                completion?(error.localizedDescription)
                return
            }
            
            let statusCode = response?.status ?? 0

            if !(200...299).contains(statusCode) {
                completion?("An error occurred during fetching values for the user. \(statusCode)")
                return
            }

            guard let self = self else {
                completion?("Failed to call NetworkService as it has been released")
                return
            }
            
            guard let dict = data?.json, dict["has_updates"] as? Bool == true else {
                self.store.finalizeValues()
                completion?(nil)
                return
            }

            self.store.saveValues(dict, cacheKey, fullUserHash) { completion?(nil) }
        }
    }

    func fetchInitialValues(
        for user: StatsigUser,
        sinceTime: UInt64,
        previousDerivedFields: [String: String],
        completion: completionBlock
    ) {
        let cacheKey = UserCacheKey.from(self.statsigOptions, user, self.sdkKey)
        if let inflight = inflightRequests[cacheKey.v2] {
            inflight.cancel()
        }
        
        if inflightRequests.count() > 50 {
            inflightRequests.reset()
        }

        var task: URLSessionDataTask?
        var completed = false
        let lock = NSLock()
        
        let done: (String?) -> Void = { [weak self] err in
            // Ensures the completion is invoked only once
            lock.lock()
            defer { lock.unlock() }
            
            self?.inflightRequests.removeValue(forKey: cacheKey.v2)
            
            guard !completed else { return }
            completed = true

            self?.store.finalizeValues {
                DispatchQueue.main.async {
                    task?.cancel()
                    completion?(err)
                }
            }

        }

        if statsigOptions.initTimeout > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + statsigOptions.initTimeout) {
                done("initTimeout Expired")
            }
        }

        let (body, parseErr) = makeReqBody([
            "user": user.toDictionary(forLogging: false),
            "statsigMetadata": user.deviceEnvironment,
            "sinceTime": sinceTime,
            "hash": statsigOptions.disableHashing ? "none" : "djb2",
            "previousDerivedFields": previousDerivedFields
        ])

        guard let body = body else {
            done(parseErr?.localizedDescription)
            return
        }

        let fullUserHash = user.getFullUserHash()

        makeAndSendRequest(
            .initialize,
            body: body,
            marker: Diagnostics.mark?.initialize.network
        ) { [weak self] data, response, error in
            if let error = error {
                done(error.localizedDescription)
                return
            }

            let statusCode = response?.status ?? 0

            if !(200...299).contains(statusCode) {
                done("An error occurred during fetching values for the user. \(statusCode)")
                return
            }

            guard let self = self else {
                done("Failed to call NetworkService as it has been released")
                return
            }

            Diagnostics.mark?.initialize.process.start()
            var values: [String: Any]? = nil
            if statusCode == 204 {
                values = ["has_updates": false]
            } else if let json = data?.json {
                values = json
            }

            guard let values = values else {
                Diagnostics.mark?.initialize.process.end(success: false)
                done("No values returned with initialize response")
                return
            }

            self.store.saveValues(values, cacheKey, fullUserHash) {
                Diagnostics.mark?.initialize.process.end(success: true)
                done(nil)
            }

        } taskCapture: { [weak self] capturedTask in
            self?.inflightRequests[cacheKey.v2] = capturedTask
            task = capturedTask
        }
    }

    func sendEvents(forUser: StatsigUser, events: [Event],
                    completion: @escaping ((_ errorMessage: String?, _ data: Data?) -> Void))
    {
        let (body, parseErr) = makeReqBody([
            "events": events.map { $0.toDictionary() },
            "user": forUser.toDictionary(forLogging: true),
            "statsigMetadata": forUser.deviceEnvironment
        ])

        guard let body = body else {
            completion(parseErr?.localizedDescription, nil)
            return
        }

        makeAndSendRequest(.logEvent, body: body) { _, response, error in
            if let error = error {
                completion(error.localizedDescription, body)
                return
            }

            guard response?.isOK == true else {
                completion("An error occurred during sending events to server. "
                           + "\(String(describing: response?.status))", body)
                return
            }
        }
    }

    func sendRequestsWithData(
        _ dataArray: [Data],
        completion: @escaping ((_ failedRequestsData: [Data]?) -> Void)
    ) {
        var failedRequests: [Data] = []
        let dispatchGroup = DispatchGroup()
        for data in dataArray {
            dispatchGroup.enter()
            makeAndSendRequest(.logEvent, body: data) { _, response, error in
                if error != nil || response?.isOK != true
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

    private func makeReqBody(_ dict: Dictionary<String, Any>) -> (Data?, Error?) {
        if JSONSerialization.isValidJSONObject(dict),
           let data = try? JSONSerialization.data(withJSONObject: dict){
            return (data, nil)
        }

        return (nil, StatsigError.invalidJSONParam("requestBody"))
    }

    private func makeAndSendRequest(
        _ endpoint: Endpoint,
        body: Data,
        marker: NetworkMarker? = nil,
        completion: @escaping NetworkCompletionHandler,
        taskCapture: TaskCaptureHandler = nil
    )
    {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = ApiHost
        urlComponents.path = endpoint.rawValue

        if let override = self.statsigOptions.mainApiUrl {
            urlComponents.applyOverride(override)
        }

        if endpoint == .logEvent, let loggingApiOverride = self.statsigOptions.logEventApiUrl {
            urlComponents.applyOverride(loggingApiOverride)
        }

        guard let requestURL = urlComponents.url else {
            completion(nil, nil, StatsigError.invalidRequestURL("\(endpoint)"))
            return
        }

        var request = URLRequest(url: requestURL)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sdkKey, forHTTPHeaderField: "STATSIG-API-KEY")
        request.setValue("\(Time.now())", forHTTPHeaderField: "STATSIG-CLIENT-TIME")
        request.setValue(DeviceEnvironment.sdkType, forHTTPHeaderField: "STATSIG-SDK-TYPE")
        request.setValue(DeviceEnvironment.sdkVersion, forHTTPHeaderField: "STATSIG-SDK-VERSION")
        request.httpBody = body
        request.httpMethod = "POST"

        sendRequest(
            request,
            retryLimit: RetryLimits[endpoint] ?? 0,
            marker: marker,
            completion: completion,
            taskCapture: taskCapture)
    }

    private func sendRequest(
        _ request: URLRequest,
        failedAttempts: Int = 0,
        retryLimit: Int,
        marker: NetworkMarker? = nil,
        completion: @escaping NetworkCompletionHandler,
        taskCapture: TaskCaptureHandler
    ) {
        DispatchQueue.main.async { [weak self] in
            let currentAttempt = failedAttempts + 1
            marker?.start(attempt: currentAttempt)


            let task = URLSession.shared.dataTask(with: request) {
                [weak self] responseData, response, error in

                marker?.end(currentAttempt, responseData, response, error)

                if failedAttempts < retryLimit,
                   let self = self,
                   let code = response?.status,
                   self.networkRetryErrorCodes.contains(code)
                {
                    self.sendRequest(
                        request,
                        failedAttempts: currentAttempt,
                        retryLimit: retryLimit,
                        marker: marker,
                        completion: completion,
                        taskCapture: taskCapture
                    )
                } else {
                    Statsig.errorBoundary.capture("sendRequest:response") {
                        completion(responseData, response, error)
                    } withRecovery: {
                        completion(nil, nil, StatsigError.unexpectedError("Response Handling"))
                    }
                }
            }

            taskCapture?(task)
            task.resume()
        }
    }
}

extension URLComponents {
    mutating func applyOverride(_ url: URL) {
        scheme = url.scheme
        host = url.host
        port = url.port
    }
}

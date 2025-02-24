import Foundation

internal enum Endpoint: String {
    case initialize = "/v1/initialize"
    case logEvent = "/v1/rgstr"

    var dnsKey: String {
        get {
            return switch self {
                case .initialize: "i"
                case .logEvent: "e"
            }
        }
    }
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
    var networkFallbackResolver: NetworkFallbackResolver

    /**
     Default URL used to initialize the SDK. Used for tests.
     */
    internal static var defaultInitializationURL = URL(string: "https://\(ApiHost)\(Endpoint.initialize.rawValue)")

    /**
     Default URL used for log_event network requests. Used for tests.
     */
    internal static var defaultEventLoggingURL = URL(string: "https://\(LogEventHost)\(Endpoint.logEvent.rawValue)")

    private final let networkRetryErrorCodes = [408, 500, 502, 503, 504, 522, 524, 599]

    init(sdkKey: String, options: StatsigOptions, store: InternalStore) {
        self.sdkKey = sdkKey
        self.statsigOptions = options
        self.store = store
        let errorBoundary = ErrorBoundary.boundary(clientKey: sdkKey, deviceEnvironment: options.environment)
        self.networkFallbackResolver = NetworkFallbackResolver(sdkKey: sdkKey, store: store, errorBoundary: errorBoundary);
    }

    func fetchUpdatedValues(
        for user: StatsigUser,
        lastSyncTimeForUser: UInt64,
        previousDerivedFields: [String: String],
        fullChecksum: String?,
        completion: ResultCompletionBlock?
    ) {
        let (body, parseErr) = makeReqBody([
            "user": user.toDictionary(forLogging: false),
            "statsigMetadata": user.deviceEnvironment,
            "lastSyncTimeForUser": lastSyncTimeForUser,
            "previousDerivedFields": previousDerivedFields,
            "full_checksum": fullChecksum ?? nil,
            "sinceTime": lastSyncTimeForUser,
            "hash": statsigOptions.disableHashing ? "none" : "djb2",
        ])

        guard let body = body else {
            self.store.finalizeValues()
            completion?(StatsigClientError(
                .failedToFetchValues,
                message: parseErr?.localizedDescription ?? "Failed to serialize request body ",
                cause: parseErr
            ))
            return
        }

        let cacheKey = UserCacheKey.from(self.statsigOptions, user, self.sdkKey)
        let fullUserHash = user.getFullUserHash()

        makeAndSendRequest(.initialize, body: body) { [weak self] data, response, error in
            if let error {
                completion?(StatsigClientError(.failedToFetchValues, cause: error))
                return
            }
            
            let statusCode = response?.status ?? 0

            if !(200...299).contains(statusCode) {
                completion?(StatsigClientError(.failedToFetchValues, message: "An error occurred during fetching values for the user. \(statusCode)"))
                return
            }

            guard let self = self else {
                completion?(StatsigClientError(.failedToFetchValues, message: "Failed to call NetworkService as it has been released"))
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
        fullChecksum: String?,
        completion: ResultCompletionBlock?
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

        let done: (StatsigClientError?) -> Void = { [weak self] err in
            // Ensures the completion is invoked only once
            lock.lock()
            defer { lock.unlock() }
            
            self?.inflightRequests.removeValue(forKey: cacheKey.v2)
            
            guard !completed else { return }
            completed = true

            self?.store.finalizeValues {
                ensureMainThread {
                    task?.cancel()
                    completion?(err)
                }
            }

        }

        if statsigOptions.initTimeout > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + statsigOptions.initTimeout) {
                done(StatsigClientError(.initTimeoutExpired))
            }
        }

        let (body, parseErr) = makeReqBody([
            "user": user.toDictionary(forLogging: false),
            "statsigMetadata": user.deviceEnvironment,
            "sinceTime": sinceTime,
            "hash": statsigOptions.disableHashing ? "none" : "djb2",
            "previousDerivedFields": previousDerivedFields,
            "full_checksum": fullChecksum ?? nil,
        ])

        guard let body = body else {
            done(StatsigClientError(.failedToFetchValues, cause: parseErr))
            return
        }

        let fullUserHash = user.getFullUserHash()

        makeAndSendRequest(
            .initialize,
            body: body,
            marker: Diagnostics.mark?.initialize.network,
            threadMarker: Diagnostics.mark?.initialize.netThreadJump
        ) { [weak self] data, response, error in
            if let error = error {
                done(StatsigClientError(.failedToFetchValues, cause: error))
                return
            }

            let statusCode = response?.status ?? 0

            if !(200...299).contains(statusCode) {
                done(StatsigClientError(.failedToFetchValues, message: "An error occurred during fetching values for the user. \(statusCode)"))
                return
            }

            guard let self = self else {
                done(StatsigClientError(.failedToFetchValues, message: "Failed to call NetworkService as it has been released"))
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
                done(StatsigClientError(.failedToFetchValues, message: "No values returned with initialize response"))
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

            completion(nil, body)
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

    private func makeReqBody(_ dict: Dictionary<String, Any?>) -> (Data?, Error?) {
        if JSONSerialization.isValidJSONObject(dict),
           let data = try? JSONSerialization.data(withJSONObject: dict){
            return (data, nil)
        }

        return (nil, StatsigError.invalidJSONParam("requestBody"))
    }

    private func urlForEndpoint(_ endpoint: Endpoint) -> URL? {
        return switch endpoint {
            case .initialize: self.statsigOptions.initializationURL ?? self.networkFallbackResolver.getActiveFallbackURL(endpoint: endpoint) ?? NetworkService.defaultInitializationURL
            case .logEvent: self.statsigOptions.eventLoggingURL ?? self.networkFallbackResolver.getActiveFallbackURL(endpoint: endpoint) ?? NetworkService.defaultEventLoggingURL
        }
    }

    private func makeAndSendRequest(
        _ endpoint: Endpoint,
        body: Data,
        marker: NetworkMarker? = nil,
        threadMarker: InitializeStepMarker? = nil,
        completion: @escaping NetworkCompletionHandler,
        taskCapture: TaskCaptureHandler = nil
    )
    {
        guard let requestURL = urlForEndpoint(endpoint) else {
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
            endpoint: endpoint,
            retryLimit: RetryLimits[endpoint] ?? 0,
            marker: marker,
            completion: completion,
            taskCapture: taskCapture,
            threadMarker: threadMarker)
    }

    private func endpointOverrideURL(endpoint: Endpoint) -> URL? {
        switch endpoint {
            case .initialize: return self.statsigOptions.initializationURL
            case .logEvent: return self.statsigOptions.eventLoggingURL
        }
    }

    private func sendRequest(
        _ request: URLRequest,
        endpoint: Endpoint,
        failedAttempts: Int = 0,
        retryLimit: Int,
        marker: NetworkMarker? = nil,
        completion: @escaping NetworkCompletionHandler,
        taskCapture: TaskCaptureHandler,
        threadMarker: InitializeStepMarker? = nil
    ) {
        threadMarker?.start()
        ensureMainThread { [weak self] in
            let currentAttempt = failedAttempts + 1
            threadMarker?.end(success: true)
            marker?.start(attempt: currentAttempt)


            let task = self?.statsigOptions.urlSession.dataTask(with: request) {
                [weak self] responseData, response, error in

                marker?.end(currentAttempt, responseData, response, error)

                guard let self = self else {
                    completion(responseData, response, error)
                    return
                }

                if error == nil && response?.isOK == true {
                    self.networkFallbackResolver.tryBumpExpiryTime(endpoint: endpoint)
                }

                guard failedAttempts < retryLimit else {
                    completion(responseData, response, error)
                    return
                }


                
                if let code = response?.status,
                    self.networkRetryErrorCodes.contains(code) {

                    self.sendRequest(
                        request,
                        endpoint: endpoint,
                        failedAttempts: currentAttempt,
                        retryLimit: retryLimit,
                        marker: marker,
                        completion: completion,
                        taskCapture: taskCapture
                    )
                } else if self.networkFallbackResolver.isDomainFailure(error: error)
                    && self.endpointOverrideURL(endpoint: endpoint) == nil
                {
                    // Fallback domains
                    self.networkFallbackResolver.tryFetchUpdatedFallbackInfo(endpoint: endpoint) { [weak self] fallbackUpdated in
                        if fallbackUpdated,
                            let self = self,
                            let fallbackUrl = self.networkFallbackResolver.getActiveFallbackURL(endpoint: endpoint)
                        {
                            var newRequest = request
                            newRequest.url = fallbackUrl
                            self.sendRequest(
                                newRequest,
                                endpoint: endpoint,
                                failedAttempts: currentAttempt,
                                retryLimit: retryLimit,
                                marker: marker,
                                completion: completion,
                                taskCapture: taskCapture
                            )
                        } else {
                            completion(responseData, response, error)
                        }
                    }
                } else {
                    completion(responseData, response, error)
                }
            }

            if let taskCapture = taskCapture, let task = task {
                taskCapture(task)
            }

            task?.resume()
        }
    }

    internal static func defaultURLForEndpoint(_ endpoint: Endpoint) -> URL? {
        return switch endpoint {
            case .initialize: NetworkService.defaultInitializationURL
            case .logEvent: NetworkService.defaultEventLoggingURL
        }
    }
}

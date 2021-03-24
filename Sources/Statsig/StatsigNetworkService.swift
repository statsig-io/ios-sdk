import Foundation

enum requestType: String {
    case initialize = "/initialize"
    case logEvent = "/log_event"
}

class StatsigNetworkService {
    var sdkKey: String
    var user: StatsigUser
    var valueStore: InternalStore
    
    final private let apiURL = "https://api.statsig.com/v1"
    final private let apiPathInitialize = "/initialize"
    final private let apiPathLog = "/log_event"

    init(sdkKey: String, user: StatsigUser, store:InternalStore) {
        self.sdkKey = sdkKey
        self.user = user
        self.valueStore = store
    }
    
    private func sendRequest(
        forType: requestType,
        extraData: Any?,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        var request = URLRequest(url: URL(string: apiURL + forType.rawValue)!)
        var params: [String: Any] = [
            "sdkKey": sdkKey,
            "user": user.toDictionary(),
            "statsigMetadata": user.environment.toDictionary()
        ]
        switch forType {
        case .initialize:
            break
        case .logEvent:
            params["events"] = extraData
            break
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: params) else {
            completion(nil, nil, nil)
            return
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.httpMethod = "POST"

        let task = URLSession.shared.dataTask(with: request) { responseData, response, error in
            completion(responseData, response, error)
        }
        
        task.resume()
    }
    
    func updateUser(withNewUser: StatsigUser) {
        self.user = withNewUser
    }
    
    func fetchValues(completion: completionBlock) {
        sendRequest(forType: .initialize, extraData: nil) { responseData, response, error in
            if error != nil {
                // TODO: handle better and retry?
                completion?(error?.localizedDescription ?? "An error occurred during fetching values for the user.")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                // TODO: handle better and retry?
                completion?("An error occurred during fetching values for the user. \((response as? HTTPURLResponse)?.statusCode)")
                    return
            }
            guard let mime = response?.mimeType, mime == "application/json" else {
                // TODO: handle better and retry?
                completion?("Received wrong MIME type for http response!")
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: responseData!, options: []) {
                if let json = json as? [String:Any] {
                    self.valueStore.set(forUser: self.user, values: UserValues(data: json))
                    completion?(nil)
                    return
                }
            }
            completion?(nil)
        }
    }
    
    func sendEvents(_ events: [Event], completion: completionBlock) {
        sendRequest(forType: .logEvent, extraData: events.map { $0.toDictionary() }) { responseData, response, error in
            if error != nil {
                // TODO: handle better and retry?
                completion?(error.debugDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                // TODO: handle better and retry?
                completion?("An error occurred during sending events to server. \((response as? HTTPURLResponse)?.statusCode)")
                return
            }
        }
    }
}

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
            DispatchQueue.main.async {
                completion(responseData, response, error)
            }
        }
        task.resume()
    }
    
    func fetchValues(completion: completionBlock) {
        var completionClone = completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            completionClone?(nil)
            completionClone = nil
        }
        sendRequest(forType: .initialize, extraData: nil) { responseData, response, error in
            if let error = error {
                completionClone?(error.localizedDescription)
                completionClone = nil
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completionClone?("An error occurred during fetching values for the user. "
                                    + "\(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                completionClone = nil
                return
            }
            guard let mime = response?.mimeType, mime == "application/json" else {
                completionClone?("Received wrong MIME type for http response!")
                completionClone = nil
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: responseData!, options: []) {
                if let json = json as? [String:Any] {
                    self.valueStore.set(forUser: self.user, values: UserValues(data: json))
                    completionClone?(nil)
                    completionClone = nil
                    return
                }
            }
            completionClone?("An error occurred during fetching values for the user.")
            completionClone = nil
        }
    }
    
    func sendEvents(_ events: [Event], completion: completionBlock) {
        sendRequest(forType: .logEvent, extraData: events.map { $0.toDictionary() }) { responseData, response, error in
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

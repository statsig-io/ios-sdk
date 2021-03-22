import Foundation

public class Statsig {
    private static var sharedInstance: Statsig?
    private var apiKey: String
    private var user: String
    
    public static func start(user: String, apiKey: String) {
        if sharedInstance != nil {
            NSLog("Statsig has already started!")
            return
        }
        sharedInstance = Statsig(user: user, apiKey: apiKey)
    }
    
    public static func get() -> Statsig? {
        return sharedInstance
    }
    
    private init(user: String, apiKey: String) {
        self.apiKey = apiKey;
        self.user = user;
        let url = URL(string: "https://api.statsig.com/v1/initialize")!;
        var request = URLRequest(url: url)
                
        // TODO: refacto this section
        let params: [String: Any] = [
            "sdkKey": "4176a946-1b82-468b-a760-4957525009ae",
            "user": [
                "userID": "jkw",
                "email": "jkw@statsig.com"
            ],
        ]
        let  jsonData = try? JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData//?.base64EncodedData()
        request.httpMethod = "POST"

        let task = URLSession.shared.dataTask(with: request) { responseData, response, error in
            if error != nil {
                // TODO: handle
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                // TODO: handle
                return
            }
            guard let mime = response?.mimeType, mime == "application/json" else {
                print("Wrong MIME type!")
                // TODO: handle?
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: responseData!, options: []) {
                print(json)
                if let json = json as? [String:Any] {
                    let gates = json["gates"] as? [String:Bool]
                    let configs = json["configs"] as? [String: Any]
                    let sdkParams = json["sdkParams"] as? [String: Any]
                    print("\(gates)")
                    print("\(configs)")
                    print("\(sdkParams)")
                }
                
            }
        
        }
        task.resume()
    }
}

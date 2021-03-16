import Foundation

public class Statsig {
    private static var sharedInstance: Statsig?
    private var apiKey: String
    private var user: String
    
    private init(user: String, apiKey: String) {
        self.apiKey = apiKey;
        self.user = user;
    }
    
    static func start(user: String, apiKey: String) {
        if sharedInstance != nil {
            NSLog("Statsig has already started!")
            return
        }
        sharedInstance = Statsig(user: user, apiKey: apiKey)
    }
    
    public static func get() -> Statsig? {
        return sharedInstance
    }
}

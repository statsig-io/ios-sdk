import Foundation

struct UserCacheKey {
    let v1: String
    let v2: String
    
    static func from(user: StatsigUser, sdkKey: String) -> UserCacheKey {
        let v1 = getVersion1(user: user)
        let v2 = getVersion2(user: user, sdkKey: sdkKey)
        return UserCacheKey(v1: v1, v2: v2)
    }
    
    static func getVersion1(user: StatsigUser) -> String {
        var key = user.userID ?? "null"
        if let customIDs = user.customIDs {
            for (idType, idValue) in customIDs {
                key += "\(idType)\(idValue)"
            }
        }
        return key
    }

    // uid:USER_ID|cids:CUSTOM_ID_KEY-CUSTOM_ID_VALUE|k:SDK_KEY
    static func getVersion2(user: StatsigUser, sdkKey: String) -> String {
        let cids: [String] = user.customIDs?.map { key, value in
            return "\(key)-\(value)"
        } ?? []
        
        return [
            "uid:\(user.userID ?? "")",
            "cids:\(cids.sorted().joined(separator: ","))",
            "k:\(sdkKey)"
        ].joined(separator: "|")
            .djb2()
    }
}

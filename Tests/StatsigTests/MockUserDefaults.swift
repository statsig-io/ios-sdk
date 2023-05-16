import Foundation

class MockDefaults: UserDefaults {
    var data: [String: Any?] = [:]

    init() {
        super.init(suiteName: nil)!
    }

    override func setValue(_ value: Any?, forKey key: String) {
        data[key] = value
    }

    override func array(forKey defaultName: String) -> [Any]? {
        return data[defaultName] as? [Any]
    }

    func reset() {
        data = [:]
    }
}

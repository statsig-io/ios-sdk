import Foundation

internal extension URLResponse {
    var asHttpResponse: HTTPURLResponse? {
        get {
            return self as? HTTPURLResponse
        }
    }

    var status: Int? {
        get {
            return self.asHttpResponse?.statusCode
        }
    }

    var statsigRegion: String? {
        get {
            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
                return self.asHttpResponse?.value(forHTTPHeaderField: "x-statsig-region")
            }

            return nil
        }
    }

    var isOK: Bool {
        get {
            let code = self.status ?? 0
            return code >= 200 && code < 300
        }
    }
}

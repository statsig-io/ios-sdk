import Dispatch

fileprivate let TIME_OFFSET = DispatchTime.now().uptimeNanoseconds
fileprivate let NANO_IN_MS = 1_000_000.0

enum MarkerContext: String {
    case initialize = "initialize"
    case apiCall = "api_call"
}

class MarkerBase {
    let context: MarkerContext
    let markerKey: String?

    private let recorder: MarkerAtomicDict
    private let offset: UInt64

    init(_ recorder: MarkerAtomicDict, context: MarkerContext, markerKey: String? = nil) {
        self.context = context
        self.markerKey = markerKey
        self.recorder = recorder
        self.offset = TIME_OFFSET
    }

    func start(_ args: [String: Any]) {
        add("start", markerKey, args)
    }

    func end(_ args: [String: Any]) {
        add("end", markerKey, args)
    }

    func getMarkerCount() -> Int {
        return recorder[context.rawValue]?.count ?? 0
    }

    private func add(_ action: String, _ markerKey: String?, _ args: [String: Any]) {
        var marker = args
        marker["key"] = marker["key"] ?? markerKey
        marker["action"] = action
        marker["timestamp"] = now()

        var local = recorder[context.rawValue] ?? []
        local.append(marker)
        recorder[context.rawValue] = local
    }

    private func now() -> Double {
        return Double(DispatchTime.now().uptimeNanoseconds - offset) / NANO_IN_MS
    }
}

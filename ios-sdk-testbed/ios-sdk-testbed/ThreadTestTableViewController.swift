import Foundation
import UIKit
import Statsig


enum Thread: Int, CaseIterable {
    case main, background, custom
}

let kDisptachPer = 2
let kActionsPer = 10

class ThreadTestTableViewController: UITableViewController {
    let customQueue = DispatchQueue(label: "Custom Queue")

    var keys: [String] = []
    var configs: [String: [(() -> Void, String)]] = [:]

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.title = "Initialization Needed"

        let startCallback: (String?) -> Void = { [weak self] errorMessage in
            if ((errorMessage) != nil) {return}
            self?.title = "Initialized"
        }

        let clientKey = ProcessInfo.processInfo.environment["STATSIG_CLIENT_KEY"] ?? ""

        configs = [
            "Start": [
                ({ Statsig.start(sdkKey: clientKey, user: nil, options: nil, completion: startCallback) }, ""),
                ({ Statsig.start(sdkKey: clientKey, user: StatsigUser(userID: "dloomb"), options: nil, completion: startCallback)}, "w/ User"),
            ],
            "Gates": [
                ({ _ = Statsig.checkGate("test_gate") }, "")
            ],
            "Log": [
                ({ Statsig.logEvent("test_gate") }, ""),
                ({ Statsig.logEvent("test_gate", metadata: ["foo": "1"]) }, "w/ Meta w/o value"),
                ({ Statsig.logEvent("test_gate", value: "bar", metadata: ["foo": "1"]) }, "w/ Meta and String value"),
                ({ Statsig.logEvent("test_gate", value: 1, metadata: ["foo": "1"]) }, "w/ Meta and Number value"),
            ],
            "Configs": [
                ({ _ = Statsig.getConfig("test_config") }, ""),
            ],
            "Experiments": [
                ({ _ = Statsig.getExperiment("test_experiment") }, ""),
                ({ _ = Statsig.getExperiment("test_experiment", keepDeviceValue: true) }, "Keep Device Value"),
            ],
            "Stable ID": [
                ({ _ = Statsig.getStableID() }, ""),
            ],
            "Update User": [
                ({ Statsig.updateUser(StatsigUser(userID:"dloomb")) }, "DLOOMB"),
                ({ Statsig.updateUser(StatsigUser(userID:"jkw")) }, "JKW"),
                ({ Statsig.updateUser(StatsigUser(userID:"tore")) }, "TORE"),
            ],
            "Shutdown": [
                ({ Statsig.shutdown() }, ""),
            ],
        ]

        keys = Array(configs.keys).sorted()
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return keys[section]
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return keys.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let key = keys[section]
        return (configs[key]?.count ?? 0) * Thread.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        let threadNumber = indexPath.row % Thread.allCases.count
        let threadName = "\(Thread(rawValue: threadNumber)!)"

        let configNumber = indexPath.row / Thread.allCases.count

        let key = keys[indexPath.section]
        let config = configs[key]![configNumber]

        let description = config.1.isEmpty ? "" : " (\(config.1))"
        cell.textLabel?.text = key + " - " + threadName.capitalized +  description

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let key = keys[indexPath.section]
        let configNumber = indexPath.row / Thread.allCases.count
        guard let config = configs[key]?[configNumber] else { return }

        let threadNumber = indexPath.row % Thread.allCases.count
        let thread = Thread(rawValue: threadNumber)!
        let queue = thread == .main ? DispatchQueue.main : (thread == .background ? DispatchQueue.global(qos: .userInitiated) : customQueue)

        for _ in 0...kDisptachPer {
            queue.async {
                for _ in 0...kActionsPer {
                    config.0()
                }
            }
        }
    }

}

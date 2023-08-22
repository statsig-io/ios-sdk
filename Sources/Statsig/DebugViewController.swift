
#if os(iOS)

import UIKit
import WebKit

class DebugViewController: UIViewController, WKNavigationDelegate {
    private var webView: WKWebView?
    private var url: URL
    private var state: [String: Any?]

    static func show(_ sdkKey: String, _ state: [String: Any?]) {
        guard JSONSerialization.isValidJSONObject(state) else {
            print("[Statsig] DebugView received Invalid state")
            return
        }

        guard let url = URL(string: "https://console.statsig.com/client_sdk_debugger_redirect?sdkKey=\(sdkKey)") else {
            print("[Statsig] DebugView failed to create required URL")
            return
        }

        var root: UIViewController?

        if root == nil, #available(iOS 13.0, *) {
            let scene = UIApplication.shared.connectedScenes.first(where: { scene in
                return scene.activationState == UIScene.ActivationState.foregroundActive
            })

            root = (scene?.delegate as? UIWindowSceneDelegate)?.window??.rootViewController
        }

        if root == nil {
            root = UIApplication.shared.keyWindow?.rootViewController
        }

        guard let root = root else {
            print("[Statsig] DebugView failed to find parent view controller")
            return
        }

        let debugger = DebugViewController(url: url, state: state)
        root.show(debugger, sender: nil)
    }

    init(url: URL, state: [String: Any?]) {
        self.url = url
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()


        do {
            let data = try JSONSerialization.data(withJSONObject: self.state, options: [])
            let json = String(data: data, encoding: .utf8) ?? "{}"

            let config = WKWebViewConfiguration()
            let script = WKUserScript(source: "window.__StatsigClientState = \(json)",
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: false)
            config.userContentController.addUserScript(script)

            let webView = WKWebView(frame: view.bounds, configuration: config)
            webView.frame = view.bounds
            webView.navigationDelegate = self
            view.addSubview(webView)
            webView.load(URLRequest(url: url))
            self.webView = webView
        } catch {
            print("[Statsig] Failed to create debug state")
        }

        // Add a close button to dismiss the modal view
        let closeButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(closeButtonTapped))
        navigationItem.rightBarButtonItem = closeButton

    }

    @objc func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
}

#else
class DebugViewController {
    static func show(_ sdkKey: String, _ state: [String: Any?]) {
        print("[Statsig] DebugView is currently only available on iOS")
    }
}
#endif

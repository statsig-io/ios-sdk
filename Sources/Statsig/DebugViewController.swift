public typealias DebuggerCallback = (Bool) -> Void

#if os(iOS)

import UIKit
import WebKit

class DebugViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    private let messageHandlerName = "statsigDebugMessageHandler"

    private var webView: WKWebView?
    private var url: URL
    private var state: [String: Any?]
    private var isReloadRequested: Bool = false
    private var callback: DebuggerCallback?


    static func show(_ sdkKey: String, _ state: [String: Any?], _ callback: DebuggerCallback? = nil) {
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

        let debugger = DebugViewController(url: url, state: state, callback: callback)
        root.present(debugger, animated: true)
    }

    init(url: URL, state: [String: Any?], callback: DebuggerCallback?) {
        self.url = url
        self.state = state
        self.callback = callback
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            let data = try JSONSerialization.data(withJSONObject: self.state, options: [])
            let json = data.text ?? "{}"

            let config = WKWebViewConfiguration()
            let userContentController = WKUserContentController()



            let script = WKUserScript(source: "window.__StatsigClientState = \(json)",
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: false)
            userContentController.addUserScript(script)

            config.userContentController = userContentController

            let webView = WKWebView(frame: view.bounds, configuration: config)
            webView.frame = view.bounds
            webView.navigationDelegate = self
            webView.configuration.userContentController.add(self, name: messageHandlerName)
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

    override func viewWillDisappear(_ animated: Bool) {
        callback?(isReloadRequested)
    }
    
    @objc func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        if (message.name != messageHandlerName) {
            return
        }

        if (message.body as? String == "RELOAD_REQUIRED") {
            isReloadRequested = true
        }
    }

}

#else
class DebugViewController {
    static func show(_ sdkKey: String, _ state: [String: Any?], _ callback: DebuggerCallback? = nil) {
        print("[Statsig] DebugView is currently only available on iOS")
    }
}
#endif

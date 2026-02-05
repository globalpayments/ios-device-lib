//
//
//  TokenServiceViewController.swift
//  ios-device-lib
//
    

import Foundation
import WebKit

class TokenServiceViewController: UIViewController {
    var webView: WKWebView!
    var html: String?
    var completion: HpsTokenServiceWebCompletionHandler?
    let apiKey = "pkapi_cert_P6dRqs1LzfWJ6HgGVZ"
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let contentControllers = WKUserContentController()
        let js = "window.dynamicApiKey = '\(TokenServiceConstant.apiKey)';"
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        contentControllers.addUserScript(userScript)
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentControllers
        
        webView = WKWebView(frame: self.view.frame, configuration: config)
        let contentController = self.webView.configuration.userContentController
        contentController.add(self, name: "cardFormMessageHandler")
        
        self.view.addSubview(webView)
        
        if let html = html {
            webView.loadHTMLString(html, baseURL: URL(string: "https://api.heartlandportico.com")!)
        }
    }
}

extension TokenServiceViewController: WKScriptMessageHandler{
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String : AnyObject] else {
            self.completion?(nil)
            return
        }

        self.completion?(dict)
    }
}

struct TokenServiceConstant {
    static let apiKey = "pkapi_cert_P6dRqs1LzfWJ6HgGVZ"
}

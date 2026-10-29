//
//
//  HpsTokenService.swift
//  ios_device_lib
//
    

import Foundation
import WebKit

public typealias HpsTokenServiceWebCompletionHandler = (_ response: [String : AnyObject]?) -> Void

public class HpsTokenServiceWeb {
    public init() {}
    
    /// Falls back to the `HpsPublicApiKey` value in the host app's Info.plist.
    public func tokenServiceWebView(completion: HpsTokenServiceWebCompletionHandler?) throws -> UIViewController? {
        return try self.tokenServiceWebView(apiKey: HpsTokenServiceWeb.plistApiKey, completion: completion)
    }
    
    public func tokenServiceWebView(apiKey: String?, completion: HpsTokenServiceWebCompletionHandler?) throws -> UIViewController? {
        if let pathURL = Bundle(identifier: "com.heartland.Heartland-iOS-SDK")?.path(forResource: "TokenService", ofType: "html") {
            let html = try String(contentsOfFile: pathURL)
            return self.tokenServiceWebView(html: html, apiKey: apiKey, completion: completion)
        }
        
        return nil
    }
    
    /// Falls back to the `HpsPublicApiKey` value in the host app's Info.plist.
    public func tokenServiceWebView(html: String, completion: HpsTokenServiceWebCompletionHandler?) -> UIViewController? {
        return self.tokenServiceWebView(html: html, apiKey: HpsTokenServiceWeb.plistApiKey, completion: completion)
    }
    
    public func tokenServiceWebView(html: String, apiKey: String?, completion: HpsTokenServiceWebCompletionHandler?) -> UIViewController? {
        let vc = TokenServiceViewController()
        vc.html = html
        vc.publicApiKey = apiKey
        vc.completion = completion
        return vc
    }
    
    private static var plistApiKey: String? {
        return Bundle.main.object(forInfoDictionaryKey: "HpsPublicApiKey") as? String
    }
}

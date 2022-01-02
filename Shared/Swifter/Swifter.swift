//
//  SignInViewModel.swift
//  TwitterLogin
//
//  Created by Yong Jin on 2022/1/1.
//

import Foundation
import AuthenticationServices

#if os(iOS)
    import UIKit
    import SafariServices
#elseif os(macOS)
    import AppKit
#endif

// MARK: - Twitter URL
public enum TwitterURL {
    
    case api
    case upload
    case stream
    case publish
    case userStream
    case siteStream
    case oauth
    
    var url: URL {
        switch self {
        case .api:          return URL(string: "https://api.twitter.com/1.1/")!
        case .upload:       return URL(string: "https://upload.twitter.com/1.1/")!
        case .stream:       return URL(string: "https://stream.twitter.com/1.1/")!
        case .userStream:   return URL(string: "https://userstream.twitter.com/1.1/")!
        case .siteStream:   return URL(string: "https://sitestream.twitter.com/1.1/")!
        case .oauth:        return URL(string: "https://api.twitter.com/")!
        case .publish:        return URL(string: "https://publish.twitter.com/")!
        }
    }
    
}

class Swifter: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    
    //MARK: - Types
    
    internal struct DataParameters {
        static let dataKey = "SwifterDataParameterKey"
        static let fileNameKey = "SwifterDataParameterFilename"
        static let jsonDataKey = "SwifterDataJSONDataParameterKey"
    }
    
    var client: SwifterClientProtocol
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
    
    // MARK: - Initializers
    
    init(consumerKey: String, consumerSecret: String, appOnly: Bool = false) {
        self.client = OAuthClient(consumerKey: consumerKey, consumerSecret: consumerSecret)
    }
    
    init(consumerKey: String, consumerSecret: String, oauthToken: String, oauthTokenSecret: String) {
        self.client = OAuthClient(consumerKey: consumerKey, consumerSecret: consumerSecret,
                                  accessToken: oauthToken, accessTokenSecret: oauthTokenSecret)
    }
}

extension Swifter {
    
    typealias TokenSuccessHandler = (Credential.OAuthAccessToken?, URLResponse) -> Void
    typealias SSOTokenSuccessHandler = (Credential.OAuthAccessToken) -> Void
    
    typealias FailureHandler = (_ error: Error) -> Void
    
    /**
     Begin Authorization with a Callback URL
     - for macOS and iOS
     */
    #if os(macOS) || os(iOS)
    @available(macOS 10.15, *)
    @available(iOS 13.0, *)
    func authorize(withProvider provider: ASWebAuthenticationPresentationContextProviding,
                   ephemeralSession: Bool = false,
                   callbackURL: URL,
                   forceLogin: Bool = false,
                   success: TokenSuccessHandler?,
                   failure: FailureHandler? = nil) {
        let callbackURLScheme = callbackURL.absoluteString.components(separatedBy: "://").first
        self.postOAuthRequestToken(with: callbackURL, success: { token, response in
            let queryURL = self.makeQueryURL(tokenKey: token!.key, forceLogin: forceLogin)
            let session = ASWebAuthenticationSession(url: queryURL, callbackURLScheme: callbackURLScheme) { (url, error) in
//                self.session = nil
                if let error = error {
                    failure?(error)
                    return
                }
                self.postOAuthAccessTokenHelper(requestToken: token!, responseURL: url!, success: success, failure: failure)
            }
            session.presentationContextProvider = provider
            session.prefersEphemeralWebBrowserSession = ephemeralSession
            session.start()
//            self.session = session
        }, failure: failure)
    }
    #endif
    
    func postOAuthRequestToken(with callbackURL: URL, success: @escaping TokenSuccessHandler, failure: FailureHandler?) {
        let path = "oauth/request_token"
        let parameters =  ["oauth_callback": callbackURL.absoluteString]
        
        self.client.post(path, baseURL: .oauth, parameters: parameters, uploadProgress: nil, downloadProgress: nil, success: { data, response in
            let responseString = String(data: data, encoding: .utf8)!
            let accessToken = Credential.OAuthAccessToken(queryString: responseString)
            success(accessToken, response)
        }, failure: failure)
    }
    
    
    private func postOAuthAccessTokenHelper(
        requestToken token: Credential.OAuthAccessToken,
        responseURL: URL,
        success: TokenSuccessHandler?,
        failure: FailureHandler? = nil
    ) {
        let parameters = responseURL.query!.queryStringParameters
        guard let verifier = parameters["oauth_verifier"] else {
            let error = SwifterError(message: "User cancelled login from Twitter App", kind: .cancelled)
            failure?(error)
            return
        }
        var requestToken = token
        requestToken.verifier = verifier
        self.postOAuthAccessToken(with: requestToken, success: { accessToken, response in
            self.client.credential = Credential(accessToken: accessToken!)
            print(#line, #function, accessToken)

            success?(accessToken!, response)
        }, failure: failure)
    }
    
    func postOAuthAccessToken(with requestToken: Credential.OAuthAccessToken, success: @escaping TokenSuccessHandler, failure: FailureHandler?) {
        if let verifier = requestToken.verifier {
            let path =  "oauth/access_token"
            let parameters = ["oauth_token": requestToken.key, "oauth_verifier": verifier]
            
            print(#line, #function, parameters.description)
            
            self.client.post(path, baseURL: .oauth, parameters: parameters, uploadProgress: nil, downloadProgress: nil, success: { data, response in
                
                let responseString = String(data: data, encoding: .utf8)!
                let accessToken = Credential.OAuthAccessToken(queryString: responseString)
                success(accessToken, response)
                
                }, failure: failure)
        } else {
            let error = SwifterError(message: "Bad OAuth response received from server",
                                     kind: .badOAuthResponse)
            failure?(error)
        }
    }
    
    
    func makeQueryURL(tokenKey: String, forceLogin: Bool) -> URL {
        let forceLogin = forceLogin ? "&force_login=true" : ""
        let query = "oauth/authorize?oauth_token=\(tokenKey)\(forceLogin)"
        return URL(string: query, relativeTo: TwitterURL.oauth.url)!.absoluteURL
    }

}

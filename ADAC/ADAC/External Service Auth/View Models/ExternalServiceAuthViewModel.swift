// Licensed under the Any Distance Source-Available License
//
//  ExternalServiceAuthViewModel.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/13/22.
//

import Foundation
import Combine
import UIKit
import OAuthSwift

enum ExternalServiceAuthError: Error {
    case oauthError(description: String)
    case invalidConfig
    case invalidRedirectURL
    case unexpected(code: Int)
}

protocol ExternalServiceViewModelInputs {
    func cancel()
    func connect()
    func disconnect()
    func presentAuth(on viewController: UIViewController)
    func presentURL(url: URL)
}

protocol ExternalServiceViewModelOutputs {
    var externalService: ExternalService { get }
    var isAuthorized: Bool { get }
    var isAuthorizationExpired: Bool { get }
    var authorization: AnyPublisher<ExternalServiceAuthorization, ExternalServiceAuthError> { get }
    var onCancel: AnyPublisher<Void, Never> { get }
    var onConnect: AnyPublisher<Void, Never> { get }
    var onDisconnect: AnyPublisher<Void, OAuthSwiftError> { get }
    var onPresentURL: AnyPublisher<URL, Never> { get }
}

protocol ExternalServiceAuthViewModelType: ExternalServiceViewModelInputs, ExternalServiceViewModelOutputs {}

class ExternalServiceAuthViewModel: ObservableObject, ExternalServiceAuthViewModelType {
    
    // MARK: - Outputs
    
    let externalService: ExternalService
    let authorization: AnyPublisher<ExternalServiceAuthorization, ExternalServiceAuthError>
    let onCancel: AnyPublisher<Void, Never>
    let onConnect: AnyPublisher<Void, Never>
    let onDisconnect: AnyPublisher<Void, OAuthSwiftError>
    let onPresentURL: AnyPublisher<URL, Never>
    
    var isAuthorized: Bool {
        let keychainStored = KeychainStore.shared
        guard let authorization = keychainStored.authorization(for: externalService) else {
            return false
        }
        
        return !authorization.expired
    }
    
    var isAuthorizationExpired: Bool {
        let keychainStored = KeychainStore.shared
        guard let authorization = keychainStored.authorization(for: externalService) else {
            return false
        }
        
        return authorization.expired
    }
    
    // MARK: - Private
    
    private var oauth: OAuthSwift?
    
    private let authorizationValue = PassthroughSubject<ExternalServiceAuthorization, ExternalServiceAuthError>()
    private let onCancelValue = PassthroughSubject<Void, Never>()
    private let onConnectValue = PassthroughSubject<Void, Never>()
    private let onDisconnectValue = PassthroughSubject<Void, OAuthSwiftError>()
    private let onPresentURLValue = PassthroughSubject<URL, Never>()
    
    init(with externalService: ExternalService) {
        self.externalService = externalService
        authorization = authorizationValue.eraseToAnyPublisher()
        onCancel = onCancelValue.eraseToAnyPublisher()
        onConnect = onConnectValue.eraseToAnyPublisher()
        onDisconnect = onDisconnectValue.eraseToAnyPublisher()
        onPresentURL = onPresentURLValue.eraseToAnyPublisher()
    }
    
}

// MARK: - Inputs

extension ExternalServiceAuthViewModel {
    
    func cancel() {
        onCancelValue.send()
    }
    
    func connect() {
        onConnectValue.send()
    }
    
    func disconnect() {
        let keychainStore = KeychainStore.shared
        guard let authorization = keychainStore.authorization(for: externalService) else { return }
        
        switch externalService {
        case .garmin:
            NSUbiquitousKeyValueStore.default.garminBackfillRequestsMade = 0
        case .wahoo, .appleHealth:
            break
        }
        
        switch externalService.oauthVersion {
        case .oauth1:
            disconnectWithOAuth1(authorization: authorization)
        case .oauth2:
            disconnectWithOAuth2(authorization: authorization)
        }
    }
    
    func presentAuth(on viewController: UIViewController) {
        guard let redirectURL = URL(string: "anydistanceathleticclub://\(externalService.rawValue)-callback") else {
            authorizationValue.send(completion: .failure(ExternalServiceAuthError.invalidRedirectURL))
            return
        }
        
        switch externalService.oauthVersion {
        case .oauth1:
            presentOAuth1Authorization(on: viewController,
                                       key: externalService.consumerKey,
                                       secret: externalService.consumerSecret,
                                       redirectURL: redirectURL)
        case .oauth2:
            presentOAuth2Authorization(on: viewController,
                                       key: externalService.consumerKey,
                                       secret: externalService.consumerSecret,
                                       redirectURL: redirectURL)
        }
    }
    
    func presentURL(url: URL) {
        onPresentURLValue.send(url)
    }
    
}

// MARK: - Private

extension ExternalServiceAuthViewModel {
    
    private func disconnectWithOAuth1(authorization: ExternalServiceAuthorization) {
        let oauth1 = OAuth1Swift(
            consumerKey: authorization.service.consumerKey,
            consumerSecret: authorization.service.consumerSecret,
            requestTokenUrl: externalService.externalServiceURL.requestToken,
            authorizeUrl: externalService.externalServiceURL.authorize,
            accessTokenUrl: externalService.externalServiceURL.accessToken
        )
        
        oauth1.client.credential.oauthToken = authorization.token
        oauth1.client.credential.oauthTokenSecret = authorization.secret
        
        oauth = oauth1
        
        oauth1.client.delete(externalService.externalServiceURL.deauthorize) { [weak self] result in
            self?.handleOAuthDeauthorization(result: result)
        }
    }
    
    private func disconnectWithOAuth2(authorization: ExternalServiceAuthorization) {
        let oauth2 = OAuth2Swift(consumerKey: authorization.service.consumerKey,
                                consumerSecret: authorization.service.consumerSecret,
                                authorizeUrl: authorization.service.externalServiceURL.authorize,
                                accessTokenUrl: authorization.service.externalServiceURL.accessToken,
                                responseType: "code")

        oauth2.client.credential.oauthToken = authorization.token
        oauth2.client.credential.oauthRefreshToken = authorization.refreshToken
        
        oauth = oauth2
        
        oauth2.client.delete(authorization.service.externalServiceURL.deauthorize) { [weak self] result in
            self?.handleOAuthDeauthorization(result: result)
        }
    }

    private func presentOAuth1Authorization(on viewController: UIViewController,
                                            key: String,
                                            secret: String,
                                            redirectURL: URL) {
        let oauth1 = OAuth1Swift(
            consumerKey: key,
            consumerSecret: secret,
            requestTokenUrl: externalService.externalServiceURL.requestToken,
            authorizeUrl: externalService.externalServiceURL.authorize,
            accessTokenUrl: externalService.externalServiceURL.accessToken
        )
        
        oauth = oauth1
        
        oauth1.authorizeURLHandler = SafariURLHandler(viewController: viewController, oauthSwift: oauth1)
        
        oauth1.addCallbackURLToAuthorizeURL = true
        
        oauth1.authorize(withCallbackURL: redirectURL) { [weak self] result in
            self?.handleOAuthAuthorization(result: result)
        }
    }
    
    private func presentOAuth2Authorization(on viewController: UIViewController,
                                            key: String,
                                            secret: String,
                                            redirectURL: URL) {
        let oauth2 = OAuth2Swift(consumerKey: key,
                                 consumerSecret: secret,
                                 authorizeUrl: externalService.externalServiceURL.authorize,
                                 accessTokenUrl: externalService.externalServiceURL.accessToken,
                                 responseType: "code")
        
        oauth2.allowMissingStateCheck = true
        oauth2.authorizeURLHandler = SafariURLHandler(viewController: viewController, oauthSwift: oauth2)
        
        oauth = oauth2
        
        oauth2.authorize(withCallbackURL: redirectURL, scope: externalService.scope, state: "") { [weak self] result in
            self?.handleOAuthAuthorization(result: result)
        }
    }
    
    private func handleOAuthDeauthorization(result: Result<OAuthSwiftResponse, OAuthSwiftError>) {
        let keychainStore = KeychainStore.shared
        keychainStore.deleteAuthorization(for: externalService)

        switch result {
        case .success:
            onDisconnectValue.send()
        case .failure(let error):
            onDisconnectValue.send(completion: .failure(error))
        }
    }
    
    private func handleOAuthAuthorization(result: Result<OAuthSwift.TokenSuccess, OAuthSwiftError>) {
        switch result {
        case .success(let (credential, _, _)):
            let authorization = ExternalServiceAuthorization(token: credential.oauthToken,
                                                             refreshToken: credential.oauthRefreshToken,
                                                             secret: credential.oauthTokenSecret,
                                                             service: self.externalService)
            #if DEBUG
            UIPasteboard.general.string = credential.oauthToken
            #endif
            self.authorizationValue.send(authorization)
        case .failure(let error):
            self.authorizationValue.send(completion: .failure(ExternalServiceAuthError.oauthError(description: error.description)))
        }
    }
    
}

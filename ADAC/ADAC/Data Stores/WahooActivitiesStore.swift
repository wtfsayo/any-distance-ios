// Licensed under the Any Distance Source-Available License
//
//  WahooActivitiesStore.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/22/22.
//

import Foundation
import OAuthSwift
import Combine

fileprivate extension DateFormatter {
    
    static let wahooDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()
    
}

class WahooActivitiesStore: ActivitiesProviderStore {

    let activitySynced: AnyPublisher<Activity, Never>
    private var activitySyncedValue = PassthroughSubject<Activity, Never>()
    
    static let shared = WahooActivitiesStore()
    
    // MARK: - Private
    
    private var _oauth: OAuth2Swift?
    
    private let keychainStore = KeychainStore.shared
    
    private var authorization: ExternalServiceAuthorization?
    
    private init() {
        activitySynced = activitySyncedValue.eraseToAnyPublisher()
    }
    
    // MARK: - ActivitiesStore
    
    func isAuthorizedForAllTypes() async throws -> Bool {
        return keychainStore.authorization(for: .wahoo) != nil
    }
    
    func load() async throws -> [Activity] {
        guard let workoutsURL = URL(string: "https://api.wahooligan.com/v1/workouts") else {
            print("Invalid URL for Wahoo Activities")
            return []
        }
        
        let parameters: OAuthSwift.Parameters = [
            "per_page": 100
        ]
        
        guard let response = try await getRequest(with: workoutsURL,
                                                  parameters: parameters) else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.wahooDateFormatter)
        let wahooActivitiesResponse = try decoder.decode(WahooActivitiesResponse.self, from: response.data)        
        return wahooActivitiesResponse.activities.filter { $0.activityType != .unknown }
    }
    
    func startObservingNewActivities() async {
        // not supported by wahoo
    }
    
    func summary(for activity: WahooActivity) async throws -> WahooActivitySummary? {
        guard let summaryURL = URL(string: "https://api.wahooligan.com/v1/workouts/\(activity.activityId)/workout_summary") else {
            print("Invalid URL Wahoo Activity Summary")
            return nil
        }
        
        guard let response = try await getRequest(with: summaryURL, parameters: [:]) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.wahooDateFormatter)
        let summary = try decoder.decode(WahooActivitySummary.self, from: response.data)
        return summary
    }
    
    // MARK: - Private
        
    private func getRequest(with url: URL, parameters: OAuthSwift.Parameters) async throws -> OAuthSwiftResponse? {
        if let auth = keychainStore.authorization(for: .wahoo),
           auth != authorization {
            authorization = auth
            let oauth = OAuth2Swift(consumerKey: auth.service.consumerKey,
                                    consumerSecret: auth.service.consumerSecret,
                                    authorizeUrl: auth.service.externalServiceURL.authorize,
                                    accessTokenUrl: auth.service.externalServiceURL.accessToken,
                                    responseType: "code")
            oauth.allowMissingStateCheck = true
            oauth.client.credential.oauthToken = auth.token
            oauth.client.credential.oauthRefreshToken = auth.refreshToken
            _oauth = oauth
        }
        
        guard let oauth = _oauth, let authorization = authorization else {
            return nil
        }
        
        let response: OAuthSwiftResponse = try await withCheckedThrowingContinuation { [weak self] continuation in
            oauth.client.requestWithAutomaticAccessTokenRenewal(url: url,
                                                                method: .GET,
                                                                parameters: parameters,
                                                                accessTokenUrl: authorization.service.externalServiceURL.accessToken,
                                                                onTokenRenewal: { result in
                switch result {
                case .failure(let error):
                    continuation.resume(throwing: error)
                case .success(let credential):
                    let authorization = ExternalServiceAuthorization(token: credential.oauthToken,
                                                                     refreshToken: credential.oauthRefreshToken,
                                                                     secret: credential.oauthTokenSecret,
                                                                     service: .wahoo)
                    do {
                        try self?.keychainStore.save(authorization: authorization)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    switch error {
                    case .tokenExpired(_):
                        self.authorizationChanged(expired: true)
                    default:
                        break
                    }
                    
                    continuation.resume(throwing: error)
                case .success(let response):
                    continuation.resume(returning: response)
                }
            }
        }
        
        return response
    }
        
    private func authorizationChanged(expired: Bool) {
        if var authorization = self.keychainStore.authorization(for: .wahoo) {
            authorization.expired = expired
            try? self.keychainStore.save(authorization: authorization)
            
            // TODO: Get rid of this
            NotificationCenter.default.post(.externalServicesConnectionStateChanged)
        }
    }
    
}

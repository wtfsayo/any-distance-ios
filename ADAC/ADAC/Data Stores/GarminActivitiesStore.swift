// Licensed under the Any Distance Source-Available License
//
//  GarminActivitiesStore.swift
//  ADAC
//
//  Created by Jarod Luebbert on 7/11/22.
//

import Foundation
import OAuthSwift
import Sentry
import Combine

class GarminActivitiesStore: ActivitiesProviderStore {
    
    static let shared = GarminActivitiesStore()
    
    let activitySynced: AnyPublisher<Activity, Never>
    private var activitySyncedValue = PassthroughSubject<Activity, Never>()
    
    // MARK: - Private
    
    private var _oauth: OAuth1Swift?
    
    private let keychainStore = KeychainStore.shared
    
    private var authorization: ExternalServiceAuthorization?
    
    private init() {
        activitySynced = activitySyncedValue.eraseToAnyPublisher()
    }
    
    // MARK: - ActivitiesStore
    
    func isAuthorizedForAllTypes() async throws -> Bool {
        return keychainStore.authorization(for: .garmin) != nil
    }
    
    func load() async throws -> [Activity] {
        guard let response = try await getRequest() else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let json = String(data: response.data, encoding: .utf8)
            let activities = try decoder.decode([GarminActivity].self, from: response.data)
            return activities
        } catch {
            SentrySDK.capture(message: "Garmin decoding error: \(error.localizedDescription)")
            SentrySDK.capture(error: error)
        }

        print("no activities")
        return []
    }
    
    func startObservingNewActivities() async {
        // not supported by garmin
    }
    
    // MARK: - Private
    
    struct Request {
        let url: URL
        let params: OAuthSwift.Parameters
        let identifier: String
        
        init(_ string: String, identifier: String, params: OAuthSwift.Parameters = [:]) {
            self.url = URL(string: string)!
            self.params = params
            self.identifier = identifier
        }
        
        var absoluteURLString: String {
            guard !params.isEmpty else { return url.absoluteString }
            
            let items: [URLQueryItem] = params.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
            var urlComponent = URLComponents(string: url.absoluteString)
            urlComponent?.queryItems = items
            return urlComponent?.url?.absoluteString ?? url.absoluteString
        }
    }
    
    private func getRequest() async throws -> OAuthSwiftResponse? {
        if let auth = keychainStore.authorization(for: .garmin),
           auth != authorization {
            authorization = auth
            let oauth = OAuth1Swift(consumerKey: auth.service.consumerKey,
                                    consumerSecret: auth.service.consumerSecret,
                                    requestTokenUrl: auth.service.externalServiceURL.requestToken,
                                    authorizeUrl: auth.service.externalServiceURL.authorize,
                                    accessTokenUrl: auth.service.externalServiceURL.accessToken)
            oauth.client.credential.oauthToken = auth.token
            oauth.client.credential.oauthTokenSecret = auth.secret
            oauth.client.credential.oauthRefreshToken = auth.refreshToken
            _oauth = oauth
        }
        
        guard let oauth = _oauth else {
            return nil
        }
        
        makeBackfillRequests(with: oauth)
        
        do {
            let activitiesResponse: OAuthSwiftResponse = try await withCheckedThrowingContinuation { continuation in
                let requests = [
                    Request("https://apis.garmin.com/wellness-api/rest/user/id",
                            identifier: "userIdRequest"),
                ]

                do {
                    let encodedDictionary = try jsonEncodedHeaders(for: requests,
                                                                   with: oauth,
                                                                   defaultHeaders: ["shorten": 1])
                    oauth.client.post(URL(string: "http://google.com/")!,
                                      headers: nil,
                                      body: encodedDictionary) { result in
                        continuation.resume(with: result)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            return activitiesResponse
        } catch {
            SentrySDK.capture(message: "Garmin activities response error: \(error.localizedDescription)")
            SentrySDK.capture(error: error)
        }
        
        return nil
    }
    
    private func makeBackfillRequests(with oauth: OAuth1Swift) {
        guard let backfillURL = URL(string: "") else {
            return
        }
        
        let totalNumberOfBackfillRequests = 1
        
        guard NSUbiquitousKeyValueStore.default.garminBackfillRequestsMade < totalNumberOfBackfillRequests else { return }
        
        let daysToRequestLimit = 89 // garmin limits us to 89 days at a time (docs say 90 but requests fail unless it's under)
        let totalDaysToRequest = daysToRequestLimit * totalNumberOfBackfillRequests
        
        var daysRequested = 0
        var endDate = Date()
        while daysRequested < totalDaysToRequest {
            let startDate = Calendar.current.date(byAdding: .day,
                                                  value: -daysToRequestLimit,
                                                  to: endDate)!
            let garminRequests = [
                Request("https://apis.garmin.com/userPermissions",
                        identifier: "permissionsRequest"),
                Request("https://apis.garmin.com/wellness-api/rest/backfill/activityDetails",
                        identifier: "backfillRequest",
                        params: [
                            "summaryStartTimeInSeconds": "\(Int(startDate.timeIntervalSince1970))",
                            "summaryEndTimeInSeconds": "\(Int(endDate.timeIntervalSince1970))"
                        ]),
            ]

            do {
                let encodedDictionary = try jsonEncodedHeaders(for: garminRequests,
                                                               with: oauth)
                oauth.client.post(backfillURL,
                                  parameters: [:],
                                  headers: nil,
                                  body: encodedDictionary) { result in
                    switch result {
                    case .success(_):
                        NSUbiquitousKeyValueStore.default.garminBackfillRequestsMade += 1
                    case .failure(let error):
                        print(error.localizedDescription)
                        SentrySDK.capture(message: "Garmin backfill response error: \(error.localizedDescription)")
                        SentrySDK.capture(error: error)
                    }
                }
            } catch {
                SentrySDK.capture(message: "Garmin backfill request error: \(error.localizedDescription)")
                SentrySDK.capture(error: error)
            }

            endDate = startDate
            
            daysRequested += daysToRequestLimit
        }
    }
    
    private func jsonEncodedHeaders(for requests: [Request],
                                    with oauth: OAuth1Swift,
                                    defaultHeaders: OAuthSwift.Parameters = [:]) throws -> Data? {
        let authorizationKey = "Authorization"
        var headers = defaultHeaders
        
        for request in requests {
            let header = oauth.client.credential.makeHeaders(request.url,
                                                             method: .GET,
                                                             parameters: request.params)
            if let oauthValue = header[authorizationKey] {
                headers[request.identifier] = [
                    "url": request.absoluteURLString,
                    "signedHeader": oauthValue
                ]
            }
        }
        
        return try JSONSerialization.data(withJSONObject: headers, options: [])
    }

}

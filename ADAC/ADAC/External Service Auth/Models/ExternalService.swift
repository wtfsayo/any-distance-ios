// Licensed under the Any Distance Source-Available License
//
//  ExternalService.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/13/22.
//

import Foundation

enum OAuthVersion {
    case oauth1, oauth2
}

struct ExternalServiceURL {
    let requestToken: String
    let authorize: String
    let accessToken: String
    let deauthorize: String
    
    init(requestToken: String = "", authorize: String, accessToken: String, deauthorize: String) {
        self.requestToken = requestToken
        self.authorize = authorize
        self.accessToken = accessToken
        self.deauthorize = deauthorize
    }
}

enum ExternalService: String, Codable {
    case wahoo, garmin, appleHealth
    
    var displayName: String { // user facing
        rawValue.camelCaseToWords().capitalized
    }
    
    var oauthVersion: OAuthVersion {
        switch self {
        case .garmin: return .oauth1
        case .wahoo: return .oauth2
        case .appleHealth: return .oauth1
        }
    }
    
    var scope: String {
        switch self {
        case .wahoo:
            return "workouts_read user_read"
        default:
            return ""
        }
    }
    
    var externalServiceURL: ExternalServiceURL {
        switch self {
        case .garmin:
            return ExternalServiceURL(requestToken: "https://connectapi.garmin.com/oauth-service/oauth/request_token",
                                      authorize: "https://connect.garmin.com/oauthConfirm",
                                      accessToken: "https://connectapi.garmin.com/oauth-service/oauth/access_token",
                                      deauthorize: "https://apis.garmin.com/wellness-api/rest/user/registration")
        case .wahoo:
            return ExternalServiceURL(authorize: "https://api.wahooligan.com/oauth/authorize",
                                      accessToken: "https://api.wahooligan.com/oauth/token",
                                      deauthorize: "https://api.wahooligan.com/v1/permissions")
        case .appleHealth:
            return ExternalServiceURL(authorize: "", accessToken: "", deauthorize: "")
        }
    }
    
    var imageNameLarge: String {
        switch self {
        case .appleHealth:
            return "glyph_applehealth_big"
        default:
            return "\(displayName)_Large"
        }
    }
    
    var imageNameSmall: String {
        "\(displayName)_Small"
    }
    
}

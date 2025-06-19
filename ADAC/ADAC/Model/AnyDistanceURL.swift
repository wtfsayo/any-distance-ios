// Licensed under the Any Distance Source-Available License
//
//  AnyDistanceURL.swift
//  ADAC
//
//  Created by Jarod Luebbert on 10/18/22.
//

import Foundation
import Combine

struct AnyDistanceURL {
    enum URLType: String, RawRepresentable {
        case activities, activity, collectibles, collectible, goals, settings,
             trackActivity, externalURL, post, friends, profile
    }
    
    let type: URLType
    let parameters: [String: String]
    
    var activityType: ActivityType? {
        guard let activityTypeRawValue = parameters["activityType"] else {
            return nil
        }
        
        // the raw values of ActivityType contain spaces, which we can't use in URLs
        let rawValue: String
        if activityTypeRawValue.contains("_") {
            rawValue =  activityTypeRawValue.replacingOccurrences(of: "_", with: " ").capitalized
        } else {
            rawValue = activityTypeRawValue
        }
        
        return ActivityType(rawValue: rawValue)
    }
    
    var goalType: RecordingGoalType? {
        guard let goalTypeRawValue = parameters["goalType"] else {
            return nil
        }
        
        return RecordingGoalType(rawValue: goalTypeRawValue)
    }
    
    var goalTarget: Float? {
        guard let goalTargetString = parameters["goalTarget"] else {
            return nil
        }
        
        return Float(goalTargetString)
    }
    
    var activity: Activity? {
        get async {
            guard let activityId = parameters["activityId"] else { return nil }
            
            return try? await ActivitiesData.shared.loadActivity(with: activityId)
        }
    }
    
    var collectibleTypeRawValue: String? {
        return parameters["collectibleRawValue"]
    }

    var showAR: Bool {
        return parameters["showAR"] == "1"
    }
    
    var externalURL: URL? {
        guard let urlString = parameters["url"] else { return nil }
        return URL(string: urlString)
    }

    var postID: String? {
        return parameters["postID"]
    }

    var friendsTabSelectedSegment: Int {
        return Int(parameters["selectedSegment"] ?? "0") ?? 0
    }

    var username: String? {
        return parameters["username"]
    }
}

class AnyDistanceURLHandler {
    
    // MARK: Public
    
    static let shared = AnyDistanceURLHandler()
        
    let handleURL: AnyPublisher<AnyDistanceURL, Never>
    
    // MARK: Private
    
    private let handleURLValue = PassthroughSubject<AnyDistanceURL, Never>()
    
    private init() {
        handleURL = handleURLValue.eraseToAnyPublisher()
    }
    
    // MARK: Public
    
    func handle(adURL: AnyDistanceURL) {
        handleURLValue.send(adURL)
    }
    
    func handle(url: URL) -> Bool {
        guard let scheme = url.scheme, let host = url.host,
           scheme.localizedCaseInsensitiveCompare("anydistance") == .orderedSame else {
            return false
        }

        guard let urlType = AnyDistanceURL.URLType(rawValue: host) else { return false }

        var parameters: [String: String] = [:]
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.forEach {
            parameters[$0.name] = $0.value
        }
        
        let adURL = AnyDistanceURL(type: urlType, parameters: parameters)

        handleURLValue.send(adURL)
        
        return true
    }
    
}

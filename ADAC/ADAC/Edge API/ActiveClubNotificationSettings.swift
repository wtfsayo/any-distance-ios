// Licensed under the Any Distance Source-Available License
//
//  ActiveClubNotificationSettings.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/17/23.
//

import Foundation

enum ActiveClubNotificationType: String, Codable, CaseIterable {
    case newPost
    case commentsAndReactions
    case friendRequest
    case friendApproval
    case friendJoin
    case friendSuggestion
    case startOfTheWeek
}

struct ActiveClubNotificationSettings: Codable {
    init() {}

    init(notificationTags: [String]) {
        for (key, _) in settings {
            settings[key] = notificationTags.contains(key.rawValue)
        }
    }

    func notificationTags() -> [String] {
        return settings.compactMap { (key, value) in
            return value ? key.rawValue : nil
        }
    }

    var settings: [ActiveClubNotificationType: Bool] = [
        .newPost: true,
        .friendRequest: true,
        .friendApproval: true,
        .friendJoin: true,
        .friendSuggestion: true,
        .commentsAndReactions: true,
        .startOfTheWeek: true
    ]

    func setting(for type: ActiveClubNotificationType) -> Bool {
        return settings[type] ?? true
    }

    mutating func set(_ value: Bool, for type: ActiveClubNotificationType) {
        settings[type] = value
    }
}

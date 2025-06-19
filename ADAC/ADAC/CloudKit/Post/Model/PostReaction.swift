// Licensed under the Any Distance Source-Available License
//
//  PostReaction.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/15/23.
//

import Foundation

enum PostReactionType: String, Codable, Hashable, Equatable, CaseIterable {
    case thumbsUp
    case heart
    case fire
    case confetti
    case oneHundred

    // legacy
    case heartEyes

    var emoji: String {
        switch self {
        case .thumbsUp:
            return "👍"
        case .heartEyes:
            return "😍"
        case .heart:
            return "❤️"
        case .fire:
            return "🔥"
        case .confetti:
            return "🎉"
        case .oneHundred:
            return "💯"
        }
    }

    static let availableTypes: [PostReactionType] = [
        .thumbsUp,
        .heart,
        .fire,
        .confetti,
        .oneHundred
    ]
}

struct PostReaction: Codable, Equatable {
    typealias ID = String

    var id: PostReaction.ID?
    var userID: ADUser.ID
    var postID: Post.ID
    var kind: PostReactionType
    var createdAt: UInt64?

    init(userID: ADUser.ID, postID: Post.ID, kind: PostReactionType) {
        self.userID = userID
        self.postID = postID
        self.kind = kind
    }

    var wasCreatedBySelf: Bool {
        return userID == ADUser.current.id
    }

    var creationDate: Date? {
        return Date(timeIntervalSince1970: createdAt)
    }
}

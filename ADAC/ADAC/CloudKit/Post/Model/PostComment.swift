// Licensed under the Any Distance Source-Available License
//
//  PostComment.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/15/23.
//

import Foundation

struct PostComment: Codable, Equatable {
    typealias ID = String

    var id: PostComment.ID?
    var userID: ADUser.ID
    var postID: Post.ID
    var body: String
    var createdAt: UInt64?

    init(userID: ADUser.ID,
         postID: Post.ID,
         body: String) {
        self.userID = userID
        self.postID = postID
        self.body = body
    }
}

extension PostComment {
    func author() async -> ADUser? {
        if ADUser.current.id == userID {
            return ADUser.current
        }

        if let user = UserCache.shared.user(forID: userID) {
            return user
        }

        return try? await UserManager.shared.getUsers(byCanonicalIDs: [userID]).first
    }

    var wasCreatedBySelf: Bool {
        return userID == ADUser.current.id
    }

    var creationDate: Date? {
        return Date(timeIntervalSince1970: createdAt)
    }
}

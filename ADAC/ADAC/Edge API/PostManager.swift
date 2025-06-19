// Licensed under the Any Distance Source-Available License
//
//  PostManager.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/9/23.
//

import Foundation
import Cache
import SwiftyJSON
import Mixpanel
import Sentry

class PostManager {
    #if DEBUG
    let DEBUG: Bool = false // change this one to test
    #else
    let DEBUG: Bool = false
    #endif

    static let shared = PostManager()
    private let baseUrl = Edge.host.appendingPathComponent("posts")
    lazy var currentUserHasPostedThisWeek: Bool = {
        hasCurrentUserHasPostedThisWeek()
    }()

    // MARK: - Post start date

    var thisWeekPostStartDate: Date {
        if DEBUG {
            return Date().addingTimeInterval(-1 * 86400 * 30)
        } else {
            if Calendar.current.component(.weekday, from: Date()) == 2 {
                return Calendar.current.startOfDay(for: Date())
            }

            return Calendar.current.nextDate(after: Date(),
                                             matching: DateComponents(weekday: 2),
                                             matchingPolicy: .strict,
                                             direction: .backward) ?? Date()
        }
    }

    private func hasCurrentUserHasPostedThisWeek() -> Bool {
        if NSUbiquitousKeyValueStore.default.overrideHasPosted {
            return false
        }
        
        if DEBUG {
            return true
        } else {
            return PostCache.shared.posts(forUserID: ADUser.current.id)
                .contains(where: { $0.activityStartDateUTC >= thisWeekPostStartDate })
        }
    }

    // MARK: - Create

    func createPost(_ post: Post) async throws {
        let url = baseUrl.appendingPathComponent("create")
        print(url.absoluteString)
        let payload = PostPayload(post: post)
        var request = try Edge.defaultRequest(with: url, method: .post)
        request.httpBody = try JSONEncoder().encode(payload)
        print(String(data: request.httpBody!, encoding: .utf8))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 201 else {
            let stringData = String(data: data, encoding: .utf8)
//            print(stringData)
            throw PostManagerError.requestError(stringData)
        }

        let responsePayload = try JSONDecoder().decode(PostPayload.self, from: data)
        await post.merge(with: responsePayload.post)
        PostCache.shared.cache(post: post, sendCachedPublisher: true)
        currentUserHasPostedThisWeek = hasCurrentUserHasPostedThisWeek()

        let taggedUserIDs = TagCoder.decodeTags(for: post.postDescription).tags.map { $0.userID }
        NotificationsManager.sendNotification(to: taggedUserIDs,
                                              withCategory: "NEW_POST",
                                              message: "\(ADUser.current.name) (@\(ADUser.current.username ?? "")) tagged you in a \(post.activityType.notificationDisplayName).",
                                              appUrl: "anydistance://post?postID=\(post.id)",
                                              type: .newPost)

        if post.isWithinThisActiveClubWeek {
            let friendIDsMinusTagged = Array(Set(ADUser.current.friendIDs).subtracting(Set(taggedUserIDs)))

            NotificationsManager.sendNotification(to: friendIDsMinusTagged,
                                                  withCategory: "NEW_POST",
                                                  message: "\(ADUser.current.name) (@\(ADUser.current.username ?? "")) just posted a \(post.activityType.notificationDisplayName).",
                                                  appUrl: "anydistance://post?postID=\(post.id)",
                                                  type: .newPost)
        }
    }

    // MARK: - Update

    func updatePost(_ post: Post) async throws {
        let url = baseUrl.appendingPathComponent("update")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "id", value: post.id)
        ]
        guard let urlWithComponents = components?.url else {
            throw PostManagerError.urlEncodingError
        }
        let payload = PostPayload(post: post)
        var request = try Edge.defaultRequest(with: urlWithComponents, method: .put)
        request.httpBody = try JSONEncoder().encode(payload)
//        print(String(data: request.httpBody!, encoding: .utf8))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
//            print(stringData)
            throw PostManagerError.requestError(stringData)
        }

        let responsePayload = try JSONDecoder().decode(PostPayload.self, from: data)
        await post.merge(with: responsePayload.post)
        PostCache.shared.cache(post: post, sendCachedPublisher: false)
    }

    // MARK: - Delete

    func deletePost(_ post: Post) async throws {
        let url = baseUrl.appendingPathComponent("delete")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "id", value: post.id)
        ]
        guard let urlWithComponents = components?.url else {
            throw PostManagerError.urlEncodingError
        }

        print(urlWithComponents.absoluteString)

        let request = try Edge.defaultRequest(with: urlWithComponents, method: .delete)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 201 ||
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            print(stringData)
            throw PostManagerError.requestError(stringData)
        }

        PostCache.shared.delete(post: post, sendCachedPublisher: true)
        currentUserHasPostedThisWeek = hasCurrentUserHasPostedThisWeek()
    }

    // MARK: - Get

    func getUserPosts(for userID: String,
                      before: String? = nil,
                      startDate: Date,
                      perPage: Int = 50) async throws -> [Post] {
        let url = baseUrl
            .appendingPathComponent("from")
            .appendingPathComponent("user")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "id", value: userID),
            URLQueryItem(name: "startDate", value: String(UInt64(startDate.timeIntervalSince1970))),
            URLQueryItem(name: "perPage", value: String(perPage))
        ]

        if let before = before {
            components?.queryItems?.append(URLQueryItem(name: "before", value: before))
        }

        guard let urlWithComponents = components?.url else {
            throw PostManagerError.urlEncodingError
        }
        let request = try Edge.defaultRequest(with: urlWithComponents, method: .get)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
//            print(stringData)
            throw PostManagerError.requestError(stringData)
        }

        return try await decodeAndCacheMultiplePosts(from: data)
    }

    func getFriendPosts(for userID: ADUser.ID = ADUser.current.id,
                        before: String? = nil,
                        startDate: Date,
                        perPage: Int = 200,
                        includeUser: Bool = true) async throws -> [Post] {
        let url = baseUrl
            .appendingPathComponent("from")
            .appendingPathComponent("friends")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "id", value: userID),
            URLQueryItem(name: "startDate", value: String(UInt64(startDate.timeIntervalSince1970))),
            URLQueryItem(name: "perPage", value: String(perPage)),
            URLQueryItem(name: "includeUser", value: String(includeUser))
        ]

        if let before = before {
            components?.queryItems?.append(URLQueryItem(name: "before", value: before))
        }

        guard let urlWithComponents = components?.url else {
            throw PostManagerError.urlEncodingError
        }
        print(urlWithComponents)
        let request = try Edge.defaultRequest(with: urlWithComponents, method: .get)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
//            print(stringData)
            throw PostManagerError.requestError(stringData)
        }

        return try await decodeAndCacheMultiplePosts(from: data, feedStartDate: startDate)
    }

    func getPost(by id: Post.ID) async throws -> Post {
        let url = baseUrl
            .appendingPathComponent("find")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "id", value: id)
        ]

        guard let urlWithComponents = components?.url else {
            throw PostManagerError.urlEncodingError
        }
        let request = try Edge.defaultRequest(with: urlWithComponents, method: .get)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
//            print(stringData)
            throw PostManagerError.requestError(stringData)
        }

        let responsePayload = try JSONDecoder().decode(PostPayload.self, from: data)
        if let cachedPost = PostCache.shared.post(withID: id) {
            await cachedPost.merge(with: responsePayload.post)
            PostCache.shared.cache(post: cachedPost, sendCachedPublisher: true)
            return cachedPost
        } else {
            let newPost = Post()
            await newPost.merge(with: responsePayload.post)
            PostCache.shared.cache(post: newPost, sendCachedPublisher: true)
            return newPost
        }
    }

    private func decodeAndCacheMultiplePosts(from data: Data,
                                             feedStartDate: Date? = nil) async throws -> [Post] {
        let json = try JSON(data: data)
        let posts = try json["results"].rawData()
        let responsePayload = try JSONDecoder().decode(MultiPostPayload.self, from: posts)

        // Remove any posts that were deleted
        if let feedStartDate = feedStartDate {
            let existingCachedFeed = PostCache.shared.friendPosts(withStartDate: feedStartDate)
            for post in existingCachedFeed {
                if !responsePayload.posts.contains(where: { $0.id == post.id }) {
                    PostCache.shared.delete(post: post, sendCachedPublisher: false)
                }
            }
        }

        // Cache new posts
        var returnedPosts: [Post] = []
        for postPayloadData in responsePayload.posts {
            guard let id = postPayloadData.id else {
                continue
            }

            if let cachedPost = PostCache.shared.post(withID: id) {
                await cachedPost.merge(with: postPayloadData)
                returnedPosts.append(cachedPost)
                PostCache.shared.cache(post: cachedPost, sendCachedPublisher: false)
            } else {
                let newPost = Post()
                await newPost.merge(with: postPayloadData)
                returnedPosts.append(newPost)
                PostCache.shared.cache(post: newPost, sendCachedPublisher: false)
            }
        }
        currentUserHasPostedThisWeek = hasCurrentUserHasPostedThisWeek()

        return returnedPosts
            .sorted(by: { $0.creationDate > $1.creationDate })
    }

    // MARK: - Comments

    func createComment(on post: Post, with body: String) async throws {
        let comment = PostComment(userID: ADUser.current.id,
                                  postID: post.id,
                                  body: body)

        await MainActor.run {
            post.comments.append(comment)
        }

        do {
            let url = Edge.host
                .appendingPathComponent("comments")
                .appendingPathComponent("create")

            var request = try Edge.defaultRequest(with: url, method: .post)
            let commentPayload = PostCommentPayload(comment: comment)
            request.httpBody = try JSONEncoder().encode(commentPayload)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 201 else {
                let stringData = String(data: data, encoding: .utf8)
//                print(stringData)
                throw PostManagerError.requestError(stringData)
            }

            let postedCommentData = try JSONDecoder().decode(PostCommentPayload.self, from: data)
            await MainActor.run {
                if !post.comments.isEmpty {
                    post.comments[post.comments.count-1].id = postedCommentData.comment.id
                    post.comments[post.comments.count-1].createdAt = postedCommentData.comment.createdAt
                }
                PostCache.shared.cache(post: post, sendCachedPublisher: false)
            }

            // Send notifications to all users who are tagged who are not the post creator.
            let decodedTags = TagCoder.decodeTags(for: postedCommentData.comment.body)
            let taggedUserIDs = decodedTags.tags
                .map { $0.userID }
                .filter { $0 != post.creatorUserID }
            let tagDecodedBody = String(decodedTags.attributedString.characters)

            let tagMessage = "@\(ADUser.current.username ?? "") mentioned you in a comment: \(tagDecodedBody)"
            NotificationsManager.sendNotification(to: taggedUserIDs,
                                                  withCategory: "POST_COMMENT",
                                                  message: tagMessage,
                                                  appUrl: "anydistance://post?postID=\(post.id)",
                                                  type: .commentsAndReactions)

            if !post.creatorIsSelf {
                // Send a comment notification to the post creator (if they're not the current user).
                let message = "@\(ADUser.current.username ?? "") commented on your \(post.activityType.notificationDisplayName): \(tagDecodedBody)"
                NotificationsManager.sendNotification(to: post.creatorUserID,
                                                      withCategory: "POST_COMMENT",
                                                      message: message,
                                                      appUrl: "anydistance://post?postID=\(post.id)",
                                                      type: .commentsAndReactions)

                // Send a notification to other commenters on the post who were not tagged AND who are
                // not the current user AND who are not the post creator.
                let otherCommenterIDs = post.comments
                    .map { $0.userID }
                    .uniqued()
                    .filter { $0 != post.creatorUserID && $0 != ADUser.current.id }
                    .filter { !taggedUserIDs.contains($0) }

                let author = await post.author()
                for id in otherCommenterIDs {
                    NotificationsManager.sendNotification(to: id,
                                                          withCategory: "POST_COMMENT",
                                                          message: "@\(ADUser.current.username ?? "") also commented on @\(author?.username ?? "")'s \(post.activityType.notificationDisplayName).",
                                                          appUrl: "anydistance://post?postID=\(post.id)",
                                                          type: .commentsAndReactions)
                }
            }
        } catch {
            await MainActor.run {
                post.comments.removeLast()
            }
            throw error
        }
    }

    func deleteComment(with id: PostComment.ID, on post: Post) async throws {
        let url = Edge.host
            .appendingPathComponent("comments")
            .appendingPathComponent("delete")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "id", value: id)
        ]
        guard let urlWithComponents = components?.url else {
            throw PostManagerError.urlEncodingError
        }
        let request = try Edge.defaultRequest(with: urlWithComponents, method: .delete)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
//            print(stringData)
            throw PostManagerError.requestError(stringData)
        }

        await MainActor.run {
            post.comments.removeAll(where: { $0.id == id })
            PostCache.shared.cache(post: post, sendCachedPublisher: false)
        }
    }

    // MARK: - Reactions

    func createReaction(on post: Post, with type: PostReactionType) async throws {
        let reaction = PostReaction(userID: ADUser.current.id,
                                    postID: post.id,
                                    kind: type)

        await MainActor.run {
            post.reactions.append(reaction)
        }

        do {
            let url = Edge.host
                .appendingPathComponent("reactions")
                .appendingPathComponent("create")

            var request = try Edge.defaultRequest(with: url, method: .post)
            let commentPayload = PostReactionPayload(reaction: reaction)
            request.httpBody = try JSONEncoder().encode(commentPayload)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 201 else {
                let stringData = String(data: data, encoding: .utf8)
                //                print(stringData)
                throw PostManagerError.requestError(stringData)
            }

            let postedReactionData = try JSONDecoder().decode(PostReactionPayload.self, from: data)
            await MainActor.run {
                if !post.reactions.isEmpty {
                    post.reactions[post.reactions.count-1].id = postedReactionData.reaction.id
                    post.reactions[post.reactions.count-1].createdAt = postedReactionData.reaction.createdAt
                }
                PostCache.shared.cache(post: post, sendCachedPublisher: false)
            }

            let message = "@\(ADUser.current.username ?? "") reacted to your \(post.activityType.notificationDisplayName): \(postedReactionData.reaction.kind.emoji)"
            NotificationsManager.sendNotification(to: post.creatorUserID,
                                                  withCategory: "POST_REACTION",
                                                  message: message,
                                                  appUrl: "anydistance://post?postID=\(post.id)",
                                                  type: .commentsAndReactions)
        } catch {
            await MainActor.run {
                _ = post.reactions.removeLast()
            }
            throw error
        }
    }
}

enum PostManagerError: Error {
    case requestError(_ errorString: String?)
    case urlEncodingError
    case responseDecodingError
}

extension NSUbiquitousKeyValueStore {
    var overrideHasPosted: Bool {
        get {
            return bool(forKey: "overrideHasPosted")
        }

        set {
            set(newValue, forKey: "overrideHasPosted")
        }
    }
}

// Licensed under the Any Distance Source-Available License
//
//  PostCache.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/14/23.
//

import Foundation
import Cache
import Combine

class PostCache: NSObject, ObservableObject {

    static let shared = PostCache()

    private var byPostIDCache: Storage<String, Post>? // post id, Post
    private var draftCache: Storage<String, Post>? // local healthkit ID, Post
    private var byUserIDCache: Storage<String, [String]>? // user id, array of Post id
    private var friendPostsByStartDateCache: Storage<Date, [String]>? // week start date, array of Post id

    let postCachedPublisher = PassthroughSubject<Void, Never>()

    /// Clear the draft cache once on the next run by incrementing this token. Helpful for
    /// schema changes, bug fixes, etc.
    let draftCacheClearToken: Int = 1

    override init() {
        let memoryConfig = MemoryConfig(expiry: .never,
                                        countLimit: 500,
                                        totalCostLimit: 10)

        byPostIDCache = try? Storage<String, Post>(
            diskConfig: DiskConfig(name: "com.anydistance.PostCache"),
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forCodable(ofType: Post.self)
        )

        draftCache = try? Storage<String, Post>(
            diskConfig: DiskConfig(name: "com.anydistance.PostDraftCache"),
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forCodable(ofType: Post.self)
        )

        byUserIDCache = try? Storage<String, [String]>(
            diskConfig: DiskConfig(name: "com.anydistance.PostByUserIDCache"),
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forCodable(ofType: [String].self)
        )

        friendPostsByStartDateCache = try? Storage<Date, [String]>(
            diskConfig: DiskConfig(name: "com.anydistance.PostByStartDateCache"),
            memoryConfig: memoryConfig,
            transformer: TransformerFactory.forCodable(ofType: [String].self)
        )

//        try? byPostIDCache?.removeAll()
//        try? byUserIDCache?.removeAll()

        // Clear the draft cache if necessary
        if NSUbiquitousKeyValueStore.default.lastDraftCacheClearToken < draftCacheClearToken {
            try? draftCache?.removeAll()
            NSUbiquitousKeyValueStore.default.lastDraftCacheClearToken = draftCacheClearToken
        }
    }

    func draftOrLivePost(for activity: Activity?) -> Post {
        guard let activity = activity else {
            return Post()
        }

        let userPosts = posts(forUserID: ADUser.current.id)
        if let matchingPost = userPosts.first(where: { $0.localHealthKitID == activity.id }) {
            return matchingPost
        } else if ADUser.current.hasRegistered,
                  let cachedPost = try? draftCache?.object(forKey: activity.id) {
            if cachedPost.creatorUserID.isEmpty {
                cachedPost.creatorUserID = ADUser.current.id
                cache(post: cachedPost, sendCachedPublisher: false)
            }
            return cachedPost
        } else {
            let newPost = Post(localActivity: activity)
            cache(post: newPost, sendCachedPublisher: true)
            return newPost
        }
    }

    func livePostExists(for activity: Activity) -> Bool {
        let userPosts = posts(forUserID: ADUser.current.id)
        return userPosts.contains(where: { $0.localHealthKitID == activity.id })
    }

    func cache(post: Post, sendCachedPublisher: Bool) {
        defer {
            DispatchQueue.main.async {
                if sendCachedPublisher {
                    self.postCachedPublisher.send()
                }
            }
        }

        if post.isDraft {
            try? draftCache?.setObject(post, forKey: post.localHealthKitID)
            return
        }

        try? byPostIDCache?.setObject(post, forKey: post.id)
        
        if let array = try? byUserIDCache?.object(forKey: post.creatorUserID) {
            if !array.contains(post.id) {
                var newArray = [post.id] + array
                newArray.sort(by: {
                    let post1Date = self.post(withID: $0)?.creationDate ?? Date()
                    let post2Date = self.post(withID: $1)?.creationDate ?? Date()
                    return post1Date > post2Date
                })
                try? byUserIDCache?.setObject(newArray, forKey: post.creatorUserID)
            }
        } else {
            try? byUserIDCache?.setObject([post.id], forKey: post.creatorUserID)
        }

        let weekStartDate = post.activeClubWeekStartDate
        if let array = try? friendPostsByStartDateCache?.object(forKey: weekStartDate) {
            if !array.contains(post.id) {
                try? friendPostsByStartDateCache?.setObject(array + [post.id], forKey: weekStartDate)
            }
        } else {
            try? friendPostsByStartDateCache?.setObject([post.id], forKey: weekStartDate)
        }
    }

    func delete(post: Post, sendCachedPublisher: Bool) {
        defer {
            DispatchQueue.main.async {
                if sendCachedPublisher {
                    self.postCachedPublisher.send()
                }
            }
        }

        let postID = post.id
        if let draftPost = try? draftCache?.object(forKey: post.localHealthKitID) {
            draftPost.id = ""
            try? draftCache?.setObject(draftPost, forKey: post.localHealthKitID)
        }

        try? byPostIDCache?.removeObject(forKey: post.id)

        if var array = try? byUserIDCache?.object(forKey: post.creatorUserID) {
            array.removeAll(where: { $0 == postID })
            try? byUserIDCache?.setObject(array, forKey: post.creatorUserID)
        }

        let weekStartDate = post.activeClubWeekStartDate
        if var array = try? friendPostsByStartDateCache?.object(forKey: weekStartDate) {
            array.removeAll(where: { $0 == postID })
            try? friendPostsByStartDateCache?.setObject(array, forKey: weekStartDate)
        }
    }

    func post(withID id: String) -> Post? {
        return try? byPostIDCache?.object(forKey: id)
    }

    func posts(forUserID id: ADUser.ID) -> [Post] {
        if let postIDs = try? byUserIDCache?.object(forKey: id) {
            return postIDs
                .compactMap { self.post(withID: $0) }
        } else {
            return []
        }
    }

    func friendPosts(withStartDate startDate: Date) -> [Post] {
        if let postIDs = try? friendPostsByStartDateCache?.object(forKey: startDate) {
            return postIDs
                .compactMap { self.post(withID: $0) }
                .filter { post in
                    return !ADUser.current.blockedIDs.contains(post.creatorUserID)
                }
                .sorted(by: { $0.creationDate > $1.creationDate })
        } else {
            return []
        }
    }

    func friendPosts(withStartDate startDate: Date,
                     earning collectible: Collectible) -> [Post] {
        return friendPosts(withStartDate: startDate)
            .filter { $0.collectibleRawValues?.contains(collectible.type.rawValue) ?? false }
    }
}

fileprivate extension NSUbiquitousKeyValueStore {
    var lastDraftCacheClearToken: Int {
        get {
            if object(forKey: "lastDraftCacheClearToken") == nil {
                return 0
            }

            return integer(forKey: "lastDraftCacheClearToken")
        }

        set {
            set(newValue, forKey: "lastDraftCacheClearToken")
        }
    }
}

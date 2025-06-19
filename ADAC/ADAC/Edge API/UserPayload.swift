// Licensed under the Any Distance Source-Available License
//
//  UserPayload.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/6/23.
//

import Foundation
import BetterCodable

struct UserPayload: Codable {
    var user: PayloadData

    struct PayloadData: Codable {
        var id: String?
        var createdAt: UInt64?
        var appleSignInID: String = ""
        var name: String?
        var email: String?
        var wantsToBeEmailed: Bool?
        var distanceUnit: DistanceUnit?
        var signupDate: UInt64?
        var lastCollectiblesRefreshDate: UInt64?
        var lastGoalRefreshDate: UInt64?
        var lastTotalDistanceRefreshDate: UInt64?
        @DefaultEmptyArray var goals: [Goal] = []
        @DefaultEmptyArray var collectibles: [Collectible] = []
        var totalDistanceTrackedMeters: Double?
        var subscriptionProductID: String?
        var username: String?
        var bio: String?
        var phone: String?
        var hashedPhone: String?
        var location: String?
        var profilePhotoURL: URL?
        var coverPhotoURL: URL?
        var recentActivityTypes: [ActivityType]?
        var allowsTags: Bool?
        var notificationTags: [String]?
    }

    init(user: ADUser) {
        self.user = PayloadData()
        self.user.id = user.id.isEmpty ? nil : user.id
        self.user.appleSignInID = user.appleSignInID
        self.user.name = user.name.trimmingCharacters(in: .whitespaces)
        self.user.email = user.email
        self.user.wantsToBeEmailed = user.wantsToBeEmailed
        self.user.distanceUnit = user.distanceUnit
        self.user.signupDate = UInt64(user.signupDate?.timeIntervalSince1970)
        self.user.lastCollectiblesRefreshDate = UInt64(user.lastCollectiblesRefreshDate?.timeIntervalSince1970)
        self.user.lastGoalRefreshDate = UInt64(user.lastGoalRefreshDate?.timeIntervalSince1970)
        self.user.lastTotalDistanceRefreshDate = UInt64(user.lastTotalDistanceRefreshDate?.timeIntervalSince1970)
        self.user.goals = user.goals
        self.user.collectibles = user.collectibles
        self.user.totalDistanceTrackedMeters = user.totalDistanceTrackedMeters
        self.user.subscriptionProductID = user.subscriptionProductID
        self.user.username = user.username?.lowercased()
        self.user.bio = user.bio
        self.user.phone = user.phoneNumber
        self.user.hashedPhone = user.phoneNumber?.sha256()
        self.user.location = user.location
        self.user.profilePhotoURL = user.profilePhotoUrl
        self.user.coverPhotoURL = user.coverPhotoUrl
        self.user.recentActivityTypes = user.recentActivityTypes
        self.user.allowsTags = user.allowsTags
        self.user.notificationTags = user.notificationTags
    }
}

struct Friendship: Codable, Equatable {
    typealias ID = String

    var id: ID
    var requestingUserID: String
    var targetUserID: String
    var approvedAt: UInt64?

    var isPending: Bool {
        return approvedAt == nil
    }
}

struct MultiUserPayload: Codable {
    var users: [UserPayload.PayloadData]
}

struct CurrentUserResponsePayload: Codable {
    var user: UserPayload.PayloadData
    var friends: [UserPayload.PayloadData]
    var friendships: [Friendship]
    var blocks: [ADUser.ID]
}

struct FriendsOfFriendsResponsePayload: Codable {
    var friend: UserPayload.PayloadData
    var totalFriends: Int
    var totalMutuals: Int
}

extension ADUser {
    func merge(with payload: UserPayload.PayloadData, hydrateAllCollectibles: Bool = false) async {
        await MainActor.run {
            self.id = payload.id ?? self.id
            self.createdAt = Date(timeIntervalSince1970: payload.createdAt) ?? self.createdAt
            self.appleSignInID = payload.appleSignInID
            self.name = payload.name ?? self.name
            self.email = payload.email ?? self.email
            self.wantsToBeEmailed = payload.wantsToBeEmailed ?? self.wantsToBeEmailed
            self.distanceUnit = payload.distanceUnit ?? self.distanceUnit
            self.signupDate = Date(timeIntervalSince1970: payload.signupDate) ?? self.signupDate
            self.lastCollectiblesRefreshDate = Date(timeIntervalSince1970: payload.lastCollectiblesRefreshDate) ?? self.lastCollectiblesRefreshDate
            self.lastGoalRefreshDate = Date(timeIntervalSince1970: payload.lastGoalRefreshDate) ?? self.lastGoalRefreshDate
            self.lastTotalDistanceRefreshDate = Date(timeIntervalSince1970: payload.lastTotalDistanceRefreshDate) ?? self.lastTotalDistanceRefreshDate
            if !payload.goals.isEmpty {
                self.goals = payload.goals
            }
            if !payload.collectibles.isEmpty {
                if self === ADUser.current || hydrateAllCollectibles {
                    self.collectibles = payload.collectibles
                } else {
                    // If this isn't the current user, only hydrate the first 30 collectibles to save
                    // memory.
                    let maxCount: Int = 30
                    var filteredCollectibles: [Collectible] = []
                    for collectible in payload.collectibles {
                        if !filteredCollectibles.contains(where: { $0.type.rawValue == collectible.type.rawValue }) {
                            filteredCollectibles.append(collectible)
                        }

                        if filteredCollectibles.count == maxCount {
                            break
                        }
                    }
                    self.collectibles = filteredCollectibles
                }
            }
            self.totalDistanceTrackedMeters = payload.totalDistanceTrackedMeters ?? self.totalDistanceTrackedMeters
            self.subscriptionProductID = payload.subscriptionProductID ?? self.subscriptionProductID
            self.username = payload.username?.lowercased() ?? self.username
            self.bio = payload.bio ?? self.bio
            self.phoneNumber = payload.phone ?? self.phoneNumber
            self.location = payload.location ?? self.location
            self.profilePhotoUrl = payload.profilePhotoURL ?? self.profilePhotoUrl
            self.coverPhotoUrl = payload.coverPhotoURL ?? self.coverPhotoUrl
            self.recentActivityTypes = payload.recentActivityTypes ?? self.recentActivityTypes
            self.allowsTags = payload.allowsTags ?? self.allowsTags
            self.notificationTags = payload.notificationTags ?? self.notificationTags
        }
    }
}

extension Date {
    init?(timeIntervalSince1970: UInt64?) {
        if let timeIntervalSince1970 = timeIntervalSince1970 {
            self.init(timeIntervalSince1970: TimeInterval(timeIntervalSince1970))
        } else {
            return nil
        }
    }
}

fileprivate extension UInt64 {
    init?(_ double: Double?) {
        if let double = double {
            self.init(double)
        } else {
            return nil
        }
    }
}

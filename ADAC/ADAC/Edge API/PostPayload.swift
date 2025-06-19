// Licensed under the Any Distance Source-Available License
//
//  PostPayload.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/9/23.
//

import Foundation
import BetterCodable
import CoreLocation

struct PostPayload: Codable {
    var post: PayloadData

    struct PayloadData: Codable {
        var id: String?
        var createdAt: UInt64?
        var beforeCursor: String?
        var userID: String?
        var localHealthKitID: String
        var mediaURLs: [String]?
        var title: String?
        var postDescription: String?
        var musicTrackID: String?
        var activityType: ActivityType
        var activityStartDateUTC: UInt64
        var activityEndDateUTC: UInt64
        var distanceMeters: Float?
        var movingTime: TimeInterval?
        var coordinates: [Float]?
        var miSplits: [Split]?
        var kmSplits: [Split]?
        var activeCalories: Float?
        var totalElevationGainMeters: Float?
        var averageSpeedMetersSecond: Float?
        var paceMeters: TimeInterval?
        var collectibleRawValues: [String]?
        var comments: [PostComment]?
        var reactions: [FailableDecodable<PostReaction>]?
        var hiddenStatTypes: [String]?
        var metadata: String?
    }

    init(post: Post) {
        let startDate = UInt64(post.activityStartDateUTC.timeIntervalSince1970)
        let endDate = UInt64(post.activityEndDateUTC.timeIntervalSince1970)
        self.post = PayloadData(localHealthKitID: post.localHealthKitID,
                                activityType: post.activityType,
                                activityStartDateUTC: startDate,
                                activityEndDateUTC: endDate)
        self.post.userID = post.creatorUserID
        self.post.mediaURLs = post.mediaUrls.map { $0.unImgixdURL.absoluteString }
        self.post.title = post.title
        self.post.postDescription = post.postDescription
        self.post.musicTrackID = post.musicTrackID
        self.post.distanceMeters = post.distanceMeters
        self.post.movingTime = post.movingTime
        self.post.coordinates = PostCoordinateCoder.encodeCoordinates(post.coordinatesClippedIfNecessary)
        self.post.miSplits = post.miSplits
        self.post.kmSplits = post.kmSplits
        self.post.activeCalories = post.activeCalories
        self.post.totalElevationGainMeters = post.totalElevationGainMeters
        self.post.averageSpeedMetersSecond = post.averageSpeedMetersSecond
        self.post.paceMeters = post.paceMeters
        self.post.collectibleRawValues = post.collectibleRawValues
        self.post.hiddenStatTypes = post.hiddenStatTypes
        self.post.metadata = post.metadata
    }
}

struct MultiPostPayload: Codable {
    var posts: [PostPayload.PayloadData]
    var beforeCursor: String
    var hasMorePages: Bool
}

struct ClubStatsData: Codable {
    var postCount: Int
    var totalDistanceMeters: Float?
    var totalMovingTime: Float?
    var totalActiveCals: Float?
    var totalElevGainMeters: Float?
    var collectibleRawValues: [String]?

    var medals: [Collectible] {
        guard let collectibleRawValues = collectibleRawValues else {
            return []
        }

        return collectibleRawValues
            .compactMap { CollectibleType(rawValue: $0) }
            .map { Collectible(type: $0, dateEarned: Date.distantPast) }
            .filter { $0.itemType == .medal }
    }

    var uniquedMedals: [Collectible] {
        guard let collectibleRawValues = collectibleRawValues else {
            return []
        }

        return collectibleRawValues
            .uniqued()
            .compactMap { CollectibleType(rawValue: $0) }
            .map { Collectible(type: $0, dateEarned: Date.distantPast) }
            .filter { $0.itemType == .medal }
    }
}

struct DateRangedClubStatsData: Codable {
    var startDate: Date
    var endDate: Date
    var data: ClubStatsData
}

struct PostCommentPayload: Codable {
    var comment: PostComment
}

struct PostReactionPayload: Codable {
    var reaction: PostReaction
}

extension Post {
    func merge(with payload: PostPayload.PayloadData) async {
        await MainActor.run {
            self.id = payload.id ?? self.id
            self.creationDate = Date(timeIntervalSince1970: payload.createdAt) ?? self.creationDate
            self.creatorUserID = payload.userID ?? self.creatorUserID
            self.localHealthKitID = payload.localHealthKitID
            self.mediaUrls = payload.mediaURLs?.compactMap { URL(string: $0)?.unImgixdURL } ?? self.mediaUrls
            self.title = payload.title ?? self.title
            self.postDescription = payload.postDescription ?? self.postDescription
            self.musicTrackID = payload.musicTrackID ?? self.musicTrackID
            self.activityType = payload.activityType
            self.activityStartDateUTC = Date(timeIntervalSince1970: payload.activityStartDateUTC) ?? self.activityStartDateUTC
            self.activityEndDateUTC = Date(timeIntervalSince1970: payload.activityEndDateUTC) ?? self.activityEndDateUTC
            self.distanceMeters = payload.distanceMeters
            self.movingTime = payload.movingTime
            self.coordinates = PostCoordinateCoder.decodeCoordinates(from: payload.coordinates) ?? self.coordinates
            self.miSplits = payload.miSplits ?? self.miSplits
            self.kmSplits = payload.kmSplits ?? self.kmSplits
            self.activeCalories = payload.activeCalories
            self.totalElevationGainMeters = payload.totalElevationGainMeters
            self.averageSpeedMetersSecond = payload.averageSpeedMetersSecond
            self.paceMeters = payload.paceMeters
            self.collectibleRawValues = payload.collectibleRawValues ?? self.collectibleRawValues
            self.comments = payload.comments ?? self.comments
            self.reactions = payload.reactions?.compactMap { $0.base } ?? self.reactions
            self.hiddenStatTypes = payload.hiddenStatTypes ?? self.hiddenStatTypes
            self.metadata = payload.metadata ?? self.metadata
        }
    }
}

class PostCoordinateCoder {
    static func encodeCoordinates(_ locations: [LocationWrapper]?) -> [Float]? {
        guard let locations = locations else {
            return nil
        }

        var coords: [Float] = []
        for location in locations {
            coords.append(Float(location.latitude))
            coords.append(Float(location.longitude))
            coords.append(Float(location.altitude))
        }
        return coords
    }

    static func decodeCoordinates(from floatArray: [Float]?) -> [LocationWrapper]? {
        guard let coords = floatArray else {
            return []
        }

        var wrappers: [LocationWrapper] = []
        for i in stride(from: 0, to: coords.count - 1, by: 3) {
            guard i < coords.count - 3 else {
                continue
            }

            let timestamp = Date().addingTimeInterval(TimeInterval((-1 * coords.count) + i))
            let wrapper = LocationWrapper(latitude: CLLocationDegrees(coords[i]),
                                          longitude: CLLocationDegrees(coords[i+1]),
                                          altitude: CLLocationDistance(coords[i+2]),
                                          timestamp: timestamp)
            wrappers.append(wrapper)
        }

        return wrappers
    }
}

// Licensed under the Any Distance Source-Available License
//
//  Post.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/14/23.
//

import Foundation
import CoreLocation
import UIKit
import Combine
import HealthKit

class Post: NSObject, ObservableObject, Codable {
    typealias ID = String

    var id: Post.ID
    @Published var creationDate: Date
    @Published var creatorUserID: String
    @Published var localHealthKitID: String
    @Published var mediaUrls: [URL]
    @Published var title: String
    @Published var postDescription: String
    @Published var musicTrackID: String
    @Published var reactions: [PostReaction]
    @Published var comments: [PostComment]
    @Published var activityType: ActivityType
    @Published var activityStartDateUTC: Date
    @Published var activityEndDateUTC: Date

    @Published var distanceMeters: Float?
    @Published var movingTime: Double?
    @Published var encodedCoordinates: [Float]?
    @Published var miSplits: [Split]?
    @Published var kmSplits: [Split]?
    @Published var activeCalories: Float?
    @Published var totalElevationGainMeters: Float?
    @Published var averageSpeedMetersSecond: Float?
    @Published var paceMeters: TimeInterval?
    @Published var collectibleRawValues: [String]?
    @Published var hiddenStatTypes: [String]
    @Published var metadata: String?

    @Published var cityAndState: String?
    var loadingCityAndState: Bool = false

    @Published var isEditing: Bool = false
    private var subscribers: Set<AnyCancellable> = []

    lazy var coordinates: [LocationWrapper]? = PostCoordinateCoder.decodeCoordinates(from: self.encodedCoordinates) {
        didSet {
            self.encodedCoordinates = PostCoordinateCoder.encodeCoordinates(coordinates)
        }
    }

    enum HiddenStatType: String {
        case distance
        case movingTime
        case splits
        case activeCalories
        case elevationGain
        case averageSpeed
        case pace
        case location
    }

    // MARK: - Codable Conformance

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PostCodingKeys.self)
        self.id = try container.decode(Post.ID.self, forKey: .id)
        self.creationDate = try container.decode(Date.self, forKey: .creationDate)
        self.creatorUserID = try container.decode(String.self, forKey: .creatorUserID)
        self.localHealthKitID = try container.decode(String.self, forKey: .localHealthKitID)
        self.mediaUrls = try container.decode([URL].self, forKey: .mediaUrls)
        self.title = try container.decode(String.self, forKey: .title)
        self.postDescription = try container.decode(String.self, forKey: .postDescription)
        self.musicTrackID = try container.decode(String.self, forKey: .musicTrackID)
        self.reactions = try container.decode([PostReaction].self, forKey: .reactions)
        self.comments = try container.decode([PostComment].self, forKey: .comments)
        self.activityType = try container.decode(ActivityType.self, forKey: .activityType)
        self.activityStartDateUTC = try container.decode(Date.self, forKey: .activityStartDateUTC)
        self.activityEndDateUTC = try container.decode(Date.self, forKey: .activityEndDateUTC)
        self.distanceMeters = try container.decodeIfPresent(Float.self, forKey: .distanceMeters)
        self.movingTime = try container.decodeIfPresent(Double.self, forKey: .movingTime)
        self.encodedCoordinates = try container.decodeIfPresent([Float].self, forKey: .coordinates)
        self.miSplits = try container.decodeIfPresent([Split].self, forKey: .miSplits)
        self.kmSplits = try container.decodeIfPresent([Split].self, forKey: .kmSplits)
        self.activeCalories = try container.decodeIfPresent(Float.self, forKey: .activeCalories)
        self.totalElevationGainMeters = try container.decodeIfPresent(Float.self, forKey: .totalElevationGainMeters)
        self.averageSpeedMetersSecond = try container.decodeIfPresent(Float.self, forKey: .averageSpeedMetersSecond)
        self.paceMeters = try container.decodeIfPresent(TimeInterval.self, forKey: .paceMeters)
        self.collectibleRawValues = try container.decodeIfPresent([String].self, forKey: .collectibleRawValues)
        self.hiddenStatTypes = try container.decodeIfPresent([String].self, forKey: .hiddenStatTypes) ?? []
        self.metadata = try container.decodeIfPresent(String.self, forKey: .metadata)
        super.init()
        self.observeDistanceUnit()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PostCodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.creationDate, forKey: .creationDate)
        try container.encode(self.creatorUserID, forKey: .creatorUserID)
        try container.encode(self.localHealthKitID, forKey: .localHealthKitID)
        try container.encode(self.mediaUrls, forKey: .mediaUrls)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.postDescription, forKey: .postDescription)
        try container.encode(self.musicTrackID, forKey: .musicTrackID)
        try container.encode(self.reactions, forKey: .reactions)
        try container.encode(self.comments, forKey: .comments)
        try container.encode(self.activityType, forKey: .activityType)
        try container.encode(self.activityStartDateUTC, forKey: .activityStartDateUTC)
        try container.encode(self.activityEndDateUTC, forKey: .activityEndDateUTC)
        try container.encodeIfPresent(self.distanceMeters, forKey: .distanceMeters)
        try container.encodeIfPresent(self.movingTime, forKey: .movingTime)
        try container.encodeIfPresent(self.encodedCoordinates, forKey: .coordinates)
        try container.encodeIfPresent(self.miSplits, forKey: .miSplits)
        try container.encodeIfPresent(self.kmSplits, forKey: .kmSplits)
        try container.encodeIfPresent(self.activeCalories, forKey: .activeCalories)
        try container.encodeIfPresent(self.totalElevationGainMeters, forKey: .totalElevationGainMeters)
        try container.encodeIfPresent(self.averageSpeedMetersSecond, forKey: .averageSpeedMetersSecond)
        try container.encodeIfPresent(self.paceMeters, forKey: .paceMeters)
        try container.encodeIfPresent(self.collectibleRawValues, forKey: .collectibleRawValues)
        try container.encode(self.hiddenStatTypes, forKey: .hiddenStatTypes)
        try container.encodeIfPresent(self.metadata, forKey: .metadata)
    }

    // MARK: - Default init

    init(localActivity: Activity) {
        self.id = ""
        self.creationDate = Date()
        self.creatorUserID = ADUser.current.id
        self.localHealthKitID = localActivity.id
        self.mediaUrls = []
        self.title = ""
        self.postDescription = ""
        self.musicTrackID = ""
        self.reactions = []
        self.comments = []
        self.activityType = localActivity.activityType
        self.activityStartDateUTC = localActivity.startDate
        self.activityEndDateUTC = localActivity.endDate
        self.distanceMeters = localActivity.distance > 0.0 ? localActivity.distance : nil
        self.movingTime = localActivity.movingTime > 0.0 ? localActivity.movingTime : nil
        self.activeCalories = localActivity.activeCalories > 0.0 ? localActivity.activeCalories : nil
        self.totalElevationGainMeters = localActivity.totalElevationGain > 0.0 ? localActivity.totalElevationGain : nil
        self.averageSpeedMetersSecond = localActivity.averageSpeed > 0.0 ? localActivity.averageSpeed : nil
        self.paceMeters = localActivity.paceMeters > 0.0 ? localActivity.paceMeters : nil
        self.collectibleRawValues = ADUser.current.collectibles(for: localActivity).map { $0.type.rawValue }
        self.hiddenStatTypes = []
        super.init()
        self.observeDistanceUnit()

        Task {
            self.coordinates = (try? await localActivity.unclippedCoordinates)?.compactMap { LocationWrapper(from: $0) }
            self.loadCityAndState()
            if !(localActivity is GarminActivity) {
                self.miSplits = try? await localActivity.loader.splits(for: localActivity, unit: .miles)
                self.kmSplits = try? await localActivity.loader.splits(for: localActivity, unit: .kilometers)
            }
            PostCache.shared.cache(post: self, sendCachedPublisher: false)
        }
    }

    override init() {
        self.id = UUID().uuidString
        self.creationDate = Date()
        self.creatorUserID = ADUser.current.id
        self.localHealthKitID = UUID().uuidString
        self.mediaUrls = []
        self.title = ""
        self.postDescription = ""
        self.musicTrackID = ""
        self.reactions = []
        self.comments = []
        self.activityType = .bikeRide
        self.activityStartDateUTC = Date().addingTimeInterval(-1000)
        self.activityEndDateUTC = Date().addingTimeInterval(-200)
        self.hiddenStatTypes = []
        super.init()
        self.observeDistanceUnit()
    }

    func observeDistanceUnit() {
        ADUser.current.$distanceUnit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &subscribers)
    }

    func setMetadata() {
        self.metadata = ""
        self.metadata?.append("appVersion=\(UIApplication.shared.versionAndBuildNumber)")

        if let localActivity = activity {
            self.metadata?.append("&")
            self.metadata?.append("source=\(localActivity.workoutSource?.rawValue ?? "")")

            if let hkWorkout = localActivity as? HKWorkout,
               let workoutMetadata = hkWorkout.metadata {
                self.metadata?.append("&")
                for datum in workoutMetadata {
                    self.metadata?.append("\(datum.key)=\(datum.value)")
                    self.metadata?.append("&")
                }
                self.metadata?.removeLast()
            }
        }
    }
}

extension Post {
    func loadCityAndState() {
        guard !loadingCityAndState else {
            return
        }
        loadingCityAndState = true

        Task(priority: .userInitiated) {
            guard let coordinate = CLLocation(wrapper: coordinates?.first) else {
                loadingCityAndState = false
                return
            }

            let cityAndState: String? = try await withCheckedThrowingContinuation { continuation in
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(coordinate) { (placemarks, error) in
                    if let error = error {
                        self.loadingCityAndState = false
                        continuation.resume(throwing: error)
                    } else if let firstLocation = placemarks?[0],
                              let city = firstLocation.locality,
                              let state = firstLocation.administrativeArea {
                        continuation.resume(returning: city + ", " + state)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }

            await MainActor.run {
                self.cityAndState = cityAndState
                self.loadingCityAndState = false
            }
        }
    }
}

enum PostCodingKeys: String, CodingKey, CaseIterable {
    case id
    case creationDate
    case creatorUserID
    case localHealthKitID
    case mediaUrls
    case title
    case postDescription
    case musicTrackID
    case reactions
    case comments
    case activityType
    case activityStartDateUTC
    case activityStartDateLocal
    case activityEndDateUTC
    case activityEndDateLocal
    case distanceMeters
    case movingTime
    case coordinates
    case miSplits
    case kmSplits
    case activeCalories
    case totalElevationGainMeters
    case averageSpeedMetersSecond
    case paceMeters
    case collectibleRawValues
    case hiddenStatTypes
    case metadata
}

extension Post {
    var coordinatesClippedIfNecessary: [LocationWrapper]? {
        guard let coordinates = coordinates else {
            return nil
        }

        guard NSUbiquitousKeyValueStore.default.defaultRecordingSettings.clipRoute else {
            return coordinates
        }

        let countToClip = Int(NSUbiquitousKeyValueStore.default.defaultRecordingSettings.routeClipPercentage * Double(coordinates.count))
        return Array(coordinates[countToClip..<coordinates.count-countToClip])
    }

    func statTypeIsVisible(_ statType: HiddenStatType) -> Bool {
        return !hiddenStatTypes.contains(statType.rawValue)
    }

    func setVisible(_ visible: Bool, for statType: HiddenStatType) {
        if !visible && statTypeIsVisible(statType) {
            hiddenStatTypes.append(statType.rawValue)
        } else if visible {
            hiddenStatTypes.removeAll(where: { $0 == statType.rawValue })
        }
    }

    var collectibles: [Collectible] {
        return (collectibleRawValues ?? []).compactMap { rawValue in
            if let type = CollectibleType(rawValue: rawValue) {
                return Collectible(type: type, dateEarned: activityStartDateUTC)
            }
            return nil
        }
    }

    var medals: [Collectible] {
        return collectibles.filter { $0.itemType == .medal }
    }

    var tagDecodedDescription: String {
        let attrString = TagCoder.decodeTags(for: postDescription,
                                             withBaseFontSize: 16.0).attributedString
        return String(attrString.characters)
    }

    func author() async -> ADUser? {
        if ADUser.current.id == creatorUserID {
            return ADUser.current
        }

        if let cached = cachedAuthor() {
            return cached
        }

        return try? await UserManager.shared.getUsers(byCanonicalIDs: [creatorUserID]).first
    }

    func cachedAuthor() -> ADUser? {
        return UserCache.shared.user(forID: creatorUserID)
    }

    var creatorIsSelf: Bool {
        return creatorUserID == ADUser.current.id
    }

    var isDraft: Bool {
        return id.isEmpty || isEditing
    }

    var isWithinThisActiveClubWeek: Bool {
        return activityStartDateUTC >= PostManager.shared.thisWeekPostStartDate
    }

    var activeClubWeekStartDate: Date {
        if Calendar.current.component(.weekday, from: activityStartDateUTC) == 2 {
            return Calendar.current.startOfDay(for: activityStartDateUTC)
        }

        return Calendar.current.nextDate(after: activityStartDateUTC,
                                         matching: DateComponents(weekday: 2),
                                         matchingPolicy: .strict,
                                         direction: .backward) ?? activityStartDateUTC
    }

    var isReactable: Bool {
        return !creatorIsSelf && !reactions.contains(where: { $0.wasCreatedBySelf })
    }

    var paceInUserSelectedUnit: TimeInterval {
        guard let paceMeters = paceMeters else {
            guard let averageSpeedMetersSecond = averageSpeedMetersSecond else {
                return 0.0
            }

            guard averageSpeedMetersSecond.isNormal && averageSpeedMetersSecond > 0.0 else {
                return 0.0
            }

            if ADUser.current.distanceUnit == .miles {
                return TimeInterval(1609.34 / averageSpeedMetersSecond)
            }

            return TimeInterval(1000 / averageSpeedMetersSecond)
        }

        guard paceMeters.isNormal && paceMeters > 0.0 else {
            return 0.0
        }

        if ADUser.current.distanceUnit == .miles {
            return TimeInterval(paceMeters / 1609.34)
        }

        return TimeInterval(paceMeters / 1000.0)
    }

    var distanceInUserSelectedUnit: Float {
        return distanceMeters?.metersToUserSelectedUnit ?? 0.0
    }

    var averageSpeedInUserSelectedUnit: Float {
        guard let movingTime = movingTime, movingTime > 0.0 else {
            return 0.0
        }

        return distanceInUserSelectedUnit / Float(movingTime / 3600)
    }

    var talliedReactions: [PostReactionType: Int] {
        var talliedReactions: [PostReactionType: Int] = [:]
        for reaction in reactions {
            if let count = talliedReactions[reaction.kind] {
                talliedReactions[reaction.kind] = count + 1
            } else {
                talliedReactions[reaction.kind] = 1
            }
        }

        return talliedReactions
    }

    var feedFormattedDate: String {
        if Calendar.current.isDateInToday(activityStartDateUTC) {
            return "Today · " + activityStartDateUTC.formatted(withFormat: "h:mm a")
        } else if Calendar.current.isDateInYesterday(activityStartDateUTC) {
            return "Yesterday · " + activityStartDateUTC.formatted(withFormat: "h:mm a")
        } else {
            return activityStartDateUTC.formatted(withFormat: "EEEE · h:mm a")
        }
    }

    var activity: Activity? {
        return ActivitiesData.shared.activity(with: localHealthKitID)
    }

    // MARK: - Images

    private var cache: HealthDataCache {
        HealthDataCache.shared
    }

    var routeImage: UIImage? {
        get async {
            if let cachedRouteImage = cache.image(.routeImage, post: self) {
                return cachedRouteImage
            }

            guard let coordinates = coordinates else {
                return nil
            }

            let clLocations = coordinates.compactMap { CLLocation(wrapper: $0) }
            let image: UIImage? = await withCheckedContinuation { continuation in
                RouteImageRenderer.renderRoute(coordinates: clLocations) { image in
                    continuation.resume(returning: image)
                }
            }

            if let image = image {
                cache.cache(.routeImage, image: image, post: self)
            }

            return image
        }
    }

    var miniRouteImage: UIImage? {
        get async {
            if let cachedMiniRouteImage = cache.image(.routeImageMini, post: self) {
                return cachedMiniRouteImage
            }

            guard let coordinates = coordinates else {
                return nil
            }

            let clLocations = coordinates.compactMap { CLLocation(wrapper: $0) }
            let image: UIImage? = await withCheckedContinuation { continuation in
                RouteImageRenderer.renderMiniRoute(coordinates: clLocations) { image in
                    continuation.resume(returning: image)
                }
            }

            if let image = image {
                cache.cache(.routeImageMini, image: image, post: self)
            }

            return image
        }
    }

    var mapRouteImage: UIImage? {
        get async {
            if let image = cache.image(.mapRouteImage, post: self) {
                return image
            }

            guard let coordinates = coordinates else {
                return nil
            }

            let clLocations = coordinates.compactMap { CLLocation(wrapper: $0) }
            let image = await MapKitMapRenderer.generateMapImage(from: clLocations)

            if let image = image {
                cache.cache(.mapRouteImage, image: image, post: self)
            }

            return image
        }
    }
}

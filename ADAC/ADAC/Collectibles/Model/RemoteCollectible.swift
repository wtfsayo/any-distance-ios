// Licensed under the Any Distance Source-Available License
//
//  RemoteCollectible.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/4/21.
//

import UIKit
import CloudKit

struct RemoteCollectible: Codable {
    var rawValue: String
    var adminOnly: Bool
    var canBeEarned: Bool
    var isVisibleBeforeBeingEarned: Bool
    var minVersion: Float
    var tieredRewardID: String?
    var itemType: ItemType
    var sectionName: String = "Special"
    var sectionSortOrder: Int = 35
    var coordinateRegions: [CoordinateRegion]
    var activityTypes: [ActivityType]
    var minDistanceMeters: Double
    var maxDistanceMeters: Double
    var minDuration: TimeInterval
    var startDate: Date?
    var endDate: Date?
    var dailyStartDate: Date?
    var dailyEndDate: Date?
    var description: String
    var blurb: String
    var unearnedBlurb: String?
    var subtitle: String?
    var hasCtaButton: Bool
    var ctaLabelTitle: String?
    var ctaUrl: URL?
    var medalImageHasBlackBackground: Bool
    var medalImageUrl: URL?
    var videoUrl: URL?
    var previewVideoUrl: URL?
    var carouselImageUrls: [URL]
    var usdzUrl: URL?
    var bloomIntensity: Float = 0.7
    var cameraDistance: Float = 50
    var shouldSpinInAR: Bool = true
    var shouldFloatInAR: Bool = true
    var superDistanceRequired: Bool
    var codableConfettiColors: [CodableColor]
    var codableCtaButtonBackgroundColor: CodableColor?
    var codableCtaButtonLabelColor: CodableColor?

    var ctaButtonBackgroundColor: UIColor? {
        return codableCtaButtonBackgroundColor?.uiColor ?? .adOrangeLighter
    }

    var ctaButtonLabelColor: UIColor? {
        return codableCtaButtonLabelColor?.uiColor ?? .black
    }

    var confettiColors: [UIColor] {
        return codableConfettiColors.map { $0.uiColor }
    }

    var canBeEarnedOrDebug: Bool {
        return (canBeEarned || Config.appConfiguration == .testFlight || Config.appConfiguration == .debug)
    }

    var hintBlurb: String {
        return unearnedBlurb ?? ""
    }

    // MARK: - CloudKit Serialization

    init(ckRecord record: CKRecord) {
        rawValue = record["rawValue"] as? String ?? ""
        adminOnly = record["adminOnly"] as? Bool ?? false
        canBeEarned = record["canBeEarned"] as? Bool ?? true
        isVisibleBeforeBeingEarned = record["isVisibleBeforeBeingEarned"] ?? false
        minVersion = record["minVersion"] as? Float ?? 0.0
        tieredRewardID = record["tieredRewardID"] as? String
        itemType = ItemType(rawValue: record["itemType"] as? String ?? "medal") ?? .medal
        sectionName = record["sectionName"] as? String ?? sectionName
        sectionSortOrder = record["sectionSortOrder"] as? Int ?? sectionSortOrder
        coordinateRegions = record.decodeArray(fromKey: "coordinateRegions",
                                               asType: CoordinateRegion.self)
        activityTypes = (record["activityTypes"] as? [String] ?? []).compactMap { ActivityType(name: $0) }
        minDistanceMeters = record["minDistanceMeters"] as? Double ?? 0
        maxDistanceMeters = record["maxDistanceMeters"] as? Double ?? .greatestFiniteMagnitude
        minDuration = record["minDuration"] as? TimeInterval ?? 0
        startDate = record["startDate"] as? Date
        endDate = record["endDate"] as? Date
        dailyStartDate = record["dailyStartDate"] as? Date
        dailyEndDate = record["dailyEndDate"] as? Date
        description = record["description"] as? String ?? ""
        blurb = record["blurb"] as? String ?? ""
        unearnedBlurb = record["unearnedBlurb"] as? String
        subtitle = record["subtitle"] as? String ?? ""
        hasCtaButton = record["hasCtaButton"] as? Bool ?? false
        ctaLabelTitle = record["ctaLabelTitle"] as? String ?? ""
        ctaUrl = URL(string: record["ctaUrl"] as? String)
        medalImageHasBlackBackground = record["medalImageHasBlackBackground"] as? Bool ?? false
        medalImageUrl = URL(string: record["medalImageUrl"] as? String)
        videoUrl = URL(string: record["videoUrl"] as? String)
        previewVideoUrl = URL(string: record["previewVideoUrl"] as? String)
        carouselImageUrls = (record["carouselImageUrls"] as? [String] ?? []).compactMap { URL(string: $0) }
        usdzUrl = URL(string: record["usdzUrl"] as? String)
        bloomIntensity = record["bloomIntensity"] ?? bloomIntensity
        cameraDistance = record["cameraDistance"] ?? cameraDistance
        shouldSpinInAR = record["shouldSpinInAR"] ?? true
        shouldFloatInAR = record["shouldFloatInAR"] ?? true
        superDistanceRequired = record["superDistanceRequired"] as? Bool ?? false
        codableConfettiColors = (record["codableConfettiColors"] as? [String] ?? []).map { CodableColor(string: $0) }
        codableCtaButtonBackgroundColor = CodableColor(string: record["codableCtaButtonBackgroundColor"] as? String ?? UIColor.adOrangeLighter.toHexString())
        codableCtaButtonLabelColor = CodableColor(string: record["codableCtaButtonLabelColor"] as? String ?? UIColor.black.toHexString())
    }
}

extension RemoteCollectible: Equatable {
    static func ==(lhs: RemoteCollectible, rhs: RemoteCollectible) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

// Licensed under the Any Distance Source-Available License
//
//  ActivityTableViewDataPoint.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/3/21.
//

import UIKit
import HealthKit

protocol ActivityTableViewDataClass {
    var sortDate: Date { get }
}

struct ActivityDataPoint: Hashable {
    let id: String
    let source: HealthKitWorkoutSource?
    let typeGlyph: UIImage?
    let bigLabelText: String
    let formattedDate: String
    let formattedDateShort: String
    let meetsGoal: Bool
    
    private static var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
    
    init(activity: Activity) {
        self.id = activity.id
        self.source = activity.workoutSource
        self.typeGlyph = activity.activityType.glyph
        let distance = activity.distanceInUserSelectedUnit.rounded(toPlaces: 2)
        if distance > 0.01 {
            self.bigLabelText = "\(distance)" + "\(ADUser.current.distanceUnit.abbreviation.uppercased())"
        } else {
            self.bigLabelText = activity.movingTime.timeFormatted()
        }
        self.formattedDate = activity.startDateLocal.formatted(withStyle: .long)
        if let hkWorkout = activity as? HKWorkout {
            self.formattedDateShort = Self.formatter.string(from: hkWorkout.startDateUTCToLocal)
        } else {
            self.formattedDateShort = Self.formatter.string(from: activity.startDateLocal)
        }
        self.meetsGoal = ActivitiesData.shared.goalMet(for: activity)
    }
}

class CollectibleDataPoint: Hashable {
    private(set) var id: Int = UUID().hashValue
    private(set) var date: Date = Date()
    private(set) var collectibles: [Collectible]

    init(collectible: Collectible) {
        self.collectibles = [collectible]
        self.date = Calendar.current.startOfDay(for: collectible.dateEarned)
    }

    func addCollectible(_ collectible: Collectible) {
        collectibles.append(collectible)
    }

    static func == (lhs: CollectibleDataPoint, rhs: CollectibleDataPoint) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(date)
        hasher.combine(collectibles)
    }
}

struct StepCountDataPoint: Hashable, Equatable {
    let id: String
    let formattedStepCount: String
    let formattedDate: String
    let date: Date
    let stepCount: DailyStepCount

    init(stepCount: DailyStepCount) {
        self.id = stepCount.id
        self.formattedStepCount = stepCount.formattedCount
        self.formattedDate = stepCount.startDate.formatted(withStyle: .long)
        self.date = stepCount.startDate
        self.stepCount = stepCount
    }

    static func == (lhs: StepCountDataPoint, rhs: StepCountDataPoint) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct FeedItemDataPoint: Hashable {
    let id: String
    let title: String
    let coverImageUrl: URL
    let link: URL

    init(feedItem: FeedItem) {
        self.id = UUID().uuidString
        self.title = feedItem.title
        self.link = feedItem.link
        self.coverImageUrl = feedItem.coverImageURL
    }
}

struct GenericDataPoint: Hashable {
    let id: String
    let type: GenericDataPointType

    init(dataClass: ActivityTableViewDataClass, type: GenericDataPointType = .superDistance) {
        self.id = "\(dataClass.sortDate.timeIntervalSince1970)"
        self.type = type
    }

    init(sortDate: Date, type: GenericDataPointType) {
        self.id = "\(sortDate.timeIntervalSince1970)"
        self.type = type
    }
    
    init(type: GenericDataPointType) {
        self.id = "\(Date().timeIntervalSince1970)"
        self.type = .superDistance
    }
}

enum GenericDataPointType {
    case superDistance
    case stravaNotice
    case dailySummary
}

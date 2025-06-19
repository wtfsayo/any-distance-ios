// Licensed under the Any Distance Source-Available License
//
//  Goal.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/20/21.
//

import Foundation
import Combine

final class Goal: ObservableObject, Codable, Identifiable {
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var activityType: ActivityType
    @Published var unit: DistanceUnit
    @Published var distanceMeters: Float /// target distance (meters)
    @Published var currentDistanceMeters: Float? /// includes only activities
    @Published var completionDistanceMeters: Float?
    @Published var isCompleted: Bool = false
    private lazy var subscribers: Set<AnyCancellable> = []

    var targetDistanceInSelectedUnit: Float {
        return max(UnitConverter.meters(distanceMeters, toUnit: unit).rounded(.down), 1.0)
    }

    var distanceInSelectedUnit: Float {
        if let completionDistanceMeters = completionDistanceMeters, completionDistanceMeters > 0.0 {
            return UnitConverter.meters(completionDistanceMeters, toUnit: unit).rounded(.down)
        }

        return UnitConverter.meters((currentDistanceMeters ?? 0), toUnit: unit).rounded(.down)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d yyyy"
        return formatter.string(from: endDate)
    }

    var formattedDaysLeft: String {
        let daysLeft = Int(endDate.timeIntervalSince(Date()) / 86400.0)
        return String(daysLeft) + " days left"
    }

    func matches(_ activity: Activity) -> Bool {
        let startDate = Calendar.current.startOfDay(for: startDate)
        let endDate = Calendar.current.startOfDay(for: endDate)

        return activityType.matchingGoalActivityTypes.contains(activity.activityType) &&
               activity.startDateLocal >= startDate &&
               activity.startDateLocal < endDate
    }
    
    func cumulativeGoalDistance(for activities: [Activity]) -> Float {
        let goalActivities = activities.filter { self.matches($0) }
        .sorted { $0.startDateLocal < $1.startDateLocal }

        let totalDistance = goalActivities.reduce(0) { $0 + $1.distance }
        return UnitConverter.meters(totalDistance, toUnit: unit)
    }

    func calculateCurrentDistanceMetersForAllActivities(saveToCloudKit: Bool = false) async {
        let activities = ActivitiesData.shared.activities.map { $0.activity }
        await calculateCurrentDistanceMetersIfNecessary(for: activities, force: true, saveToCloudKit: saveToCloudKit)
    }

    func calculateCurrentDistanceMetersIfNecessary(for activities: [Activity], 
                                                   force: Bool = false,
                                                   saveToCloudKit: Bool = false) async {
        guard currentDistanceMeters == nil || force else {
            return
        }
        
        let calculatedDistance = cumulativeGoalDistance(for: activities)
        currentDistanceMeters = UnitConverter.value(calculatedDistance, inUnitToMeters: unit)

        if saveToCloudKit {
            await UserManager.shared.updateCurrentUser()
        }
    }

    /// Returns whether the goal is newly completed.
    @discardableResult func markAsCompletedIfNecessary() -> Bool {
        guard !isCompleted || completionDistanceMeters == nil || completionDistanceMeters == 0 else {
            return false
        }

        if distanceInSelectedUnit >= targetDistanceInSelectedUnit || Date() >= endDate {
            isCompleted = true
            completionDistanceMeters = UnitConverter.value(distanceInSelectedUnit, inUnitToMeters: unit)
            return true
        }

        return false
    }

    static func new() -> Goal {
        return Goal(startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date(), wrappingComponents: false) ?? Date(),
                    activityType: .run,
                    distanceMeters: UnitConverter.value(100, inUnitToMeters: ADUser.current.distanceUnit),
                    unit: ADUser.current.distanceUnit)
    }

    init(startDate: Date, endDate: Date, activityType: ActivityType, distanceMeters: Float, unit: DistanceUnit) {
        self.startDate = startDate
        self.endDate = endDate
        self.activityType = activityType
        self.distanceMeters = distanceMeters
        self.unit = unit
        observeSelf()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: GoalCodingKeys.self)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.endDate = try container.decode(Date.self, forKey: .endDate)
        self.activityType = try container.decode(ActivityType.self, forKey: .activityType)
        self.unit = try container.decode(DistanceUnit.self, forKey: .unit)
        self.distanceMeters = try container.decode(Float.self, forKey: .distanceMeters)
        self.currentDistanceMeters = try? container.decode(Float.self, forKey: .currentDistanceMeters)
        self.completionDistanceMeters = try? container.decode(Float.self, forKey: .completionDistanceMeters)
        self.isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        observeSelf()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: GoalCodingKeys.self)
        try container.encode(self.startDate, forKey: .startDate)
        try container.encode(self.endDate, forKey: .endDate)
        try container.encode(self.activityType, forKey: .activityType)
        try container.encode(self.unit, forKey: .unit)
        try container.encode(self.distanceMeters, forKey: .distanceMeters)
        try container.encode(self.currentDistanceMeters, forKey: .currentDistanceMeters)
        try container.encode(self.completionDistanceMeters, forKey: .completionDistanceMeters)
        try container.encode(self.isCompleted, forKey: .isCompleted)
    }

    private func observeSelf() {
        objectWillChange
            .receive(on: DispatchQueue.main)
            .throttle(for: 1.0, scheduler: RunLoop.main, latest: true)
            .sink { _ in
                ADUser.current.saveToUserDefaults()
            }
            .store(in: &subscribers)
    }
}

fileprivate enum GoalCodingKeys: String, CodingKey {
    case startDate
    case endDate
    case activityType
    case unit
    case distanceMeters
    case currentDistanceMeters
    case completionDistanceMeters
    case isCompleted
}

extension Goal: Equatable, Hashable {
    static func == (lhs: Goal, rhs: Goal) -> Bool {
        return lhs === rhs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(startDate.timeIntervalSince1970)
        hasher.combine(endDate.timeIntervalSince1970)
        hasher.combine(activityType.rawValue)
        hasher.combine(unit.rawValue)
        hasher.combine(distanceMeters)
    }
}

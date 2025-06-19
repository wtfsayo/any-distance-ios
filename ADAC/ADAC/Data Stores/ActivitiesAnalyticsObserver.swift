// Licensed under the Any Distance Source-Available License
//
//  ActivitiesAnalyticsObserver.swift
//  ADAC
//
//  Created by Jarod Luebbert on 9/21/22.
//

import Foundation
import Combine

import OneSignal

class ActivitiesAnalyticsObserver {
    
    private let activities: AnyPublisher<[Activity], Never>
    private var disposables = Set<AnyCancellable>()
    
    init(with activitiesPublisher: AnyPublisher<[ActivityIdentifiable], Never>) {
        // for analytics ignore step counts and cached activities
        activities = activitiesPublisher
            .map { activities in
                return activities.compactMap { activityIdentifiable -> Activity? in
                    let activity = activityIdentifiable.activity
                    guard !(activity is DailyStepCount) &&
                            !(activity is CachedActivity) else {
                        return nil
                    }
                    
                    return activity
                }
            }
            .eraseToAnyPublisher()
    }

    func startObservingActivitiesForAnalytics() {
        activities.sink { activities in
            var activityTypeCount = [ActivityType: Int]()
            var activitiesSinceSignupCount = 0
            for activity in activities {
                if let signupDate = ADUser.current.signupDate,
                   activity.startDate >= signupDate {
                    activitiesSinceSignupCount += 1
                }
                
                if let count = activityTypeCount[activity.activityType] {
                    activityTypeCount[activity.activityType] = count + 1
                } else {
                    activityTypeCount[activity.activityType] = 1
                }
            }
            
            for (activityType, count) in activityTypeCount {
                OneSignal.sendTag("activity_count_\(activityType.rawValue.lowercased())",
                                  value: "\(count)")
            }
            
            if let lastActivity = activities.first {
                OneSignal.sendTag("last_activity_synced", value: "\(lastActivity.startDate.timeIntervalSince1970)")
            }
            
            if ADUser.current.hasRegistered {
                OneSignal.sendTag("activities_synced_since_signup", value: "\(activitiesSinceSignupCount)")
            }
        }
        .store(in: &disposables)
    }
    
    func stopObservingActivitiesForAnalytics() {
        disposables.removeAll()
    }
    
}

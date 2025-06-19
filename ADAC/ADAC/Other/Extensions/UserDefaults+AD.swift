// Licensed under the Any Distance Source-Available License
//
//  UserDefaults+UpdateAppGroup.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/29/21.
//

import Foundation
import WidgetKit
import Sentry
import OneSignal

extension NSUbiquitousKeyValueStore {
    var currentUser: ADUser {
        get {
            if let data = data(forKey: "currentUser") {
                let string = String(data: data, encoding: .utf8)
//                print(string)

                do {
                    let user = try JSONDecoder().decode(ADUser.self, from: data)
                    return user
                } catch {
                    SentrySDK.capture(error: error)
                }
            }

            let newUser = ADUser()
            let data = try? JSONEncoder().encode(newUser)
            set(data, forKey: "currentUser")
            return newUser
        }

        set {
            let data = try? JSONEncoder().encode(newValue)
            set(data, forKey: "currentUser")
            WatchPreferences.shared.sendPreferencesToWatch()
        }
    }

    var numberOfActivitiesShared: Int {
        get {
            if object(forKey: "numberOfActivitiesShared") == nil {
                self.numberOfActivitiesShared = 0
                return 0
            }

            return integer(forKey: "numberOfActivitiesShared")
        }

        set {
            set(newValue, forKey: "numberOfActivitiesShared")
        }
    }

    var garminBackfillRequestsMade: Int {
        get {
            if object(forKey: "garminBackfillRequestsMade") == nil {
                self.garminBackfillRequestsMade = 0
                return 0
            }

            return integer(forKey: "garminBackfillRequestsMade")

        }
        set {
            set(newValue, forKey: "garminBackfillRequestsMade")
        }
    }

    var numberOfAppLaunches: Int {
        get {
            return integer(forKey: "numberOfAppLaunches")
        }
        set {
            set(newValue, forKey: "numberOfAppLaunches")
        }
    }

    var shouldShowSubscriptionScreenAfterOnboarding: Bool {
        get {
            return bool(forKey: "shouldShowSubscriptionScreenAfterOnboarding")
        }

        set {
            set(newValue, forKey: "shouldShowSubscriptionScreenAfterOnboarding")
        }
    }

    var hasAskedForNotificationsPermission: Bool {
        get {
            return bool(forKey: "hasAskedForNotificationsPermission")
        }

        set {
            set(newValue, forKey: "hasAskedForNotificationsPermission")
        }
    }

    var hasShownInitialPurchaseScreen: Bool {
        get {
            return bool(forKey: "hasShownInitialPurchaseScreen")
        }

        set {
            set(newValue, forKey: "hasShownInitialPurchaseScreen")
        }
    }

    var hasSetNotificationsOn: Bool {
        return object(forKey: "notificationsOn") != nil
    }
    
    func disableAllNotifications() {
        activityShareReminderNotificationsOn = false
        featureUpdateNotificationsOn = false
        collectiblesNotificationsOn = false
    }
    
    func enableAllNotifications() {
        activityShareReminderNotificationsOn = true
        featureUpdateNotificationsOn = true
        collectiblesNotificationsOn = true
    }

    var activityShareReminderNotificationsOn: Bool {
        get {
            return bool(forKey: "notificationsOn")
        }

        set {
            set(newValue, forKey: "notificationsOn")
        }
    }
    
    var featureUpdateNotificationsOn: Bool {
        get {
            return bool(forKey: "featureUpdateNotificationsOn")
        }

        set {
            set(newValue, forKey: "featureUpdateNotificationsOn")
            
            OneSignal.sendTag("feature_update_notifications", value: newValue ? "1" : "0")
        }
    }
    
    var collectiblesNotificationsOn: Bool {
        get {
            return bool(forKey: "collectiblesNotificationsOn")
        }

        set {
            set(newValue, forKey: "collectiblesNotificationsOn")
            
            OneSignal.sendTag("collectibles_notifications", value: newValue ? "1" : "0")
        }
    }

    var feedItems: [FeedItem] {
        get {
            guard let itemData = data(forKey: "feedItems") else {
                return []
            }

            do {
                let items = try JSONDecoder().decode([FeedItem].self, from: itemData)
                return items
            } catch {
                print("Error decoding feedItems: \(error.localizedDescription)")
            }

            return []
        }

        set {
            do {
                let itemData = try JSONEncoder().encode(newValue)
                set(itemData, forKey: "feedItems")
            } catch {
                print("Error encoding feedItems: \(error.localizedDescription)")
            }
        }
    }

    var hasSeenFilterTapAgainView: Bool {
        get {
            return bool(forKey: "hasSeenFilterTapAgainView")
        }

        set {
            set(newValue, forKey: "hasSeenFilterTapAgainView")
        }
    }
    
    var hasSeenDoubleTapToResetGraph: Bool {
        get {
            if object(forKey: "hasSeenDoubleTapToResetGraph") == nil {
                return numberOfAppLaunches > 1
            }
            
            return bool(forKey: "hasSeenDoubleTapToResetGraph")
        }

        set {
            set(newValue, forKey: "hasSeenDoubleTapToResetGraph")
        }
    }

    var lastActivitiesRefreshDate: Date? {
        get {
            if object(forKey: "lastActivitiesRefreshDate") == nil {
                return nil
            }

            return Date(timeIntervalSince1970: double(forKey: "lastActivitiesRefreshDate"))
        }

        set {
            set(newValue?.timeIntervalSince1970, forKey: "lastActivitiesRefreshDate")
        }
    }

    var lastStepCountEventSendDate: Date? {
        get {
            if object(forKey: "lastStepCountEventSendDate") == nil {
                return nil
            }

            return Date(timeIntervalSince1970: double(forKey: "lastStepCountEventSendDate"))
        }

        set {
            set(newValue?.timeIntervalSince1970, forKey: "lastStepCountEventSendDate")
        }
    }

    var shouldShowStepCount: Bool {
        get {
            if object(forKey: "shouldShowStepCount") == nil {
                return true
            }

            return bool(forKey: "shouldShowStepCount")
        }

        set {
            set(newValue, forKey: "shouldShowStepCount")
            WatchPreferences.shared.sendPreferencesToWatch()
        }
    }

    var shouldShowAnyDistanceBranding: Bool {
        get {
            if object(forKey: "shouldShowAnyDistanceBranding") == nil {
                return true
            }

            return bool(forKey: "shouldShowAnyDistanceBranding")
        }

        set {
            set(newValue, forKey: "shouldShowAnyDistanceBranding")
        }
    }

    var shouldShowCollaborationCollectibles: Bool {
        get {
            if object(forKey: "shouldShowCollaborationCollectibles") == nil {
                return true
            }

            return bool(forKey: "shouldShowCollaborationCollectibles")
        }

        set {
            set(newValue, forKey: "shouldShowCollaborationCollectibles")
        }
    }

    var hasSeenRecordingPrivacyStatement: Bool {
        get {
            return bool(forKey: "hasSeenRecordingPrivacyStatement")
        }

        set {
            set(newValue, forKey: "hasSeenRecordingPrivacyStatement")
        }
    }

    var overrideShowNoFriendsEmptyState: Bool {
        get {
            return bool(forKey: "overrideShowNoFriendsEmptyState")
        }

        set {
            set(newValue, forKey: "overrideShowNoFriendsEmptyState")
        }
    }
}

extension NSUbiquitousKeyValueStore {
    func integer(forKey key: String) -> Int {
        return object(forKey: key) as? Int ?? 0
    }

    func float(forKey key: String) -> Float {
        return object(forKey: key) as? Float ?? 0
    }
}

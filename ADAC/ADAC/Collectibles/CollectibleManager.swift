// Licensed under the Any Distance Source-Available License
//
//  CollectibleManager.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/1/21.
//

import Foundation
import OneSignal

final class CollectibleManager {
    @discardableResult
    static func grantBetaAndDay1CollectibleIfNecessary() -> Bool {
        var granted: Bool = false
        let signupDate = ADUser.current.signupDate ?? Date()

        if (Config.appConfiguration == .testFlight || Config.appConfiguration == .debug),
           !ADUser.current.collectibles.contains(where: { $0.type == .special(.beta) }) {
            let collectible = Collectible(type: .special(.beta), dateEarned: signupDate)
            ADUser.current.collectibles.append(collectible)
            granted = true
        }

        if let day1Collectible = ADUser.current.collectibles.first(where: { $0.type == .special(.day1) }) {
            // fixes bug where day1 earned date was not set for some users
            if day1Collectible.dateEarned == Date(timeIntervalSince1970: 0) {
                day1Collectible.dateEarned = signupDate
            }
        } else {
            let collectible = Collectible(type: .special(.day1), dateEarned: signupDate)
            ADUser.current.collectibles.append(collectible)
            granted = true
        }

        let oneWeekAfterLaunch = Date(timeIntervalSince1970: 1614124800)
        if (ADUser.current.signupDate ?? Date()) <= oneWeekAfterLaunch &&
            !ADUser.current.collectibles.contains(where: { $0.type == .special(.launch) }) {
            let collectible = Collectible(type: .special(.launch), dateEarned: signupDate)
            ADUser.current.collectibles.append(collectible)
            granted = true
        }

        return granted
    }

    static func grantPreseedCollectibleIfNecessary() -> Bool {
        var granted: Bool = false

        let userIds: [String] = []

        if userIds.contains(ADUser.current.id) {
            let collectible = Collectible(type: .special(.preseed), dateEarned: Date())
            if !ADUser.current.collectibles.contains(where: { $0.type == .special(.preseed) }) {
                ADUser.current.collectibles.append(collectible)
                granted = true
            }
        }

        return granted
    }

    static func grantSuperDistanceCollectible() {
        if !ADUser.current.collectibles.contains(where: { $0.type == .special(.superdistance) }) {
            let collectible = Collectible(type: .special(.superdistance), dateEarned: Date())
            ADUser.current.collectibles.append(collectible)
        }
    }

    /// Grants the user collectibles, filtering out one-time only collectibles that the user has
    /// already earned.
    static func grantCollectibles(_ collectibles: [Collectible]) {
        guard !collectibles.isEmpty else {
            return
        }

        ADUser.current.collectibles = CollectibleCalculator.userCollectiblesAfterGranting(collectibles).all
    }

    static func grantActivityTrackingEarlyAccessCollectible() {
        let rawValue = "special_activity_tracking_early_access"
        if let remote = CollectibleLoader.shared.remoteCollectible(withRawValue: rawValue),
           !ADUser.current.collectibles.contains(where: { $0.type.rawValue.contains(rawValue) }) {
            let collectible = Collectible(type: .remote(remote),
                                          dateEarned: Date())
            ADUser.current.collectibles.append(collectible)
            ReloadPublishers.collectibleGranted.send()
        }
    }
}

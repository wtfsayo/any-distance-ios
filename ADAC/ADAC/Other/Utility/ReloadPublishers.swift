// Licensed under the Any Distance Source-Available License
//
//  ReloadPublishers.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/20/22.
//

import Foundation
import Combine

class ReloadPublishers {
    static let activitiesTableViewReloaded = PassthroughSubject<Void, Never>()
    static let collectibleGranted = PassthroughSubject<Void, Never>()
    static let adActivityRecorded = PassthroughSubject<Void, Never>()
    static let rewardCodeRedeemed = PassthroughSubject<Void, Never>()
    static let activityDeleted = PassthroughSubject<Void, Never>()
    static let activityPosted = PassthroughSubject<Void, Never>()
    static let friendInvited = PassthroughSubject<Void, Never>()
    static let healthKitAuthorizationChanged = PassthroughSubject<Void, Never>()
    static let setNewGoal = PassthroughSubject<Void, Never>()
}

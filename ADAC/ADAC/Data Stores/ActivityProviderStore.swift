// Licensed under the Any Distance Source-Available License
//
//  ActivitiesStore.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/22/22.
//

import Foundation
import Combine

protocol ActivitiesProviderStore {
    var activitySynced: AnyPublisher<Activity, Never> { get }
    
    func isAuthorizedForAllTypes() async throws -> Bool
    func load() async throws -> [Activity]
    func startObservingNewActivities() async // to send push notifications
}

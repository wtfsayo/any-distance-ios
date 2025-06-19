// Licensed under the Any Distance Source-Available License
//
//  SettingsViewModel.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/3/22.
//

import Foundation
import SwiftUI
import Combine

enum ExternalServiceConnectionState {
    case connected, disconnected, revoked, unknown
}

final class SettingsViewModel: SwiftUIViewModel<SettingsViewController> {
    @Published var activityShareReminderNotificationsOn: Bool = NSUbiquitousKeyValueStore.default.activityShareReminderNotificationsOn
    @Published var featureNotificationsOn: Bool = NSUbiquitousKeyValueStore.default.featureUpdateNotificationsOn
    @Published var overrideHasPosted: Bool = NSUbiquitousKeyValueStore.default.overrideHasPosted
    @Published var overrideShowNoFriendsEmptyState: Bool = NSUbiquitousKeyValueStore.default.overrideShowNoFriendsEmptyState
    @Published var collectiblesNotificationsOn: Bool = NSUbiquitousKeyValueStore.default.collectiblesNotificationsOn
    @Published var wahooConnectionState: ExternalServiceConnectionState = .disconnected
    @Published var garminConnectionState: ExternalServiceConnectionState = .disconnected

    private var subscribers: Set<AnyCancellable> = []

    override init(controller: SettingsViewController) {
        super.init(controller: controller)

        ReloadPublishers.rewardCodeRedeemed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }.store(in: &subscribers)
    }

    func closeAction() { controller?.closeAction() }
    func seeFeaturesAction() { controller?.seeFeaturesAction() }
    func billingSupportAction() { controller?.billingSupportAction() }
    func restoreAction() { controller?.restoreAction() }
    func cancelPlanAction() { controller?.cancelPlanAction() }
    func renewsAction() { controller?.renewsAction() }
    func joinBetaAction() { controller?.joinBetaAction() }
    func setDisplayAction(_ newValue: DistanceUnit) { controller?.setDisplayAction(newValue) }
    func setStepCountOnAction(_ newValue: Bool) { controller?.setStepCountOnAction(newValue) }
    func setShowBrandingOnAction(_ newValue: Bool) { controller?.setShowBrandingOnAction(newValue) }
    func setShowCollaborationsOnAction(_ newValue: Bool) { controller?.setShowCollaborationsOnAction(newValue) }
    func setAppIcon(_ idx: Int) { controller?.setAppIcon(idx) }
    func dailyRemindersAction() { controller?.dailyRemindersAction() }
    func setActivityShareNotificationsOnAction(_ newValue: Bool) { controller?.setActivityShareNotificationsOnAction(newValue) }
    func setFeatureNotificationsOnAction(_ newValue: Bool) { controller?.setFeatureNotificationsOnAction(newValue) }
    func setCollectiblesNotificationsOnAction(_ newValue: Bool) { controller?.setCollectibleNotificationsOnAction(newValue) }
    
    // sync connect
    func appleHealthAction() { controller?.appleHealthAction() }
    func learnMoreSyncingAction() { controller?.learnMoreSyncingAction() }
    
    // external services
    func wahooAction() { controller?.wahooAction() }
    func garminAction() { controller?.garminAction() }
    
    func workWithUsAction() { controller?.workWithUsAction() }
    func requestNewFeaturesAction() { controller?.requestNewFeaturesAction() }
    func storeAction() { controller?.storeAction() }
    func followAction() { controller?.followAction() }
    func contactAction() { controller?.contactAction() }
    func sendFeedbackAction() { controller?.sendFeedbackAction() }
    func deleteAccountAction() { controller?.deleteAccountAction() }
    func privacyCommitmentAction() { controller?.privacyCommitmentAction() }
    func privacyPolicyAction() { controller?.privacyPolicyAction() }
    func termsAction() { controller?.termsAction() }

    // admin
    func showOnboardingAction() { controller?.showOnboardingAction() }

    // danger zone
    func recalculateCollectiblesAction() { controller?.recalculateCollectiblesAction() }
}

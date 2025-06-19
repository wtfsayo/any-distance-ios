// Licensed under the Any Distance Source-Available License
//
//  FriendFinderViewModel.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/21/23.
//

import Foundation
import SwiftUI
import ContactsUI
import Combine
import Sentry
import MessageUI

/// View model for FriendManagerView
@MainActor
class FriendFinderViewModel: NSObject, ObservableObject {
    weak var onboardingModel: OnboardingViewModel?
    private var subscribers: Set<AnyCancellable> = []

    private var invitingFriend: FriendFinderUser?

    var activeClubsInviteLink: URL {
        return URL(string: "")!
    }

    override init() {
        super.init()

        ADUser.current.$friendships
            .receive(on: DispatchQueue.main)
            .throttle(for: 1.0, scheduler: DispatchQueue.main, latest: true)
            .sink { _ in
                Task(priority: .medium) {
                    FriendFinderAPI.shared.reloadCached()
                }
            }
            .store(in: &subscribers)

        ADUser.current.$friendIDs
            .receive(on: DispatchQueue.main)
            .throttle(for: 1.0, scheduler: DispatchQueue.main, latest: true)
            .sink { _ in
                Task(priority: .medium) {
                    FriendFinderAPI.shared.reloadCached()
                }
            }
            .store(in: &subscribers)
    }

    func requestPermissionsAndLoad() {
        Task(priority: .userInitiated) {
            do {
                try await FriendFinderAPI.shared.requestContactsPermission()
                try await FriendFinderAPI.shared.load(with: onboardingModel)
            } catch {
                SentrySDK.capture(error: error)
                DispatchQueue.main.async {
                    if error.localizedDescription == "Access Denied" {
                        let alert = UIAlertController(title: "Contacts Permission Denied",
                                                      message: "Open Settings to grant contacts permission to Any Distance.",
                                                      preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }))

                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                        UIApplication.shared.topViewController?.present(alert, animated: true)
                    } else {
                        if let onboardingModel = self.onboardingModel {
                            onboardingModel.state = .searchingError
                        } else {
                            UIApplication.shared.topViewController?.showFailureToast(with: error)
                        }
                    }
                }
            }
        }
    }

    func loadForFindingFriendsManually() {
        Task(priority: .userInitiated) {
            do {
                try await FriendFinderAPI.shared.load(with: onboardingModel)
            } catch {
                SentrySDK.capture(error: error)
                DispatchQueue.main.async {
                    if let onboardingModel = self.onboardingModel {
                        onboardingModel.state = .searchingError
                    } else {
                        UIApplication.shared.topViewController?.showFailureToast(with: error)
                    }
                }
            }
        }
    }

    func sendInvite(toFriend friend: FriendFinderUser) {
        guard friend.friendState == .notInvited,
              !friend.phoneNumber.isEmpty else {
            return
        }

        invitingFriend = friend
        let composeController = MFMessageComposeViewController()
        composeController.messageComposeDelegate = self
        composeController.body = "\(activeClubsInviteLink.absoluteString) 👋 Hey! Join me on Any Distance."
        composeController.recipients = [friend.phoneNumber]
        UIApplication.shared.topViewController?.present(composeController,
                                                        animated: true,
                                                        completion: nil)
    }

    func shareActiveClubsInviteLink() {
        let activityVC = UIActivityViewController(activityItems: [activeClubsInviteLink],
                                                  applicationActivities: nil)
        UIApplication.shared.topViewController?.present(activityVC, animated: true, completion: nil)
    }

    func sendFriendRequest(toFriend friend: FriendFinderUser) {
        guard friend.friendState == .notAdded,
              let userID = friend.adUser?.id else {
            return
        }

        Task(priority: .userInitiated) {
            do {
                try await UserManager.shared.sendFriendRequest(to: userID)
                DispatchQueue.main.async {
                    friend.friendState = .added
                }
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }
}

extension FriendFinderViewModel: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                      didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
        if result == .sent {
            invitingFriend?.markAsInvited()
            invitingFriend = nil
            Analytics.logEvent("Invite sent", "Friend Manager", .otherEvent)
        }
    }
}

enum FriendFinderViewState: Int {
    case allowPermissions
    case searching
    case error
    case viewingContacts
}

extension FriendFinderUser {
    func cellSubtitleText() -> String {
        if let user = adUser, (isInContacts || wasSearched) {
            return "@\(user.username ?? "")"
        } else {
            return friendState.contactCountText(forCount: contactCount)
        }
    }
}

/// Convenience formatted text accessors for FriendState
extension FriendState {
    func contactCountText(forCount count: Int) -> String {
        switch self {
        case .notAdded, .added:
            return "\(count) mutual friend\(count > 1 ? "s" : "")"
        case .notInvited, .invited:
            return "\(count) friend\(count > 1 ? "s" : "") on Any Distance"
        }
    }

    var buttonText: String {
        switch self {
        case .notAdded:
            return "Add"
        case .added:
            return "Requested"
        case .notInvited:
            return "Invite"
        case .invited:
            return "Invited"
        }
    }

    var buttonSymbolName: String? {
        switch self {
        case .notAdded:
            return "plus"
        case .added:
            return "checkmark"
        case .notInvited, .invited:
            return nil
        }
    }

    var buttonBackgroundColor: Color {
        switch self {
        case .notAdded:
            return .white
        case .added:
            return .adDarkGreen
        case .notInvited:
            return .adOrangeLighter
        case .invited:
            return .clear
        }
    }

    var buttonTextColor: Color {
        switch self {
        case .notAdded:
            return .black
        case .added:
            return .white
        case .notInvited:
            return .black
        case .invited:
            return .adDarkGreen
        }
    }
}

// Licensed under the Any Distance Source-Available License
//
//  ProfileViewModel.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/23/23.
//

import SwiftUI
import Combine
import MessageUI

/// Model for ProfileView
class ProfileViewModel: NSObject, ObservableObject {
    weak var controller: ProfileViewController?
    var user: ADUser
    private var subscribers: Set<AnyCancellable> = []

    @Published var posts: [Post] = []
    @Published var postCellModels: [PostCellModel] = []
    @Published var namePendingEdit: String = ""
    @Published var bioPendingEdit: String = ""
    @Published var locationPendingEdit: String = ""
    @Published var isEditing: Bool = false

    private var oldProfilePhotoURL: URL?
    private var oldCoverPhotoURL: URL?

    var screenName: String {
        if user.isSelf {
            return "Self Profile"
        } else {
            return "Profile"
        }
    }

    init(controller: ProfileViewController) {
        self.controller = controller
        self.user = ADUser.current
        super.init()
        self.setup()
    }

    init(user: ADUser) {
        self.user = user
        super.init()
        self.setup()
    }

    private func setup() {
        self.resetPendingEdits()
        self.posts = PostCache.shared.posts(forUserID: user.id)
        self.postCellModels = self.posts.map { PostCellModel(post: $0, screenName: screenName) }
        if ADUser.current.hasRegistered {
            self.loadPosts()
        }

        PostCache.shared.postCachedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else {
                    return
                }

                self.posts = PostCache.shared.posts(forUserID: self.user.id)
                self.postCellModels = self.posts.map { PostCellModel(post: $0, screenName: self.screenName) }
            }
            .store(in: &subscribers)

        user.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &subscribers)
    }

    func authorizeHealth() {
        HealthKitActivitiesStore.shared.requestAuthorization(with: screenName)
    }

    func resetPendingEdits() {
        self.namePendingEdit = user.name
        self.bioPendingEdit = user.bio
        self.locationPendingEdit = user.location
    }

    func stageCurrentUserMedia() {
        oldProfilePhotoURL = user.profilePhotoUrl
        oldCoverPhotoURL = user.coverPhotoUrl
    }

    func discardMediaEdits() {
        if oldProfilePhotoURL != nil {
            self.user.profilePhotoUrl = oldProfilePhotoURL
            oldProfilePhotoURL = nil
        }

        if oldCoverPhotoURL != nil {
            self.user.coverPhotoUrl = oldCoverPhotoURL
            oldCoverPhotoURL = nil
        }
    }

    func loadPosts() {
        let startDate = Date(timeIntervalSince1970: 0)
        Task(priority: .background) {
            do {
                let newPosts = try await PostManager.shared.getUserPosts(for: user.id,
                                                                         startDate: startDate,
                                                                         perPage: 50)
                DispatchQueue.main.async {
                    self.posts = newPosts

                    var newPostCellModels = self.postCellModels
                    for post in newPosts {
                        if !newPostCellModels.contains(where: { $0.post.id == post.id }) {
                            newPostCellModels.append(PostCellModel(post: post, screenName: self.screenName))
                        }
                    }
                    if newPostCellModels.count != self.postCellModels.count {
                        newPostCellModels.sort(by: { $0.post.activityStartDateUTC > $1.post.activityStartDateUTC })
                        self.postCellModels = newPostCellModels
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    func saveUser() {
        let nameBeforeEdit: String = user.name
        let bioBeforeEdit: String = user.bio
        let locationBeforeEdit: String = user.location

        user.name = namePendingEdit
        user.bio = bioPendingEdit
        user.location = locationPendingEdit

        Task {
            do {
                try await UserManager.shared.updateUser(ADUser.current)
                DispatchQueue.main.async {
                    self.showSuccessToast()
                }

                oldProfilePhotoURL = nil
            } catch {
                user.name = nameBeforeEdit
                user.bio = bioBeforeEdit
                user.location = locationBeforeEdit
                resetPendingEdits()

                DispatchQueue.main.async {
                    self.showFailureToast(with: error)
                }
            }
        }
    }

    func unfriendUser() {
        Task(priority: .userInitiated) {
            do {
                try await UserManager.shared.unfriendUser(with: user.id)
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.dismiss(animated: true) {
                        UIApplication.shared.topViewController?.showSuccessToast(withTitle: "Unfriended @\(self.user.username ?? "")")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func blockUser() {
        Task(priority: .userInitiated) {
            do {
                try await UserManager.shared.blockUser(with: user.id)
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.dismiss(animated: true) {
                        UIApplication.shared.topViewController?.showSuccessToast(withTitle: "Blocked @\(self.user.username ?? "")", bottomInset: 20.0)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func unblockUser() {
        Task(priority: .userInitiated) {
            do {
                try await UserManager.shared.unblockUser(with: user.id)
                DispatchQueue.main.async {
                    self.user.objectWillChange.send()
                    UIApplication.shared.topViewController?.showSuccessToast(withTitle: "Unblocked @\(self.user.username ?? "")", bottomInset: 20.0)
                }
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func reportUser() {
        let message = "I'd like to report this user: \(user.name) @\(user.username ?? "") \(user.id)"
        UIApplication.shared.topViewController?.sendEmail(to: "support@anydistance.club",
                                                          subject: "Reporting a user",
                                                          message: message)
    }

    func approveFriendRequest() {
        guard let friendship = ADUser.current.friendships.first(where: {
            $0.isPending &&
            $0.requestingUserID == user.id
        }) else {
            return
        }

        Task(priority: .userInitiated) {
            do {
                try await UserManager.shared.approveFriendRequest(friendship)
                DispatchQueue.main.async {
                    self.user.objectWillChange.send()
                    UIApplication.shared.topViewController?.showSuccessToast(withTitle: "Request approved!", bottomInset: 20.0)
                }

                self.loadPosts()
                Task(priority: .userInitiated) {
                    try await UserManager.shared.getUsers(byCanonicalIDs: [user.id])
                }
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func denyFriendRequest() {
        guard let friendship = ADUser.current.friendships.first(where: {
            $0.isPending &&
            $0.requestingUserID == user.id
        }) else {
            return
        }

        Task(priority: .userInitiated) {
            do {
                try await UserManager.shared.deleteFriendRequest(with: friendship.id)
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.dismiss(animated: true) {
                        UIApplication.shared.topViewController?.showSuccessToast(withTitle: "Request denied!", bottomInset: 20.0)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func cancelFriendRequest() {
        guard let friendship = ADUser.current.friendships.first(where: {
            $0.isPending &&
            $0.requestingUserID == ADUser.current.id &&
            $0.targetUserID == user.id
        }) else {
            return
        }

        Task(priority: .userInitiated) {
            do {
                try await UserManager.shared.deleteFriendRequest(with: friendship.id)
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showSuccessToast(withTitle: "Request canceled!", bottomInset: 20.0)
                    self.user.objectWillChange.send()
                }
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func sendFriendRequest() {
        Task(priority: .userInitiated) {
            do {
                try await UserManager.shared.sendFriendRequest(to: user.id)
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showSuccessToast(withTitle: "Request sent!", bottomInset: 20.0)
                    self.user.objectWillChange.send()
                }
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func setProfilePicture(_ image: UIImage) {
        if let currentProfilePhotoURL = ADUser.current.profilePhotoUrl {
            Task(priority: .userInitiated) {
                try? await S3.deleteMedia(withURL: currentProfilePhotoURL)
            }
        }

        Task(priority: .userInitiated) {
            do {
                let objectURL = try await S3.uploadImage(image)
                guard isEditing else {
                    try await S3.deleteMedia(withURL: objectURL)
                    return
                }

                await MainActor.run {
                    ADUser.current.profilePhotoUrl = objectURL
                    UIApplication.shared.topViewController?.showSuccessToast(withTitle: "Profile picture set!")
                }
                await UserManager.shared.updateCurrentUser()
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func setCoverPhoto(_ image: UIImage) {
        if let currentCoverPhotoURL = ADUser.current.coverPhotoUrl {
            Task(priority: .userInitiated) {
                try? await S3.deleteMedia(withURL: currentCoverPhotoURL)
            }
        }

        Task(priority: .userInitiated) {
            do {
                let objectURL = try await S3.uploadImage(image)
                await MainActor.run {
                    ADUser.current.coverPhotoUrl = objectURL
                    UIApplication.shared.topViewController?.showSuccessToast(withTitle: "Cover photo set!")
                }
                await UserManager.shared.updateCurrentUser()
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    private func showSuccessToast() {
        UIApplication.shared.topViewController?.showSuccessToast(withTitle: "Saved!")
    }

    private func showFailureToast(with error: Error) {
        UIApplication.shared.topViewController?.showFailureToast(with: error)
    }
}

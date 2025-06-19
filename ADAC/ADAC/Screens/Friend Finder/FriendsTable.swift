// Licensed under the Any Distance Source-Available License
//
//  FriendsTable.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/13/23.
//

import SwiftUI
import Combine

/// Cell view for a friend, with an Unfriend button
fileprivate struct FriendTableViewCell: View {
    @ObservedObject var model: FriendsTableModel
    var friend: ADUser
    var idx: Int
    var arrayCount: Int

    let screenName = "Friend Manager"

    private func cellType(for idx: Int) -> TableViewCellType {
        if arrayCount == 1 {
            return .floating
        }

        switch idx {
        case 0:
            return .top
        case arrayCount - 1:
            return .bottom
        default:
            return .middle
        }
    }

    var unfriendButton: some View {
        Button {
            model.unfriendUser(with: friend.id)
            Analytics.logEvent("Unfriend tapped", screenName, .buttonTap)
        } label: {
            Text("Unfriend")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.black)
                .padding([.top, .bottom], 9)
                .padding([.leading, .trailing], 12)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .foregroundColor(Color.white)
                }
        }
        .buttonStyle(PlainButtonStyle())
    }

    var body: some View {
        ZStack {
            UserTableViewCell(profilePictureURL: friend.profilePhotoUrl,
                              nameText: friend.name,
                              subtitleText: "@\(friend.username ?? "")",
                              type: cellType(for: idx)) {
                ZStack {
                    unfriendButton
                }
            }
        }
        .onTapGesture {
            let vc = UIHostingController(rootView:
                ProfileView(model: ProfileViewModel(user: friend),
                                                    presentedInSheet: true)
            )
            vc.view.backgroundColor = .clear
            UIApplication.shared.topViewController?.present(vc, animated: true)
            Analytics.logEvent("Friends - view profile from cell", screenName, .buttonTap)
        }
    }
}

/// Section within FriendManagerView that shows a table of the current user's friends
struct FriendsTable: View {
    @StateObject var model: FriendsTableModel = FriendsTableModel()

    var hasData: Bool {
        return !model.user.friendIDs.isEmpty
    }

    var body: some View {
        let sideInsets = EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15)

        ZStack {
            List {
                SectionHeaderText(text: "\(ADUser.current.friendIDs.count)/100 Active Club members")
                    .listRowBackground(EmptyView())
                    .listRowSeparator(.hidden)
                    .listRowInsets(sideInsets)
                ForEach(model.friends.enumerated().map { $0 }, id: \.element) { (idx, friend) in
                    FriendTableViewCell(model: model,
                                        friend: friend,
                                        idx: idx,
                                        arrayCount: model.user.friendIDs.count)
                    .listRowBackground(EmptyView())
                    .listRowSeparator(.hidden)
                    .listRowInsets(sideInsets)
                    .drawingGroup()
                }

                Spacer()
                    .frame(height: 100)
                    .listRowBackground(EmptyView())
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .background(Color.black)
            .opacity(hasData ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: hasData)

            AndiEmptyState(text: "No active club members! Add friends in the Suggested tab.")
                .opacity(hasData ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: hasData)
        }
    }
}

/// Model for FriendsTable
class FriendsTableModel: NSObject, ObservableObject {
    @Published var user = ADUser.current
    @Published var friends: [ADUser] = []

    private var subscribers: Set<AnyCancellable> = []

    override init() {
        super.init()
        user.$friendIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadFriends()
            }
            .store(in: &subscribers)

        loadFriends()
    }

    func loadFriends() {
        var cachedLoadedFriends: [ADUser] = []
        var friendIDsToQuery: [ADUser.ID] = []

        for friendUserID in user.friendIDs {
            if let cachedUser = UserCache.shared.user(forID: friendUserID) {
                cachedLoadedFriends.append(cachedUser)
            } else {
                friendIDsToQuery.append(friendUserID)
            }
        }

        self.friends = cachedLoadedFriends.sortedByUsername

        let friendIDs = friendIDsToQuery
        Task(priority: .high) {
            guard let loadedFriends = try? await UserManager.shared.getUsers(byCanonicalIDs: friendIDs) else {
                return
            }

            await MainActor.run {
                var loadedFriendsToAppend = loadedFriends.filter { friend in
                    return !self.friends.contains(where: { $0.id == friend.id })
                }
                self.friends = (self.friends + loadedFriendsToAppend).sortedByUsername
            }
        }
    }

    func unfriendUser(with id: ADUser.ID) {
        Task(priority: .userInitiated) {
            do {
                try await UserManager.shared.unfriendUser(with: id)
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showSuccessToast(withTitle: "User unfriended!")
                }
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }
}

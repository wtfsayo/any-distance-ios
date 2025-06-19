// Licensed under the Any Distance Source-Available License
//
//  BlockedTable.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/18/23.
//

import SwiftUI
import Combine

/// Cell for a blocked user, with an Unblock button
fileprivate struct BlockedTableViewCell: View {
    @ObservedObject var model: BlockedTableModel
    var user: ADUser
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

    var unblockButton: some View {
        Button {
            model.unblockUser(with: user.id)
            Analytics.logEvent("Unblock tapped", screenName, .buttonTap)
        } label: {
            Text("Unblock")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.white)
                .padding([.top, .bottom], 9)
                .padding([.leading, .trailing], 12)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .foregroundColor(Color.adRed)
                }
        }
        .buttonStyle(PlainButtonStyle())
    }

    var body: some View {
        ZStack {
            UserTableViewCell(profilePictureURL: user.profilePhotoUrl,
                              nameText: user.name,
                              subtitleText: "@\(user.username ?? "")",
                              type: cellType(for: idx)) {
                ZStack {
                    unblockButton
                }
            }
        }
        .onTapGesture {
            let vc = UIHostingController(rootView:
                                            ProfileView(model: ProfileViewModel(user: user),
                                                        presentedInSheet: true)
            )
            vc.view.backgroundColor = .clear
            UIApplication.shared.topViewController?.present(vc, animated: true)
            Analytics.logEvent("Blocked - view profile from cell", screenName, .buttonTap)
        }
    }
}

/// Section within FriendManagerView that shows a table of blocked users
struct BlockedTable: View {
    @StateObject var model: BlockedTableModel = BlockedTableModel()

    var hasData: Bool {
        return !model.user.blockedIDs.isEmpty
    }

    var body: some View {
        let sideInsets = EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15)

        ZStack {
            ZStack {
                List {
                    ForEach(model.blockedUsers.enumerated().map { $0 }, id: \.element) { (idx, user) in
                        BlockedTableViewCell(model: model,
                                             user: user,
                                             idx: idx,
                                             arrayCount: model.user.blockedIDs.count)
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

                AndiEmptyState(text: "No blocked users! Block a user by going to their profile, tapping the menu at the top right, and tapping \"Block\"")
                    .opacity(hasData ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: hasData)
            }
        }
    }
}

/// Model for BlockedTable
class BlockedTableModel: NSObject, ObservableObject {
    @Published var user = ADUser.current
    @Published var blockedUsers: [ADUser] = []

    private var subscribers: Set<AnyCancellable> = []

    override init() {
        super.init()
        user.$blockedIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadBlockedUsers()
            }
            .store(in: &subscribers)

        loadBlockedUsers()
    }

    func loadBlockedUsers() {
        var cachedLoadedBlockedUsers: [ADUser] = []
        var blockedIDsToQuery: [ADUser.ID] = []

        for blockedUserID in user.blockedIDs {
            if let cachedUser = UserCache.shared.user(forID: blockedUserID) {
                cachedLoadedBlockedUsers.append(cachedUser)
            } else {
                blockedIDsToQuery.append(blockedUserID)
            }
        }

        self.blockedUsers = cachedLoadedBlockedUsers.sortedByUsername

        let blockedIDs = blockedIDsToQuery
        Task(priority: .high) {
            guard let loadedBlockedUsers = try? await UserManager.shared.getUsers(byCanonicalIDs: blockedIDs) else {
                return
            }

            await MainActor.run {
                self.blockedUsers = (self.blockedUsers + loadedBlockedUsers).sortedByUsername
            }
        }
    }

    func unblockUser(with id: ADUser.ID) {
        Task(priority: .userInitiated) {
            let user = blockedUsers.first(where: { $0.id == id })
            do {
                try await UserManager.shared.unblockUser(with: id)
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showSuccessToast(withTitle: "Unblocked @\(user?.username ?? "")!", bottomInset: 20.0)
                }
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }
}

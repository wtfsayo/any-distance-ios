// Licensed under the Any Distance Source-Available License
//
//  RequestsTable.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/13/23.
//

import SwiftUI
import Combine

/// Cell view that shows a given friend request with an accept, deny, or cancel button
fileprivate struct RequestTableViewCell: View {
    enum RequestType {
        case sent
        case received
    }

    @ObservedObject var model: RequestsTableModel
    var friendship: Friendship
    var requestType: RequestType
    @State var user: ADUser?
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

    private var userID: String {
        return requestType == .sent ? friendship.targetUserID : friendship.requestingUserID
    }

    var acceptButton: some View {
        Button {
            model.acceptRequest(friendship)
            Analytics.logEvent("Accept request tapped", screenName, .buttonTap)
        } label: {
            Text("Accept")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.white)
                .padding([.top, .bottom], 9)
                .padding([.leading, .trailing], 12)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .foregroundColor(Color.adDarkGreen)
                }
        }
        .buttonStyle(PlainButtonStyle())
    }

    var denyButton: some View {
        Button {
            model.denyOrCancelRequest(friendship)
            Analytics.logEvent("Deny request tapped", screenName, .buttonTap)
        } label: {
            Text("Deny")
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

    var cancelButton: some View {
        Button {
            model.denyOrCancelRequest(friendship)
            Analytics.logEvent("Cancel request tapped", screenName, .buttonTap)
        } label: {
            Text("Cancel")
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
            UserTableViewCell(profilePictureURL: user?.profilePhotoUrl,
                              nameText: user?.name ?? "",
                              subtitleText: "@\(user?.username ?? "")",
                              type: cellType(for: idx)) {
                ZStack {
                    switch requestType {
                    case .sent:
                        cancelButton
                    case .received:
                        HStack {
                            denyButton
                            acceptButton
                        }
                    }
                }
            }
        }
        .onAppear {
            if let cachedUser = UserCache.shared.user(forID: userID) {
                self.user = cachedUser
            } else {
                Task {
                    self.user = try? await UserManager.shared.getUsers(byCanonicalIDs: [userID]).first
                }
            }
        }
        .onTapGesture {
            guard let adUser = user else {
                return
            }

            let vc = UIHostingController(rootView:
                ProfileView(model: ProfileViewModel(user: adUser),
                            presentedInSheet: true)
            )
            vc.view.backgroundColor = .clear
            UIApplication.shared.topViewController?.present(vc, animated: true)
            Analytics.logEvent("Requests - view profile from cell", screenName, .buttonTap)
        }
    }
}

/// Section within FriendManagerView that shows pending friend requests (sent and received)
struct RequestsTable: View {
    @StateObject var model: RequestsTableModel = RequestsTableModel()

    var hasData: Bool {
        return !model.sentRequests.isEmpty || !model.receivedRequests.isEmpty
    }

    var body: some View {
        let sideInsets = EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15)

        ZStack {
            List {
                if !model.receivedRequests.isEmpty {
                    SectionHeaderText(text: "Received")
                        .listRowBackground(EmptyView())
                        .listRowSeparator(.hidden)
                        .listRowInsets(sideInsets)
                    ForEach(model.receivedRequests.enumerated().map { $0 },
                            id: \.element.id) { (idx, friendship) in
                        RequestTableViewCell(model: model,
                                             friendship: friendship,
                                             requestType: .received,
                                             idx: idx,
                                             arrayCount: model.receivedRequests.count)
                        .listRowBackground(EmptyView())
                        .listRowSeparator(.hidden)
                        .listRowInsets(sideInsets)
                        .drawingGroup()
                    }
                }

                if !model.sentRequests.isEmpty {
                    SectionHeaderText(text: "Sent")
                        .listRowBackground(EmptyView())
                        .listRowSeparator(.hidden)
                        .listRowInsets(sideInsets)
                    ForEach(model.sentRequests.enumerated().map { $0 },
                            id: \.element.id) { (idx, friendship) in
                        RequestTableViewCell(model: model,
                                             friendship: friendship,
                                             requestType: .sent,
                                             idx: idx,
                                             arrayCount: model.sentRequests.count)
                        .listRowBackground(EmptyView())
                        .listRowSeparator(.hidden)
                        .listRowInsets(sideInsets)
                        .drawingGroup()
                    }
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

            AndiEmptyState(text: "No sent or received requests yet!")
                .opacity(hasData ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: hasData)
        }
    }
}

/// Model for RequestsTable
class RequestsTableModel: NSObject, ObservableObject {
    @Published var receivedRequests: [Friendship] = []
    @Published var sentRequests: [Friendship] = []

    private var subscribers: Set<AnyCancellable> = []

    func acceptRequest(_ friendship: Friendship) {
        UIApplication.shared.topViewController?.showSuccessToast(withTitle: "Request approved!",
                                                                 actionHandler: {
            guard let user = UserCache.shared.user(forID: friendship.requestingUserID) else {
                return
            }

            let hostingView = UIHostingController(rootView: ProfileView(model: ProfileViewModel(user: user),
                                                                        presentedInSheet: true))
            DispatchQueue.main.async {
                UIApplication.shared.topViewController?.present(hostingView, animated: true)
            }
        })

        Task(priority: .userInitiated) {
            do {
                try await UserManager.shared.approveFriendRequest(friendship)
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    func denyOrCancelRequest(_ friendship: Friendship) {
        Task(priority: .userInitiated) {
            do {
                try await UserManager.shared.deleteFriendRequest(with: friendship.id)
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    override init() {
        super.init()
        ADUser.current.$friendships
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.receivedRequests = ADUser.current.receivedRequests
                self?.sentRequests = ADUser.current.sentRequests
            }
            .store(in: &subscribers)
    }
}

// Licensed under the Any Distance Source-Available License
//
//  SuggestedTable.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/13/23.
//

import SwiftUI
import Contacts
import SwiftRichString
import SwiftUIX

/// Cell view that shows a given FriendFinderUser (contact or AD user)
struct SuggestedTableViewCell: View {
    @StateObject var model: FriendFinderViewModel
    @StateObject var friend: FriendFinderUser
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

    var body: some View {
        UserTableViewCell(profilePicture: friend.contactProfilePhoto,
                          profilePictureURL: friend.adUser?.profilePhotoUrl,
                          nameText: friend.adUser?.name ?? friend.name,
                          subtitleText: friend.cellSubtitleText(),
                          type: cellType(for: idx)) {
            AddButton(buttonAction: {
                switch friend.friendState {
                case .added:
                    break //
                case .notAdded:
                    Analytics.logEvent("Add tapped", screenName, .buttonTap)
                    model.sendFriendRequest(toFriend: friend)
                case .notInvited:
                    Analytics.logEvent("Invite tapped", screenName, .buttonTap)
                    model.sendInvite(toFriend: friend)
                case .invited:
                    break
                }
            }, state: friend.friendState)
        }
        .onTapGesture {
            guard let adUser = friend.adUser else {
                return
            }

            let vc = UIHostingController(rootView:
                ProfileView(model: ProfileViewModel(user: adUser),
                                                    presentedInSheet: true)
            )
            vc.view.backgroundColor = .clear
            UIApplication.shared.topViewController?.present(vc, animated: true)
            Analytics.logEvent("Suggested - view profile from cell", screenName, .buttonTap)
        }
    }
}

/// Button accessory for UserTableViewCell that adds a user on AD as a friend
fileprivate struct AddButton: View {
    var buttonAction: () -> Void
    var state: FriendState = .notAdded
    var isLoading: Bool = false

    var body: some View {
        Button(action: buttonAction) {
            ZStack {
                if isLoading {
                    ProgressView()
                } else {
                    HStack(spacing: 3) {
                        Text(state.buttonText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(state.buttonTextColor)
                            .fixedSize(horizontal: true, vertical: false)
                        if let buttonSymbolName = state.buttonSymbolName {
                            Image(systemName: buttonSymbolName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .font(.system(size: 17, weight: .bold))
                                .frame(width: 8, height: 8)
                                .foregroundColor(state.buttonTextColor)
                        }
                    }
                    .padding([.top, .bottom], 9)
                    .padding([.leading, .trailing], 12)
                    .background {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .foregroundColor(state.buttonBackgroundColor)
                    }
                }
            }
        }
        .id(state.rawValue + (isLoading ? 5 : 6))
        .modifier(BlurOpacityTransition())
        .buttonStyle(PlainButtonStyle())
    }
}

/// Cell that prompts users to invite 10 contacts to redeem an AD performance shirt. Contains a progress
/// bar that shows how close the user is to earning the shirt
fileprivate struct PerformanceShirtPromotion: View {
    let numInvitesRequired: Int = 10
    @State private var numInvitedFriends: Int = 0
    @State private var invitesRemaining: Int = 0

    private func updateInvites() {
        numInvitedFriends = NSUbiquitousKeyValueStore.default.invitedPhoneNumbers.count
        invitesRemaining = max(numInvitesRequired - numInvitedFriends, 0)
    }

    var inviteText: String {
        if invitesRemaining > 0 {
            return "Invite \(invitesRemaining) more friends to Any Distance and earn a limited edition performance t-shirt."
        } else {
            return "Thanks for inviting \(numInvitesRequired) friends to Any Distance!"
        }
    }

    var progressBar: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .foregroundColor(Color(hexadecimal: "0D3B00"))
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(LinearGradient(colors: [
                            Color(hexadecimal: "027307"),
                            Color(hexadecimal: "36C603"),
                            Color(hexadecimal: "B7FB69")
                        ], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * (CGFloat(numInvitedFriends) / CGFloat(numInvitesRequired)).clamped(to: 0...1))
                        .shadow(color: Color(hexadecimal: "30D158"), radius: 6.0)
                    Spacer()
                        .minWidth(0.0)
                }
            }
            .frame(height: 5.0)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16.0, style: .continuous)
                .foregroundColor(.white)
                .opacity(0.1)

            HStack {
                VStack(alignment: .leading, spacing: 5.0) {
                    Text("Andi Moves")
                        .font(.system(size: 19, weight: .semibold))
                    Text(inviteText)
                        .font(.system(size: 13))
                        .lineLimit(10)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if invitesRemaining == 0 {
                        Button {
                            UIApplication.shared.topViewController?
                                .openUrl(withString: Links.redeemAndiMovesReward.absoluteString)
                            Analytics.logEvent("Redeem Reward tapped", "Friend Manager", .buttonTap)
                        } label: {
                            HStack(spacing: 2.0) {
                                Text("Redeem Reward")
                                    .font(.system(size: 13.0, weight: .semibold))
                                Image(systemName: .arrowRight)
                                    .font(.system(size: 13.0, weight: .bold))
                                    .foregroundColor(Color(hexadecimal: "30D158"))
                            }
                            .padding(4.0)
                            .contentShape(Rectangle())
                        }
                        .offset(x: -4.0, y: -2.0)
                    }

                    progressBar
                        .if(invitesRemaining > 0) { view in
                            view.padding(.top, 6.0)
                        }
                }

                Spacer()
                    .frame(width: 130.0)
            }
            .padding([.leading, .trailing], 20.0)
            .padding([.top, .bottom], 18.0)
            .background {
                HStack {
                    Spacer()
                    Image("performance_shirt")
                        .offset(x: 30, y: 30)
                }
            }
            .mask {
                RoundedRectangle(cornerRadius: 16.0, style: .continuous)
            }
        }
        .onAppear {
            updateInvites()
        }
        .onReceive(ReloadPublishers.friendInvited) { _ in
            updateInvites()
        }
    }
}

/// Table that shows contacts on any distance, friends of contacts, contacts not on any distance,
/// or team AD members if there are no contacts on AD
fileprivate struct SuggestedTable: View {
    @ObservedObject var model: FriendFinderViewModel
    @StateObject var friendFinderAPI: FriendFinderAPI = FriendFinderAPI.shared

    var modelHasLoaded: Bool {
        return !friendFinderAPI.contactsOnAnyDistance.isEmpty ||
               !friendFinderAPI.friendsOfContacts.isEmpty ||
               !friendFinderAPI.contactsNotOnAnyDistance.isEmpty
    }

    var body: some View {
        let contactsOnAnyDistance = friendFinderAPI.contactsOnAnyDistance.enumerated().map { $0 }
        let friendsOfContacts = friendFinderAPI.friendsOfContacts.enumerated().map { $0 }
        let contactsNotOnAnyDistance = friendFinderAPI.contactsNotOnAnyDistance.enumerated().map { $0 }
        let teamAnyDistance = friendFinderAPI.teamAnyDistance.enumerated().map { $0 }
        let sideInsets = EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15)

        List {
            if !teamAnyDistance.isEmpty && contactsOnAnyDistance.isEmpty && friendsOfContacts.isEmpty {
                SectionHeaderText(text: "Team Any Distance")
                    .listRowBackground(EmptyView())
                    .listRowSeparator(.hidden)
                    .listRowInsets(sideInsets)
                    .padding(.top, 16)
                    .padding(.bottom, 5)

                ForEach(teamAnyDistance,
                        id: \.element.id) { idx, friend in
                    SuggestedTableViewCell(model: model,
                                           friend: friend,
                                           idx: idx,
                                           arrayCount: teamAnyDistance.count)
                    .listRowBackground(EmptyView())
                    .listRowSeparator(.hidden)
                    .listRowInsets(sideInsets)
                    .drawingGroup()
                }
            }

            if !contactsOnAnyDistance.isEmpty || !friendsOfContacts.isEmpty {
                SectionHeaderText(text: "On Any Distance")
                    .listRowBackground(EmptyView())
                    .listRowSeparator(.hidden)
                    .listRowInsets(sideInsets)
                    .padding(.top, 16)
                    .padding(.bottom, 5)
            }

            if !contactsOnAnyDistance.isEmpty {
                ForEach(contactsOnAnyDistance,
                        id: \.element.id) { idx, friend in
                    SuggestedTableViewCell(model: model,
                                           friend: friend,
                                           idx: idx,
                                           arrayCount: contactsOnAnyDistance.count + friendsOfContacts.count)
                    .listRowBackground(EmptyView())
                    .listRowSeparator(.hidden)
                    .listRowInsets(sideInsets)
                    .drawingGroup()
                }
            }

            if !friendsOfContacts.isEmpty {
                ForEach(friendsOfContacts,
                        id: \.element.id) { idx, friend in
                    SuggestedTableViewCell(model: model,
                                           friend: friend,
                                           idx: contactsOnAnyDistance.count + idx,
                                           arrayCount: contactsOnAnyDistance.count + friendsOfContacts.count)
                    .listRowBackground(EmptyView())
                    .listRowSeparator(.hidden)
                    .listRowInsets(sideInsets)
                    .drawingGroup()
                }
            }

            SectionHeaderText(text: "Earn invite rewards")
                .listRowBackground(EmptyView())
                .listRowSeparator(.hidden)
                .listRowInsets(sideInsets)
                .padding(.top, 16)
                .padding(.bottom, 5)
            PerformanceShirtPromotion()
                .listRowBackground(EmptyView())
                .listRowSeparator(.hidden)
                .listRowInsets(sideInsets)

            if !contactsNotOnAnyDistance.isEmpty {
                SectionHeaderText(text: "Invite your friends")
                    .listRowBackground(EmptyView())
                    .listRowSeparator(.hidden)
                    .listRowInsets(sideInsets)
                    .padding(.top, 16)
                    .padding(.bottom, 5)
                ForEach(contactsNotOnAnyDistance,
                        id: \.element.id) { idx, friend in
                    SuggestedTableViewCell(model: model,
                                           friend: friend,
                                           idx: idx,
                                           arrayCount: contactsNotOnAnyDistance.count)
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
        .opacity(modelHasLoaded ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: modelHasLoaded)
    }
}

/// Empty state that displays within SearchTable if there are no results and user hasn't granted
/// contacts permission
fileprivate struct SearchContactsEmptyState: View {
    @ObservedObject var friendFinderModel: FriendFinderViewModel
    @StateObject var friendFinderAPI: FriendFinderAPI = FriendFinderAPI.shared

    var modelHasLoaded: Bool {
        return !friendFinderAPI.teamAnyDistance.isEmpty
    }

    var body: some View {
        VStack {
            let teamAnyDistance = friendFinderAPI.teamAnyDistance.enumerated().map { $0 }
            let sideInsets = EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15)

            List {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Try your contacts")
                            .font(.system(size: 17, weight: .bold))
                            .padding(.bottom, 4)
                        Text("Find friends already using Any Distance by searching your contacts.")
                            .font(.system(size: 14))
                        Button {
                            friendFinderModel.requestPermissionsAndLoad()
                        } label: {
                            HStack(spacing: 2) {
                                Text("Search")
                                Image(systemName: .magnifyingglass)
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding([.top, .bottom], 8)
                            .padding([.leading, .trailing], 11)
                            .background {
                                RoundedRectangle(cornerRadius: 30)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .foregroundColor(.white)

                    Spacer()

                    Image("try_contacts_hero")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 132, height: 132)
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .foregroundColor(.white)
                        .opacity(0.1)
                }
                .listRowBackground(EmptyView())
                .listRowSeparator(.hidden)
                .listRowInsets(sideInsets)
                .drawingGroup()

                if !teamAnyDistance.isEmpty {
                    SectionHeaderText(text: "Team Any Distance")
                        .listRowBackground(EmptyView())
                        .listRowSeparator(.hidden)
                        .listRowInsets(sideInsets)
                        .padding(.top, 16)
                        .padding(.bottom, 5)

                    ForEach(teamAnyDistance,
                            id: \.element.id) { idx, friend in
                        SuggestedTableViewCell(model: friendFinderModel,
                                               friend: friend,
                                               idx: idx,
                                               arrayCount: teamAnyDistance.count)
                        .listRowBackground(EmptyView())
                        .listRowSeparator(.hidden)
                        .listRowInsets(sideInsets)
                        .drawingGroup()
                    }
                }

                Spacer()
                    .frame(height: 400)
                    .listRowBackground(EmptyView())
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .background(Color.clear)
            .opacity(modelHasLoaded ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: modelHasLoaded)
        }
    }
}

/// Table that loads and displays users on AD from a given search term
fileprivate struct SearchTable: View {
    @ObservedObject var friendFinderModel: FriendFinderViewModel
    @Binding var searchText: String
    @State var users: [FriendFinderUser] = []
    @State var contacts: [FriendFinderUser] = []
    @State var isSearching: Bool = false

    private func search() {
        isSearching = true
        let originalSearchText = searchText
        let filteredSearchText = searchText.replacingOccurrences(of: "@", with: "")
        self.contacts = FriendFinderAPI.shared.contactsNotOnAnyDistance.filter { $0.name.lowercased().contains(filteredSearchText.lowercased()) }

        Task(priority: .userInitiated) {
            do {
                let users = try await FriendFinderAPI.shared.searchUsers(by: filteredSearchText)
                await MainActor.run {
                    if searchText == originalSearchText {
                        self.users = users
                    }
                }
            } catch {}

            await MainActor.run {
                isSearching = false
            }
        }
    }

    var body: some View {
        let sideInsets = EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15)
        let enumeratedUsers = users.enumerated().map { $0 }
        let enumeratedContacts = contacts.enumerated().map { $0 }

        ZStack {
            if users.isEmpty && contacts.isEmpty {
                if isSearching {
                    VStack {
                        HStack {
                            Spacer()
                            ProgressView()
                                .frame(height: 100)
                                .modifier(BlurOpacityTransition(speed: 1.5))
                            Spacer()
                        }
                        Spacer()
                    }
                } else if CNContactStore.authorizationStatus(for: .contacts) != .authorized {
                    VStack {
                        SearchContactsEmptyState(friendFinderModel: friendFinderModel)
                            .padding(.top, 30)
                            .modifier(BlurOpacityTransition(speed: 1.5))
                        Spacer()
                    }
                } else {
                    VStack {
                        AndiEmptyState(text: "No results")
                            .padding(.top, 30)
                            .modifier(BlurOpacityTransition(speed: 1.5))
                        Spacer()
                    }
                }
            } else {
                List {
                    if !users.isEmpty {
                        SectionHeaderText(text: "On Any Distance")
                            .listRowBackground(EmptyView())
                            .listRowSeparator(.hidden)
                            .listRowInsets(sideInsets)
                            .padding(.top, 16)
                            .padding(.bottom, 5)
                        ForEach(enumeratedUsers, id: \.element.id) { idx, user in
                            SuggestedTableViewCell(model: friendFinderModel,
                                                   friend: user,
                                                   idx: idx,
                                                   arrayCount: enumeratedUsers.count)
                            .listRowBackground(EmptyView())
                            .listRowSeparator(.hidden)
                            .listRowInsets(sideInsets)
                            .drawingGroup()
                        }
                    }

                    if !contacts.isEmpty {
                        SectionHeaderText(text: "Invite your friends")
                            .listRowBackground(EmptyView())
                            .listRowSeparator(.hidden)
                            .listRowInsets(sideInsets)
                            .padding(.top, 16)
                            .padding(.bottom, 5)
                        ForEach(enumeratedContacts, id: \.element.id) { idx, user in
                            SuggestedTableViewCell(model: friendFinderModel,
                                                   friend: user,
                                                   idx: idx,
                                                   arrayCount: enumeratedContacts.count)
                            .listRowBackground(EmptyView())
                            .listRowSeparator(.hidden)
                            .listRowInsets(sideInsets)
                            .drawingGroup()
                        }
                    }

                    Spacer()
                        .frame(height: 400)
                        .listRowBackground(EmptyView())
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .id(users.isEmpty ? 1 : 0)
        .modifier(BlurOpacityTransition(speed: 1.5))
        .onChange(of: searchText) { newValue in
            search()
        }
        .onAppear {
            search()
        }
    }
}

/// Empty state that shows if user hasn't authorized contacts permission
struct ContactsUnauthorizedEmptyState: View {
    @ObservedObject var friendFinderModel: FriendFinderViewModel
    @StateObject var friendFinderAPI: FriendFinderAPI = FriendFinderAPI.shared

    var body: some View {
        VStack {
            let teamAnyDistance = friendFinderAPI.teamAnyDistance.enumerated().map { $0 }
            let sideInsets = EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15)

            List {
                HStack {
                    Spacer()
                    VStack(spacing: -20) {
                        Image("onboarding_contacts_search")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 260, height: 260)
                        Text("Search for your friends via their name or @username.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding([.leading, .trailing], 50)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(.bottom, 16)
                .listRowBackground(EmptyView())
                .listRowSeparator(.hidden)
                .listRowInsets(sideInsets)
                .drawingGroup()

                if !teamAnyDistance.isEmpty {
                    SectionHeaderText(text: "Team Any Distance")
                        .listRowBackground(EmptyView())
                        .listRowSeparator(.hidden)
                        .listRowInsets(sideInsets)
                        .padding(.top, 16)
                        .padding(.bottom, 5)
                        .modifier(BlurOpacityTransition(speed: 1.5))

                    ForEach(teamAnyDistance,
                            id: \.element.id) { idx, friend in
                        SuggestedTableViewCell(model: friendFinderModel,
                                               friend: friend,
                                               idx: idx,
                                               arrayCount: teamAnyDistance.count)
                        .listRowBackground(EmptyView())
                        .listRowSeparator(.hidden)
                        .listRowInsets(sideInsets)
                        .drawingGroup()
                        .modifier(BlurOpacityTransition(speed: 1.5))
                    }
                }

                Spacer()
                    .frame(height: 400)
                    .listRowBackground(EmptyView())
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }
}

/// Section within FriendManager view that shows a table of suggested uers – contacts, users on AD,
/// friends of friends
struct SuggestedView: View {
    @ObservedObject var friendFinderModel: FriendFinderViewModel
    @State var searchText: String = ""

    var body: some View {
        ZStack {
            VStack {
                SearchField(text: $searchText)
                    .placeholder("Search by full name or @username")
                    .padding([.leading, .trailing], 8)
                Spacer()
            }

            ZStack {
                if searchText.isEmpty {
                    if CNContactStore.authorizationStatus(for: .contacts) != .authorized {
                        ContactsUnauthorizedEmptyState(friendFinderModel: friendFinderModel)
                            .modifier(BlurOpacityTransition(speed: 1.5))
                    } else {
                        SuggestedTable(model: friendFinderModel)
                            .modifier(BlurOpacityTransition(speed: 1.5))
                    }
                } else {
                    SearchTable(friendFinderModel: friendFinderModel,
                                searchText: $searchText)
                    .modifier(BlurOpacityTransition(speed: 1.5))
                }
            }
            .edgesIgnoringSafeArea(.bottom)
            .mask {
                LinearGradient(colors: [.clear, .black],
                               startPoint: .top,
                               endPoint: UnitPoint(x: 0.5, y: 0.02))
            }
            .padding(.top, 56)
        }
    }
}
